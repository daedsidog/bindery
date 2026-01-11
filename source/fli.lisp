;;;; Copyright (C) 2025 DAEDSIDOG.  All rights reserved.

(uiop:define-package #:ck-fli
  (:use #:cl #:ck-clle)
  (:reexport #:ck-fli/external-registry))

(in-package #:ck-fli)

(defclass asdf-user::cxx-grovel-file (cffi-grovel:grovel-file) ())

#+win32
(defmethod asdf:perform :around ((op cffi-grovel::process-op) (c asdf-user::cxx-grovel-file))
  (let ((old-value cffi-toolchain:*ld-exe-flags*))
    (setf cffi-toolchain:*ld-exe-flags*
          (substitute "-Wl,--export-all-symbols"
                      "-Wl,--export-dynamic"
                      old-value
                      :test #'string=))
    (unwind-protect
        (call-next-method)
      (setf cffi-toolchain:*ld-exe-flags* old-value))))
