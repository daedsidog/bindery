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

#ifndef PROCESS_QUERY_LIMITED_INFORMATION
#define PROCESS_QUERY_LIMITED_INFORMATION 0x1000
#endif

#ifndef TH32CS_SNAPPROCESS
#define TH32CS_SNAPPROCESS 0x00000002
#endif

#ifndef BINDERY_PROCESSENTRY32W
#define BINDERY_PROCESSENTRY32W
typedef struct tagPROCESSENTRY32W {
  DWORD dwSize;
  DWORD cntUsage;
  DWORD th32ProcessID;
  ULONG_PTR th32DefaultHeapID;
  DWORD th32ModuleID;
  DWORD cntThreads;
  DWORD th32ParentProcessID;
  LONG pcPriClassBase;
  DWORD dwFlags;
  WCHAR szExeFile[MAX_PATH];
} PROCESSENTRY32W, *PPROCESSENTRY32W, *LPPROCESSENTRY32W;
#endif

#ifndef WAVE_FORMAT_PCM
#define WAVE_FORMAT_PCM 1
#endif

#ifndef CALLBACK_FUNCTION
#define CALLBACK_FUNCTION 0x00030000
#endif

#ifndef WOM_DONE
#define WOM_DONE 0x3BD
#endif

#ifndef WAVE_MAPPER
#define WAVE_MAPPER ((UINT)-1)
#endif

#ifndef BINDERY_WAVEFORMATEX
#define BINDERY_WAVEFORMATEX
typedef struct tWAVEFORMATEX {
  WORD wFormatTag;
  WORD nChannels;
  DWORD nSamplesPerSec;
  DWORD nAvgBytesPerSec;
  WORD nBlockAlign;
  WORD wBitsPerSample;
  WORD cbSize;
} WAVEFORMATEX, *PWAVEFORMATEX, *LPWAVEFORMATEX;
#endif

#ifndef BINDERY_WAVEHDR
#define BINDERY_WAVEHDR
typedef struct wavehdr_tag {
  LPSTR lpData;
  DWORD dwBufferLength;
  DWORD dwBytesRecorded;
  DWORD_PTR dwUser;
  DWORD dwFlags;
  DWORD dwLoops;
  struct wavehdr_tag *lpNext;
  DWORD_PTR reserved;
} WAVEHDR, *PWAVEHDR, *LPWAVEHDR;
#endif

#ifndef TIMERR_NOERROR
#define TIMERR_NOERROR 0
#endif

#ifndef BINDERY_TIMECAPS
#define BINDERY_TIMECAPS
typedef struct timecaps_tag {
  UINT wPeriodMin;
  UINT wPeriodMax;
} TIMECAPS, *PTIMECAPS, *LPTIMECAPS;
#endif

#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif

#ifndef WM_MOUSEHWHEEL
#define WM_MOUSEHWHEEL 0x020E
#endif

#ifndef MOUSEEVENTF_HWHEEL
#define MOUSEEVENTF_HWHEEL 0x01000
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
