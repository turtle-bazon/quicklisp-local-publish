# quicklisp-local-publish — Configuration

Everything `qlp` does is said on the command line. There is no configuration
file, no environment variable and no state: one invocation is all that
describes a publication.

## The Four That Are Always Needed

```bash
qlp publish --name mydist \
            --base-url https://dist.example.org \
            --projects-dir /srv/lisp/projects \
            --dists-dir /srv/www/dist
```

| Option | Meaning |
|--------|---------|
| `--name NAME` | distribution name |
| `--base-url URL` | URL the distribution will be served from |
| `--projects-dir DIR` | directory holding one directory per project |
| `--dists-dir DIR` | directory the distribution is written to |

Leaving any of them out is an error before anything is written, and the
error names the option:

```
qlp: Missing required option --dists-dir.
```

An option given as the empty string is refused just the same.

## The Rest

| Option | Default | Meaning |
|--------|---------|---------|
| `--dist-version VERSION` | today's date as `YYYYMMDD` | version of this publication |
| `--tar-program PATH` | `tar` | GNU tar to run |
| `--exclude PATTERN` | see below | name or pattern kept out of the archives; repeatable |
| `--yes` | — | `qlp clean` only; without it nothing is removed |

`--exclude` **extends** what is already left out. It is repeatable, and

```bash
qlp publish ... --exclude '*.bak' --exclude notes
```

excludes `*.bak` and `notes` *and* everything below.

### Left out by default

```
.git  .hg  .svn  .bzr  CVS  .DS_Store  .gitmodules
*.fasl  *.FASL  *.ufasl  *.lib  *.fas
build  target  .cache  .cpcache  node_modules
```

An exclusion is matched against the file name, or against the last
component of a directory, so `*` never has to cross a `/` unless the
pattern says so.

## Subcommands

Every subcommand takes the options above, because every subcommand needs to
know which distribution it is about:

```bash
qlp publish   # write the distribution
qlp verify    # check the indexes against the archives beside them
qlp systems   # list the systems the projects define
qlp clean     # remove one version's directory
```

`qlp clean` additionally requires `--yes`. `qlp verify` exits 1 when the
distribution is inconsistent.

## A Full Example

```bash
qlp publish  --name local \
             --base-url https://lisp.example.org/dist \
             --projects-dir /srv/lisp/projects \
             --dists-dir /srv/www/dist

qlp verify   --name local --base-url https://lisp.example.org/dist \
             --projects-dir /srv/lisp/projects --dists-dir /srv/www/dist

qlp systems  --name local --base-url https://lisp.example.org/dist \
             --projects-dir /srv/lisp/projects --dists-dir /srv/www/dist

qlp clean --yes --name local --base-url https://lisp.example.org/dist \
          --projects-dir /srv/lisp/projects --dists-dir /srv/www/dist \
          --dist-version 20261019
```

The same four options repeat because each invocation stands alone — which
is also why a shell alias or function is the natural place for them:

```bash
qlpd () {
  qlp "$1" --name local \
           --base-url https://lisp.example.org/dist \
           --projects-dir /srv/lisp/projects \
           --dists-dir /srv/www/dist \
           "${@:2}"
}
```
