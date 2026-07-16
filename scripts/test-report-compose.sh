#!/usr/bin/env sh
# Compose the test-report markdown for the GitHub Issue body.
#
# Run by the report job in `.github/workflows/test-report.yml` after
# it downloads:
#   - per-target `test-results-<target>/{bench.txt,smoke.log}`
#   - optional `<target>.release.{sha256,zip}` from `gh release download`
#
# Output: a fully-formed GitHub markdown document to stdout, ready to
# pipe into `gh issue create --body-file -`.
#
# Pure POSIX sh + awk (no bash, no jq). Pass `-h` to see options.
#
# Usage:
#   RELEASE_TAG=v0.6.0 \
#   RESULTS_DIR=$PWD/results \
#   ASSETS_DIR=$PWD/release-assets \
#   bash scripts/test-report-compose.sh > issue-body.md

set -eu

usage() {
	cat >&2 <<'EOF'
Usage: RELEASE_TAG=vX.Y.Z \
       RESULTS_DIR=path/to/artifacts \
       [ASSETS_DIR=path/to/release-assets] \
       bash scripts/test-report-compose.sh

Env:
  RELEASE_TAG  (required)   e.g. v0.6.0 — release tag being reported on
  RESULTS_DIR  (required)   dir with per-target subdirs (test-results-<target>/)
  ASSETS_DIR   (optional)   dir with release assets for SHA256 + §2.a shape check;
                            pass empty to skip the bundle-integrity section
  RUN_URL      (optional)   URL of the workflow run (for the footer link)
  SHA          (optional)   commit SHA being tested (footer)
EOF
	exit 2
}

[ "${1:-}" != "-h" ] || usage
[ -n "${RELEASE_TAG:-}" ]  || { echo "RELEASE_TAG is required" >&2; usage; }
[ -n "${RESULTS_DIR:-}" ]  || { echo "RESULTS_DIR is required" >&2; usage; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

TARGETS="x86_64-linux-musl aarch64-linux-musl x86_64-macos aarch64-macos x86_64-windows"
SHA="${SHA:-${GITHUB_SHA:-unknown}}"
RUN_URL="${RUN_URL:-${GITHUB_RUN_URL:-}}"
RUN_NO="${RUN_NO:-${GITHUB_RUN_NUMBER:-}}"

# Pretty date (UTC) — works on GNU + macOS + Alpine date(1) for %Y-%m-%d.
DATE="$(date -u +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

# Portable stat (input bytes already in bench.txt; used here only if
# we end up computing ratios ourselves — keeps the helpers consistent).
size_of() {
	if stat -c%s "$1" >/dev/null 2>&1; then
		stat -c%s "$1"
	else
		stat -f%z "$1"
	fi
}

# --- aggregation helpers ---------------------------------------------------
# Both stats work on stdin, one number per line; output is one number.
median() {
	sort -n | awk '
		{ a[NR] = $1; n = NR }
		END {
			if (n == 0) { print "n/a"; exit }
			if (n % 2 == 1) printf "%.4f", a[(n + 1) / 2]
			else            printf "%.4f", (a[n / 2] + a[n / 2 + 1]) / 2
		}
	'
}

stddev() {
	awk '
		{ a[NR] = $1; sum += $1; sq += $1 * $1 }
		END {
			n = NR
			if (n < 2) { print "0.0000"; exit }
			mean = sum / n
			var = (sq - n * mean * mean) / (n - 1)
			if (var < 0) var = 0
			printf "%.4f", sqrt(var)
		}
	'
}

# --- per-target data collectors ---------------------------------------------

# Layout under $RESULTS_DIR: each per-target artifact is a subdir
# named after the artifact (test-results-<target>/). The per-target
# workflow stages files under stage/<target>/ and uploads that
# directory; actions/upload-artifact@v4 with `path: stage/` zips the
# CONTENTS, so the artifact unzipes to:
#   $RESULTS_DIR/test-results-<target>/<target>/bench.txt
#   $RESULTS_DIR/test-results-<target>/<target>/smoke.log
T_BENCH() { echo "$RESULTS_DIR/test-results-$1/$1/bench.txt"; }
T_SMOKE() { echo "$RESULTS_DIR/test-results-$1/$1/smoke.log"; }

# Smaller wrapper: bench_stat2 target op median|stddev
bench_stat2() {
	_target="$1" _op="$2" _stat="$3"
	_b="$(T_BENCH "$_target")"
	[ -f "$_b" ] || { echo 'n/a'; return; }
	awk -v op="$_op" '$1 == op {print $3}' "$_b" > "$WORK/samples.$$"
	[ -s "$WORK/samples.$$" ] || { echo 'n/a'; rm -f "$WORK/samples.$$"; return; }
	case "$_stat" in
	median) sort -n "$WORK/samples.$$" | median ;;
	stddev) stddev < "$WORK/samples.$$" ;;
	esac
	rm -f "$WORK/samples.$$"
}

# Smoke outcome for $TARGET — looks for "smoke OK" line.
smoke_outcome() {
	_t="$1"
	_l="$(T_SMOKE "$_t")"
	[ -f "$_l" ] || { echo '—missing—'; return; }
	if grep -qE '^smoke OK' "$_l"; then
		echo 'PASS'
	elif grep -qE '^FAIL: ' "$_l"; then
		echo 'FAIL'
	elif grep -qiE 'informational|WINDOWS|continue-on-error' "$_l"; then
		echo 'INFO'
	else
		echo 'UNKNOWN'
	fi
}

# Count of upstream lha-testN tests passed/total in smoke.log.
# Each upstream test prints lines like "lha-testN #M ... ok" or
# "lha-testN ... ok"; we count unique test numbers with any "ok" line.
smoke_test_count() {
	_t="$1"
	_l="$(T_SMOKE "$_t")"
	[ -f "$_l" ] || { echo '0/0'; return; }
	# pass = unique lha-testN values that have at least one ok line
	pass=$(grep -oE '^lha-test[0-9]+ .*\bok\b' "$_l" \
		| grep -oE '^lha-test[0-9]+' | sort -u | wc -l | tr -d ' ')
	# fail = unique lha-testN values that have an ok line + at least one FAIL/Failed line
	fail_count=$(grep -oE '^lha-test[0-9]+ .*\b(FAIL|Failed)\b' "$_l" \
		| grep -oE '^lha-test[0-9]+' | sort -u | wc -l | tr -d ' ')
	# total = from header "lha-test1..19"
	total=$(grep -oE 'lha-test[0-9]+\.\.[0-9]+' "$_l" \
		| head -1 | sed -E 's/^lha-test([0-9]+)\.\.([0-9]+)/\2/')
	[ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null \
		&& echo "${pass:-0}/${total}" \
		|| echo '—'
}

# Bundle shape check on a release asset. $1 = asset (path or '-' for skip).
bundle_shape_row() {
	_asset="$1" _tg="$2"
	[ "$_asset" = "-" ] && { echo "$_tg|no|—|—|—"; return; }
	[ -f "$_asset" ] || { echo "$_tg|no|missing|missing|missing"; return; }
	# verify §2.a shape: src/lha/, LICENSE, TAKEDOWN.md, README.md, man/, bin/
	case "$_asset" in
	*.tar.xz)
		_l=$(tar tJf "$_asset" 2>/dev/null | grep -cE '/LICENSE$')
		_t=$(tar tJf "$_asset" 2>/dev/null | grep -cE '/TAKEDOWN\.md$')
		_r=$(tar tJf "$_asset" 2>/dev/null | grep -cE '/README\.md$')
		_s=$(tar tJf "$_asset" 2>/dev/null | grep -cE '^[^/]+/src/lha/')
		_b=$(tar tJf "$_asset" 2>/dev/null | grep -cE '/bin/lha$')
		_m=$(tar tJf "$_asset" 2>/dev/null | grep -cE '/man/man1/lha\.1$')
		;;
	*.zip)
		_l=$(unzip -l "$_asset" 2>/dev/null | grep -cE '(^|\s)LICENSE\s*$')
		_t=$(unzip -l "$_asset" 2>/dev/null | grep -cE '(^|\s)TAKEDOWN\.md\s*$')
		_r=$(unzip -l "$_asset" 2>/dev/null | grep -cE '(^|\s)README\.md\s*$')
		_s=$(unzip -l "$_asset" 2>/dev/null | grep -cE 'src\\lha\\')
		_b=$(unzip -l "$_asset" 2>/dev/null | grep -cE 'bin\\lha\.exe\s*$')
		_m=$(unzip -l "$_asset" 2>/dev/null | grep -cE 'man\\man1\\lha\.1\s*$')
		;;
	*)
		echo "$_tg|no|unsupported|—|—"
		return
		;;
	esac
	flag=yes
	[ "$_l" -ge 1 ] && [ "$_t" -ge 1 ] && [ "$_r" -ge 1 ] && [ "$_s" -ge 1 ] && [ "$_b" -ge 1 ] && [ "$_m" -ge 1 ] || flag=no
	echo "$_tg|$flag|$_l|$_t|$_r $_s $_b $_m"
}

# --- emit -------------------------------------------------------------------

emit_header() {
	cat <<EOF
# lha test report — $DATE

| | |
|---|---|
| **Release tag** | [\`$RELEASE_TAG\`](https://github.com/ljh-sh/lha/releases/tag/$RELEASE_TAG) |
| **Tested commit** | [\`${SHA:0:12}\`](https://github.com/ljh-sh/lha/commit/$SHA) |
| **Run** | ${RUN_NO:+(#$RUN_NO) }${RUN_URL:+[workflow run]($RUN_URL)} |
| **Targets** | $(echo "$TARGETS" | tr ' ' ', ') |

> _Generated by [\`.github/workflows/test-report.yml\`](https://github.com/ljh-sh/lha/blob/main/.github/workflows/test-report.yml) on a manual \`workflow_dispatch\`. Re-run from the Actions tab to refresh._
EOF
}

emit_matrix() {
	cat <<'EOF'

## Build & test matrix

| Target | Build | Tests | Bench |
|---|---|---|---|
EOF
	for t in $TARGETS; do
		out=$(smoke_outcome "$t")
		case "$out" in
		PASS) emoji='✓ PASS' ;;
		FAIL) emoji='✗ FAIL' ;;
		INFO) emoji='ⓘ INFO' ;;
		*)    emoji='— ?' ;;
		esac
		bfile="$(T_BENCH "$t")"
		bstat='—'
		[ -f "$bfile" ] && bstat='yes'
		printf '| `%s` | ✓ | %s (%s) | %s |\n' \
			"$t" "$emoji" "$(smoke_test_count "$t")" "$bstat"
	done
}

emit_perf() {
	cat <<'EOF'

## Performance (median ± stddev, N=5)

Time to compress / extract / list a 1 MiB seeded-random blob.

| Target | `c` (s) | `x` (s) | `l` (s) | ratio |
|---|---|---|---|---|
EOF
	for t in $TARGETS; do
		bfile="$(T_BENCH "$t")"
		[ -f "$bfile" ] || { printf '| `%s` | _no bench_ | _no bench_ | _no bench_ | — |\n' "$t"; continue; }
		c_m=$(bench_stat2 "$t" c median);     c_s=$(bench_stat2 "$t" c stddev)
		x_m=$(bench_stat2 "$t" x median);     x_s=$(bench_stat2 "$t" x stddev)
		l_m=$(bench_stat2 "$t" l median);     l_s=$(bench_stat2 "$t" l stddev)
		ratio=$(awk -F'\t' '$1=="ratio"{print $2; exit}' "$bfile")
		[ -z "$ratio" ] && ratio='—'
		printf '| `%s` | %s ± %s | %s ± %s | %s ± %s | %s |\n' \
			"$t" "$c_m" "$c_s" "$x_m" "$x_s" "$l_m" "$l_s" "$ratio"
	done

	cat <<'EOF'

> _Incompressible random input → default `lh5` method produces an
> archive slightly larger than the input (ratio ≥ 1). The "ratio"
> column is `bytes_out / bytes_in`; lower is better._
> _Times measured with \`date +%s.%N\` on each runner; macOS and
> Linux runners both support sub-second precision in 2026._
EOF
}

emit_bundle_integrity() {
	[ -n "${ASSETS_DIR:-}" ] || { cat <<'EOF'

## Bundle integrity (skipped)

_Asset verification requires \`ASSETS_DIR\` to be set (download the
release assets first)._
EOF
		return; }
	[ -d "$ASSETS_DIR" ] || { echo "_No \$ASSETS_DIR ($ASSETS_DIR) — bundle integrity skipped_"; return; }

	cat <<'EOF'

## Bundle integrity (release assets)

Verifies the assets actually published in the release match what was
built, and that every asset has the §2.a-bundle shape (binary + src +
man + LICENSE + README + TAKEDOWN).

| Target | Asset | SHA256 verified | §2.a shape | SHA mismatch? |
|---|---|---|---|---|
EOF
	for t in $TARGETS; do
		case "$t" in
		*-windows)    ext=zip ;;
		*)            ext=tar.xz ;;
		esac
		asset="$ASSETS_DIR/lha-$t.$ext"
		sha="$ASSETS_DIR/lha-$t.$ext.sha256"
		ok='—'
		if [ -f "$asset" ]; then
			if [ -f "$sha" ] && ( cd "$ASSETS_DIR" && tr -d '\r' < "$sha" | sha256sum -c - >/dev/null 2>&1 ); then
				ok='✓'
			else
				ok='✗'
			fi
		fi
		shape=$(bundle_shape_row "$asset" "$t" | awk -F'|' '{print $2}')
		missing=$([ -f "$asset" ] || echo 'yes')
		[ -f "$asset" ] && missing='no'
		asset_cell="[\`$t.$ext\`](https://github.com/ljh-sh/lha/releases/download/$RELEASE_TAG/lha-$t.$ext)"
		[ -f "$asset" ] || asset_cell="\`$t.$ext\` (downloaded? $([ -f "$asset" ] && echo no || echo yes))"
		printf '| `%s` | %s | %s | %s | %s |\n' \
			"$t" "$asset_cell" "$ok" "$shape" "$missing"
	done
}

emit_footer() {
	cat <<EOF

---

_Re-run: Actions tab → \`lha test report\` → Run workflow. Tag defaults
to \`latest\`; override via the \`release_tag\` input._

EOF
}

{
	emit_header
	emit_matrix
	emit_perf
	emit_bundle_integrity
	emit_footer
}
