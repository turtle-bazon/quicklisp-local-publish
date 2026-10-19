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

;;; Pathname helpers. Distribution indexes address files with Unix
;;; separators relative to the project directory, never with host syntax.

(defun directory-pathname (directory)
  "Return DIRECTORY as a directory pathname that exists."
  (let ((path (uiop:ensure-directory-pathname directory)))
    (unless (uiop:directory-exists-p path)
      (error "Directory doesn't exist: ~a" directory))
    (truename path)))

(defun directory-entries (directory)
  "Return the entries of DIRECTORY, files and subdirectories alike.
UIOP's DIRECTORY-FILES deliberately leaves subdirectories out, so the
two wildcards UIOP is shipped with are matched separately and merged."
  (let ((path (uiop:ensure-directory-pathname directory)))
    (remove-duplicates
     (append (uiop:directory-files path)
             (uiop:directory* (merge-pathnames uiop:*wild-directory* path)))
     :test #'uiop:pathname-equal)))

(defun file-pathname (path)
  "Return PATH as a pathname naming a file rather than a directory."
  (let ((parsed (if (pathnamep path) path (parse-namestring (string path)))))
    (make-pathname :name (or (pathname-name parsed) "qlp") :defaults parsed)))

(defun path-string (path)
  "Return PATH as a namestring using the host syntax."
  (uiop:native-namestring path))

(defun unix-filename (pathname)
  "Return PATHNAME as a Unix-style file name, e.g. \"foo.bar\"."
  (let ((name (or (pathname-name pathname) ""))
        (type (pathname-type pathname)))
    (if type (format nil "~a.~a" name type) name)))

(defun unix-pathname (pathname)
  "Return PATHNAME with Unix separators."
  (with-output-to-string (out)
    (iter (for part :in (butlast (pathname-directory pathname)))
          (write-string part out)
          (write-char #\/ out))
    (write-string (unix-filename pathname) out)))

(defun relative-path (base path)
  "Return PATH relative to directory BASE, using Unix separators."
  (let* ((base-string (path-string (truename base)))
         (path-string (path-string (truename path)))
         (prefix (with-output-to-string (out)
                   (write-string base-string out)
                   (unless (uiop:string-suffix-p base-string "/")
                     (write-char #\/ out)))))
    (unless (uiop:string-prefix-p prefix path-string)
      (error "~a is not inside ~a" path-string base-string))
    (subseq path-string (length prefix))))

(defun directory-name (pathname)
  "Return the last directory component of PATHNAME as a string."
  (first (last (pathname-directory pathname))))

(defun directory-basename (directory)
  "Return the last component of DIRECTORY as a string."
  (directory-name (truename directory)))

(defun asd-file-p (path)
  "True when PATH is an ASDF system definition file."
  (and (pathname-name path)
       (string-equal "asd" (or (pathname-type path) ""))))

(defun write-string-to-file (contents path
                             &key (if-exists :supersede) (if-does-not-exist :create))
  "Write the string CONTENTS to PATH, creating its directory if needed."
  (let ((file (file-pathname path)))
    (ensure-directories-exist file)
    (with-open-file (stream file :direction :output
                                  :if-exists if-exists
                                  :if-does-not-exist if-does-not-exist
                                  :external-format :utf-8)
      (write-string contents stream))
    file))
