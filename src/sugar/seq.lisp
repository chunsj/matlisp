;;; -*- Mode: lisp; Syntax: ansi-common-lisp; Package: :matlisp; Base: 10 -*-
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (c) 2000 The Regents of the University of California.
;;; All rights reserved. 
;;; 
;;; Permission is hereby granted, without written agreement and without
;;; license or royalty fees, to use, copy, modify, and distribute this
;;; software and its documentation for any purpose, provided that the
;;; above copyright notice and the following two paragraphs appear in all
;;; copies of this software.
;;; 
;;; IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
;;; FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
;;; ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
;;; THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
;;; SUCH DAMAGE.
;;;
;;; THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
;;; INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
;;; MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE
;;; PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
;;; CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
;;; ENHANCEMENTS, OR MODIFICATIONS.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(in-package #:matlisp)

(defun arange (start end &optional (h 1d0))
  (let ((quo (ceiling (if (> start end) (- start end) (- end start)) h)))
    (if (= quo 0) nil
	(let*-typed ((ret (real-typed-zeros (idxv quo)) :type real-tensor)
		     (sto-r (store ret) :type real-store-vector)
		     (h (coerce-real-unforgiving (if (> start end) (- h) h)) :type real-type))
		    (loop :for i :from 0 :below quo
		       :for ori := (coerce-real-unforgiving start) :then (+ ori h)
		       :do (setf (aref sto-r i) ori))
		    ret))))

(defun linspace (start end &optional (num-points (1+ (abs (- start end)))))
  (let ((h (/ (- end start) (1- num-points))))
    (arange start (+ h end) (abs h))))

#+nil (export '(seq))

(if (not (fboundp '%push-on-end%))
(defmacro %push-on-end% (value location)
  `(setf ,location (nconc ,location (list ,value)))))


(defun seq (start step &optional end)
  "
 Syntax
 ======
 (SEQ start [step] end)

 Purpose
 =======
 Creates a list containing the sequence

  START, START+STEP, ..., START+(N-1)*STEP

 where       | END-START |
        N =  | --------- | + 1
             |   STEP    |
             --         --
 
 The representations of START,STEP,END are
 assumed to be exact (i.e. the arguments
 are rationalized.

 The type of the elements in the 
 sequence are of the same type as STEP.

 The optional argument STEP defaults to 1. 
"
  (when (not end)
    (setq end step)
    (setq step 1))

  (let ((start (rationalize start))
	(type (if (typep step 'integer)
		  'integer
		  'rational))
	(step (rationalize step))
	(end (rationalize end))
	(seq nil))

    (when (zerop step)
      (error "STEP equal to 0"))
    (do ((x start (+ x step)))
	((if (> step 0)
	     (> x end)
	     (< x end))
	 (nreverse seq))
      (push (coerce x type) seq))))