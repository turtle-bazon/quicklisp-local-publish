;;;; qlp-tests — test suite for qlp
;;;; Copyright (C) 2026 Azamat S. Kalimoulline <turtle@bazon.ru>
;;;; SPDX-License-Identifier: GPL-3.0-or-later

(defsystem "qlp-tests"
  :name "qlp-tests"
  :license "GPL-3.0-or-later"
  :description "Tests for qlp"
  :depends-on ("qlp" "fiveam")
  :serial t
  :components ((:module "t"
                :components ((:file "package")
                             (:file "template-tests")
                             (:file "config-tests")
                             (:file "paths-tests")
                             (:file "archive-tests")
                             (:file "asdf-scan-tests")
                             (:file "index-tests")
                             (:file "publish-tests")))))
