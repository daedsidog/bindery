(defsystem "cfli"
  :description "Common foreign language interface."
  :author "Jan Jouleodov"
  :license "MIT"
  :if-feature (:and :win32 :x86-64)
  :defsystem-depends-on ("pathway/asdf")
  :depends-on ("clean" "pathway" "cffi")
  :serial t
  :components
  ((:workspace-extract "external/libffi-3.5.2-x86-64bit-msvc-binaries.zip/libffi-8.dll")
   (:module "source"
    :components ((:file "package")))))

(defsystem "cfli/asdf"
  :defsystem-depends-on ("pathway/asdf")
  :if-feature (:and :win32 :x86-64)
  :depends-on ("cfli" "cffi-toolchain" "cffi-grovel")
  :serial t
  :components
  ((:workspace-extract "external/tcc-0.9.27-win64-bin.zip/tcc/tcc.exe"
    :workspace-pathname "tcc/tcc.exe")
   (:workspace-extract "external/tcc-0.9.27-win64-bin.zip/tcc/include/"
    :workspace-pathname "tcc/include/")
   (:workspace-extract "external/tcc-0.9.27-win64-bin.zip/tcc/libtcc.dll"
    :workspace-pathname "tcc/libtcc.dll")
   (:workspace-extract "external/tcc-0.9.27-win64-bin.zip/tcc/lib/"
    :workspace-pathname "tcc/lib/")
   (:workspace-extract "external/libffi-3.5.2-x86-64bit-msvc-binaries.zip/ffi.h"
    :workspace-pathname "include/ffi.h")
   (:workspace-extract "external/libffi-3.5.2-x86-64bit-msvc-binaries.zip/ffitarget.h"
    :workspace-pathname "include/ffitarget.h")
   (:module "source"
    :components ((:module "asdf"
                  :components ((:file "package")))))))
