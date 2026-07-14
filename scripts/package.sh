#!/usr/bin/env sh
# Stage the built lha into a self-contained dist archive. Linux + macOS.
#   TARGET    e.g. x86_64-linux-musl | aarch64-linux-musl | aarch64-macos
#   BUILD_DIR (default $ROOT/build)
#   LHA_SRC   (default $ROOT/upstream/lha — for the man page)
#   DIST      (default $ROOT/dist)
#
# Stage layout inside dist/lha-$TARGET/:
#   bin/lha          (the binary, +x)
#   man/man1/lha.1   (the man page, source roff — not auto-rendered)
#   README.md        (link to ljh-sh/lha)
#
# Output: dist/lha-$TARGET.tar.gz + dist/lha-$TARGET.tar.gz.sha256.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
LHA_SRC="${LHA_SRC:-$ROOT/upstream/lha}"
DIST="${DIST:-$ROOT/dist}"
TARGET="${TARGET:?set TARGET, e.g. x86_64-linux-musl}"

ext_for() { [ -f "$1.exe" ] && printf '%s.exe' "$1" || printf '%s' "$1"; }
BIN="$(ext_for "$BUILD_DIR/src/lha")"
[ -x "$BIN" ] || { echo "error: $BIN not built (out-of-tree BUILD_DIR=$BUILD_DIR)" >&2; exit 1; }

MAN_SRC="$LHA_SRC/man/lha.1"
[ -f "$MAN_SRC" ] || { echo "error: $MAN_SRC not found" >&2; exit 1; }

STAGE="$DIST/lha-$TARGET"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/man/man1"

cp "$BIN" "$STAGE/bin/lha"
chmod +x "$STAGE/bin/lha"
cp "$MAN_SRC" "$STAGE/man/man1/lha.1"

# A tiny README so the archive is self-explanatory.
cat > "$STAGE/README.md" <<'EOF'
# lha — single-binary release

Self-contained archive from https://github.com/ljh-sh/lha (release tag).
The wrapper LICENSE and NOTICE live there; the `lha` binary carries the
upstream LHa redistribution terms — see `../upstream/lha/man/lha.man` in
the source repo or https://github.com/jca02266/lha.

Install (optional, manual):

    sudo install -m 0755 bin/lha /usr/local/bin/lha
    sudo install -m 0644 man/man1/lha.1 /usr/local/share/man/man1/

Then:  man lha
EOF

( cd "$DIST" && tar czf "lha-$TARGET.tar.gz" "lha-$TARGET" )

# SHA256 — emit basename-only so `sha256sum -c FILE.sha256` works from
# any directory (the absolute CI-workspace path we'd otherwise get
# breaks verification for users downloading individual archives).
# Prefer coreutils sha256sum, then macOS shasum, then OpenSSL.
ARCHIVE="$DIST/lha-$TARGET.tar.gz"
if   command -v sha256sum >/dev/null 2>&1; then
	HASH_CMD='sha256sum'
elif command -v shasum     >/dev/null 2>&1; then
	HASH_CMD='shasum -a 256'
else
	HASH_CMD='openssl dgst -sha256 -r'
fi
( cd "$DIST" && $HASH_CMD "lha-$TARGET.tar.gz" \
	| awk '{printf "%s  lha-'"$TARGET"'.tar.gz\n", $1}' ) > "$ARCHIVE.sha256"

echo "==> $DIST/lha-$TARGET.tar.gz"
echo "==> $DIST/lha-$TARGET.tar.gz.sha256"
