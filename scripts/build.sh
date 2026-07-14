#!/usr/bin/env sh
# Build lha as a static, self-contained binary. Linux gnu + macOS + MinGW.
# Out-of-tree build into BUILD_DIR (default ./build) — leaves upstream/
# untouched so musl alpine + host glibc builds don't fight over state.
#
# Used by:
#   - .github/workflows/release.yml on macos-14 (host arch = aarch64-macos)
#     and on windows-latest under MSYS2/mingw64 (host arch = x86_64-windows).
#   - Local development on any POSIX host.
#
# Autotools bootstraps `configure` from `configure.ac` inside the source
# tree (upstream removed `configure` from git; see `autoreconf -is`).
# --disable-dependency-tracking keeps the one-shot CI build fast.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SRC="${LHA_SRC:-$ROOT/upstream/lha}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"

[ -f "$SRC/configure.ac" ] || { echo "error: $SRC/configure.ac not found" >&2; exit 1; }
command -v autoreconf >/dev/null 2>&1 \
	|| { echo "error: autoreconf not found in PATH (install autoconf + automake + libtool)" >&2; exit 1; }

JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.nproc 2>/dev/null || echo 4)"

# Minimal configure args. By default:
#   --disable-dependency-tracking   (one-shot CI build, no dep graph)
#   --disable-silent-rules          (so `make` logs each step — CI shows it)
# AppleSingle/AppleDouble (applefile) is off by default in jca02266/lha;
# we don't enable it — keeps the binary dependency-free.
CONFIGURE_ARGS="--disable-dependency-tracking --disable-silent-rules"
# Optional escape hatch — CI flows don't set this; downstream can.
[ -n "${LHA_EXTRA_CONFIGURE_ARGS:-}" ] && CONFIGURE_ARGS="$CONFIGURE_ARGS $LHA_EXTRA_CONFIGURE_ARGS"

# Clean any prior in-tree state left by a previous build — otherwise
# `configure` rejects the out-of-tree run with "source directory already
# configured". Idempotent on fresh checkouts (Makefile absent → no-op).
echo "==> distclean (in-tree, idempotent)"
( cd "$SRC" && [ -f Makefile ] && make distclean >/dev/null 2>&1 ) || true

echo "==> autoreconf -is"
( cd "$SRC" && autoreconf -is )

echo "==> configure (out-of-tree: $BUILD_DIR)"
mkdir -p "$BUILD_DIR"
( cd "$BUILD_DIR" && "$SRC/configure" --srcdir="$SRC" $CONFIGURE_ARGS )

echo "==> make -C $BUILD_DIR -j$JOBS"
( cd "$BUILD_DIR" && make -j"$JOBS" )

echo "==> built:"
ext_for() { [ -f "$1.exe" ] && printf '%s.exe' "$1" || printf '%s' "$1"; }
ls -l "$(ext_for "$BUILD_DIR/src/lha")" \
	|| { echo "error: lha binary not found under $BUILD_DIR/src/" >&2; exit 1; }
