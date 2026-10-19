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

;;; The two index files, in the format Quicklisp reads.

(defun sample-release (root)
  "Return a release whose project directory lives under ROOT."
  (qlp::%make-release "ironclad" root "ironclad-20240101"
                      (merge-pathnames "ironclad-20240101.tgz" root)
                      "http://example.org/dist/ironclad/archive/ironclad-20240101.tgz"
                      1234 "d41d8cd98f00b204e9800998ecf8427e"
                      "8843d7f92416211de9ebb963ff4ce28125932878"
                      '("ironclad.asd")
                      (let ((asd (merge-pathnames "ironclad.asd" root)))
                        (list (qlp::%make-system-definition "ironclad" '("bordeaux-threads") '() asd)
                              (qlp::%make-system-definition "ironclad/aead/gcm" '("ironclad/core") '() asd)))))

(test fields-are-single-spaced
  "Index fields are separated by exactly one space."
  (is (equal "a b c" (qlp::join-fields '("a" "b" "c"))))
  (is (equal "a c" (qlp::join-fields '("a" nil "c"))))
  (is (equal "a" (qlp::join-fields '("a")))))

(test release-line-format
  "A release line carries the archive and every .asd file it ships."
  (with-temp-directory (root)
    (write-file (merge-pathnames "ironclad.asd" root) "(asdf:defsystem \"ironclad\")")
    (let ((line (qlp::release-line (sample-release root))))
      (is (equal (format nil
                         "ironclad http://example.org/dist/ironclad/archive/ironclad-20240101.tgz 1234 ~a ~a ironclad-20240101 ironclad.asd"
                         "d41d8cd98f00b204e9800998ecf8427e"
                         "8843d7f92416211de9ebb963ff4ce28125932878")
                 line)))))

(test system-line-format
  "Every system gets its own line, naming the .asd file that defines it."
  (with-temp-directory (root)
    (write-file (merge-pathnames "ironclad.asd" root) "(asdf:defsystem \"ironclad\")")
    (let* ((release (sample-release root))
           (systems (qlp:release-systems release)))
      (is (equal "ironclad ironclad.asd ironclad bordeaux-threads"
                 (qlp::system-line release (first systems))))
      (is (equal "ironclad ironclad.asd ironclad/aead/gcm ironclad/core"
                 (qlp::system-line release (second systems)))))))

(test index-headers-are-first
  "Each index starts with a comment describing its columns."
  (with-temp-directory (root)
    (write-file (merge-pathnames "ironclad.asd" root) "(asdf:defsystem \"ironclad\")")
    (let ((release (sample-release root)))
      (is (equal "# project url size file-md5 content-sha1 prefix [system-file1..system-fileN]"
                 (first (qlp::release-index-lines (list release)))))
      (is (equal "# project system-file system-name [dependency1..dependencyN]"
                 (first (qlp::system-index-lines (list release)))))
      (is (= 3 (length (qlp::system-index-lines (list release))))
          "one header and one line per system"))))

(test index-lines-are-parsed-back
  "What is written can be read again, headers and all."
  (with-temp-directory (root)
    (write-file (merge-pathnames "ironclad.asd" root) "(asdf:defsystem \"ironclad\")")
    (let* ((release (sample-release root))
           (path (qlp::write-lines
                  (merge-pathnames "releases.txt" root)
                  (qlp::release-index-lines (list release))))
           (entries (qlp::read-index path)))
      (is (= 1 (length entries)))
      (is (equal "ironclad" (first (first entries))))
      (is (equal "ironclad-20240101" (sixth (first entries)))))))

(test blank-and-commented-lines-are-not-entries
  "A comment or an empty line yields no index entry."
  (is (null (qlp::parse-index-line "# a header")))
  (is (null (qlp::parse-index-line "")))
  (is (null (qlp::parse-index-line "   ")))
  (is (equal '("a" "b") (qlp::parse-index-line "a   b "))))
