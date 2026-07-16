#!/usr/bin/env sh
# Single-target lha benchmark.
#
# Usage:
#   BENCH_BIN=path/to/lha [BENCH_N=5] [BENCH_LABEL=local] bash scripts/bench.sh
#
# Output: a small text envelope that the test-report composer
# (`scripts/test-report-compose.sh`) parses into a markdown table.
#
#   line 1  : "label=<label> n=<N> input_bytes=<n>"  — meta
#   line 2  : "# per-iter samples (op iter seconds)"  — header
#   next 3N : "op iter seconds"   — raw samples per (op, iter)
#   next..  : "# summary" + "size_in\t<n>" + "size_lzh\t<n>" + "ratio\t<f>"
#
# Stats aggregation (median, stddev) happens in the composer —
# keeping this script a thin, fixed-format emitter makes it easy to
# swap data sources later (CI artifact upload, ad-hoc bench runs,
# future in-process timing in tests).
#
# Portability notes:
#   - `stat -c%s` (GNU) vs `stat -f%z` (BSD/macOS): hand-rolled fallback
#   - `date +%s.%N`: works on GNU coreutils + macOS 14+ BSD date +
#     Alpine busybox. Falls back to integer seconds on missing %N.
#   - Random bytes via POSIX `awk srand(42) ... printf "%c"` — no
#     /dev/urandom needed (BusyBox lacks it on minimal Alpine).

set -eu

BIN="${BENCH_BIN:?set BENCH_BIN=path/to/lha binary}"
N="${BENCH_N:-5}"
LABEL="${BENCH_LABEL:-local}"

size_of() {
	# GNU stat uses -c%s; BSD stat uses -f%z. Try GNU first.
	if stat -c%s "$1" >/dev/null 2>&1; then
		stat -c%s "$1"
	else
		stat -f%z "$1"
	fi
}

now() {
	# GNU + macOS-14+ BSD + BusyBox modern all support %N.
	# Old macOS / very old BusyBox fall back to whole seconds.
	date +%s.%N 2>/dev/null && return 0
	date +%s
}

# 1 MiB seeded-random blob (deterministic across platforms so the
# compression ratio comparison is apples-to-apples).
gen_blob() {
	awk 'BEGIN {
		srand(42)
		for (i = 0; i < 1048576; i++) printf "%c", int(rand() * 256)
	}'
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

gen_blob > "$TMP/blob"
size_in=$(size_of "$TMP/blob")

# Pre-create archive for x and l ops (also gives us size_lzh for ratio).
"$BIN" c "$TMP/blob.lzh" "$TMP/blob" >/dev/null
size_lzh=$(size_of "$TMP/blob.lzh")
ratio=$(awk -v i="$size_in" -v o="$size_lzh" 'BEGIN { printf "%.3f", o / i }')

echo "label=$LABEL n=$N input_bytes=$size_in"
echo "# per-iter samples (op iter seconds)"

for op in c x l; do
	iter=1
	while [ "$iter" -le "$N" ]; do
		case "$op" in
		c)
			rm -f "$TMP/blob.lzh"
			t0=$(now)
			"$BIN" c "$TMP/blob.lzh" "$TMP/blob" >/dev/null
			t1=$(now)
			;;
		x)
			rm -f "$TMP/blob.out"
			t0=$(now)
			( cd "$TMP" && "$BIN" xq blob.lzh >/dev/null )
			t1=$(now)
			;;
		l)
			t0=$(now)
			"$BIN" l "$TMP/blob.lzh" >/dev/null
			t1=$(now)
			;;
		esac
		awk -v s="$t0" -v e="$t1" -v o="$op" -v i="$iter" \
			'BEGIN { printf "%s %d %.4f\n", o, i, e - s }'
		iter=$((iter + 1))
	done
done

echo "# summary"
echo -e "size_in\t$size_in"
echo -e "size_lzh\t$size_lzh"
echo -e "ratio\t$ratio"
