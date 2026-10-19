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

;;; Every setting comes from the command line, so these tests are about
;;; defaults, about validation, and about what the options end up meaning.

(defparameter +cli-options+
  '("--name" "conf"
    "--dist-version" "20250601"
    "--base-url" "http://conf.example.org"
    "--projects-dir" "/tmp/conf/projects/"
    "--dists-dir" "/tmp/conf/dists/")
  "A command line that says everything a distribution needs.")

(defun parsed-config (&rest arguments)
  "Return the configuration a publish run given ARGUMENTS would build."
  (qlp::command-config (clingon:parse-command-line (qlp::publish-command)
                                                   arguments)))

(defun config-error-message (thunk)
  "Call THUNK and return the message of the error it signals, or NIL."
  (handler-case (progn (funcall thunk) nil)
    (error (condition) (princ-to-string condition))))

(test config-defaults-to-now-and-the-standard-exclusions
  "A configuration built from nothing needs a version no more than a list
of its own of what to leave out."
  (let ((config (qlp:make-config)))
    (is (eq :now (qlp:config-version config)))
    (is (equal qlp::*default-exclude* (qlp:config-exclude config)))
    (is (equal "tar" (qlp:config-tar-program config)))))

(test config-options-build-a-configuration
  "The options a publish run needs are the ones it gets."
  (let ((config (apply #'parsed-config +cli-options+)))
    (is (equal "conf" (qlp:config-name config)))
    (is (equal "20250601" (qlp:config-version config)))
    (is (equal "http://conf.example.org" (qlp:config-base-url config)))
    (is (equal "/tmp/conf/projects/" (qlp:config-projects-dir config)))
    (is (equal "/tmp/conf/dists/" (qlp:config-dists-dir config)))))

(test config-absent-options-leave-the-defaults-untouched
  "An option that was not given cannot clear a default."
  (let ((config (parsed-config "--name" "conf"
                               "--base-url" "http://x"
                               "--projects-dir" "/tmp/p/"
                               "--dists-dir" "/tmp/d/")))
    (is (eq :now (qlp:config-version config))
        "no --dist-version means the current time")
    (is (equal "tar" (qlp:config-tar-program config)))
    (is (equal qlp::*default-exclude* (qlp:config-exclude config)))))

(test command-line-exclusions-extend-the-defaults
  "Names excluded on the command line are added to the ones left out by
default, never replacing them."
  (let ((exclude (qlp:config-exclude
                  (parsed-config "--name" "conf"
                                 "--base-url" "http://x"
                                 "--projects-dir" "/tmp/p/"
                                 "--dists-dir" "/tmp/d/"
                                 "--exclude" "mine"))))
    (is (equal "mine" (first exclude)))
    (is (member ".git" exclude :test #'string=)
        "the default exclusions are still in force")
    (is (equal (length qlp::*default-exclude*) (1- (length exclude))))))

(test config-requires-its-essential-fields
  "A configuration without them cannot write a distribution."
  (signals error (qlp::validate-config (qlp:make-config))))

(test a-missing-required-option-is-named
  "Validation names the option that was left out, not the field."
  (let ((message (config-error-message
                  (lambda () (qlp::validate-config (parsed-config))))))
    (is (search "--name" message))))

(test an-empty-required-option-is-refused
  "An option given as the empty string is no better than one left out.
The command line parser already refuses it; validation refuses it too,
so that a configuration built as a library value is checked the same."
  (let ((config (qlp:make-config :name "" :base-url "http://x"
                                 :projects-dir "/tmp/p/"
                                 :dists-dir "/tmp/d/")))
    (signals error (qlp::validate-config config))))

(test config-accepts-everything-a-distribution-needs
  "A configuration that says everything validates."
  (is (qlp::validate-config (apply #'parsed-config +cli-options+))))

(test config-accepts-a-missing-version
  "The version is the one setting that may be left out."
  (let ((config (parsed-config "--name" "conf" "--base-url" "http://x"
                               "--projects-dir" "/tmp/p/"
                               "--dists-dir" "/tmp/d/")))
    (is (eq :now (qlp:config-version config)))
    (is (qlp::validate-config config))))

(test config-rejects-a-version-that-is-not-a-name
  "A version has to be a name, not a number or some other value."
  (signals error
           (qlp::validate-config (list :name "conf"
                                       :version 20250601
                                       :base-url "http://x"
                                       :projects-dir "/tmp/p/"
                                       :dists-dir "/tmp/d/"))))
