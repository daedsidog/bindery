(defpackage #:cfli/asdf
  (:use #:clean)
  (:local-nicknames (#:pw #:pathway)))

(in-package #:cfli/asdf)

(let* ((ws (pw:default-workspace-pathname))
       (tcc-exe (merge-pathnames "tcc/tcc.exe" ws))
       (tcc-include (merge-pathnames #p"tcc/include/" ws))
       (libffi-include (merge-pathnames #p"include/" ws)))
  (when (probe-file tcc-exe)
    (setf cffi-toolchain:*cc* (namestring tcc-exe)
          cffi-toolchain:*cc-flags* (list "-m64"
                                          (format nil "-I~A"
                                                  (namestring tcc-include))
                                          (format nil "-I~A"
                                                  (namestring libffi-include)))
          cffi-toolchain:*ld* (namestring tcc-exe)
          cffi-toolchain:*ld-exe-flags* (list "-m64")
          cffi-toolchain:*ld-dll-flags* (list "-shared" "-m64"))))
