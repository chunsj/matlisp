(in-package #:matlisp)

(defclass linear-store ()
  ((head :initarg :head :initform 0 :reader head :type index-type
    :documentation "Head for the store's accessor.")
   (strides :initarg :strides :reader strides :type index-store-vector
    :documentation "Strides for accesing elements of the tensor.")
   (store :initarg :store :reader store :type vector
    :documentation "The actual storage for the tensor.")))

(declaim (ftype (function (base-tensor) index-store-vector) strides)
	 (ftype (function (base-tensor) index-type) head))

;;
(defun store-indexing-vec (idx hd strides dims)
"
  Syntax
  ======
  (STORE-INDEXING-VEC IDX HD STRIDES DIMS)

  Purpose
  =======
  Does error checking to make sure IDX is not out of bounds.
  Returns the sum:

    length(STRIDES)
       __
  HD + \  STRIDE  * IDX
       /_        i      i
     i = 0
"
  (declare (type index-type hd)
	   (type index-store-vector idx strides dims))
  (let-typed ((rank (length strides) :type index-type))
    (assert (= rank (length idx) (length dims)) nil 'tensor-index-rank-mismatch :index-rank (length idx) :rank rank)
    (very-quickly
      (loop
	 :for i :of-type index-type :from 0 :below rank
	 :for cidx :across idx
	 :with sto-idx :of-type index-type := hd
	 :do (progn
	       (assert (< -1 cidx (aref dims i)) nil 'tensor-index-out-of-bounds :argument i :index cidx :dimension (aref dims i))
	       (incf sto-idx (the index-type (* (aref strides i) cidx))))
	 :finally (return sto-idx)))))

(defun store-indexing-lst (idx hd strides dims)
"
  Syntax
  ======
  (STORE-INDEXING-LST IDX HD STRIDES DIMS)

  Purpose
  =======
  Does error checking to make sure idx is not out of bounds.
  Returns the sum:

    length(STRIDES)
       __
  HD + \  STRIDE  * IDX
       /_        i      i
     i = 0
"
  (declare (type index-type hd)
	   (type index-store-vector strides dims)
	   (type cons idx))
  (let-typed ((rank (length strides) :type index-type))
    (assert (= rank (length dims)) nil 'tensor-dimension-mismatch)
    (very-quickly
      (loop :for cidx :of-type index-type :in idx
	 :for i :of-type index-type := 0 :then (1+ i)
	 :with sto-idx :of-type index-type := hd
	 :do (progn
	       (assert (< -1 cidx (aref dims i)) nil 'tensor-index-out-of-bounds :argument i :index cidx :dimension (aref dims i))
	       (incf sto-idx (the index-type (* (aref strides i) cidx))))
	 :finally (progn
		    (assert (= (1+ i) rank) nil 'tensor-index-rank-mismatch :index-rank (1+ i) :rank rank)
		    (return sto-idx))))))

(definline store-indexing (idx tensor)
"
  Syntax
  ======
  (STORE-INDEXING IDX TENSOR)

  Purpose
  =======
  Returns the linear index of the element pointed by IDX.
  Does error checking to make sure idx is not out of bounds.
  Returns the sum:

    length(STRIDES)
       __
  HD + \  STRIDES  * IDX
       /_        i      i
     i = 0
"
  (etypecase idx
    (cons (store-indexing-lst idx (head tensor) (strides tensor) (dimensions tensor)))
    (vector (store-indexing-vec idx (head tensor) (strides tensor) (dimensions tensor)))))

;;Stride makers.
(definline make-stride-rmj (dims)
  (declare (type index-store-vector dims))
  (let-typed ((stds (allocate-index-store (length dims)) :type index-store-vector))
    (very-quickly
      (loop
	 :for i  :of-type index-type :downfrom (1- (length dims)) :to 0
	 :and st :of-type index-type := 1 :then (the index-type (* st (aref dims i)))	 
	 :do (progn
	       (assert (> st 0) nil 'tensor-invalid-dimension-value :argument i :dimension (aref dims i))
	       (setf (aref stds i) st))
	 :finally (return (values stds st))))))

(definline make-stride-cmj (dims)
  (declare (type index-store-vector dims))
  (let-typed ((stds (allocate-index-store (length dims)) :type index-store-vector))
    (very-quickly
      (loop
	 :for i :of-type index-type :from 0 :below (length dims)
	 :and st :of-type index-type := 1 :then (the index-type (* st (aref dims i)))
	 :do (progn
	       (assert (> st 0) nil 'tensor-invalid-dimension-value :argument i :dimension (aref dims i))
	       (setf (aref stds i) st))
	 :finally (return (values stds st))))))

(definline make-stride (dims)
  (ecase *default-stride-ordering* (:row-major (make-stride-rmj dims)) (:col-major (make-stride-cmj dims))))

;;Is it a tensor, is a store ? It is both!
(defclass standard-tensor (dense-tensor linear-store) ())

(defmethod initialize-instance :after ((tensor standard-tensor) &rest initargs)
  (declare (ignore initargs))
  (when *check-after-initializing?*
    (let-typed ((dims (dimensions tensor) :type index-store-vector))
      (assert (>= (head tensor) 0) nil 'tensor-invalid-head-value :head (head tensor) :tensor tensor)
      (if (not (slot-boundp tensor 'strides))
	  (multiple-value-bind (stds size) (make-stride dims)
	    (declare (type index-store-vector stds)
		     (type index-type size))
	    (setf (slot-value tensor 'strides) stds)
	    (assert (<= (+ (head tensor) size) (store-size tensor)) nil 'tensor-insufficient-store :store-size (store-size tensor) :max-idx (+ (head tensor) (1- (size tensor))) :tensor tensor))
	  (very-quickly
	    (let-typed ((stds (strides tensor) :type index-store-vector))
	      (loop :for i :of-type index-type :from 0 :below (order tensor)
		 :for sz :of-type index-type := (aref dims 0) :then (the index-type (* sz (aref dims i)))
		 :for lidx :of-type index-type := (the index-type (* (aref stds 0) (1- (aref dims 0)))) :then (the index-type (+ lidx (the index-type (* (aref stds i) (1- (aref dims i))))))
		 :do (progn
		       (assert (> (aref stds i) 0) nil 'tensor-invalid-stride-value :argument i :stride (aref stds i) :tensor tensor)
		       (assert (> (aref dims i) 0) nil 'tensor-invalid-dimension-value :argument i :dimension (aref dims i) :tensor tensor))
		 :finally (assert (>= (the index-type (store-size tensor)) (the index-type (+ (the index-type (head tensor)) lidx))) nil 'tensor-insufficient-store :store-size (store-size tensor) :max-idx lidx :tensor tensor))))))))

(defmethod ref ((tensor standard-tensor) &rest subscripts)
  (let ((clname (class-name (class-of tensor))))
    (assert (member clname *tensor-type-leaves*) nil 'tensor-abstract-class :tensor-class clname)
    (compile-and-eval
     `(defmethod ref ((tensor ,clname) &rest subscripts)
	(let ((subs (if (numberp (car subscripts)) subscripts (car subscripts))))
	  (t/store-ref ,clname (store tensor) (store-indexing subs tensor)))))
    (apply #'ref (cons tensor subscripts))))

(defmethod (setf ref) (value (tensor standard-tensor) &rest subscripts)
  (let ((clname (class-name (class-of tensor))))
    (assert (member clname *tensor-type-leaves*) nil 'tensor-abstract-class :tensor-class clname)
    (compile-and-eval
     `(defmethod (setf ref) (value (tensor ,clname) &rest subscripts)
	(let* ((subs (if (numberp (car subscripts)) subscripts (car subscripts)))
	       (idx (store-indexing subs tensor))
	       (sto (store tensor)))
	  (t/store-set ,clname (t/coerce ,(field-type clname) value) sto idx)
	  (t/store-ref ,clname sto idx))))
    (setf (ref tensor (if (numberp (car subscripts)) subscripts (car subscripts))) value)))

;;
(defmethod subtensor~ ((tensor standard-tensor) (subscripts list) &optional (preserve-rank nil) (ref-single-element? t))
  (multiple-value-bind (hd dims stds) (parse-slicing-args (dimensions tensor) (strides tensor) subscripts preserve-rank ref-single-element?)
    (incf hd (head tensor))
    (if dims
	(let ((*check-after-initializing?* nil))
	  (make-instance (class-of tensor)
			 :head hd
			 :dimensions (make-index-store dims)
			 :strides (make-index-store stds)
			 :store (store tensor)
			 :parent-tensor tensor))
	(store-ref tensor hd))))
