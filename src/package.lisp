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

(defpackage :qlp
  (:use :cl :iterate :metabang-bind)
  (:local-nicknames (#:ironclad :ironclad)
                    (#:clingon :clingon))
  (:export #:main
           #:publish
           #:verify-dist
           #:discover-systems
           #:make-config
           #:render-template
           #:config-name
           #:config-version
           #:config-base-url
           #:config-projects-dir
           #:config-dists-dir
           #:config-exclude
           #:config-tar-program
           #:system-definition
           #:system-definition-name
           #:system-definition-depends-on
           #:system-definition-defsystem-depends-on
           #:system-definition-source-file
           #:scan-asd-file
           #:relative-path
           #:path-string
           #:unix-filename
           #:release-systems
           #:*distinfo-template*
           #:*distinfo-file-template*
           #:*dist-dir-template*
           #:*archive-dir-template*
           #:*archive-url-template*
           #:project
           #:project-name
           #:project-path
           #:project-system-files
           #:project-systems
           #:analyze-project
           #:dist-publish-report
           #:report-release-count
           #:report-system-count
           #:report-skipped))
