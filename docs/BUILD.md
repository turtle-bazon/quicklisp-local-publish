# quicklisp-local-publish — Build & Run

## Requirements

- SBCL with Quicklisp installed (`ql:quickload` must work)
- GNU `tar` and `gzip` — archives are built by running them
- `make`

Nothing is vendored: `clingon`, `ironclad`, `iterate`, `metabang-bind` and
`fiveam` are pulled from Quicklisp the first time a target loads `qlp`.

## Targets

```bash
make build     # writes build/qlp
make tests     # runs the FiveAM suite; exits non-zero if anything fails
make clean     # removes build/
make prepare   # creates build/ without building
make repl      # loads qlp and its tests, then drops into SBCL
```

`make build` is the default.

## The Binary

`qlp.asd` declares `:build-operation "program-op"`, `:build-pathname
"build/qlp"` and `:entry-point "qlp:main"`, so `asdf:make` produces a
standalone executable that needs no Quicklisp at run time:

```bash
build/qlp --help
build/qlp --version
```

A clean build takes a minute or two; most of it is compiling ironclad.
After that only this project's files are recompiled.

## Tests

```bash
make tests
```

The suite is one FiveAM suite, `qlp-tests`, split across `t/*.lisp`:

| File | Covers |
|------|--------|
| `t/template-tests.lisp` | placeholder rendering, forms, unknown keys |
| `t/config-tests.lisp` | defaults, validation, options building a configuration, exclusions |
| `t/paths-tests.lisp` | file walking, glob matching, relative paths |
| `t/asdf-scan-tests.lisp` | sub-systems, dependencies, leaving ASDF untouched |
| `t/index-tests.lisp` | index line formats and parsing |
| `t/publish-tests.lisp` | publication end to end, reproducibility, verification |

Tests that need the filesystem use `with-temp-directory`, which creates a
fresh directory under the system temporary directory and removes it
afterwards.

`run-qlp-tests` returns true only when every check passed, so `make tests`
fails the build on a real failure.

### When a test fails

```bash
sbcl --noinform --non-interactive \
  --eval '(ql:quickload :qlp-tests :silent t)' \
  --eval '(fiveam:run! (quote qlp:qlp-tests))'
```

Replace `qlp:qlp-tests` with a single test name to run just that one.
Running a test in isolation while it fails in the suite usually means an
earlier test left state behind — ASDF's registry is the usual suspect.

## Conventions

Two that catch people out:

- iteration is `iterate` — `iter`, never `loop`, `dolist`, `dotimes`,
  `mapcar` or `maphash`;
- no function longer than 50 lines.

## Gotcha: Stale FASLs

ASDF caches compiled files under `~/.cache/common-lisp/`. It recompiles
when a source file's timestamp moves, so this is rarely a problem, but if
a change seems to have no effect:

```bash
rm -rf ~/.cache/common-lisp/*/*/quicklisp-local-publish/
```

Rebuilding then recompiles everything from source.
