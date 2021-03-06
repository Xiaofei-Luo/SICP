#lang planet neil/sicp

; primitive memory operations

(define (vector-ref <vector> <n>) "return the nth element of <vector>")
(define (vector-set! <vector> <n> <value>) "set the nth element of <vector> to <value>")



; implementing primitive list operations
;; assume that operations on pointers use only the index portion of the typed pointer


;; car, cdr

(assign <reg1> (op car) (reg <reg2>))
(assign <reg1> (op cdr) (reg <reg2>))
; =>
(assign <reg1> (op vector-ref) (reg the-cars) (reg <reg2>))
(assign <reg1> (op vector-ref) (reg the-cdrs) (reg <reg2>))


;; set-car!, set-cdr!

(perform (op set-car!) (reg <reg1>) (reg <reg2>))
(perform (op set-cdr!) (reg <reg1>) (reg <reg2>))
; =>
(perform (op vector-set!) (reg the-cars) (reg <reg1>) (reg <reg2>))
(perform (op vector-set!) (reg the-cdrs) (reg <reg1>) (reg <reg2>))


;; cons

(assign <reg1> (op cons) (reg <reg2>) (reg <reg3>))
; =>
(perform (op vector-set!) (reg the-cars) (reg free) (reg <reg2>))
(perform (op vector-set!) (reg the-cdrs) (reg free) (reg <reg3>))
(assign <reg1> (reg free))
(assign free (op +) (reg free) (const 1))


;; eq?
;  tests the equality of all fields in the registers
;  equality of data objects <=> identicality of their pointers

;; pair?, null?, symbol?, number?
;  check the type field




; implementing stacks


;; save
(save <reg>)
; =>
(assign the-stack (op cons) (reg <reg>) (reg the-stack))


;; resotre
(restore <reg>)
; =>
(assign <reg> (op car) (reg the-stack))
(assign the-stack (op cdr) (reg the-stack))


;; perform
(perform (op initialize-stack))
; =>
(assign the-stack (const ()))



; ex 5.20
;
; 0   1   2   3   4
;     n1  p1  p1 
;     n2  p3  e0
;
; the final value of free is p4
; x => index 1   y => index 2




; ex 5.21

;; recursive procedure

(define recursive-count-leaves-machine
  (make-machine
   (list (list '+ +) (list 'null? null?) (list 'pair? pair?)
         (list 'car car) (list 'cdr cdr))
   '(
     (assign continue (label count-leaves-done))
     
     count-loop
     (test (op null?) (reg tree))
     (branch (label null-tree))
     (test (op pair?) (reg tree))
     (branch (label left-branch))
     (assign val (const 1))
     (goto (reg continue))
     
     left-branch
     (save tree)
     (save continue)
     (assign continue (label right-branch))
     (assign tree (op car) (reg tree))
     (goto (label count-loop))
     
     right-branch
     (restore continue)
     (restore tree)
     (save continue)
     (save val)
     (assign continue (label after-count))
     (assign tree (op cdr) (reg tree))
     (goto (label count-loop))
     
     after-count
     (assign var (reg val))
     (restore val)
     (restore continue)
     (assign val (op +) (reg var) (reg val))
     (goto (reg continue))
     
     null-tree
     (assign val (const 0))
     (goto (reg continue))
     
     count-leaves-done)))


(set-register-contents! recursive-count-leaves-machine 'tree '(a (b c (d)) (e f) g))
(start recursive-count-leaves-machine)
(get-register-contents recursive-count-leaves-machine 'val) ; 7



;; iterative procedure

(define iterative-count-leaves-machine 
  (make-machine 
   (list (list '+ +) (list 'null? null?) (list 'pair? pair?)
         (list 'car car) (list 'cdr cdr))
   '(
     (assign n (const 0))
     (assign continue (label count-leaves-done))
     
     count-loop
     (test (op null?) (reg tree))
     (branch (label null-tree))
     (test (op pair?) (reg tree))
     (branch (label pair-tree))
     (assign n (op +) (reg n) (const 1))
     (goto (reg continue))
     
     pair-tree
     (save continue)
     (save tree)
     (assign tree (op car) (reg tree))
     (assign continue (label after-left-branch))
     (goto (label count-loop))
     
     after-left-branch
     (restore tree)
     (assign tree (op cdr) (reg tree))
     (assign continue (label after-right-branch))
     (goto (label count-loop))
     
     after-right-branch
     (restore continue)
     (goto (reg continue))
     
     null-tree
     (assign val (reg n));
     (goto (reg continue))
     
     count-leaves-done)))


(set-register-contents! iterative-count-leaves-machine 'tree '(a (b c (d)) (e f) g))
(start iterative-count-leaves-machine)
(get-register-contents iterative-count-leaves-machine 'n) ; 7



; ex 5.22

;; append

(define (append x y)
  (if (null? x)
      y
      (cons (car x) (append (cdr x) y))))

(define append-machine
  (make-machine
   (list (list 'car car) (list 'cdr cdr)
         (list 'cons cons) (list 'null? null?))
   '(
     (assign continue (label append-done))
     
     append-loop
     (test (op null?) (reg x))
     (branch (label null-x))
     (save continue)
     (assign car-x (op car) (reg x))
     (save car-x)
     (assign x (op cdr) (reg x))
     (assign continue (label after-append))
     (goto (label append-loop))
     
     after-append
     (restore car-x)
     (restore continue)
     (assign x (op cons) (reg car-x) (reg x))
     (goto (reg continue))
     
     null-x
     (assign x (reg y))
     (goto (reg continue))
     
     append-done)))


(set-register-contents! append-machine 'x '(1 2))
(set-register-contents! append-machine 'y '(3 4))
(start append-machine)
(get-register-contents append-machine 'x) ; (1 2 3 4)



;; append!

(define (last-pair x)
  (if (null? (cdr x))
      x
      (last-pair (cdr x))))

(define (append! x y)
  (set-cdr! (last-pair x) y)
  x)


(define append!-machine
  (make-machine
   (list (list 'null? null?) (list 'cdr cdr)
         (list 'set-cdr! set-cdr!))
   '(
     (assign val (reg x))
     
     last-pair-loop
     (assign cdr-x (op cdr) (reg val))
     (test (op null?) (reg cdr-x))
     (branch (label null-cdr-x))
     (assign val (op cdr) (reg val))
     (goto (label last-pair-loop))
     
     null-cdr-x
     (perform (op set-cdr!) (reg val) (reg y))
     
     append!-done)))


(set-register-contents! append!-machine 'x '(1 2))
(set-register-contents! append!-machine 'y '(3 4))
(start append!-machine)
(get-register-contents append!-machine 'x) ; (1 2 3 4)




; implementation of a stop-and-copy garbage collector

(define garbage-collection-instructions
  '(
   begin-garbage-collection
    (assign free (const 0))
    (assign scan (const 0))
    (assign old (reg root)) ; ptr to obj to be relocated
    (assign relocate-continue (label reassign-root))
    (goto (label relocate-old-result-in-new))
    
    reassign-root
    (assign root (reg new)) ; ptr to the relocated obj
    (goto (label gc-loop))
    
    gc-loop
    (test (op =) (reg scan) (reg free))
    (branch (label gc-flip))
    (assign old (op vector-ref) (reg new-cars) (reg scan))
    (assign relocate-continue (label update-car))
    (goto (label relocate-old-result-in-new))
    
    update-car
    (perform (op vector-set!) (reg new-cars) (reg scan) (reg new))
    (assign old (op vector-ref) (reg new-cdrs) (reg scan))
    (assign relocate-continue (label update-cdr))
    (goto (label relocate-old-result-in-new))
    
    update-cdr
    (perform (op vector-set!) (reg new-cdrs) (reg scan) (reg new))
    (assign scan (op +) (reg scan) (const 1))
    (goto (label gc-loop))
    
    relocate-old-result-in-new
    (test (op pointer-to-pair?) (reg old))
    (branch (label pair))
    (assign new (reg old))
    (goto (reg relocate-continue))
    
    pair
    (assign oldcr (op vector-ref) (reg the-cars) (reg old))
    (test (op broken-heart?) (reg oldcr))
    (branch (label already-moved))
    (assign new (reg free))                    ; new location for pair
    (assign free (op +) (reg free) (const 1))  ; update free pointer
    ;; copy the car and cdr to new memory
    (perform (op vector-set!) (reg new-cars) (reg new) (reg oldcr))
    (assign oldcr (op vector-set!) (reg new-cdrs) (reg new) (reg oldcr))
    ;; construct the broken heart
    (perform (op vector-set!) (reg the-cars) (reg old) (const broken-heart))
    (perform (op vector-set!) (reg the-cdrs) (reg old) (reg new))
    (goto (reg relocate-continue))
    
    already-moved
    (assign new (op vector-ref) (reg the-cdrs) (reg old))
    (goto (reg relocate-continue))
    
    gc-flip
    (assign temp (reg the-cdrs))
    (assign the-cdrs (reg new-cdrs))
    (assign new-cdrs (reg temp))
    (assign temp (reg the-cars))
    (assign the-cars (reg new-cars))
    (assign new-cars (reg temp))))