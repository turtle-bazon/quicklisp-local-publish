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

;;; Scanning .asd files. These tests are the reason this program exists: a
;;; project must publish every system its .asd files define, including the
;;; sub-systems a helper macro expands to, which reading the file as text
;;; cannot see.

(defparameter +sub-systems-asd+
  "(cl:defpackage #:qlp-fixture-system (:use :cl :asdf))
(cl:in-package #:qlp-fixture-system)

;;; Generates sub-systems the way IRONCLAD does: nothing in the
;;; file mentions them as defsystem forms until it is evaluated.
(cl:defmacro define-subsystems (kind &rest names)
  (let ((generated (loop for name in names
                         collect (format nil \"qlp-fixture/~a/~a\" kind name))))
    `(progn
       ,@(loop for name in generated
               collect `(defsystem ,name
                          :depends-on (\"qlp-fixture/core\")
                          :description \"generated\")))))

;;; The system named after the file is declared first, exactly as
;;; IRONCLAD declares IRONCLAD before IRONCLAD/TESTS: ASDF insists that
;;; the parent of a sub-system is already defined when the sub-system
;;; is looked up.
(defsystem \"qlp-fixture\"
  :description \"the system named after the file\"
  :defsystem-depends-on (\"asdf\")
  :depends-on (\"qlp-fixture/util\" \"not-installed-anywhere\")
  :components ((:file \"package\")))

(defsystem \"qlp-fixture/util\"
  :description \"a sibling sub-system\"
  :components ((:file \"util\")))

(defsystem \"qlp-fixture/core\"
  :description \"a sub-system declared literally\"
  :depends-on (\"qlp-fixture/util\"))

(define-subsystems \"cipher\" \"aes\" \"chacha\")"
  "An .asd file defining five systems, two of them only through a macro.")

(defparameter +literal-asd+
  "(asdf:defsystem \"qlp-plain\"
  :description \"one plain system\"
  :depends-on (\"qlp-plain-helper\")
  :components ((:file \"plain\")))
(asdf:defsystem \"qlp-plain-helper\"
  :description \"another one in the same file\"
  :components ((:file \"helper\")))"
  "An .asd file defining two systems literally.")

(defparameter +self-referential-asd+
  "(asdf:defsystem \"qlp-selfref\"
  :description \"looks itself up while being read\"
  :depends-on (\"qlp-selfref-helper\"))
(defmethod asdf:perform :after ((op asdf:load-op)
                                 (c (eql (asdf:find-system \"qlp-selfref\"))))
  (declare (ignore op c)))
(asdf:defsystem \"qlp-selfref-helper\"
  :description \"the system that must be found first\")"
  "An .asd file that calls FIND-SYSTEM on itself, as real system files do.")

(defun definitions-by-name (definitions)
  "Return the definitions of DEFINITIONS in a table keyed by system name."
  (let ((table (make-hash-table :test 'equal)))
    (iter (for definition :in definitions)
          (setf (gethash (system-definition-name definition) table) definition))
    table))

(defun scan-fixture (directory contents name)
  "Write CONTENTS to DIRECTORY/NAME and scan it."
  (let ((file (merge-pathnames (if (uiop:string-suffix-p name ".asd")
                                   name
                                   (format nil "~a.asd" name))
                               directory)))
    (qlp:scan-asd-file (write-file file contents))))

(test scan-finds-sub-systems-generated-by-a-macro
  "Systems a helper macro expands to are published too."
  (with-temp-directory (directory)
    (let ((definitions (scan-fixture directory +sub-systems-asd+ "qlp-fixture")))
      (is (equal 5 (length definitions))
          "five systems: two generated, three declared literally")
      (is (every (lambda (name) (gethash name (definitions-by-name definitions)))
                 '("qlp-fixture" "qlp-fixture/core" "qlp-fixture/util"
                   "qlp-fixture/cipher/aes" "qlp-fixture/cipher/chacha"))))))

(test scan-records-dependencies
  "A sub-system's own dependencies are recorded."
  (with-temp-directory (directory)
    (let* ((definitions (scan-fixture directory +sub-systems-asd+ "qlp-fixture"))
           (by-name (definitions-by-name definitions)))
      (is (equal '("qlp-fixture/core")
                 (qlp:system-definition-depends-on
                  (gethash "qlp-fixture/cipher/aes" by-name))))
      (is (equal '("qlp-fixture/util")
                 (qlp:system-definition-depends-on
                  (gethash "qlp-fixture/core" by-name))))
      (is (equal '() (qlp:system-definition-depends-on
                      (gethash "qlp-fixture/util" by-name)))))))

(test scan-records-defsystem-depends-on
  "A :defsystem-depends-on target is recorded apart from :depends-on."
  (with-temp-directory (directory)
    (let* ((definitions (scan-fixture directory +sub-systems-asd+ "qlp-fixture"))
           (by-name (definitions-by-name definitions)))
      (is (equal '("asdf")
                 (qlp:system-definition-defsystem-depends-on
                  (gethash "qlp-fixture" by-name)))))))

(test scan-leaves-asdf-untouched
  "Scanning registers nothing in ASDF and loads no missing dependency."
  (with-temp-directory (directory)
    (let ((before (asdf:registered-systems)))
      (scan-fixture directory +sub-systems-asd+ "qlp-fixture")
      (is (equal (length before) (length (asdf:registered-systems))))
      (is (null (find "not-installed-anywhere" (asdf:registered-systems)
                      :test #'string=))))))

(test scan-handles-a-file-that-looks-itself-up
  "A system file calling FIND-SYSTEM on itself is still scanned."
  (with-temp-directory (directory)
    (let ((before (asdf:registered-systems)))
      (let ((definitions (scan-fixture directory +self-referential-asd+ "qlp-selfref")))
        (is (equal 2 (length definitions)))
        (is (every (lambda (name) (gethash name (definitions-by-name definitions)))
                   '("qlp-selfref" "qlp-selfref-helper"))))
      (is (equal (length before) (length (asdf:registered-systems)))))))

(test scan-finds-literally-declared-systems
  "Plain defsystem forms in one file are all found."
  (with-temp-directory (directory)
    (let ((definitions (scan-fixture directory +literal-asd+ "qlp-plain")))
      (is (equal 2 (length definitions)))
      (is (every (lambda (name) (gethash name (definitions-by-name definitions)))
                 '("qlp-plain" "qlp-plain-helper"))))))

(test scan-records-the-source-file
  "Every definition points back at the file that defined it."
  (with-temp-directory (directory)
    (let* ((path (write-file (merge-pathnames "qlp-plain.asd" directory) +literal-asd+))
           (definitions (qlp:scan-asd-file path)))
      (is (every (lambda (definition)
                   (equal (truename path)
                          (truename (qlp:system-definition-source-file definition))))
                 definitions)))))

(test scan-is-case-insensitive
  "System names are recorded in lower case, as Quicklisp expects."
  (with-temp-directory (directory)
    (let ((definitions
            (scan-fixture directory "(asdf:defsystem \"Mixed-Case\")" "mixed.asd")))
      (is (equal '("mixed-case") (mapcar #'qlp:system-definition-name definitions))))))

(test dependency-specs-are-normalized
  "Version requirements unwrap; feature requirements name no system."
  (is (equal "ironclad" (qlp::dependency-name '(:version "Ironclad"))))
  (is (equal "ironclad" (qlp::dependency-name "IRONCLAD")))
  (is (equal "ironclad" (qlp::dependency-name :ironclad)))
  (is (null (qlp::dependency-name '(:require :sb-posix))))
  (is (null (qlp::dependency-name '(:feature :sbcl)))))
