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

;;; The two index files Quicklisp reads, in its own format.
;;;
;;; releases.txt names every archive of the distribution:
;;;
;;;   project url size file-md5 content-sha1 prefix [system-file1..system-fileN]
;;;
;;; and systems.txt names every system a distribution provides:
;;;
;;;   project system-file system-name [dependency1..dependencyN]
;;;
;;; A project contributes one line to releases.txt, however many systems it
;;; defines. Sub-systems share their parent's .asd file and each get their own
;;; line in systems.txt, which is what lets Quicklisp load a single .asd
;;; directly with (ql:quickload :project/sub-system).

(defparameter *release-index-header*
  "# project url size file-md5 content-sha1 prefix [system-file1..system-fileN]")

(defparameter *system-index-header*
  "# project system-file system-name [dependency1..dependencyN]")

(defun join-fields (fields)
  "Join the non-NIL FIELDS with single spaces."
  (format nil "~{~a~^ ~}" (remove nil fields)))

(defun system-file-name (release system)
  "Return the .asd file SYSTEM lives in, relative to its release."
  (relative-path (release-path release) (system-definition-source-file system)))

(defun release-line (release)
  "Return the releases.txt line describing RELEASE."
  (join-fields (append (list (release-project-name release)
                             (release-archive-url release)
                             (release-size release)
                             (release-md5 release)
                             (release-sha1 release)
                             (release-prefix release))
                       (release-system-files release))))

(defun system-line (release system)
  "Return the systems.txt line describing SYSTEM inside RELEASE."
  (join-fields (append (list (release-project-name release)
                             (system-file-name release system)
                             (system-definition-name system))
                       (system-definition-depends-on system))))

(defun release-index-lines (releases)
  "Return every line of the release index, header included."
  (cons *release-index-header*
        (iter (for release :in releases)
              (collect (release-line release)))))

(defun system-index-lines (releases)
  "Return every line of the system index, header included.
Each system a release defines gets a line, sub-systems included."
  (cons *system-index-header*
        (iter (for release :in releases)
              (appending (iter (for system :in (release-systems release))
                               (collect (system-line release system)))))))

(defun write-lines (path lines)
  "Write LINES to PATH, one per line, ending with a newline."
  (ensure-directories-exist path)
  (with-open-file (stream path :direction :output
                          :if-exists :supersede :if-does-not-exist :create
                          :external-format :utf-8)
    (iter (for line :in lines)
          (write-string line stream)
          (terpri stream)))
  path)
