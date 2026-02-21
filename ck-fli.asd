;;;; Copyright (C) 2025 DAEDSIDOG.  All rights reserved.

(defsystem #:ck-fli/external-registry
  :depends-on (#:ck-clle #:ck-fs #:cffi)
  :components ((:module "source"
                :components ((:file "external-registry")))))

;;; ASDF component classes for foreign assets

(defclass foreign-dynamic-library (asdf:file-component) ())

(defmethod asdf:file-type ((component foreign-dynamic-library))
  #+win32 "dll"
  #+darwin "dylib"
  #+(and unix (not darwin)) "so"
  #-(or win32 darwin unix) nil)

(defmethod asdf:perform ((op asdf:compile-op) (component foreign-dynamic-library))
  nil)

(defmethod asdf:perform ((op asdf:load-op) (component foreign-dynamic-library))
  (funcall (find-symbol "REGISTER-FOREIGN-DYNAMIC-LIBRARY" "CK-FLI/EXTERNAL-REGISTRY")
           (asdf:component-name component)
           (asdf:component-system component)))

(defclass foreign-cxx-header (asdf:file-component) ())

(defmethod asdf:file-type ((component foreign-cxx-header))
  "h")

(defmethod asdf:perform ((op asdf:compile-op) (component foreign-cxx-header))
  nil)

(defmethod asdf:perform ((op asdf:load-op) (component foreign-cxx-header))
  (funcall (find-symbol "REGISTER-FOREIGN-CXX-HEADER" "CK-FLI/EXTERNAL-REGISTRY")
           (asdf:component-name component)
           (asdf:component-system component)))

;;; TCC (Tiny C Compiler) external subsystem for CFFI groveling

(defsystem #:ck-fli/external/tcc
  :if-feature (:and :win32 :x86-64)
  :depends-on (#:ck-fli/external-registry #:cffi-toolchain))

(defmethod asdf:perform ((op asdf:compile-op) (c (eql (asdf:find-system :ck-fli/external/tcc))))
  nil)

(defmethod asdf:perform ((op asdf:load-op) (c (eql (asdf:find-system :ck-fli/external/tcc))))
  (let* ((extraction-dir (funcall (find-symbol "REGISTER-FOREIGN-TOOLCHAIN"
                                               "CK-FLI/EXTERNAL-REGISTRY")
                                  "external/tcc-0.9.27-win64-bin.zip"
                                  c))
         (tcc-dir (merge-pathnames #p"tcc/" extraction-dir))
         (tcc-exe (namestring (merge-pathnames "tcc.exe" tcc-dir))))
    (when (probe-file tcc-exe)
      (macrolet ((tv (name)
                   `(symbol-value (find-symbol ,name "CFFI-TOOLCHAIN"))))
        (setf (tv "*CC*")           tcc-exe
              (tv "*CC-FLAGS*")     (list "-m64")
              (tv "*LD*")           tcc-exe
              (tv "*LD-EXE-FLAGS*") (list "-m64")
              (tv "*LD-DLL-FLAGS*") (list "-shared" "-m64"))))))

;;; libffi external subsystem

(defsystem #:ck-fli/external/libffi
  :if-feature (:and :win32 :x86-64)
  :depends-on (#:ck-fli/external-registry #:cffi-grovel)
  :components
  ((:foreign-dynamic-library "external/libffi-3.5.2-x86-64bit-msvc-binaries.zip/libffi-8.dll")
   (:foreign-cxx-header "external/libffi-3.5.2-x86-64bit-msvc-binaries.zip/ffi.h")
   (:foreign-cxx-header "external/libffi-3.5.2-x86-64bit-msvc-binaries.zip/ffitarget.h")))

;; Add the extracted libffi headers to the C compiler's include path so CFFI-GROVEL can find ffi.h
;; and ffitarget.h when generating FFI bindings.
(defmethod asdf:perform :before ((op asdf:load-op)
                                 (c (eql (asdf:find-system :ck-fli/external/libffi))))
  (let* ((cache-base (funcall (find-symbol "USER-CACHE-DIRECTORY" "CK-FS")
                              (make-pathname :directory '(:relative "ck-fli" "external"))))
         (libffi-include (merge-pathnames
                          #p"libffi-3.5.2-x86-64bit-msvc-binaries/include/"
                          cache-base))
         (cc-flags (find-symbol "*CC-FLAGS*" "CFFI-GROVEL"))
         (ld-flags (find-symbol "*LD-FLAGS*" "CFFI-GROVEL")))
    (when (and cc-flags libffi-include (probe-file libffi-include))
      (pushnew (format nil "-I~A" (namestring libffi-include))
               (symbol-value cc-flags)
               :test #'string=))
    (when ld-flags
      (setf (symbol-value ld-flags)
            (substitute "-Wl,--export-all-symbols"
                        "-Wl,--export-dynamic"
                        (symbol-value ld-flags)
                        :test #'string=)))))

(defsystem #:ck-fli
  :depends-on (#:ck-fli/external-registry #:ck-fli/external/libffi #:cffi-grovel)
  :components ((:module "source"
                :components ((:file "package")))))
