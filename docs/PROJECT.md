# quicklisp-local-publish — Project Overview

`quicklisp-local-publish` (binary `qlp`) turns a directory of local Common
Lisp projects into a Quicklisp distribution. Each project directory becomes
one release archive; each system its `.asd` files define becomes an entry in
the system index — sub-systems included.

It is a modern reimplementation of
[quickdist](https://github.com/orivej/quickdist/) with one feature quickdist
lacks: it publishes ASDF sub-systems.

Publishing only writes files to a directory. It runs no HTTP server —
serving the distribution is the work of whatever hosts `--base-url`.

## Tech Stack

| Component | Choice |
|-----------|--------|
| Language | Common Lisp (SBCL) |
| Build | Makefile + ASDF `program-op` → `build/qlp` |
| CLI | Clingon — `qlp` with `publish`, `verify`, `systems`, `clean` |
| Iteration | `iterate` |
| Binding | `metabang-bind` |
| Digests | ironclad (MD5 for the release index, SHA-1 for `content-sha1`) |
| Archives | GNU `tar` + `gzip` |
| Testing | FiveAM — `make tests` |

## License

`quicklisp-local-publish` is free software, licensed under the **GNU General
Public License version 3 or (at your option) any later version**
(GPL-3.0-or-later). See the `LICENSE` file at the repository root for the
full text. Keep the SPDX header on every source file.

## CLI Commands

Defined in `src/cli.lisp`, wired together in `src/main.lisp`.

```bash
# Write the distribution
qlp publish --name NAME --base-url URL --projects-dir DIR --dists-dir DIR
            [--dist-version VERSION] [--tar-program PATH] [--exclude PATTERN]...

# Check what was written against the archives beside it; exits 1 on trouble
qlp verify   [same options as publish]

# List every system the projects define, sub-systems included
qlp systems  [same options as publish]

# Remove one version's distribution directory; refuses without --yes
qlp clean    [same options as publish] --yes
```

`--exclude` is repeatable and **extends** the exclusions already in force,
never replaces them, so `.git` and friends stay out of the archives.

Everything is said on the command line: there is no configuration file and
no environment variable. `--name`, `--base-url`, `--projects-dir` and
`--dists-dir` are required; leaving one out is reported before anything is
written, and naming the option. See [`docs/CONFIG.md`](CONFIG.md).

## What Publication Produces

Given `--name mydist --base-url https://dist.example.org`:

| File | Contents |
|------|----------|
| `mydist.txt` | distinfo: name, version, and the URLs a client subscribes to |
| `mydist/<version>/distinfo.txt` | the same distinfo inside the version directory |
| `mydist/<version>/releases.txt` | `project url size file-md5 content-sha1 prefix [system-file…]` |
| `mydist/<version>/systems.txt` | `project system-file system-name [dependency…]` |
| `mydist/archive/<prefix>.tgz` | the archive each release line points at |

`qlp verify` re-reads those indexes and reports a missing archive, an
archive whose size or MD5 no longer matches, or a system naming an `.asd`
file its release does not ship.

## The Feature That Is Not in quickdist

An `.asd` file may define several systems, and may define them through a
macro: `ironclad.asd` defines `ironclad`, `ironclad/cipher/aes` and about
ninety others, some of them emitted by helper macros. Those systems are as
real as the one the file is named after, and a distribution that indexes
only that one leaves the rest unreachable.

`qlp` reads `.asd` files the way ASDF reads them — evaluating them in the
`asdf-user` package with ASDF's registration function hooked — so what it
records is what ASDF would register, macro-generated systems included. A
textual scan of literal `defsystem` forms is the fallback for a file that
cannot be evaluated.

## Docs Index

- `docs/ARCHITECTURE.md` — source layout, ASDF systems, the publishing pipeline
- `docs/BUILD.md` — build & run, tests
- `docs/CONFIG.md` — the command line, option by option
