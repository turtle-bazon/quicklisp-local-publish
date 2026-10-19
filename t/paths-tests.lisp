;;; qlp-tests — test suite for qlp
;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;;

(in-package :qlp/tests)

(in-suite qlp-tests)

;;; Paths, wildcards and the file walk.

(test wildcard-matching
  "Patterns match the way shell globs do."
  (is (qlp::wildcard-match-p "*" "anything"))
  (is (qlp::wildcard-match-p "*.fasl" "package.fasl"))
  (is (qlp::wildcard-match-p "*.fasl" "package.FASL"))
  (is (qlp::wildcard-match-p "build" "build"))
  (is (not (qlp::wildcard-match-p "build" "rebuild")))
  (is (qlp::wildcard-match-p "a?c" "abc"))
  (is (qlp::wildcard-match-p "**/target" "src/deep/target"))
  (is (not (qlp::wildcard-match-p "*.fasl" "package.lisp"))))

(test unix-filenames
  "A pathname becomes a Unix file name."
  (is (equal "ironclad.asd" (qlp:unix-filename #P"/tmp/ironclad.asd")))
  (is (equal "README" (qlp:unix-filename #P"/tmp/README"))))

(test relative-paths-use-unix-separators
  "A path under a base is reported relative to it, with slashes."
  (with-temp-directory (root)
    (write-file (merge-pathnames "src/deep/file.lisp" root) ";; hi")
    (is (equal "src/deep/file.lisp"
               (qlp:relative-path root (merge-pathnames "src/deep/file.lisp" root))))))

(test file-walk-prunes-excluded-directories
  "Excluded directories are neither listed nor descended into."
  (with-temp-directory (root)
    (write-file (merge-pathnames "src/main.lisp" root) ";; main")
    (write-file (merge-pathnames ".git/config" root) "[core]")
    (write-file (merge-pathnames "package.fasl" root) "fasl")
    (let ((found (mapcar (lambda (path) (qlp:relative-path root path))
                         (qlp::list-files root '(".git" "*.fasl")))))
      (is (equal '("src/main.lisp") found)))))

(test file-walk-is-ordered
  "The walk returns files in a stable order, which makes archives reproducible."
  (with-temp-directory (root)
    (write-file (merge-pathnames "b.lisp" root) "b")
    (write-file (merge-pathnames "a.lisp" root) "a")
    (write-file (merge-pathnames "c.lisp" root) "c")
    (let ((found (mapcar (lambda (path) (qlp:relative-path root path))
                         (qlp::list-files root '()))))
      (is (equal '("a.lisp" "b.lisp" "c.lisp") found)))))

(test asd-files-are-found-recursively
  "A system file in a subdirectory still belongs to the project."
  (with-temp-directory (root)
    (write-file (merge-pathnames "top.asd" root) "(asdf:defsystem \"top\")")
    (write-file (merge-pathnames "sub/deep.asd" root) "(asdf:defsystem \"deep\")")
    (let ((found (qlp::find-system-files root '())))
      (is (equal 2 (length found)))
      (is (member "sub/deep.asd" (mapcar (lambda (path) (qlp:relative-path root path)) found)
                  :test #'string=)))))
