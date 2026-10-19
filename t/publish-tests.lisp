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

;;; Publishing a whole distribution, end to end.

(defparameter +project-asd+
  "(cl:defpackage #:qlp-e2e-system (:use :cl :asdf))
(cl:in-package #:qlp-e2e-system)
(cl:defmacro define-subsystems (&rest names)
  `(progn ,@(loop for name in names
                  collect `(defsystem ,(format nil \"qlp-e2e/~a\" name)
                                :depends-on (\"qlp-e2e\")
                                :description \"generated\"))))
(define-subsystems \"sub\" \"extra\")
(defsystem \"qlp-e2e\"
  :description \"the project\"
  :components ((:file \"e2e\")))"
  "An .asd file defining a system and two macro-generated sub-systems.")

(defparameter +bare-asd+ "(asdf:defsystem \"qlp-empty\")")

(defun make-project (root name asd &key extra-files)
  "Create a project directory NAME under ROOT containing ASD."
  (let ((directory (uiop:ensure-directory-pathname (merge-pathnames name root))))
    (write-file (merge-pathnames (format nil "~a.asd" name) directory) asd)
    (write-file (merge-pathnames "e2e.lisp" directory) ";;;; e2e")
    (write-file (merge-pathnames "README.md" directory) "# e2e")
    (write-file (merge-pathnames ".git/config" directory) "[core]")
    (iter (for (path contents) :in extra-files)
          (write-file (merge-pathnames path directory) contents))
    directory))

(defun test-config (projects dists &key (version "20240101"))
  "Return a configuration publishing PROJECTS into DISTS."
  (qlp:make-config :name "testdist" :version version
                   :base-url "http://localhost:4242"
                   :projects-dir (path-string projects)
                   :dists-dir (path-string dists)))

(defun archive-members (archive)
  "Return the member names of ARCHIVE, as listed by tar."
  (remove "" (uiop:split-string
              (uiop:run-program (list "tar" "--list" "--file" (path-string archive))
                                :output :string)
              :separator '(#\Newline))
          :test #'string=))

(defun index-path (dists file)
  "Return the index FILE of the published test distribution."
  (merge-pathnames (format nil "testdist/20240101/~a" file)
                   (uiop:ensure-directory-pathname dists)))

(test publish-writes-the-three-dist-files
  "Publication leaves a distinfo and both indexes where Quicklisp looks."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (dists (merge-pathnames "dists/" root)))
      (make-project projects "qlp-e2e" +project-asd+)
      (qlp:publish (test-config projects dists))
      (is (probe-file (merge-pathnames "testdist.txt" dists)))
      (is (probe-file (index-path dists "distinfo.txt")))
      (is (probe-file (index-path dists "releases.txt")))
      (is (probe-file (index-path dists "systems.txt"))))))

(test publish-indexes-sub-systems
  "Macro-generated sub-systems are listed as systems of their own."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (dists (merge-pathnames "dists/" root)))
      (make-project projects "qlp-e2e" +project-asd+)
      (qlp:publish (test-config projects dists))
      (let ((lines (qlp::read-index (index-path dists "systems.txt"))))
        (is (= 3 (length lines)) "the system and its two sub-systems")
        (is (every (lambda (line)
                     (and (equal "qlp-e2e" (first line))
                          (equal "qlp-e2e.asd" (second line))))
                   lines)
            "all are declared in the same .asd file of the same project")
        (is (member "qlp-e2e/sub" lines :key #'third :test #'string=))
        (is (member "qlp-e2e/extra" lines :key #'third :test #'string=)))
      (let ((lines (qlp::read-index (index-path dists "releases.txt"))))
        (is (= 1 (length lines)) "one release per project")
        (is (equal "qlp-e2e.asd" (seventh (first lines))))))))

(test publish-reports-counts
  "The report says how many releases and systems were published."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (dists (merge-pathnames "dists/" root)))
      (make-project projects "qlp-e2e" +project-asd+)
      (let ((report (qlp:publish (test-config projects dists))))
        (is (= 1 (qlp:report-release-count report)))
        (is (= 3 (qlp:report-system-count report)))))))

(test publish-skips-project-without-asd-files
  "A directory holding no .asd file is skipped and named in the report."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (dists (merge-pathnames "dists/" root))
           (report (progn
                     (make-project projects "qlp-e2e" +project-asd+)
                     (write-file (merge-pathnames "not-a-project/README.md" projects) "hi")
                     (qlp:publish (test-config projects dists)))))
      (is (equal '("not-a-project") (qlp:report-skipped report)))
      (is (= 1 (qlp:report-release-count report))))))

(test archives-are-reproducible
  "The same sources produce a byte identical archive."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (first-dists (merge-pathnames "dists-a/" root))
           (second-dists (merge-pathnames "dists-b/" root)))
      (make-project projects "qlp-e2e" +project-asd+)
      (qlp:publish (test-config projects first-dists))
      (qlp:publish (test-config projects second-dists))
      (is (equal (qlp::read-index (index-path first-dists "releases.txt"))
                 (qlp::read-index (index-path second-dists "releases.txt")))))))

(test archives-exclude-vcs-and-build-directories
  "Version control data never reaches a release archive."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (dists (merge-pathnames "dists/" root)))
      (make-project projects "qlp-e2e" +project-asd+
                    :extra-files '(("package.fasl" "stale compiled file")))
      (qlp:publish (test-config projects dists))
      (let* ((release (first (qlp::read-index (index-path dists "releases.txt"))))
             (archive (merge-pathnames (format nil "testdist/archive/~a.tgz" (sixth release))
                                       (uiop:ensure-directory-pathname dists)))
             (members (archive-members archive)))
        (is (find (format nil "~a/qlp-e2e.asd" (sixth release)) members :test #'string=)
            "sources are present")
        (is (notany (lambda (member) (search ".git/" member)) members))
        (is (notany (lambda (member) (search "package.fasl" member)) members))))))

(test archive-paths-are-rooted-in-the-release-prefix
  "Every member sits under a single top level directory named for the release."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (dists (merge-pathnames "dists/" root)))
      (make-project projects "qlp-e2e" +project-asd+)
      (qlp:publish (test-config projects dists))
      (let* ((release (first (qlp::read-index (index-path dists "releases.txt"))))
             (archive (merge-pathnames (format nil "testdist/archive/~a.tgz" (sixth release))
                                       (uiop:ensure-directory-pathname dists)))
             (members (archive-members archive)))
        (is (every (lambda (member) (uiop:string-prefix-p (sixth release) member)) members))))))

(test verify-accepts-a-freshly-published-distribution
  "Verification passes on what publication just wrote."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (dists (merge-pathnames "dists/" root))
           (config (test-config projects dists)))
      (make-project projects "qlp-e2e" +project-asd+)
      (qlp:publish config)
      (multiple-value-bind (consistent problems) (qlp:verify-dist config)
        (is-true consistent)
        (is (null problems))))))

(test verify-reports-a-tampered-archive
  "A changed archive no longer matches the MD5 in the release index."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (dists (merge-pathnames "dists/" root))
           (config (test-config projects dists)))
      (make-project projects "qlp-e2e" +project-asd+)
      (qlp:publish config)
      (let* ((release (first (qlp::read-index (index-path dists "releases.txt"))))
             (archive (merge-pathnames (format nil "testdist/archive/~a.tgz" (sixth release))
                                       (uiop:ensure-directory-pathname dists))))
        ;; One byte is flipped rather than the file truncated, so that the size
        ;; still matches and it is the MD5 that has to catch the change.
        (let ((bytes (with-open-file (stream archive :element-type '(unsigned-byte 8))
                       (let ((buffer (make-array (file-length stream)
                                                 :element-type '(unsigned-byte 8))))
                         (read-sequence buffer stream)
                         buffer))))
          (setf (aref bytes 0) (logxor (aref bytes 0) #xff))
          (with-open-file (stream archive :direction :output :if-exists :supersede
                                  :element-type '(unsigned-byte 8))
            (write-sequence bytes stream)))
        (multiple-value-bind (consistent problems) (qlp:verify-dist config)
          (is (not consistent))
          (is (some (lambda (problem) (search "MD5" problem)) problems)))))))

(test verify-reports-an-index-naming-an-unknown-project
  "A system whose project has no release is a problem."
  (with-temp-directory (root)
    (let* ((projects (merge-pathnames "projects/" root))
           (dists (merge-pathnames "dists/" root))
           (config (test-config projects dists)))
      (make-project projects "qlp-e2e" +project-asd+)
      (qlp:publish config)
      (qlp::write-lines (index-path dists "systems.txt")
                        (list "# project system-file system-name"
                              "ghost ghost.asd ghost-system"))
      (multiple-value-bind (consistent problems) (qlp:verify-dist config)
        (is (not consistent))
        (is (some (lambda (problem) (search "ghost-system" problem)) problems))))))

(test publish-refuses-an-incomplete-configuration
  "A configuration without a base URL is rejected before anything is written."
  (with-temp-directory (root)
    (let ((dists (merge-pathnames "dists/" root)))
      (signals error
               (qlp:publish (qlp:make-config :name "x" :projects-dir root
                                             :dists-dir (path-string dists))))
      (is (not (probe-file (merge-pathnames "x.txt" dists)))))))
