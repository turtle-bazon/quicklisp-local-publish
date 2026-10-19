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

;;; Turning a directory of projects into a distribution directory.

(defstruct (dist-publish-report
             (:constructor %make-dist-publish-report (releases skipped)))
  (releases '() :type list)
  (skipped '() :type list))

(defun report-release-count (report)
  "Return how many releases the publication produced."
  (length (dist-publish-report-releases report)))

(defun report-system-count (report)
  "Return how many systems the publication made available."
  (iter (for release :in (dist-publish-report-releases report))
        (sum (length (release-systems release)))))

(defun report-skipped (report)
  "Return the names of the projects that were left out."
  (dist-publish-report-skipped report))

(defun resolve-version (version)
  "Return VERSION as a string, resolving :NOW to the current UTC timestamp."
  (if (eq version :now)
      (format-timestamp (get-universal-time))
      version))

(defun template-data (config version)
  "Return the plist the layout templates are rendered against."
  (list :name (config-name config)
        :version version
        :base-url (string-right-trim "/" (config-base-url config))
        :dists-dir (string-right-trim "/" (path-string
                                           (uiop:ensure-directory-pathname
                                            (config-dists-dir config))))))

(defun render-layout (config version)
  "Return the file and directory locations of this distribution."
  (let ((data (template-data config version)))
    (list :distinfo (file-pathname (render-template *distinfo-file-template* data))
          :dist-dir (uiop:ensure-directory-pathname
                     (render-template *dist-dir-template* data))
          :archive-dir (uiop:ensure-directory-pathname
                        (render-template *archive-dir-template* data))
          :archive-url (render-template *archive-url-template* data))))

(defun archive-projects (projects layout exclude tar-program)
  "Archive every non-empty PROJECT, returning releases and skipped names."
  (iter (for project :in projects)
        (if (null (project-systems project))
            (progn
              (warn "No systems found in ~a, skipping." (project-path project))
              (collect (cons project nil)))
            (collect (cons project (archive-project project
                                                      (getf layout :archive-dir)
                                                      (getf layout :archive-url)
                                                      :exclude exclude
                                                      :tar-program tar-program))))))

(defun publish (config)
  "Publish CONFIG as a Quicklisp distribution and return a report.
Every subdirectory of the projects directory becomes one release."
  (validate-config config)
  (let* ((version (resolve-version (config-version config)))
         (exclude (config-exclude config))
         (layout (render-layout config version))
         (projects (find-projects (config-projects-dir config) :exclude exclude))
         (archived (archive-projects projects layout exclude (config-tar-program config)))
         (releases (iter (for entry :in archived)
                         (when (cdr entry) (collect (cdr entry)))))
         (skipped (iter (for entry :in archived)
                        (unless (cdr entry) (collect (car entry))))))
    (write-lines (merge-pathnames "releases.txt" (getf layout :dist-dir))
                 (release-index-lines releases))
    (write-lines (merge-pathnames "systems.txt" (getf layout :dist-dir))
                 (system-index-lines releases))
    (let ((distinfo (render-template *distinfo-template* (template-data config version))))
      (write-string-to-file distinfo (getf layout :distinfo)
                            :if-exists :supersede :if-does-not-exist :create)
      (write-string-to-file distinfo
                            (merge-pathnames "distinfo.txt" (getf layout :dist-dir))
                            :if-exists :supersede :if-does-not-exist :create))
    (%make-dist-publish-report releases
                               (iter (for project :in skipped)
                                     (collect (project-name project))))))

(defun discover-systems (config)
  "Return every system the projects of CONFIG define, grouped by project."
  (let ((exclude (config-exclude config)))
    (iter (for project :in (find-projects (config-projects-dir config) :exclude exclude))
          (collect (cons project (project-systems project))))))
