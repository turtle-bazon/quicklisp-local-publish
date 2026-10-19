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

;;; A configuration is a plist with :name, :version, :base-url,
;;; :projects-dir, :dists-dir, :exclude and :tar-program. Nothing is read
;;; from disk: every value comes from the command line, so that one command
;;; says everything that will happen.

(defparameter *default-exclude*
  '(".git" ".hg" ".svn" ".bzr" "CVS"
    ".DS_Store" ".gitmodules"
    "*.fasl" "*.FASL" "*.ufasl" "*.lib" "*.fas"
    "build" "target" ".cache" ".cpcache" "node_modules")
  "Names never put into an archive, unless the exclusion list is replaced.")

(defparameter *required-fields*
  '((:name . "--name")
    (:base-url . "--base-url")
    (:projects-dir . "--projects-dir")
    (:dists-dir . "--dists-dir"))
  "Fields a distribution cannot be written without, each with the option
that supplies it.")

(defun make-config (&key name version base-url projects-dir dists-dir
                         exclude tar-program)
  "Return a configuration from the given values, filling in the defaults.
Nothing is checked here: PUBLISH and VERIFY-DIST validate, so that a
configuration assembled from a command line is checked once, as a whole."
  (list :name name
        :version (or version :now)
        :base-url base-url
        :projects-dir projects-dir
        :dists-dir dists-dir
        :exclude (or exclude (copy-list *default-exclude*))
        :tar-program (or tar-program "tar")))

(defun config-name (config)
  "Return the distribution name of CONFIG."
  (getf config :name))

(defun config-version (config)
  "Return the distribution version of CONFIG, a string or :NOW."
  (getf config :version))

(defun config-base-url (config)
  "Return the URL the distribution will be served from."
  (getf config :base-url))

(defun config-projects-dir (config)
  "Return the directory holding the projects."
  (getf config :projects-dir))

(defun config-dists-dir (config)
  "Return the directory the distribution is written to."
  (getf config :dists-dir))

(defun config-exclude (config)
  "Return the list of names kept out of the archives."
  (getf config :exclude))

(defun config-tar-program (config)
  "Return the tar program to run."
  (getf config :tar-program))

(defun validate-config (config)
  "Signal an error if CONFIG cannot be used to write a distribution."
  (iter (for (field . option) :in *required-fields*)
        (unless (stringp (getf config field))
          (error "Missing required option ~a." option))
        (when (string= "" (getf config field))
          (error "Option ~a may not be empty." option)))
  (unless (eq :now (config-version config))
    (unless (stringp (config-version config))
      (error "Option --dist-version must be a string or omitted")))
  config)

(defun merge-config (base overrides)
  "Return BASE with every non-NIL value in OVERRIDES taking its place.
A value that is absent from OVERRIDES leaves BASE alone: an option that
was not given on the command line cannot clear what the command said."
  (iter (for (key value) :on overrides :by #'cddr)
        (when value
          (setf (getf base key) value)))
  base)

(defmacro with-config ((config &rest parameters &key name version base-url
                                                projects-dir dists-dir
                                                exclude tar-program)
                       &body body)
  "Bind CONFIG to a configuration made from the given values and run BODY."
  (declare (ignore name version base-url projects-dir dists-dir
                   exclude tar-program))
  `(let ((,config (make-config ,@parameters)))
     ,@body))
