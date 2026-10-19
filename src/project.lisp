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

;;; Locating projects and the systems inside them.

(defstruct (project (:constructor %make-project (name path system-files systems)))
  (name "" :type string)
  (path nil)
  (system-files '() :type list)
  (systems '() :type list))

(defun wildcard-match-p (pattern string)
  "True when STRING matches PATTERN, where * spans any run, ? one character
and ** spans any run including the directory separator."
  (labels ((match (p s)
             (cond ((zerop (length p)) (zerop (length s)))
                   ((uiop:string-prefix-p "**/" p)
                    ;; ** spans any run, separators included, so the pattern
                    ;; after it is tried against every suffix of the string.
                    (let ((rest (subseq p 3)))
                      (or (match rest s)
                          (iter (for i :from 1 :to (length s))
                                (when (match rest (subseq s i))
                                  (return t))
                                (finally (return nil))))))
                   ((uiop:string-prefix-p "**" p) (match (subseq p 2) s))
                   ((char= (char p 0) #\*)
                    (iter (for i :from 0 :to (length s))
                          (when (and (match (subseq p 1) (subseq s i))
                                     (or (zerop i) (char/= (char s (1- i)) #\/)))
                            (return t))
                          (finally (return nil))))
                   ((and (plusp (length s))
                         (or (char= (char p 0) #\?)
                             (char-equal (char p 0) (char s 0))))
                    (match (subseq p 1) (subseq s 1)))
                   (t nil))))
    (match pattern string)))

(defun excluded-p (path exclude)
  "True when the name of PATH, file or directory, matches one of EXCLUDE."
  (let ((name (or (and (pathname-name path) (unix-filename path))
                  (directory-name path)
                  "")))
    (iter (for pattern :in exclude)
          (when (wildcard-match-p pattern name) (return t))
          (finally (return nil)))))

(defun list-files (root exclude)
  "Return every file under ROOT, sorted, skipping entries EXCLUDE matches.
Excluded directories are not descended into."
  (labels ((walk (directory)
             (iter (for entry :in (directory-entries directory))
                   (unless (excluded-p entry exclude)
                     (if (uiop:directory-pathname-p entry)
                         (appending (walk entry))
                         (collect entry))))))
    (sort (walk root) #'string< :key #'path-string)))

(defun find-system-files (root exclude)
  "Return the .asd files under ROOT."
  (iter (for path :in (list-files root exclude))
        (when (asd-file-p path) (collect path))))

(defun scan-system-files (root exclude)
  "Scan every .asd file under ROOT and return the definitions found."
  (iter (for path :in (find-system-files root exclude))
        (appending (scan-asd-file path))))

(defun analyze-project (directory &key (exclude '()))
  "Describe the project in DIRECTORY: its name and every system it defines."
  (let* ((path (directory-pathname directory))
         (systems (scan-system-files path exclude))
         (contributing (remove-duplicates
                        (iter (for system :in systems)
                              (collect (relative-path path
                                                      (system-definition-source-file system))))
                        :test #'string=)))
    (%make-project (directory-basename path) path
                   (sort contributing #'string<) systems)))

(defun find-projects (projects-directory &key (exclude '()))
  "Return the projects found in PROJECTS-DIRECTORY, ordered by name."
  (let ((root (directory-pathname projects-directory)))
    (sort (iter (for entry :in (directory-entries root))
                (when (and (uiop:directory-pathname-p entry)
                           (not (excluded-p entry exclude)))
                  (collect (analyze-project entry :exclude exclude))))
          #'string< :key #'project-name)))
