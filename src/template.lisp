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

;;; Layout templates. The placeholders are read as Common Lisp forms, so
;;; {name} is the symbol NAME and {(:or version "19700101")} is a form.

(defparameter *distinfo-template*
  "name: {name}
version: {version}
distinfo-subscription-url: {base-url}/{name}.txt
release-index-url: {base-url}/{name}/{version}/releases.txt
system-index-url: {base-url}/{name}/{version}/systems.txt
"
  "Contents of the distinfo file Quicklisp subscribes to.")

(defparameter *distinfo-file-template* "{dists-dir}/{name}.txt")
(defparameter *dist-dir-template*      "{dists-dir}/{name}/{version}")
(defparameter *archive-dir-template*   "{dists-dir}/{name}/archive")
(defparameter *archive-url-template*   "{base-url}/{name}/archive")

(defvar *template-readtable*
  (let ((readtable (copy-readtable)))
    (set-syntax-from-char #\} #\) readtable)
    readtable))

(defun read-template-form (stream)
  "Read one placeholder form from STREAM, consuming the closing brace."
  (let ((*readtable* *template-readtable*)
        (*package* (find-package :keyword)))
    (prog1 (read stream nil nil)
      (let ((closing (peek-char t stream nil nil)))
        (unless (and closing (char= closing #\}))
          (error "Unterminated placeholder in the template."))
        (read-char stream nil nil)))))

(defun directive-value (operator form data)
  "Resolve the directive OPERATOR of the placeholder FORM against DATA."
  (case operator
    (:or (or (getf data (second form)) (eval (third form))))
    (:if (if (eval (second form))
             (getf data (third form))
             (getf data (fourth form))))
    (t (error "Unknown template directive ~s in ~s" operator form))))

(defun template-value (form data)
  "Resolve the placeholder FORM against the plist DATA."
  (let ((value (if (consp form)
                   (directive-value (car form) form data)
                   (getf data form))))
    (unless value
      (error "The value of {~a} is undefined." form))
    value))

(defun render-template (template data)
  "Render TEMPLATE, substituting DATA's values for its placeholders."
  (with-output-to-string (out)
    (with-input-from-string (in template)
      (iter (for char = (read-char in nil))
            (while char)
            (if (char= char #\{)
                (write-string (princ-to-string (template-value (read-template-form in) data)) out)
                (write-char char out))))))
