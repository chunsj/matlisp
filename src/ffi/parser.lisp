(in-package :matlisp)
(in-readtable :infix-dispatch-table)

(defmacro ppcre-match ((m r) keyform &rest clauses)
  (with-gensyms (key mm rr)
    `(let ((,key ,keyform) ,mm ,rr)
       (cond ,@(mapcar #'(λ (x)
			    (if (eq (car x) t) x
				`((setf (values ,mm ,rr) (values-list (or ,@(mapcar #'(lambda (r) `(letv* ((,rr ,mm (cl-ppcre:scan-to-strings ,r ,key)))
												     (when ,rr (list ,rr ,mm))))
										    (ensure-list (car x))))))
				  (let ((,m ,mm) (,r ,rr)) (declare (ignorable ,m ,r)) ,@(cdr x)))))
		       clauses)))))

(defun split-routines (fname)
  (let (routines)
    (iter (for line in (splitlines (file->string fname)))
	  (with cfunc = nil) (with name = nil)
	  (push line cfunc)	
	  (ppcre-match (m r) (string-downcase line)
	    (("^ {6}.+function +([a-z][0-9a-z]+)" "^ {6}subroutine +([a-z][0-9a-z]+)") (setf name (aref r 0)))
	    ("^ {6}end *$"
	     ;;(unless name (print cfunc) (error "missing name for routine."))
	     (when (and name (not (cffi:foreign-symbol-pointer (funcall matlisp-ffi::+f77-name-mangler+ name) :library *blas-lib*)))
	       (push (cons name (apply #'string-join #\Newline (nreverse cfunc))) routines))
	     (setf cfunc nil name nil))))
    routines))

;; (progn (setf *buggy* (split-routines "/home/neptune/devel/matlisp-packages/lib-src/odepack/opkda1.f")) t)
;; (split-routines "/home/neptune/devel/matlisp-packages/lib-src/toms715/")

(defun split-functions (dir)
  (let ((split-dir (ensure-directories-exist (pathname (string+ dir "/" "split/")))))
    (loop :for f :in (directory (make-pathname :directory dir :name :wild :type "f"))
       :do (let ((routines (split-routines f)))
	     (map nil #'(lambda (x)
			  (destructuring-bind (name . code) x
			    (with-open-file (fstr (make-pathname :directory (pathname-directory split-dir) :name (string+ name ".f")) :direction :output :if-exists :supersede :if-does-not-exist :create)
			      (format fstr "~a" code))))
		  routines)
	     (delete-file f)))
    (loop :for f :in (directory (make-pathname :directory (pathname-directory split-dir) :name :wild :type "f"))
       :do (rename-file f (make-pathname :directory (pathname-directory dir)
					 :name (pathname-name f) :type (pathname-type f))))
    (cl-fad:delete-directory-and-files split-dir)))

(split-functions "/home/neptune/devel/matlisp-packages/lib-src.bk/toms715/")
