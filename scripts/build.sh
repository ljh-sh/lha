#!/usr/bin/env sh
# Build lha as a static, self-contained binary. Linux gnu + macOS + MinGW.
# Out-of-tree build into BUILD_DIR (default ./build) — leaves upstream/
# untouched so musl alpine + host glibc builds don't fight over state.
#
# Used by:
#   - .github/workflows/build-and-test.yml + release.yml on:
#       macos-14          (host arch = aarch64-macos; cross to x86_64 too)
#       windows-latest    (MSYS2/mingw64 x86_64)
#       windows-11-arm    (MSYS2/mingw64 aarch64 — cross from x86_64 host)
#   - Local development on any POSIX host.
#
# Cross-compile: set LHA_TARGET_ARCH + LHA_TARGET_OS (or LHA_TRIPLET) +
# LHA_OS_HINT (darwin | windows). The script exports CC/CFLAGS/LDFLAGS
# and tells autotools --host=<triplet>. macOS uses clang -arch; MinGW
# uses the cross-toolchain named aarch64-w64-mingw32-gcc.
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

# Cross-compile: LHA_TARGET_ARCH (x86_64 / aarch64), LHA_TARGET_OS
# (apple-darwin / w64-mingw32), LHA_TRIPLET (full autoconf triplet, e.g.
# x86_64-apple-darwin). When target arch != host arch, we tell autotools
# --host=<triplet> so it picks the right lib paths, and we add the
# toolchain's arch flag (-arch for clang darwin, the cross-gcc bin
# prefix for MinGW) so the per-file compilation actually targets the
# new arch. Export via env (CC/CFLAGS/LDFLAGS) — autotools reads these
# natively and we avoid the shell-quoting nightmare of embedded spaces.
HOST_ARCH="$(uname -m 2>/dev/null || echo unknown)"
TARGET_ARCH="${LHA_TARGET_ARCH:-$HOST_ARCH}"
TRIPLET="${LHA_TRIPLET:-}"
if [ -n "$LHA_TARGET_OS" ]; then
	TRIPLET="${TRIPLET:-${LHA_TARGET_ARCH}-${LHA_TARGET_OS}}"
fi
if [ "$TARGET_ARCH" != "$HOST_ARCH" ] || [ -n "$LHA_TARGET_OS" ]; then
	[ -z "$TRIPLET" ] && TRIPLET="$TARGET_ARCH"
	case "${LHA_OS_HINT:-}" in
	darwin)
		# Apple SDK is shared between arches; clang auto-discovers via xcrun.
		export CC=clang
		export CFLAGS="-arch $TARGET_ARCH -O2"
		export LDFLAGS="-arch $TARGET_ARCH"
		;;
	windows)
		# MinGW cross-toolchain (e.g. aarch64-w64-mingw32-gcc from msys2).
		export CC="${TARGET_ARCH}-w64-mingw32-gcc"
		export CXX="${TARGET_ARCH}-w64-mingw32-g++"
		;;
	*)
		# Generic clang fallback (Linux/musl cross via clang).
		export CC=clang
		export CFLAGS="-arch $TARGET_ARCH -O2"
		export LDFLAGS="-arch $TARGET_ARCH"
		;;
	esac
	export LDFLAGS="$LDFLAGS"
	CONFIGURE_ARGS="$CONFIGURE_ARGS --host=$TRIPLET"
	[ -n "${LHA_BUILD_TRIPLET:-}" ] && CONFIGURE_ARGS="$CONFIGURE_ARGS --build=$LHA_BUILD_TRIPLET"
	echo "==> cross-compile: host=$HOST_ARCH → target=$TARGET_ARCH ($TRIPLET)"
fi

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
