(defpackage #:bindery
  (:use #:clean))

(in-package #:bindery)

(pushnew '(pathway:default-workspace-pathname) cffi:*foreign-library-directories* :test #'equalp)
