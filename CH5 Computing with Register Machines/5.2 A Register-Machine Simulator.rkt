#lang planet neil/sicp

;; the machine model
(define (make-machine register-names ops controller-text)
  (let ((machine (make-new-machine)))
    (for-each (lambda (register-name)
                ((machine 'allocate-register) register-name))
              register-names)
    ((machine 'install-operations) ops)
    ((machine 'install-instruction-sequence)
     (assemble controller-text machine))
    machine))

;; registers
(define (make-register name)
  (let ((contents '*unassigned*)
        (tracing false))
    (define (dispatch message)
      (cond ((eq? message 'get) contents)
            ((eq? message 'set)
             (lambda (value)
               (if tracing
                   (begin (newline)
                          (display name) (display " ")
                          (display contents) (display " ")
                          (display value) (display " ")))
               (set! contents value)))
            ((eq? message 'trace-on) (set! tracing true)) ; ex 5.18
            ((eq? message 'trace-off) (set! tracing false))
            (else (error "Unknown request -- REGISTER" message))))
    dispatch))

(define (get-contents register) (register 'get))
(define (set-contents! register value) ((register 'set) value))

;; stack
(define (make-stack)
  (let ((s '())
        (number-pushes 0)
        (max-depth 0)
        (current-depth 0))
    (define (push x)
      (set! s (cons x s))
      (set! number-pushes (+ 1 number-pushes))
      (set! max-depth (max current-depth max-depth))
      (set! current-depth (+ 1 current-depth)))
    (define (pop)
      (if (null? s)
          (error "Empty stack -- POP")
          (let ((top (car s)))
            (set! s (cdr s))
            (set! current-depth (- current-depth 1))
            top)))
    (define (initialize)
      (set! s '())
      (set! number-pushes 0)
      (set! max-depth 0)
      (set! current-depth 0)
      'done)
    (define (print-statistics)
      (newline)
      (display (list 'total-pushes '= number-pushes
                     'maximum-depth '= max-depth)))
    (define (dispatch message)
      (cond ((eq? message 'push) push)
            ((eq? message 'pop) pop)
            ((eq? message 'initialize) initialize)
            ((eq? message 'print-statistics) (print-statistics))
            (else (error "Unknown request -- STACK" message))))
    dispatch))

(define (pop stack) (stack 'pop))
(define (push stack value) ((stack 'push) value))
(define (initialize stack) (stack 'initialize))

;; the basic machine
(define (make-new-machine)
  (let ((pc (make-register 'pc))
        (flag (make-register 'flag))
        (stack (make-stack))
        (the-instruction-sequence '())
        (instruction-count 0)
        (tracing-instruction false))
    (let ((the-ops
           (list (list 'initialize-stack
                       (lambda () (stack 'initialize)))))
          (register-table
           (list (list 'pc pc) (list 'flag flag))))
      (define (allocate-register name)
        (if (assoc name register-table)
            (error "Multiply defined register: " name)
            (set! register-table
                  (cons (list name (make-register name))
                        register-table)))
        'register-allocated)
      (define (lookup-register name)
        (let ((val (assoc name register-table)))
          (if val
              (cadr val)
              (error "Unknown register: " name))))
      (define (execute)
        (let ((insts (get-contents pc)))
          (if (null? insts)
              'done
              (begin (if tracing-instruction (begin (newline) (display (caar insts))))
                ((instruction-execution-proc (car insts)))
                     (set! instruction-count (+ instruction-count 1))
                     (execute)))))
      (define (print-instruction-count)
        (display (newline) (list instruction-count 'instructions)))
      (define (dispatch message)
        (cond ((eq? message 'start)
               (set-contents! pc the-instruction-sequence)
               (execute))
              ((eq? message 'install-instruction-sequence)
               (lambda (seq) (set! the-instruction-sequence seq)))
              ((eq? message 'allocate-register) allocate-register)
              ((eq? message 'get-register) (lookup-register))
              ((eq? message 'install-operations)
               (lambda (ops) (set! the-ops (append the-ops ops))))
              ((eq? message 'stack) stack)
              ((eq? message 'operations) the-ops)
              ((eq? message 'instruction-count) print-instruction-count) ; ex 5.15
              ((eq? message 'trace-on) (set! tracing-instruction true))  ; ex 5.16
              ((eq? message 'trace-off) (set! tracing-instruction false))
              (else (error "Unknown request -- MACHINE" message))))
      dispatch)))

(define (start machine) (machine 'start))

(define (get-register machine reg-name) ((machine 'get-register) reg-name))
(define (get-register-contents machine register-name)
  (get-contents (get-register machine register-name)))
(define (set-register-contents! machine register-name value)
  (set-contents! (get-register machine register-name) value))

; ex 5.18
(define (turn-on-register-trace machine register-name)
  ((get-register machine register-name) 'trace-on))
(define (turn-off-register-trace machine register-name)
  ((get-register machine register-name) 'trace-off))

;; the assembler
(define (assemble controller-text machine)
  (let ((result (extract-labels controller-text)))
    (let ((insts (car result))
          (labels (cdr result)))
      (update-insts! insts labels machine)
      insts)))

(define (extract-labels text)
  (if (null? text)
      (cons '() '())
      (let ((result (extract-labels (cdr text))))
        (let ((insts (car result))
              (labels (cdr result)))
          (let ((next-inst (car text)))
            (if (symbol? next-inst)
                ;; ex 5.8
                (if (assoc next-inst insts)
                    (error "duplicate labels -- ASSEMBLE" next-inst)
                    (cons insts
                          (cons (make-label-entry next-inst insts) labels)))
                (cons (cons (make-instruction next-inst) insts)
                      labels)))))))

(define (make-instruction text) (cons text '()))
(define (instruction-text inst) (car inst))
(define (instruction-execution-proc inst) (cdr inst))
(define (set-instruction-execution-proc! inst proc) (set-cdr! inst proc))

(define (make-label-entry label-name insts) (cons label-name insts))
(define (lookup-label labels label-name)
  (let ((val (assoc label-name labels)))
    (if val
        (cdr val)
        (error "Undefined label -- ASSEMBLE" label-name))))

(define (update-insts! insts labels machine)
  (let ((pc (get-register machine 'pc))
        (flag (get-register machine 'flag))
        (stack (machine 'stack))
        (ops (machine 'operations)))
    (for-each
     (lambda (inst)
       (set-instruction-execution-proc!
        inst
        (make-execution-procedure
         (instruction-text inst) labels machine
         pc flag stack ops)))
     insts)))

;; generating execution procedures for instructions
(define (make-execution-procedure inst labels machine
                                  pc flag stack ops)
  (let ((tag (car inst)))
    (cond ((eq? tag 'assign) (make-assign inst machine labels ops pc))
          ((eq? tag 'test) (make-test inst machine labels ops flag pc))
          ((eq? tag 'branch) (make-branch inst machine labels flag pc))
          ((eq? tag 'goto) (make-goto inst machine labels pc))
          ((eq? tag 'save) (make-save inst machine stack pc))
          ((eq? tag 'restore) (make-restore inst machine stack pc))
          ((eq? tag 'perform) (make-perform inst machine labels ops pc))
          (else (error "Unknown instruction type -- ASSEMBLE" inst)))))

;; assign
(define (make-assign inst machine labels operations pc)
  (let ((target (get-register machine (cadr inst)))
        (value-exp (cddr inst)))
    (let ((value-proc
           (if (operation-exp? value-exp)
               (make-operation-exp value-exp machine labels operations)
               (make-primitive-exp (car value-exp) machine labels))))
      (lambda ()
        (set-contents! target (value-proc))
        (advance-pc pc)))))

(define (advance-pc pc) (set-contents! pc (cdr (get-contents pc))))

;; test
(define (make-test inst machine labels operations flag pc)
  (let ((condition (cdr inst)))
    (if (operation-exp? condition)
        (let ((condition-proc
               (make-operation-exp condition machine labels operations)))
          (lambda ()
            (set-contents! flag (condition-proc))
            (advance-pc pc)))
        (error "Bad TEST instruction -- ASSEMBLE" inst))))

;; branch
(define (make-branch inst machine labels flag pc)
  (let ((dest (cadr inst)))
    (if (label-exp? dest)
        (let ((insts (lookup-label labels (cadr dest))))
          (lambda ()
            (if (get-contents flag)
                (set-contents! pc insts)
                (advance-pc pc))))
        (error "Bad BRANCH instruction -- ASSEMBLE" inst))))

;; goto
(define (make-goto inst machine labels pc)
  (let ((dest (cadr inst)))
    (cond ((label-exp? dest)
           (let ((insts (lookup-label labels (cadr dest))))
             (lambda () (set-contents! pc insts))))
          ((register-exp? dest)
           (let ((reg (get-register machine (cadr dest))))
             (lambda () (set-contents! pc (get-contents reg)))))
          (else (error "Bad GOTO instruction -- ASSEMBLE" inst)))))

;; save, restore, perform
(define (make-save inst machine stack pc)
  (let ((reg (get-register machine (cadr inst))))
    (lambda ()
      (push stack (get-contents reg))
      (advance-pc pc))))

(define (make-restore inst machine stack pc)
  (let ((reg (get-register machine (cadr inst))))
    (lambda ()
      (set-contents! reg (pop stack))
      (advance-pc pc))))

;; ex 5.11b
(define (make-save-ex11-b inst machine stack pc)
  (let ((reg (get-register machine (cadr inst))))
    (lambda ()
      (push stack (cons (cadr inst) (get-contents reg)))
      (advance-pc pc))))

(define (make-restore-ex11-b inst machine stack pc)
  (let ((reg (get-register machine (cadr inst))))
    (lambda ()
      (if (eq? (car (car stack)) (cadr inst))
          (begin
            (set-contents! reg (pop stack))
            (advance-pc pc))
          (error "value not from the register -- MAKE-RESTORE" (cadr inst))))))


(define (make-perform inst machine labels operations pc)
  (let ((action (cdr inst)))
    (if (operation-exp? action)
        (let ((action-proc
               (make-operation-exp action machine labels operations)))
          (lambda ()
            (action-proc)
            (advance-pc pc)))
        (error "Bad PERFORM instruction -- ASSEMBLE" inst))))

;; execution procedures for subexpressions
(define (make-primitive-exp exp machine labels)
  (cond ((constant-exp? exp)
         (let ((c (cadr exp)))
           (lambda () c)))
        ((label-exp? exp)
         (let ((insts (lookup-label labels (cadr exp))))
           (lambda () insts)))
        ((register-exp? exp)
         (let ((r (get-register machine (cadr exp))))
           (lambda () (get-contents r))))
        (else (error "Unknown expression type -- ASSEMBLE" exp))))

(define (make-operation-exp exp machine labels operations)
  (let ((op (lookup-prim (cadar exp) operations))
        (aprocs (map
                 (lambda (e)
                   ;; ex 5.9
                   (if (or (label-exp? e) (register-exp? e))
                       (make-primitive-exp e machine labels)
                       (error "operate used only with registers and constants" e)))
                 (cdr exp))))
    (lambda () (apply op (map (lambda (p) (p)) aprocs)))))

(define (lookup-prim symbol operations)
  (let ((val (assoc symbol operations)))
    (if val
        (cadr val)
        (error "Unknown operation -- ASSEMBLE" symbol))))                     

(define (tagged-list? exp tag) (if (pair? exp) (eq? (car exp) tag) false))
(define (register-exp? exp) (tagged-list? exp 'reg))
(define (constant-exp? exp) (tagged-list? exp 'const))
(define (label-exp? exp) (tagged-list? exp 'label))
(define (operation-exp? exp) (tagged-list? (car exp) 'op))

;; test the machine simulator

;; GCD machine
(define gcd-machine
  (make-machine
   '(a b t)
   (list (list 'rem remainder) (list '= =))
   '(test-b
     (test (op =) (reg b) (const 0))
     (branch (label gcd-done))
     (assign t (op rem) (reg a) (reg b))
     (assign a (reg b))
     (assign b (reg t))
     (goto (label test-b))
     gcd-done)))

; ex 5.7
;; recursive exponentiation machine
(define exp-rec-machine
  (make-machine
   '(b n continue)
   (list (list '= =) (list '- -) (list '* *))
   '(
     (assign continue (label exp-done))
     exp-loop
     (test (op =) (reg n) (const 0))
     (branch (label base-case))
     (save continue)
     (assign n (op -) (reg n) (const 1))
     (assign continue (label after-exp))
     (goto (label exp-loop))
     after-exp
     (restore continue)
     (assign val (op *) (reg b) (reg val))
     (goto (reg continue))
     base-case
     (assign val (const 1))
     (goto (reg continue))
     exp-done)))

;; iterative exponentiation machine
(define exp-it-machine
  (make-machine
   '(b n product)
   (list ('= =) ('- -))
   '(
     assign product (const 1))
   exp-loop
   (test (op =) (reg n) (const 0))
   (branch (label exp-done))
   (assign product (op *) (reg b) (reg product))
   (assign n (op -) (reg n) (const 1))
   (goto (label exp-loop))
   exp-done))