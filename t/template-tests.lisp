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

;;; Rendering the layout templates.

(test template-placeholder-substitution
  "A placeholder is replaced by the matching configuration value."
  (is (equal "hello world"
             (qlp:render-template "hello {who}" (list :who "world")))))

(test template-form-placeholders
  "A placeholder may be a form, so a fallback value is expressible."
  (is (equal "20240101"
             (qlp:render-template "{(:or version \"20240101\")}"
                                 (list :version "20240101"))))
  (is (equal "fallback"
             (qlp:render-template "{(:or version \"fallback\")}" nil))))

(test template-undefined-placeholder
  "An undefined placeholder is an error rather than empty text."
  (signals error (qlp:render-template "{missing}" (list :name "x"))))

(test distinfo-template-fields
  "The distinfo template names the distribution and points at its indexes."
  (let ((rendered (qlp:render-template qlp:*distinfo-template*
                                      (list :name "mydist" :version "20240101"
                                            :base-url "http://localhost:4242"))))
    (is (search "name: mydist" rendered))
    (is (search "version: 20240101" rendered))
    (is (search "distinfo-subscription-url: http://localhost:4242/mydist.txt" rendered))
    (is (search "release-index-url: http://localhost:4242/mydist/20240101/releases.txt" rendered))
    (is (search "system-index-url: http://localhost:4242/mydist/20240101/systems.txt" rendered))))

(test layout-template-trims-trailing-slash
  "A base URL with a trailing slash still yields single slashed URLs."
  (let* ((config (qlp:make-config :name "mydist" :version "1"
                                  :base-url "http://example.org/"
                                  :projects-dir "/tmp" :dists-dir "/tmp"))
         (data (qlp::template-data config "1")))
    (is (equal "http://example.org/mydist/archive"
               (qlp:render-template qlp:*archive-url-template* data)))))
