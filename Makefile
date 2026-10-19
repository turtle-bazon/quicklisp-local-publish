all: build

.PHONY: all build clean prepare tests repl

SBCL_OPTS = sbcl --noinform --non-interactive

build:
	mkdir -p build
	$(SBCL_OPTS) \
	  --eval '(ql:quickload :qlp :silent t)' \
	  --eval '(asdf:make "qlp")'

clean:
	rm -rf build

prepare:
	mkdir -p build

tests:
	$(SBCL_OPTS) \
	  --eval '(ql:quickload :qlp-tests :silent t)' \
	  --eval '(unless (qlp/tests:run-qlp-tests) (uiop:quit 1))'

repl:
	$(SBCL_OPTS) \
	  --eval '(ql:quickload :qlp :silent t)' \
	  --eval '(ql:quickload :qlp-tests :silent t)'
