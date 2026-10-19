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
mydist.txt                                     the distinfo a client subscribes to
mydist/20261019233007/distinfo.txt             the same, inside the version directory
mydist/20261019233007/releases.txt             one line per release
mydist/20261019233007/systems.txt              one line per system
mydist/archive/somepackage-20261019233007.tgz  the archives those lines point at
```

## Serving and subscribing

`--dists-dir` is an ordinary directory tree, so serve it at `--base-url` with
any static file server — every file's URL is just its path under that root:

```
https://dist.example.org/mydist.txt                                subscribe here
https://dist.example.org/mydist/20261019233007/distinfo.txt        the same distinfo
https://dist.example.org/mydist/20261019233007/releases.txt
https://dist.example.org/mydist/20261019233007/systems.txt
https://dist.example.org/mydist/archive/somepackage-20261019233007.tgz
```

`mydist.txt` is the one a client subscribes to, and the
`distinfo-subscription-url` field inside it names that very file (the copy
under the version directory is byte-identical):

```
name: mydist
version: 20261019233007
distinfo-subscription-url: https://dist.example.org/mydist.txt
release-index-url: https://dist.example.org/mydist/20261019233007/releases.txt
system-index-url: https://dist.example.org/mydist/20261019233007/systems.txt
```

Subscribe with the Quicklisp client:

```lisp
(ql-dist:install-dist "https://dist.example.org/mydist.txt" :prompt nil)
(ql:quickload "somepackage")
```

The client keeps the URL it subscribed from, so once you publish again:

```lisp
(ql:update-all-dists :prompt nil)
```

## Why sub-systems

A file such as `somepackage.asd` may define `somepackage` *and* a couple of
dozen more systems under `somepackage/`. Quicklisp indexes them only when a
project's `.asd` files are read the way ASDF reads them, so `qlp` reads them
that way: it evaluates each `.asd` file with ASDF's own registration hooked,
records every `defsystem` it sees, and then puts ASDF back the way it found
it. Systems that macro helpers expand into are caught too, because what is
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
