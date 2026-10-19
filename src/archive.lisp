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

;;; Building release archives.
;;;
;;; Archives are reproducible: the same sources always yield byte identical
;;; tarballs. Member order comes from our own sorted file list, timestamps
;;; are pinned to the project's newest source file, and ownership is zeroed,
;;; so only a real change to the sources changes the archive.
;;;
;;; The file list handed to tar is the very same pruned list the scanner
;;; walked, which keeps a published release and its index in agreement about
;;; what the project contains.

(defstruct (release
             (:constructor %make-release (project-name path prefix archive-path
                                            archive-url size md5 sha1
                                            system-files systems)))
  (project-name "" :type string)
  (path nil)
  (prefix "" :type string)
  (archive-path nil)
  (archive-url "" :type string)
  (size 0 :type integer)
  (md5 "" :type string)
  (sha1 "" :type string)
  (system-files '() :type list)
  (systems '() :type list))

(defun format-date (universal-time)
  "Format UNIVERSAL-TIME as YYYYMMDD."
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time universal-time)
    (declare (ignore second minute hour))
    (format nil "~4,'0d~2,'0d~2,'0d" year month day)))

(defun effective-mtime (root exclude)
  "Return the newest modification time under ROOT as a universal time."
  (let ((newest 0))
    (iter (for path :in (list-files root exclude))
          (for date = (or (file-write-date path) 0))
          (when (> date newest) (setf newest date)))
    newest))

(defun archive-prefix (project exclude)
  "Return the archive prefix of PROJECT: its name and its source date."
  (format nil "~a-~a" (project-name project)
          (format-date (effective-mtime (project-path project) exclude))))

(defun write-file-list (path entries)
  "Write the NUL separated relative file names ENTRIES to PATH."
  (with-open-file (stream path :direction :output
                          :if-exists :supersede :if-does-not-exist :create
                          :external-format :utf-8)
    (iter (for entry :in entries)
          (write-string entry stream)
          (write-char (code-char 0) stream))))

(defun tar-command (project-path tar-path list-path epoch prefix)
  "Return the argument list that builds TAR-PATH out of PROJECT-PATH."
  (list "--create" "--file" (path-string tar-path)
        "--directory" (path-string project-path)
        "--transform" (format nil "s#^#~a/#" prefix)
        "--owner" "0" "--group" "0" "--numeric-owner"
        "--format" "gnu"
        "--mtime" (format nil "@~d" epoch)
        "--null" "--files-from" (path-string list-path)))

(defun run-tar (tar-program project-path tar-path list-path epoch prefix)
  "Create a deterministic tar archive of PROJECT-PATH with TAR-PROGRAM."
  (uiop:run-program (cons (path-string tar-program)
                          (tar-command project-path tar-path list-path epoch prefix))
                    :output :string :error-output :interactive))

(defun gzip-path (tar-path)
  "Return the name gzip gives TAR-PATH, which appends .gz to it."
  (let ((type (pathname-type tar-path)))
    (make-pathname :type (if type (format nil "~a.gz" type) "gz")
                   :defaults tar-path)))

(defun relative-entries (project exclude)
  "Return PROJECT's files as Unix paths relative to its root."
  (let ((root (project-path project)))
    (iter (for path :in (list-files root exclude))
          (collect (relative-path root path)))))

(defun archive-project (project archive-directory archive-url
                        &key (exclude *default-exclude*) (tar-program "tar"))
  "Archive PROJECT into ARCHIVE-DIRECTORY and describe the result.
The archive is stored under ARCHIVE-URL."
  (let* ((directory (uiop:ensure-directory-pathname archive-directory))
         (prefix (archive-prefix project exclude))
         (tar-path (merge-pathnames (format nil "~a.tar" prefix) directory))
         (archive-path (merge-pathnames (format nil "~a.tgz" prefix) directory))
         (list-path (merge-pathnames (format nil "~a.files" prefix) directory))
         (epoch (effective-mtime (project-path project) exclude)))
    (ensure-directories-exist directory)
    (unwind-protect
         (progn
           (write-file-list list-path (relative-entries project exclude))
           (run-tar tar-program (project-path project) tar-path list-path epoch prefix)
           (let ((sha1 (file-sha1 tar-path)))
             (uiop:run-program (list "gzip" "-n" "-9" "-f" (path-string tar-path)))
             (rename-file (gzip-path tar-path) archive-path)
             (%make-release (project-name project) (project-path project) prefix archive-path
                            (format nil "~a/~a.tgz" archive-url prefix)
                            (file-size archive-path) (file-md5 archive-path) sha1
                            (project-system-files project) (project-systems project))))
      (uiop:delete-file-if-exists tar-path)
      (uiop:delete-file-if-exists list-path)
      (uiop:delete-file-if-exists (gzip-path tar-path)))))
