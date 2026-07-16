#!/usr/bin/env sh
# Stage the built lha into a self-contained §2.a-bundle. Linux + macOS.
#   TARGET    e.g. x86_64-linux-musl | aarch64-linux-musl | aarch64-macos
#   BUILD_DIR (default $ROOT/build)
#   LHA_SRC   (default $ROOT/upstream/lha — verbatim upstream jca02266/lha)
#   DIST      (default $ROOT/dist)
#
# §2.a-bundle layout inside dist/lha-$TARGET/:
#   bin/lha                    (the binary, +x)
#   src/lha/                   (verbatim upstream source, pruned of build
#                                artifacts: autom4te.cache, *.o, Makefile,
#                                config.{h,log,status}, .deps/, *.stamp)
#   man/man1/lha.1
#   LICENSE                    (§1-§7 verbatim of ORIGINAL LHA LICENSE)
#   README.md                  (archive-level pointer back to ljh-sh/lha)
#   TAKEDOWN.md                (contact channel for §1-§7 claims)
#
# Output: dist/lha-$TARGET.tar.xz + dist/lha-$TARGET.tar.xz.sha256.
#
# Why .tar.xz (not .tar.gz): the user explicitly preferred xz for its
# ~30% better compression on small sources like lha's, with no real
# runtime cost (xz -T0 is fast enough on the build runner).
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

[ -f "$ROOT/LICENSE"     ] || { echo "error: $ROOT/LICENSE not found"     >&2; exit 1; }
[ -f "$ROOT/TAKEDOWN.md" ] || { echo "error: $ROOT/TAKEDOWN.md not found" >&2; exit 1; }

STAGE="$DIST/lha-$TARGET"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/man/man1" "$STAGE/src"

# binary
cp "$BIN" "$STAGE/bin/lha"
chmod +x "$STAGE/bin/lha"

# man page (auto-rendered by the user's `man lha` later; we ship the
# roff source per upstream convention)
cp "$MAN_SRC" "$STAGE/man/man1/lha.1"

# §2.a — verbatim upstream source (cleaned of build artifacts).
# tar(1) --exclude is portable across Linux + macOS; the patterns below
# drop the regenerated/regenerable bits that would otherwise bloat the
# archive (autom4te.cache alone is ~1 MB and regenerates from
# configure.ac via `autoreconf -i`).
mkdir -p "$STAGE/src/lha"
( cd "$LHA_SRC" && tar cf - \
	--exclude=autom4te.cache \
	--exclude='*.o' \
	--exclude='*.exe' \
	--exclude='.deps' \
	--exclude='.libs' \
	--exclude='Makefile' \
	--exclude='Makefile.in~' \
	--exclude='*.in~' \
	--exclude='config.h' \
	--exclude='config.h.in~' \
	--exclude='config.log' \
	--exclude='config.status' \
	--exclude='stamp-h1' \
	--exclude='*.stamp' \
	--exclude='*~' \
	--exclude='.#*' \
	--exclude='.git' \
	--exclude='.gitignore' \
	--exclude='.travis.yml' \
	--exclude='.github' \
	. ) | ( cd "$STAGE/src/lha" && tar xf - )

# Repo-root LICENSE and TAKEDOWN — these are the ljh-sh/lha regulatory
# documents (§1-§7 verbatim LICENSE + takedown contact channel). They
# belong at the archive root, not under src/, because they're the
# *wrapper's* obligations, not the upstream source's.
cp "$ROOT/LICENSE"     "$STAGE/LICENSE"
cp "$ROOT/TAKEDOWN.md" "$STAGE/TAKEDOWN.md"

# Archive-level README — small pointer back to the source repo. The full
# multi-section README is at https://github.com/ljh-sh/lha; this is
# just to make the archive self-explanatory when extracted.
cat > "$STAGE/README.md" <<EOF
# lha — single-target §2.a-bundle (release tarball)

Source:      https://github.com/ljh-sh/lha (release tag)
Target:      ${TARGET}
Upstream:    jca02266/lha @ ac20220213 (LHa for UNIX 1.14i)

This archive is laid out per **§2.a** of the ORIGINAL LHA LICENSE
(the redistribution clause we ship under — see \`LICENSE\`): the
binary, the verbatim upstream source (\`src/lha/\`), the man page,
the LICENSE (§1-§7 verbatim), and the TAKEDOWN contact channel.

## Install (manual)

\`\`\`sh
sudo install -m 0755 bin/lha         /usr/local/bin/lha
sudo install -m 0644 man/man1/lha.1  /usr/local/share/man/man1/
man lha
\`\`\`

## Rebuild from source

\`\`\`sh
cd src/lha
autoreconf -is
./configure
make
\`\`\`

The wrapper repo (ljh-sh/lha) has CI that runs the upstream
\`make check\` test suite plus a 1 MiB random round-trip — see
\`scripts/smoke.sh\`.
EOF

# xz compression (better ratio on small source than gz; user-specified).
( cd "$DIST" && tar cJf "lha-$TARGET.tar.xz" "lha-$TARGET" )

# SHA256 — basename-only so `sha256sum -c FILE.sha256` works from any
# directory. Prefer coreutils sha256sum, then macOS shasum, then OpenSSL.
ARCHIVE="$DIST/lha-$TARGET.tar.xz"
if   command -v sha256sum >/dev/null 2>&1; then
	HASH_CMD='sha256sum'
elif command -v shasum     >/dev/null 2>&1; then
	HASH_CMD='shasum -a 256'
else
	HASH_CMD='openssl dgst -sha256 -r'
fi
( cd "$DIST" && $HASH_CMD "lha-$TARGET.tar.xz" \
	| awk '{printf "%s  lha-'"$TARGET"'.tar.xz\n", $1}' ) > "$ARCHIVE.sha256"

echo "==> $DIST/lha-$TARGET.tar.xz"
echo "==> $DIST/lha-$TARGET.tar.xz.sha256"
