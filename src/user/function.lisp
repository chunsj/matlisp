(in-package #:matlisp-user)

;;conjugate
(definline conjugate! (a)
  (tensor-conjugate! a))

(definline conjugate (a)
  (tensor-conjugate a))
;;

(defmacro lift-function (fn &aux (pkg (find-package "MATLISP-USER")))
  (letv* ((fname (symbol-name fn)) (fpkg (symbol-package fn)))
    (letv* ((fn (find-symbol fname fpkg))
	    (fn-package (intern fname pkg))
	    (ge-fn (intern (string+ fname "-GENERIC!") pkg)))
      `(progn
	 (closer-mop:defgeneric ,ge-fn (x)
	   (:generic-function-class tensor-method-generator))
	 (define-tensor-method ,ge-fn ((x dense-tensor :x))
	   `(dorefs (idx (dimensions x))
		    ((ref-x x :type ,(matlisp::cl :x)))
		    (setf ref-x (,',fn ref-x)))
	   'x)
	 (definline ,(intern (string+ fname "!") (find-package "MATLISP-USER")) (x)
	   (etypecase x
	     (number (,fn x))
	     (tensor (,ge-fn x))))
	 (definline ,fn-package (x)
	   (etypecase x
	     (number (,fn x))
	     (tensor (,ge-fn (copy x)))))))))

(macrolet ((lift-fns (&rest lst)
	     `(progn ,@ (mapcar #'(lambda (x) `(lift-function ,x)) lst))))
  (lift-fns cl:sin cl:cos cl:tan cl:asin cl:acos cl:exp cl:sinh cl:cosh cl:tanh cl:asinh cl:acosh cl:atanh))

;;log
(closer-mop:defgeneric log-generic! (x y)
  (:generic-function-class tensor-method-generator))
(define-tensor-method log-generic! ((x dense-tensor :x) (y dense-tensor :y))
  `(dorefs (idx (dimensions x))
	   ((ref-x x :type ,(matlisp::cl :x))
	    (ref-y y :type ,(matlisp::cl :y)))
     (setf ref-x (cl:log ref-x ref-y)))
  'x)
(define-tensor-method log-generic! ((x dense-tensor :x) (y number))
  `(dorefs (idx (dimensions x))
	   ((ref-x x :type ,(matlisp::cl :x)))
     (setf ref-x (cl:log ref-x y)))
  'x)
(define-tensor-method log-generic! ((x dense-tensor :x) (y null))
  `(dorefs (idx (dimensions x))
	   ((ref-x x :type ,(matlisp::cl :x)))
     (setf ref-x (cl:log ref-x)))
  'x)

(definline log! (base &optional power)
  (cart-etypecase (base power)
    ((number number) (cl:log base power))
    ((tensor (or tensor number)) (log-generic! base power))))
(definline log (base &optional power)
  (cart-etypecase (base power)
    ((number number) (cl:log base power))
    ((number null) (cl:log base))
    ((tensor (or tensor number null)) (log-generic! (copy base (complexified-tensor (class-of base))) power))
    ((number tensor) (log-generic! (copy! base (zeros (dimensions power) (tensor (let ((type (type-of base)))
										   (if (subtypep type 'complex) type `(complex ,type))))))
				   power))))
;;atan
(closer-mop:defgeneric atan-generic! (x y)
  (:generic-function-class tensor-method-generator))
(define-tensor-method atan-generic! ((x dense-tensor :x) (y dense-tensor :y))
  `(dorefs (idx (dimensions x))
	   ((ref-x x :type ,(matlisp::cl :x))
	    (ref-y y :type ,(matlisp::cl :y)))
     (setf ref-x (cl:atan ref-x ref-y)))
  'x)
(define-tensor-method atan-generic! ((x dense-tensor :x) (y number))
  `(dorefs (idx (dimensions x))
	   ((ref-x x :type ,(matlisp::cl :x)))
     (setf ref-x (cl:atan ref-x y)))
  'x)
(define-tensor-method atan-generic! ((x dense-tensor :x) (y null))
  `(dorefs (idx (dimensions x))
	   ((ref-x x :type ,(matlisp::cl :x)))
     (setf ref-x (cl:atan ref-x)))
  'x)

(definline atan! (y &optional x)
  (cart-etypecase (y x)
    ((number number) (cl:atan y x))
    ((number null) (cl:atan y))
    ((tensor (or tensor number)) (atan-generic! y x))))
(definline atan (y &optional x)
  (cart-etypecase (y x)
    ((number number) (cl:atan y x))
    ((number null) (cl:atan y))
    ((tensor (or tensor number null)) (atan-generic! (copy y (complexified-tensor (class-of y))) x))
    ((number tensor) (atan-generic! (copy! y (zeros (dimensions x) (tensor (let ((type (type-of y)))
									     (if (subtypep type 'complex) type `(complex ,type))))))
				    x))))
;;expt
(closer-mop:defgeneric expt-generic! (x y)
  (:generic-function-class tensor-method-generator))
(define-tensor-method expt-generic! ((x dense-tensor :x) (y dense-tensor :y))
  `(dorefs (idx (dimensions x))
	   ((ref-x x :type ,(matlisp::cl :x))
	    (ref-y y :type ,(matlisp::cl :y)))
	   (setf ref-x (expt ref-x ref-y)))
  'x)
(define-tensor-method expt-generic! ((x dense-tensor :x) (y number))
  `(dorefs (idx (dimensions x))
	   ((ref-x x :type ,(matlisp::cl :x)))
     (setf ref-x (expt ref-x y)))
  'x)

(definline expt! (base power)
  (cart-etypecase (base power)
    ((number number) (cl:expt base power))
    ((tensor (or tensor number)) (expt-generic! base power))))
(definline expt (base power)
  (cart-etypecase (base power)
    ((number number) (cl:expt base power))
    ((tensor (or tensor number)) (expt-generic! (copy base) power))
    ((number tensor) (expt-generic! (copy! base (zeros (dimensions power) (tensor (type-of base)))) power))))
;;
