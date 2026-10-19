# quicklisp-local-publish — Architecture

## ASDF Systems

| System | File | Purpose |
|--------|------|---------|
| `qlp` | `qlp.asd` | the library and the binary |
| `qlp-tests` | `qlp-tests.asd` | FiveAM suite, `:serial t` over `t/` |

`qlp` builds itself with `program-op`, entry point `qlp:main`, output
`build/qlp`.

Dependencies: `uiop`, `iterate`, `metabang-bind`, `clingon`, `ironclad`.
ASDF and UIOP ship with SBCL; everything else comes from Quicklisp.

## Source Layout

Files load in the order `qlp.asd` lists them (`:serial t`):

| File | Role |
|------|------|
| `src/package.lisp` | the `qlp` package and its exports |
| `src/config.lisp` | configuration plists: defaults, merging, validation |
| `src/template.lisp` | `{placeholder}` rendering for paths and the distinfo |
| `src/paths.lisp` | pathname helpers: `directory-entries`, `relative-path`, `path-string` |
| `src/asdf-scan.lisp` | reading `.asd` files for the systems they define |
| `src/project.lisp` | walking a project: excluded names, file listing, project analysis |
| `src/digest.lisp` | `file-md5`, `file-sha1`, `file-size` |
| `src/archive.lisp` | building one reproducible release archive |
| `src/index.lisp` | `releases.txt` and `systems.txt` lines |
| `src/dist.lisp` | `publish`, the report, `discover-systems` |
| `src/verify.lisp` | `verify-dist` |
| `src/cli.lisp` | options and the subcommand handlers |
| `src/main.lisp` | command tree and the `main` entry point |

Tests mirror this: `t/package.lisp` (suite, `with-temp-directory`,
`write-file`, `run-qlp-tests`) then one file per area.

## Reading a Project

```
find-projects        each subdirectory of --projects-dir is one project
  └ analyze-project
      └ scan-system-files
          └ find-system-files     .asd files, after exclusions
              └ scan-asd-file     the systems one .asd defines
```

`list-files` walks the tree, pruning directories whose *name* matches an
exclusion pattern (`*.fasl`, `.git`, `build`, …). `excluded-p` compares
against the Unix file name, or the last directory component for a
directory, so `*` in a pattern never has to span a separator unless the
pattern says `**`.

## Reading an `.asd` File — `src/asdf-scan.lisp`

This is the part that makes sub-systems work, and it is worth reading
closely.

`asdf:load-asd` is deliberately *not* used: it plans a full `load-op`,
which resolves dependencies and can try to build systems that are not
present. What is needed is only what the file declares.

So `qlp` evaluates the file itself, in a context shaped like the one ASDF
would provide:

- `*package*` is `asdf-user`, the package a normal `.asd` is read in;
- `*default-pathname-defaults*` is the directory of the file;
- `*load-pathname*` and `*load-truename*` are the file itself — ASDF takes
  the source file of a system from `(load-pathname)` when `:defsystem` does
  not name one, and without it a `:file` component has no directory to
  resolve against;
- `asdf:*central-registry*` is `NIL`, so nothing the file mentions causes
  ASDF to go looking elsewhere.

While the file is evaluated, `register-system-definition` — ASDF's own
function, located at run time by `registration-symbols` so the scanner
survives ASDF releases — is temporarily replaced by `make-recorder`, which
records a `system-definition` and then calls the original. Every
`defsystem` the file performs is caught this way, including the ones a
macro expands into, because the hook sits below macroexpansion.

Evaluation then unwinds: the original registration function is restored
and every system registered since the scan began is cleared, passing the
*name* to `asdf:clear-system` rather than the object, since looking the
object up can register it all over again. Nothing the scan registered is
left behind — `scan-leaves-asdf-untouched` asserts it.

Two details worth knowing:

- **`*load-pathname*` matters.** Without it a `:components` form fails
  with `Invalid relative pathname … for component`, because ASDF cannot
  work out the system's directory. It also makes behaviour independent of
  whether `qlp` was started from `--load` or `--eval`.
- **Redefinition warnings are muted** during evaluation only
  (`mute-redefinitions`). Two `.asd` files of one project routinely define
  the same helper class or macro; nothing defined here is kept, so the
  report would only be noise. Other warnings, of a badly named system say,
  are left alone.

If evaluation fails at all — an unreadable file, an `.asd` that insists on
looking itself up beyond what the bindings allow — `textual-definitions`
falls back to reading the forms and keeping literal
`(defsystem NAME …)` ones, without dependencies. The failure is reported
as a warning naming the file and the reason.

## The Publishing Pipeline

`publish` in `src/dist.lisp`:

1. `validate-config` — refuse early, before anything is written.
2. `render-layout` — resolve the five templates into concrete paths.
3. `find-projects` — analyse every project directory.
4. `archive-projects` — build one archive per project that has systems;
   a project with none is reported as skipped rather than archived.
5. `write-lines` — `releases.txt` and `systems.txt`.
6. `write-string-to-file` — the distinfo, both where a subscriber looks
   for it and inside the version directory.

The report it returns carries the release count, the system count and the
names skipped, which `qlp publish` prints.

## Reproducible Archives — `src/archive.lisp`

Determinism is a property of how the tar is built, not of post-processing:

| Step | Why |
|------|-----|
| file list written sorted, NUL separated | entry order is decided by `qlp`, not by the filesystem |
| `--mtime=@<epoch>` on every member | one project-wide timestamp, the newest non-excluded mtime |
| `--owner=0 --group=0 --numeric-owner` | no build machine's identities |
| `--format=gnu` | one format, not the host default |
| `--transform s#^#<prefix>/#` | every member under one top level directory |
| `gzip -n -9 -f` | `-n` stores no timestamp or name in the gzip header |

`file-md5` is taken of the `.tgz`, `file-sha1` of the uncompressed `.tar`,
matching what a Quicklisp client and `content-sha1` expect.

## Templates — `src/template.lisp`

Path templates are the ones quickdist named, so their shape will be
familiar: `*distinfo-template*`, `*distinfo-file-template*`,
`*dist-dir-template*`, `*archive-dir-template*`, `*archive-url-template*`.
All are exported and may be rebound to change the layout.

`{name}` reads as the symbol `NAME`; a placeholder may also be a form,
`{(:or version "19700101")}`, in which case `(:or …)` takes the first key the
data supplies and `(:if …)` picks between two. Reading uses a copy
readtable in which `}` closes the form, with `*package*` bound to
`:keyword`.

Trailing-slash trimming of `--base-url` happens in `template-data`, where
configuration becomes template data, not in `render-template` — rendering
a template is expected to substitute values, not to repair them.

## Verification — `src/verify.lisp`

`verify-dist` returns `(values problems-p problems)`. It first checks that
the three index files exist, then that every release line's archive is
present, of the recorded size, and of the recorded MD5, and finally that
every system line names an `.asd` file some release actually ships and a
project some release provides.
