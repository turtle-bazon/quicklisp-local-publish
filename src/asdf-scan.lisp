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

;;; Discovering the systems an .asd file defines.
;;;
;;; A .asd file may define more than one system. Sub-systems are declared
;;; inside a parent system file, either literally, as a secondary
;;; (defsystem "parent/sub" ...) form, or through a helper macro that expands
;;; to any number of them -- IRONCLAD, for one, generates ~90 systems from
;;; define-ironclad-subsystems. Reading the file textually therefore misses
;;; everything a macro produces.
;;;
;;; So we evaluate the file the way ASDF itself does -- in the ASDF-USER
;;; package, with the standard readtable, and with the file's own directory
;;; as the pathname default -- while intercepting the single function every
;;; defsystem form ends up calling. Each call is recorded and passed through
;;; to ASDF unchanged, because real system files do look themselves up while
;;; being read (IRONCLAD specializes a method on (eql (find-system "ironclad"))).
;;; Afterwards everything the evaluation registered is unregistered again.
;;;
;;; ASDF's central registry is bound to NIL for the duration, so a dependency
;;; on a system that is not installed cannot trigger a download or a load, and
;;; ASDF's own state is left exactly as we found it.
;;;
;;; This is not thread safe: the interception is a global mutation. Projects
;;; are scanned one at a time, which is far cheaper than archiving them.

(defstruct (system-definition
            (:constructor %make-system-definition (name depends-on
                                                   defsystem-depends-on source-file)))
  (name "" :type string)
  (depends-on '() :type list)
  (defsystem-depends-on '() :type list)
  (source-file nil))

(defun dependency-name (spec)
  "Return the lower-cased system name SPEC refers to, or NIL.
Version requirements unwrap to their name; feature requirements, which
name no system, yield NIL."
  (let ((form (if (and (consp spec) (eq (car spec) :version)) (second spec) spec)))
    (cond ((stringp form) (string-downcase form))
          ((symbolp form) (string-downcase (symbol-name form)))
          ((and (consp form)
                (member (car form) '(:require :feature :around :weakly-depends-on)))
           nil)
          (t nil))))

(defun normalize-dependencies (specs)
  "Return the sorted, duplicate-free system names named by SPECS."
  (sort (remove-duplicates (remove nil (iter (for spec :in specs)
                                             (collect (dependency-name spec))))
                           :test #'string=)
        #'string<))

(defun asdf-package-p (package)
  "True when PACKAGE belongs to ASDF or UIOP."
  (let ((name (package-name package)))
    (or (uiop:string-prefix-p "ASDF" name)
        (uiop:string-prefix-p "UIOP" name))))

(defun registration-symbols ()
  "Return the symbols ASDF registers system definitions through.
Resolved at runtime so the scanner keeps working across ASDF releases."
  (iter (for package :in (list-all-packages))
        (for name = (package-name package))
        (for sym = (find-symbol "REGISTER-SYSTEM-DEFINITION" package))
        (when (and sym (eq (symbol-package sym) package)
                   (fboundp sym) (asdf-package-p package))
          (collect sym))))

(defun make-recorder (original record)
  "Return a function that hands a definition to RECORD then calls ORIGINAL.
RECORD takes the SYSTEM-DEFINITION; it closes over the caller's list,
which a PUSH on a mere parameter could not reach."
  (lambda (name &rest options &key defsystem-depends-on &allow-other-keys)
    (declare (ignorable defsystem-depends-on))
    (funcall record
             (%make-system-definition
              (string-downcase (string name))
              (normalize-dependencies (getf options :depends-on))
              (normalize-dependencies defsystem-depends-on)
              nil))
    (apply original name options)))

(defun unregister-new-systems (before)
  "Unregister every system ASDF knows now but did not know before.
CLEAR-SYSTEM is handed the name rather than the object: looking the
object up first can register the system all over again."
  (iter (for name :in (asdf:registered-systems))
        (unless (member name before :test #'string=)
          (ignore-errors (asdf:clear-system name)))))

(defun read-forms (path)
  "Return the top level forms of PATH, skipping past unreadable ones."
  (let ((forms '()))
    (handler-case
        (with-open-file (stream path :external-format :utf-8)
          (with-standard-io-syntax
            (let ((*package* (or (find-package :asdf-user) (find-package :keyword))))
              (iter (for form = (read stream nil :eof))
                    (until (eq form :eof))
                    (push form forms)))))
      (error (condition)
        (warn "Error while reading ~a: ~a" path condition)))
    (nreverse forms)))

(defun textual-system-name (form)
  "Return the system name a literal (defsystem NAME ...) form defines."
  (when (and (consp form) (symbolp (car form))
             (string-equal "defsystem" (symbol-name (car form)))
             (second form))
    (string-downcase (string (second form)))))

(defun textual-definitions (path)
  "Return the systems PATH defines literally, used when evaluation fails."
  (iter (for form :in (read-forms path))
        (for name = (textual-system-name form))
        (when name (collect (%make-system-definition name nil nil path)))))

(defun deduplicate-definitions (definitions)
  "Keep one definition per system name, ordered by name."
  (sort (remove-duplicates definitions
                           :key #'system-definition-name :test #'string=)
        #'string-lessp
        :key #'system-definition-name))

(defun scan-asd-file (asd-path)
  "Return every system ASD-PATH defines, sub-systems included."
  (let* ((path (truename asd-path))
         (definitions (handler-case (evaluate-asd-file path)
                        (error (condition)
                          (warn "Cannot evaluate ~a (~a); scanning it textually." path condition)
                          nil))))
    (when (null definitions)
      (setf definitions (textual-definitions path)))
    (iter (for definition :in definitions)
          (setf (system-definition-source-file definition) path))
    (deduplicate-definitions definitions)))

(defun mute-redefinitions (condition)
  "Muffle CONDITION when it only reports that a scanned file defines
something an earlier scanned file already defined.
Nothing defined while scanning is kept, so such a report says nothing
about the project and would only be noise; other warnings, of a badly
named system say, are left alone."
  (when (typep condition 'sb-kernel:redefinition-warning)
    (muffle-warning condition)))

(defun eval-asd-file (path)
  "Read and evaluate every top level form of PATH, as ASDF itself would.
LOAD-PATHNAME and LOAD-TRUENAME are bound to PATH so that a system's
components resolve against the directory of the file that declares
them: ASDF falls back on them for the source file of a system whose
:defsystem does not name one, and without them it cannot work out
where a :file component lives."
  (handler-bind ((warning #'mute-redefinitions))
    (with-open-file (stream path :external-format :utf-8)
      (with-standard-io-syntax
        (let ((*package* (or (find-package :asdf-user) (find-package :keyword)))
              (*default-pathname-defaults*
                (uiop:pathname-directory-pathname (uiop:physicalize-pathname path)))
              (*load-pathname* path)
              (*load-truename* path))
          (iter (for form = (read stream nil :eof))
                (until (eq form :eof))
                (eval form)))))))

(defun evaluate-asd-file (path)
  "Return the SYSTEM-DEFINITIONs PATH defines, or NIL if it cannot be read."
  (let ((symbols (registration-symbols)))
    (when (null symbols)
      (warn "Cannot locate ASDF's system registration function; ~a will be scanned textually." path)
      (return-from evaluate-asd-file nil))
    (let* ((saved (iter (for sym :in symbols)
                        (collect (cons sym (symbol-function sym)))))
           (captured '())
           (before (asdf:registered-systems)))
      (unwind-protect
           (progn
             (iter (for (sym . original) :in saved)
                   (setf (symbol-function sym)
                         (make-recorder original
                                        (lambda (definition)
                                          (push definition captured)))))
             (let ((asdf:*central-registry* nil))
               (eval-asd-file path))
             (nreverse captured))
        (iter (for (sym . original) :in saved)
              (setf (symbol-function sym) original))
        (unregister-new-systems before)))))
