;;;; qlp — publish local Common Lisp projects as a Quicklisp distribution
;;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;;; SPDX-License-Identifier: GPL-3.0-or-later

(defsystem "qlp"
  :name "qlp"
  :license "GPL-3.0-or-later"
  :version "0.0.1.1"
  :description "Publish local Common Lisp projects as a Quicklisp distribution"
  :author "Azamat S. Kalimoulline <turtle@bazon.ru>"
  :depends-on ("uiop"
               "iterate"
               "metabang-bind"
               "clingon"
               "ironclad")
  :serial t
  :components ((:module "src"
                :components ((:file "package")
                             (:file "config")
                             (:file "template")
                             (:file "paths")
                             (:file "asdf-scan")
                             (:file "project")
                             (:file "digest")
                             (:file "archive")
                             (:file "index")
                             (:file "dist")
                             (:file "verify")
                             (:file "cli")
                             (:file "main"))))
  :build-operation "program-op"
  :build-pathname "build/qlp"
  :entry-point "qlp:main")
