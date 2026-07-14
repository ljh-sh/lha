# NOTICE

This repository (`ljh-sh/lha`) provides self-contained, statically-linked
builds of **lha** (the LZH archiver) and the build/packaging layer around
it.

## Wrapper license (this repo's own files)

`scripts/`, `.github/workflows/`, `README.md`, `NOTICE.md`, `.gitattributes`,
`.gitignore`, and `LICENSE` (the MIT half) are

    Copyright (c) 2026 Li Junhao
    Licensed under the MIT License — see LICENSE.

## Upstream license (`upstream/lha/` and the `lha` binary)

`upstream/lha/` is a copy of [jca02266/lha](https://github.com/jca02266/lha)
(the maintained autoconf fork of LHa for UNIX, originally by Y. Tagawa /
M. Okubo / N. Watazaki and friends — see `man/lha.man` for the full credits
in English and Japanese). Upstream is vendored via `git subtree`.

### The "LHa license"

There is **no top-level LICENSE/COPYING file** in upstream. The redistribution
terms live verbatim inside `man/lha.man` (item 2 of the 末尾 / "in the end"
section). In short:

- Source-level redistribution is permitted (with attribution and a notice
  if modified).
- Binary-only redistribution is **not** permitted without contacting the
  authors (item 2c).
- The authors disclaim all warranties and have no obligation to fix bugs
  (items 4, 5).
- A derived program must not be called "LHa" (item 6).
- Commercial use is allowed under additional rules (item 7): the program
  must not be the *main* part of a commercial product, the upstream authors
  may decline distribution to unsuitable parties, etc.

See `man/lha.man` for the full original text (Japanese) and `README.md` /
`README.jp.md` for the maintainer commentary.

### Why this matters for the release artifacts

Each release ships a pre-built `lha` binary. Because item 2c of the LHa
terms prohibits binary-only redistribution without first contacting the
authors, the release tags here exist **primarily** as a convenience for
people who are already running the same compilation locally and need a
reproducible build environment; downstream packagers who wish to ship the
binary in another distribution should consult the upstream terms
(`man/lha.man`) and contact `jca02266@gmail.com` per those terms before
including it. The MIT wrapper license does not change this.

The CI build runs `make check` against the upstream test suite as smoke
verification (see `scripts/smoke.sh`).

## No patches applied to the vendored source

`upstream/lha/` is a clean copy. There are no local patches over the
upstream HEAD at the time of vendoring. Re-vendor (or `git subtree pull`)
to refresh.

## How vendoring is structured

`upstream/lha/` was created with:

    git subtree add --prefix=upstream/lha https://github.com/jca02266/lha.git master --squash

Subsequent updates should use:

    git subtree pull --prefix=upstream/lha https://github.com/jca02266/lha.git master --squash
