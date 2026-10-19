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

;;; Checking a published distribution against its own files.
;;;
;;; Publication and verification are separate passes on purpose: the point of
;;; verifying is to catch a distribution that was indexed inconsistently,
;;; copied badly or tampered with after it was written.

(defun parse-index-line (line)
  "Split an index LINE into fields, or NIL for a header or blank line."
  (let ((trimmed (string-right-trim '(#\Space #\Tab #\Newline) line)))
    (when (and (plusp (length trimmed)) (not (uiop:string-prefix-p "#" trimmed)))
      (remove "" (uiop:split-string trimmed :separator '(#\Space #\Tab))
              :test #'string=))))

(defun read-index (path)
  "Return the entry fields of the index file PATH."
  (iter (for line :in (uiop:read-file-lines path))
        (for fields = (parse-index-line line))
        (when fields (collect fields))))

(defun archive-for (archive-dir fields)
  "Return the local archive path described by the release index FIELDS."
  (merge-pathnames (format nil "~a.tgz" (sixth fields)) archive-dir))

(defun verify-archive (archive-dir fields)
  "Return a problem description for one releases.txt entry, or NIL."
  (let ((path (archive-for archive-dir fields)))
    (cond ((not (probe-file path))
           (format nil "~a: missing archive ~a" (first fields) (path-string path)))
          ((/= (or (parse-integer (third fields) :junk-allowed t) -1) (file-size path))
           (format nil "~a: archive size does not match the index" (first fields)))
          ((not (string= (fourth fields) (file-md5 path)))
           (format nil "~a: archive MD5 does not match the index" (first fields)))
          (t nil))))

(defun verify-release-index (archive-dir release-fields)
  "Return the problems found in the releases.txt entries RELEASE-FIELDS."
  (iter (for fields :in release-fields)
        (for problem = (verify-archive archive-dir fields))
        (when problem (collect problem))))

(defun release-for (release-fields project)
  "Return the release index fields describing PROJECT."
  (find project release-fields :key #'first :test #'string=))

(defun verify-system-entry (release-fields fields)
  "Return a problem description for one systems.txt entry, or NIL."
  (let* ((project (first fields))
         (asd-file (second fields))
         (system (third fields))
         (release (release-for release-fields project)))
    (cond ((null release)
           (format nil "~a: no release provides project ~a" system project))
          ((not (member asd-file release :test #'string=))
           (format nil "~a: release ~a does not ship ~a" system project asd-file))
          (t nil))))

(defun verify-system-index (release-fields system-fields)
  "Return the problems found in the systems.txt entries SYSTEM-FIELDS."
  (iter (for fields :in system-fields)
        (for problem = (verify-system-entry release-fields fields))
        (when problem (collect problem))))

(defun verify-dist (config)
  "Verify the distribution CONFIG describes.
Returns (VALUES PROBLEMS-P PROBLEMS), where PROBLEMS-P is true when the
distribution is inconsistent with the archives stored beside it."
  (validate-config config)
  (let* ((version (resolve-version (config-version config)))
         (layout (render-layout config version))
         (dist-dir (getf layout :dist-dir))
         (indexes (list (getf layout :distinfo)
                        (merge-pathnames "releases.txt" dist-dir)
                        (merge-pathnames "systems.txt" dist-dir)))
         (missing (iter (for path :in indexes)
                        (unless (probe-file path) (collect (path-string path))))))
    (if (plusp (length missing))
        (values t (iter (for path :in missing)
                        (collect (format nil "missing index file ~a" path))))
        (let* ((release-fields (read-index (second indexes)))
               (system-fields (read-index (third indexes)))
               (problems (append (verify-release-index (getf layout :archive-dir)
                                                        release-fields)
                                 (verify-system-index release-fields system-fields))))
          (values (null problems) problems)))))
