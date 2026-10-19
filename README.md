# quicklisp-local-publish — `qlp`

Turn a directory of local Common Lisp projects into a Quicklisp
distribution. One directory per project becomes one release; every system
those projects define — including the sub-systems declared inside another
system's `.asd` file — becomes an entry in the system index.

Publishing only writes files to a directory. Serving them is an HTTP
server's work.

```bash
qlp publish --name mydist \
            --base-url https://dist.example.org \
            --projects-dir ~/lisp/projects \
            --dists-dir /srv/www/dist
```

That writes, under `/srv/www/dist`:

```
mydist.txt                                  distinfo, for quicklisp-client:dist
mydist/20261019/distinfo.txt                 the same, inside the version directory
mydist/20261019/releases.txt                 one line per release
mydist/20261019/systems.txt                  one line per system
mydist/archive/ironclad-20261019.tgz         the archives those lines point at
```

Copy `/srv/www/dist` to a web root and subscribe with:

```lisp
(ql:quickload "quicklisp-client" :silent t)
(ql:quickload "mydist" :silent t)   ; after registering the dist
```

## Why sub-systems

A file such as `ironclad.asd` defines `ironclad` *and* a couple of dozen
systems under `ironclad/`. Quicklisp indexes them only when a project's
`.asd` files are read the way ASDF reads them, so `qlp` reads them that way:
it evaluates each `.asd` file with ASDF's own registration hooked, records
every `defsystem` it sees, and then puts ASDF back the way it found it.
Systems that macro helpers expand into are caught too, because what is
recorded is what ASDF registers, not what the file literally says.

## Commands

```bash
qlp publish   # write the distribution
qlp verify    # check indexes against the archives beside them
qlp systems   # list every system the projects define
qlp clean     # remove one version's directory (needs --yes)
```

`qlp publish --help`, and `--help` for each subcommand, list every option.
The four always needed are `--name`, `--base-url`, `--projects-dir` and
`--dists-dir`; `--dist-version`, `--tar-program` and the repeatable
`--exclude` fill in the rest. There is no configuration file and no
environment variable: one invocation says everything that will happen.
See [`docs/CONFIG.md`](docs/CONFIG.md).

## Reproducible archives

The same sources produce a byte-identical archive: entries are listed in an
order `qlp` decides, every member carries the project's newest non-excluded
mtime, owner and group are 0, the format is GNU tar, and gzip runs with
`-n` so it stores no timestamp. Two runs of `qlp publish` over unchanged
projects give the same `file-md5` and `content-sha1`.

## Building

Requires SBCL with Quicklisp installed, GNU `tar` and `gzip`.

```bash
make build     # writes build/qlp
make tests     # runs the FiveAM suite
```

See [`docs/BUILD.md`](docs/BUILD.md) for detail.

## Documentation

- [`docs/PROJECT.md`](docs/PROJECT.md) — overview, tech stack, CLI
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — source layout and how a project becomes a distribution
- [`docs/BUILD.md`](docs/BUILD.md) — building, testing
- [`docs/CONFIG.md`](docs/CONFIG.md) — the command line, option by option

## License

GNU General Public License version 3 or (at your option) any later version
(GPL-3.0-or-later). See [`LICENSE`](LICENSE).
