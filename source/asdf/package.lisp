(defpackage #:bindery/asdf
  (:use #:clean)
  (:local-nicknames (#:pw #:pathway)))

(in-package #:bindery/asdf)

(defparameter +win32-compat-declarations+ "
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00
#endif
#ifndef WINVER
#define WINVER 0x0A00
#endif

#include <windows.h>

#ifndef EXTENDED_STARTUPINFO_PRESENT
#define EXTENDED_STARTUPINFO_PRESENT 0x00080000
#endif

#ifndef PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE
#define PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE 0x00020016
#endif

#ifndef BINDERY_STARTUPINFOEXW
#define BINDERY_STARTUPINFOEXW
typedef struct _PROC_THREAD_ATTRIBUTE_LIST *PPROC_THREAD_ATTRIBUTE_LIST;
typedef struct _STARTUPINFOEXW {
  STARTUPINFOW StartupInfo;
  PPROC_THREAD_ATTRIBUTE_LIST lpAttributeList;
} STARTUPINFOEXW, *LPSTARTUPINFOEXW;
#endif
"
  "Declarations absent from the frozen headers TCC bundles in place of the system
SDK.  Forced ahead of every translation unit, so it must pick the version target
itself, and each guard yields to a real header.")

(let* ((ws (pw:default-workspace-pathname))
       (tcc-exe (merge-pathnames "tcc/tcc.exe" ws))
       (tcc-include (merge-pathnames #p"tcc/include/" ws))
       (libffi-include (merge-pathnames #p"include/" ws))
       (win32-compat (merge-pathnames "win32-compat.h" ws)))
  (when (probe-file tcc-exe)
    (with-open-file (stream win32-compat :direction :output
                                         :if-exists :supersede)
      (write-string +win32-compat-declarations+ stream))
    (setf cffi-toolchain:*cc* (namestring tcc-exe)
          cffi-toolchain:*cc-flags* (list "-m64"
                                          (format nil "-I~A"
                                                  (namestring tcc-include))
                                          (format nil "-I~A"
                                                  (namestring libffi-include))
                                          "-include"
                                          (namestring win32-compat))
          cffi-toolchain:*ld* (namestring tcc-exe)
          cffi-toolchain:*ld-exe-flags* (list "-m64")
          cffi-toolchain:*ld-dll-flags* (list "-shared" "-m64"))))
