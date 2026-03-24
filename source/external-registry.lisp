;;;; Copyright (C) 2024 DAEDSIDOG.  All rights reserved.

(defpackage #:cfli/external-registry
  (:use #:cl #:clean)
  (:local-nicknames (#:fs #:pathway))
  (:export #:register-foreign-dynamic-library
           #:register-foreign-cxx-header
           #:register-foreign-toolchain))

(in-package #:cfli/external-registry)

(defvar *external-registry* (make-hash-table))
(defvar *archive-metadata* (make-hash-table :test 'equalp))

(defparameter +cache-directory-name+    "cfli")
(defparameter +external-directory-name+ "external")
(defparameter +binaries-directory-name+ "bin")
(defparameter +include-directory-name+  "include")

(defparameter +external-source-directory+
  (make-pathname :directory `(:relative ,+external-directory-name+)))

(defparameter +external-base-directory+
  (fs:user-cache-directory (make-pathname :directory
                                          `(:relative ,+cache-directory-name+
                                                      ,+external-directory-name+))))

(defparameter +archives-metadata-file+
  (merge-pathnames "external-archives-metadata.lisp"
                   +external-base-directory+))

(defparameter +binaries-directory-path+
  (make-pathname :directory `(:relative ,+binaries-directory-name+)))

(defparameter +include-directory-path+
  (make-pathname :directory `(:relative ,+include-directory-name+)))

(defun load-archive-metadata ()
  "Load archive metadata from disk into *ARCHIVE-METADATA*."
  (when (probe-file +archives-metadata-file+)
    (handler-case
        (with-open-file (stream +archives-metadata-file+ :direction :input)
          (let ((data (read stream)))
            (when (listp data)
              (loop :for entry :in data
                    :do (setf (gethash (car entry) *archive-metadata*)
                              (cdr entry))))))
      (error (e)
        (warn "Failed to load archive metadata: ~A" e)))))

(defun save-archive-metadata ()
  "Save archive metadata from *ARCHIVE-METADATA* to disk."
  (ensure-directories-exist +external-base-directory+)
  (with-open-file (stream +archives-metadata-file+
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (let ((data (loop :for key :being :the :hash-keys :of *archive-metadata*
                      :using (hash-value value)
                      :collect (cons key value))))
      (write data :stream stream :readably t :pretty t))))

(defun parse-archive-path (archive-path-string)
  "Parse ARCHIVE-PATH-STRING, returning archive and internal paths.

<paths>         ::= (values <archive-path> <internal-path>)
<archive-path>  ::= string
<internal-path> ::= string"
  (let ((zip-pos (search ".zip/" archive-path-string)))
    (unless zip-pos
      (error "Invalid archive path (no .zip/): ~A" archive-path-string))
    (let ((split-pos (+ zip-pos 4)))  ; Position after ".zip"
      (values (subseq archive-path-string 0 split-pos)
              (subseq archive-path-string (1+ split-pos))))))

(defun needs-extraction-p (archive-path)
  "Return T if ARCHIVE-PATH needs to be extracted based on modification time."
  (let ((metadata (gethash (namestring archive-path) *archive-metadata*)))
    (if metadata
        (let ((cached-timestamp (getf metadata :timestamp)))
          (handler-case
              (let ((current-timestamp (fs:file-age archive-path)))
                (or (nullp cached-timestamp)
                    (> current-timestamp cached-timestamp)))
            (error ()
              t)))
        t)))

(defun extract-archive-file (archive-path internal-path destination-type source-system)
  "Extract INTERNAL-PATH from ARCHIVE-PATH, copy to designated cache location, and return it.

<designated-cache-location> ::= pathname
<destination-type>          ::= :BIN | :INCLUDE
<source-system>             ::= symbol | string"
  (let* ((archive-stem    (fs:pathname-stem (file-namestring archive-path)))
         (dest-subdir-path (ecase destination-type
                             (:bin +binaries-directory-path+)
                             (:include +include-directory-path+)))
         (cache-dir (merge-pathnames dest-subdir-path
                                     (merge-pathnames
                                      (make-pathname :directory `(:relative ,archive-stem))
                                      +external-base-directory+)))
         (destination (merge-pathnames (file-namestring internal-path) cache-dir)))
    (ensure-directories-exist cache-dir)
    (when (or (not (probe-file destination))
              (needs-extraction-p archive-path))
      (fs:extract-files-from-archive archive-path (list (cons internal-path destination)))
      (let ((metadata (gethash (namestring archive-path) *archive-metadata*)))
        (setf (gethash (namestring archive-path) *archive-metadata*)
              (list :timestamp (fs:file-age archive-path)
                    :extracted-files (cons (cons internal-path (namestring destination))
                                           (getf metadata :extracted-files))))
        (save-archive-metadata)))
    destination))

(defun register-foreign-dynamic-library (pathname system)
  "Register foreign dynamic library file from archive.

<pathname> ::= string
<system>   ::= symbol | string"
  (multiple-value-bind (archive-name internal-path)
      (parse-archive-path pathname)
    (let* ((archive-full-path (merge-pathnames archive-name
                                               (asdf:system-source-directory system)))
           (destination (extract-archive-file archive-full-path internal-path :bin system)))
      (setf (gethash pathname *external-registry*) :dynamic-library)
      (pushnew (uiop:pathname-directory-pathname destination)
               cffi:*foreign-library-directories*
               :test #'uiop:pathname-equal))))

(defun register-foreign-cxx-header (pathname system)
  "Return the destination pathname after registering foreign C/C++ header file from archive.

<pathname> ::= string
<system>   ::= symbol | string"
  (multiple-value-bind (archive-name internal-path)
      (parse-archive-path pathname)
    (let* ((archive-full-path (merge-pathnames archive-name
                                               (asdf:system-source-directory system)))
           (destination (extract-archive-file archive-full-path internal-path :include system)))
      (setf (gethash pathname *external-registry*) :cxx-header)
      destination)))

(defun extract-archive-preserving-structure (archive-path)
  "Extract entire ARCHIVE-PATH preserving directory structure, returning the extraction directory."
  (let* ((archive-stem (fs:pathname-stem (file-namestring archive-path)))
         (extraction-dir (merge-pathnames (make-pathname :directory `(:relative ,archive-stem))
                                          +external-base-directory+)))
    (when (or (not (probe-file extraction-dir))
              (needs-extraction-p archive-path))
      (ensure-directories-exist extraction-dir)
      (multiple-value-bind (output error-output exit-code)
          (uiop:run-program #+win32 (list "tar" "-xf" (namestring archive-path)
                                          "-C" (namestring extraction-dir))
                            #-win32 (list "unzip" "-q" "-o" (namestring archive-path)
                                          "-d" (namestring extraction-dir))
                            :ignore-error-status t)
        (declare (ignore output error-output))
        (unless (zerop exit-code)
          (error "Failed to extract archive: ~A" archive-path)))
      (setf (gethash (namestring archive-path) *archive-metadata*)
            (list :timestamp (fs:file-age archive-path)
                  :extraction-dir (namestring extraction-dir)))
      (save-archive-metadata))
    extraction-dir))

(defun register-foreign-toolchain (archive-name system)
  "Extract and register a foreign toolchain archive, returning the extraction directory.

<archive-name> ::= string
<system>       ::= symbol | string"
  (let* ((archive-full-path (merge-pathnames archive-name
                                             (asdf:system-source-directory system)))
         (extraction-dir (extract-archive-preserving-structure archive-full-path)))
    (setf (gethash archive-name *external-registry*) extraction-dir)
    extraction-dir))

(load-archive-metadata)
