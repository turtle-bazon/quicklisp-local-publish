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

(in-package :qlp/tests)

(in-suite qlp-tests)

;;; The archive prefix of a project carries the day its newest source file was
;;; written, and the version of a publication carries the instant it was
;;; published. Both are formed in UTC: two people publishing the same sources
;;; from different sides of the world should not get two distributions.

;; 2024-03-05 23:30:07 UTC, encoded in UTC rather than in the local zone so
;; that these expectations hold wherever the suite runs.
(defparameter *known-instant* (encode-universal-time 7 30 23 5 3 2024 0))

(test format-date-is-a-day-in-utc
  "A source date is eight digits, and 23:30 UTC is still the fifth."
  (is (equal "20240305" (qlp::format-date *known-instant*))))

(test format-timestamp-is-an-instant-in-utc
  "A publication version is fourteen digits naming one instant in UTC."
  (is (equal "20240305233007" (qlp::format-timestamp *known-instant*))))

(test format-timestamp-is-sorted-by-the-instants-it-names
  "Later instants form larger versions, so they sort later as strings."
  (is (string< (qlp::format-timestamp *known-instant*)
               (qlp::format-timestamp (1+ *known-instant*)))))

(test resolve-version-stamps-now-or-keeps-the-given-name
  ":NOW becomes the fourteen digits of the present instant, and a version
  given on the command line is used exactly as given."
  (let ((version (qlp::resolve-version :now)))
    (is (= 14 (length version)))
    (is (every #'digit-char-p version)))
  (is (equal "20250601" (qlp::resolve-version "20250601"))))
