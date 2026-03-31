(defsystem #:cfli
  :defsystem-depends-on (#:pathway/asdf)
  :depends-on (#:clean #:pathway #:cffi)
  :serial t
  :components
  ((:workspace-extract "external/libffi-3.5.2-x86-64bit-msvc-binaries.zip/libffi-8.dll")
   (:module "source"
    :components ((:file "package")))))
