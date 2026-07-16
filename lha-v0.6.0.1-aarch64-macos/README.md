# lha — self-contained multi-platform builds

[Vendored](upstream/lha/) [jca02266/lha](https://github.com/jca02266/lha)
(the maintained autoconf fork of LHa for UNIX — the original `.lzh`
archiver) with a native per-OS packaging layer that produces
**statically-linked, self-contained** binaries. No glibc / libiconv /
applefile to install on the target machine. Just download, extract, run.

This is a **distribution repo** (lha source + build/packaging scripts +
CI). It is independent of `ljh-sh/kenlm` and the other ljh-sh dist repos.
See `NOTICE.md` for the upstream LHa license terms that apply to the
binary.

## Install

```sh
# install via x eget (one-line):
x eget ljh-sh/lha

# or download a release tarball from
# https://github.com/ljh-sh/lha/releases/tag/latest
# extract, then:
sudo install -m 0755 lha-*/bin/lha /usr/local/bin/lha
sudo install -m 0644 lha-*/man/man1/lha.1 /usr/local/share/man/man1/
man lha
```

## Usage (1988 CLI, not GNU-getopt)

LHa for UNIX 1.14i CLI is from 1988; there's no `-h` or `--help`.
To see version + usage, just run with no args:

```sh
$ lha
LHa for UNIX version 1.14i-ac20220213 (aarch64-apple-darwin25.5.0)
LHarc    for UNIX  V 1.02  Copyright(C) 1989  Y.Tagawa
LHx      for MSDOS V C2.01 Copyright(C) 1990  H.Yoshizaki
LHx(arc) for OSK   V 2.01  Modified     1990  Momozou
LHa      for UNIX  V 1.00  Copyright(C) 1992  Masaru Oki
LHa      for UNIX  V 1.14  Modified     1995  Nobutaka Watazaki
LHa      for UNIX  V 1.14i Modified     2000  Tsugio Okamoto
LHA-PMA  for UNIX  V 2     PMA added    2000  Maarten ter Huurne
                   Autoconfiscated 2001-2008  Koji Arai
```

**Commands** (`lhasa` is decode-only and missing most of these —
that's why this build exists):

| cmd | action |
|-----|--------|
| `a`  | append to archive |
| `c`  | create new archive    ← lhasa CANNOT do this |
| `d`  | delete from archive |
| `e`  | extract (synonym for `x`) |
| `l`  | list contents |
| `m`  | move into archive |
| `p`  | print to stdout |
| `t`  | test CRC |
| `u`  | update entries |
| `v`  | verbose list |
| `x`  | extract |

**Options**: `f` force overwrite · `i` ignore directory path ·
`n` dry run · `q{num}` quiet · `v` verbose · `w=<dir>` extract
directory.

**Examples**:

```sh
lha x archive.lzh                    # extract
lha c archive.lzh file1 file2        # create
lha l archive.lzh                    # list
lha t archive.lzh                    # verify CRC
lha p archive.lzh file               # print single file to stdout
```

## Takedown / license concerns

See [`TAKEDOWN.md`](./TAKEDOWN.md) — two channels available:

- **Email**: `edwin.jh.lee@gmail.com` (preferred for private concerns)
- **GitHub Issue**: [file a takedown issue](../../issues/new?template=takedown.md)
  (public, traceable)

§1-§7 of the ORIGINAL LHA LICENSE is reproduced verbatim in
[`LICENSE`](./LICENSE).

## Binary

Built into each release archive under `bin/`:

| binary | purpose |
|---|---|
| `lha` | the single LZH archiver binary (add / extract / list / delete, etc.) |

The man page `lha(1)` is shipped under `man/` in the same archive.

## Platform matrix

Every release builds **multiple targets** via GitHub Actions on native
runners. Linux uses **musl-static** (Alpine toolchain) so the binary runs
on Alpine, Debian/Ubuntu, RHEL/Fedora, Arch — every Linux distro — with
zero system-library dependencies; there is intentionally no separate
glibc/dynamic Linux variant.

| target | runner | linkage | archive |
|---|---|---|---|
| `x86_64-linux-musl` | `ubuntu-latest` + Alpine 3.20 docker | fully static musl | `.tar.gz` |
| `aarch64-linux-musl` | `ubuntu-24.04-arm` + Alpine 3.20 docker | fully static musl | `.tar.gz` |
| `aarch64-macos` | `macos-14` | static, system libc++/libSystem | `.tar.gz` |
| `x86_64-windows` | MinGW cross from `ubuntu-latest` | fully static | `.zip` |

> macOS is **Apple Silicon only**. Intel macOS is dropped for the same
> reason as `ljh-sh/kenlm`: `macos-13` is deprecated with severe capacity
> shortages. Cross-build `x86_64-apple-darwin` via `arch -x86_64` on
> `macos-14` if you need it.

## Self-containedness

- **Linux** (musl, alpine container): `ldd` reports *not a dynamic executable*
  on `aarch64-linux-musl`; verified end-to-end inside Alpine.
- **macOS**: every dep statically or system-linked; `otool -L` shows only
  `/usr/lib/…` and `/System/Library/…`.
- **Windows**: MinGW `-static` → no DLLs to bundle.

## Build locally

```sh
git clone https://github.com/ljh-sh/lha.git
cd lha
sh scripts/build.sh                    # host arch (auto)
cd upstream/lha && autoreconf -is && ./configure && make
```

Each `scripts/build*.sh` and the workflow files are POSIX shell with
`set -eu`; they're standalone and don't depend on each other.

## Smoke test

`scripts/smoke.sh` runs the upstream `make check` (running the upstream
test corpus) on the freshly built binary. A green smoke test on Alpine is
the runtime proof that the musl-static binary works there.

## Releases

Tags follow `vX.Y.Z`. Each release uploads `lha-<target>.tar.gz` (or
`.zip`) plus a `.sha256` per archive and a top-level `SHA256SUMS`. See
[Releases](https://github.com/ljh-sh/lha/releases).

## Vendoring

`upstream/lha/` is a `git subtree` of [jca02266/lha](https://github.com/jca02266/lha).
Refresh with `git subtree pull --prefix=upstream/lha …`. See `NOTICE.md`
for full attribution and the LHa license terms.

## Related ljh-sh dist repos

- [`ljh-sh/kenlm`](https://github.com/ljh-sh/kenlm) — same dist pattern,
  C++/Boost.
- `upxz`, `chardet`, `fmeta`, `roff`, `homebrew-cli`, `silk`, `macli`,
  `maclisten`, `macvision`, `aria` (sibling repos under the same dist
  regime).
