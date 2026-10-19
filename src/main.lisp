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

;;; Wiring the subcommands together.

(defun guarded-handler (thunk)
  "Return a clingon handler calling THUNK with the parsed options."
  (lambda (cmd) (guarded (lambda () (funcall thunk cmd)))))

(defun publish-command ()
  "Return the publish subcommand."
  (clingon:make-command
   :name "publish"
   :description "Publish local projects as a Quicklisp distribution"
   :long-description "Archive every directory under the projects directory and
write the distinfo, release index and system index a Quicklisp client needs."
   :options (common-options)
   :handler (guarded-handler #'run-publish)))

(defun verify-command ()
  "Return the verify subcommand."
  (clingon:make-command
   :name "verify"
   :description "Check a published distribution against its archives"
   :long-description "Re-read the indexes and confirm that every archive is
present and matches the size and MD5 recorded for it, and that every system
names an .asd file its release actually ships."
   :options (common-options)
   :handler (guarded-handler #'run-verify)))

(defun systems-command ()
  "Return the systems subcommand."
  (clingon:make-command
   :name "systems"
   :description "List every system the projects define, sub-systems included"
   :long-description "Scan the project directories and report each system together
with the .asd file that defines it. Sub-systems declared inside another
system's .asd file are listed as systems of their own."
   :options (common-options)
   :handler (guarded-handler #'run-systems)))

(defun clean-command ()
  "Return the clean subcommand."
  (clingon:make-command
   :name "clean"
   :description "Remove the published directory of one distribution version"
   :options (append (common-options)
                    (list (clingon:make-option :flag :long-name "yes" :key :yes
                                               :description "Confirm the removal")))
   :handler (guarded-handler #'run-clean)))

(defun qlp-version ()
  "Return the version declared in qlp.asd, the one place it is written."
  (asdf:component-version (asdf:find-system "qlp")))

(defun qlp-command ()
  "Return the top level qlp command."
  (clingon:make-command
   :name "qlp"
   :version (qlp-version)
   :description "Publish local Common Lisp projects as a Quicklisp distribution"
   :long-description "qlp turns a directory of local projects into a Quicklisp
distribution: reproducible release archives, a release index, a system index and
a distinfo file. It understands ASDF sub-systems, so every system defined inside
a project's .asd files is published, not just the one named after the file."
   :authors '("Azamat S. Kalimoulline <turtle@bazon.ru>")
   :license "GPL-3.0-or-later"
   :handler (lambda (cmd) (clingon:print-usage-and-exit cmd t))
   :sub-commands (list (publish-command) (verify-command)
                       (systems-command) (clean-command))))

(defun main (&optional argv)
  "Entry point of the qlp binary."
  (clingon:run (qlp-command) argv))
