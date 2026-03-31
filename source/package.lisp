(defpackage #:cfli
  (:use #:clean))

(in-package #:cfli)

(pushnew '(pathway:default-workspace-pathname) cffi:*foreign-library-directories* :test #'equalp)
