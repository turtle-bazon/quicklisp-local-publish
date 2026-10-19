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

;;; The qlp command line.

(defun common-options ()
  "Return the options every qlp subcommand accepts."
  (list (clingon:make-option :string :long-name "name" :key :name
                             :description "Name of the distribution")
        (clingon:make-option :string :long-name "dist-version" :key :version
                             :description "Version of the distribution (default: today's date)")
        (clingon:make-option :string :long-name "base-url" :key :base-url
                             :description "URL the distribution will be served from")
        (clingon:make-option :filepath :long-name "projects-dir" :key :projects-dir
                             :description "Directory holding one directory per project")
        (clingon:make-option :filepath :long-name "dists-dir" :key :dists-dir
                             :description "Directory the distribution is written to")
        (clingon:make-option :string :long-name "tar-program" :key :tar-program
                             :description "Path to the GNU tar program")
        (clingon:make-option :list :long-name "exclude" :key :exclude
                             :description "Name or pattern to keep out of the archives; repeatable")))

(defun option-pathname (cmd key)
  "Return the pathname option KEY of CMD as a string, or NIL when unset."
  (let ((value (clingon:getopt cmd key)))
    (and value (path-string value))))

(defun command-config (cmd)
  "Build a configuration from the options CMD was invoked with.
Excluded names given on the command line are added to those kept out by
default, rather than replacing them: an option that excludes `mine' would
be a poor trade for `.git' ending up in an archive."
  (let ((config (merge-config
                 (make-config)
                 (list :name (clingon:getopt cmd :name)
                       :version (clingon:getopt cmd :version)
                       :base-url (clingon:getopt cmd :base-url)
                       :projects-dir (option-pathname cmd :projects-dir)
                       :dists-dir (option-pathname cmd :dists-dir)
                       :tar-program (clingon:getopt cmd :tar-program)))))
    (let ((extra (clingon:getopt cmd :exclude)))
      (if extra
          (merge-config config (list :exclude (append extra (config-exclude config))))
          config))))

(defun run-publish (cmd)
  "Publish a distribution."
  (let* ((config (command-config cmd))
         (report (publish config)))
    (format t "Published ~d release(s) providing ~d system(s) into ~a~%"
            (report-release-count report) (report-system-count report)
            (config-dists-dir config))
    (iter (for name :in (report-skipped report))
          (format t "  skipped ~a: no systems found~%" name))
    0))

(defun run-verify (cmd)
  "Verify a published distribution against the archives beside it."
  (multiple-value-bind (consistent problems) (verify-dist (command-config cmd))
    (if consistent
        (progn (format t "Distribution is consistent.~%") 0)
        (progn
          (format t "Distribution has ~d problem(s):~%" (length problems))
          (iter (for problem :in problems) (format t "  ~a~%" problem))
          (clingon:exit 1)
          1))))

(defun print-project-systems (entry)
  "Print the systems ENTRY, a project and its systems, as a cons cell."
  (let ((project (car entry)))
    (format t "~a~%" (project-name project))
    (iter (for system :in (cdr entry))
          (format t "  ~a~%      defined in ~a~%"
                  (system-definition-name system)
                  (relative-path (project-path project)
                                 (system-definition-source-file system))))))

(defun run-systems (cmd)
  "List every system the projects define, sub-systems included."
  (let ((entries (discover-systems (command-config cmd))))
    (if (null entries)
        (progn (format t "No systems found.~%") 0)
        (progn
          (iter (for entry :in entries) (print-project-systems entry))
          (format t "~&~d system(s) in ~d project(s).~%"
                  (iter (for entry :in entries) (sum (length (cdr entry))))
                  (length entries))
          0))))

(defun run-clean (cmd)
  "Remove the published directory of one distribution version."
  (unless (clingon:getopt cmd :yes)
    (format *error-output* "Refusing to remove files without --yes.~%")
    (clingon:exit 1))
  (let* ((config (command-config cmd))
         (version (resolve-version (config-version config)))
         (directory (getf (render-layout config version) :dist-dir)))
    (if (uiop:directory-exists-p directory)
        (progn (uiop:delete-directory-tree directory :validate t)
               (format t "Removed ~a~%" (path-string directory)))
        (format t "Nothing to remove.~%"))
    0))

(defun guarded (thunk)
  "Call THUNK, reporting any error and exiting non-zero."
  (handler-case (funcall thunk)
    (error (condition)
      (format *error-output* "qlp: ~a~%" condition)
      (clingon:exit 1)
      1)))
