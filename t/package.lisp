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

(defpackage :qlp/tests
  (:use :cl :iterate :fiveam :qlp)
  (:export #:run-qlp-tests
           #:with-temp-directory))

(in-package :qlp/tests)

(def-suite qlp-tests
  :description "qlp test suite")

(in-suite qlp-tests)

(defvar *temp-counter* 0)

(defun next-temp-directory ()
  "Return a fresh temporary directory pathname that does not exist yet."
  (setf *temp-counter* (1+ *temp-counter*))
  (merge-pathnames (format nil "qlp-test-~d-~d-~d/"
                           (get-universal-time) *temp-counter* (random 1000000))
                   (uiop:temporary-directory)))

(defmacro with-temp-directory ((var) &body body)
  "Bind VAR to a fresh temporary directory, removing it afterwards."
  `(let ((,var (next-temp-directory)))
     (unwind-protect
          (progn (ensure-directories-exist ,var) ,@body)
       (uiop:delete-directory-tree ,var :validate t :if-does-not-exist :ignore))))

(defun write-file (path contents)
  "Write CONTENTS to PATH, creating the directories it needs."
  (ensure-directories-exist path)
  (with-open-file (stream path :direction :output :if-exists :supersede
                          :external-format :utf-8)
    (write-string contents stream))
  path)

(defmacro with-qlp-temp-directory ((var) &body body)
  "Bind VAR to a fresh temporary directory, removing it afterwards."
  `(with-temp-directory (,var) ,@body))

(defun run-qlp-tests ()
  "Run the whole qlp test suite. Returns true when every test passed."
  (let ((results (fiveam:run 'qlp-tests)))
    (fiveam:explain! results)
    (fiveam:results-status results)))
