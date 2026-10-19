;;; quicklisp-local-publish — publish local Common Lisp projects as a Quicklisp dist
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

(in-package :qlp)

;;; Checksums. Quicklisp verifies both: the MD5 of the archive as downloaded
;;; and the SHA1 of its unpacked content, which together catch a corrupted
;;; transfer and a swapped archive respectively.

(defun file-digest (algorithm path)
  "Return the hexadecimal ALGORITHM digest of the file PATH."
  (ironclad:byte-array-to-hex-string (ironclad:digest-file algorithm path)))

(defun file-md5 (path)
  "Return the hexadecimal MD5 digest of PATH."
  (file-digest :md5 path))

(defun file-sha1 (path)
  "Return the hexadecimal SHA1 digest of PATH."
  (file-digest :sha1 path))

(defun file-size (path)
  "Return the size of PATH in bytes."
  (with-open-file (stream path :element-type '(unsigned-byte 8))
    (file-length stream)))
