#lang racket
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedures for dfas, nfas, and nbas

; Dana Angluin
; September 2020

(provide
 final-loop-lang
 nfa-accepts? nfa-trim
 nba-accepts-from-state? nba-accepts?
 nba-list-accepted nba-list-random-accepted
 nba-reachable nba-reachable-nonempty nba-trim
 random-reverse-det-nba-k
 GNBA->NBA write-NBA)


(require "general-utilities.rkt")
(require "sequence-utilities.rkt")
(require "aut-definitions.rkt")
(require "aut-procedures.rkt")
(require "graph-paths.rkt")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Deterministic finite automata (DFAs)
; These are just aut-f machines that have a single initial state and
; a deterministic (though possibly not complete) transition relation.

; Example of a dfa
(define dfa1
  (aut-f
   (aut
    '(a b)
    '(1 2 3 4)
    '(1)
    (list
     (entry '(1 a) 2)
     (entry '(1 b) 4)
     (entry '(2 a) 3)
     (entry '(2 b) 3)
     (entry '(3 a) 2)
     (entry '(3 b) 4)
     (entry '(4 a) 3)
     (entry '(4 b) 1)))
   '(4)))

; Given a possibly incomplete dfa and a state,
; return a trimmed dfa for the language of nonempty strings that start
; at the given state, end at the given state, and arrive at some
; final state along the way.

(define (final-loop-lang dfa1 state)
;  (displayln "final-loop-lang")
  (let* ((alphabet (aut-f-alphabet dfa1))
         (states (aut-f-states dfa1))
         (trans (aut-f-trans dfa1))
         (final-states (aut-f-final-states dfa1))
         (states0 (c-product states '(0)))
         (states1 (c-product states '(1)))
         (trans0
          (map (lambda (tuple)
                 (let* ((source-state (first (entry-key tuple)))
                        (symbol (second (entry-key tuple)))
                        (dest-state (entry-value tuple))
                        (flag (if (member dest-state final-states) 1 0)))
                   (entry (list (list source-state 0) symbol)
                          (list dest-state flag))))
               trans))
         (trans1
          (map (lambda (tuple)
                 (let* ((source-state (first (entry-key tuple)))
                        (symbol (second (entry-key tuple)))
                        (dest-state (entry-value tuple)))
                   (entry (list (list source-state 1) symbol)
                                        (list dest-state 1))))
               trans)))
    (nfa-trim
     (aut-f
      (aut
       alphabet
       (append states0 states1)
       (list (list state 0))
       (append trans0 trans1))
      (list (list state 1))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; NFA is just an aut-f with a list of final states.  It may have more
; than one initial state, and may have a nondeterministic or incomplete
; transition relation.

; Given a set of states and a list of symbols, make a list of the
; states an nfa can reach on that sequence of input symbols.

(define (nfa-string-reaches states str nfa1)
  (let* [(trans (aut-f-trans nfa1))]
    (if (empty? str)
        states
        (let* [(curr-symbol (first str))
               (successors
                (remove-duplicates
                 (apply append
                        (map (lambda (state)
                               (lookup-all (list state curr-symbol) trans))
                             states))))]
          (nfa-string-reaches successors (rest str) nfa1)))))
               
; Does an NFA accept a string (represented as a list of symbols)?

(define (nfa-accepts? str nfa1)
  (let* [(init-states (aut-f-init-states nfa1))
         (final-states (aut-f-final-states nfa1))]
    (not (empty? (set-intersect
                  (nfa-string-reaches init-states str nfa1)
                  final-states)))))
 
; Given an NFA (or DFA), trim it by removing any state that
; is not reachable from the initial states or doesn't reach a final state.

(define (nfa-trim nfa1)
;  (displayln "nfa-trim")
  (let* ((alphabet (aut-f-alphabet nfa1))
         (states (aut-f-states nfa1))
         (init-states (aut-f-init-states nfa1))
         (init-states-reach (aut-reachable (aut-f-aut nfa1) init-states))
         (trans (aut-f-trans nfa1))
         (final-states (aut-f-final-states nfa1))
         (reach-final-states (aut-reaches (aut-f-aut nfa1) final-states))
         (new-states (fast-set-intersect init-states-reach reach-final-states)))
    (aut-f
     (aut
      alphabet
      new-states
      (fast-set-intersect init-states new-states)
      (filter
       (lambda (entry1)
         (and (member (first (entry-key entry1)) new-states)
              (member (entry-value entry1) new-states)))
       trans))
      (fast-set-intersect final-states new-states))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; An NBA is an aut-f with a list of final states.  The acceptance
; criterion for an infinite word is whether there is a run on that
; word that visits at least one final state infinitely many times.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedures related to testing whether an NBA accepts a given sequence u(v)^w.

; Find NBA "marked" next states from a given "marked" state
; and a given alphabet symbol.
; A "marked" state is a list (state mark)
; where mark is either 0 or 1.

; If the input state is marked 1, all the one-step reachable
; states are marked 1.  If the input state is marked 0, then
; only those one-step reachable states that are final are marked 1.

; The marks are used to keep track of whether a final state
; has been visited along at least one path between two states.

(define (nba-next-marked-states symbol marked-state nba1)
  (let* [(state (first marked-state))
         (mark (second marked-state))
         (trans (aut-f-trans nba1))
         (final-states (aut-f-final-states nba1))
         (next-states (lookup-all (list state symbol) trans))]
    (if (equal? mark 1)
        (map (lambda (state) (list state 1)) next-states)
        (map (lambda (state) (list state (if (member state final-states) 1 0)))
             next-states))))

; Find NBA marked states reached from a given list of marked states
; with a given input string of symbols.

(define (nba-string-marked-states str marked-states nba1)
  (let* [(aut1 (aut-f-aut nba1))
         (final-states (aut-f-final-states nba1))]
    (if (null? str)
        marked-states
        (let* [(all-next-marked-states
                (apply append
                       (map (lambda (marked-state)
                              (nba-next-marked-states (first str) marked-state nba1))
                            marked-states)))
               (refined-next-marked-states
                (refine all-next-marked-states))]
          (nba-string-marked-states (rest str) refined-next-marked-states nba1)))))

; (refine marked-states)
; marked-states is a list of items (state mark)
; returned is a list of items (state mark), one for each
; of the different states, with mark set to the *maximum* of the marks that
; state appears with
; Example:
;> (refine '((1 0) (3 1) (3 0) (1 1) (2 0)))
;'((1 1) (3 1) (2 0))

(define (refine marked-states)
  (let* [(states (remove-duplicates (map first marked-states)))]
    (map (lambda (state)
           (if (member (list state 1) marked-states)
               (list state 1)
               (list state 0)))
         states)))

; Given a string str, a set of marked states and an NBA,
; iterate applying the string until the set of marked states
; converges (doesn't change from one iteration to the next)
; and return the final result.

(define (nba-string-marked-states-converge str marked-states nba1)
;  (display "str ")(displayln str)
;  (display "marked-states ")(displayln marked-states)
  (let* [(next-marked-states (nba-string-marked-states str marked-states nba1))]
;   (display "next-marked-states ")(displayln next-marked-states)
    (if (set-subset? next-marked-states marked-states)
        marked-states
        (nba-string-marked-states-converge
         str (refine (append marked-states next-marked-states)) nba1))))
      
; Is there an accepting loop from the given state to itself
; on the input v^k for some positive integer k?

(define (nba-accept-loop? v state nba1)
  (let* [(v-states (aut-string-states v state (aut-f-aut nba1)))
         (marked-v-states (map (lambda (state) (list state 0)) v-states))
         (v-converged-states (nba-string-marked-states-converge v marked-v-states nba1))]
;    (display "v-states ")(displayln v-states)
;    (display "v-converged-states ")(displayln v-converged-states)
    (if (member (list state 1) v-converged-states)
        #t
        #f)))

; Is the given ultimately-periodic word (seq) accepted by the given NBA
; from the given state?

(define (nba-accepts-from-state? seq nba1 state)
  (let* [(u (first seq))
         (v (second seq))
         (u-states (aut-string-states u state (aut-f-aut nba1)))
         (marked-u-states (map (lambda (state) (list state 0)) u-states))
         (uv-converged-states (nba-string-marked-states-converge v marked-u-states nba1))]
;    (display "u-states ")(displayln u-states)
;    (display "uv-converged-states ")(displayln uv-converged-states)
    (exists? (lambda (marked-state)
               (nba-accept-loop? v (first marked-state) nba1))
             uv-converged-states)))

; Is the given ultimately-periodic word (seq) accepted by the given NBA?
; Examples:
;> (nba-accepts? '((a b) (b)) nba-inf-as)
;#f
;> (nba-accepts? '((a) (a b)) nba-inf-as)
;#t
;> (nba-accepts? '(() (a a a)) nba-inf-as)
;#t

(define nba-accepts?
  (lambda (seq nba1)
    (exists? (lambda (state)
               (nba-accepts-from-state? seq nba1 state))
             (aut-f-init-states nba1))))

; Make a list of the ultimately periodic words u(v)^w
; with lengths of u and v bounded by k that are accepted by the given NBA.
; This is useful to help with debugging and also understanding a given NBA.

(define (nba-list-accepted k nba1)
  (let* ((alphabet (aut-f-alphabet nba1))
         (seqs (bounded-seqs-k alphabet k)))
    (filter (lambda (seq) (nba-accepts? seq nba1))
            seqs)))


; Generate a specified number of randomly chosen ultimately periodic words u(v)^w
; with the lengths of u and v bounded by k that are accepted by the given NBA.
; The result is '() if none are found.  This uses the random-path procedures.

(define (nba-list-random-accepted count k nba1)
  (let* [(trimmed-nba (nba-trim nba1))
         (init-states (aut-f-init-states trimmed-nba))
         (final-states (aut-f-final-states trimmed-nba))
         (graph (aut->digraph (aut-f-aut trimmed-nba)))]
    (if (or (empty? init-states) (empty? final-states))
        '()
        (nba-list-random-accepted-loop count init-states final-states k graph '()))))

(define (nba-list-random-accepted-loop
         count init-states final-states k graph accepted-seqs)
  (if (<= count 0)
      accepted-seqs
      (let* [(init-state (pick init-states))
             (final-state (pick final-states))
             (lens-init-final
              (map (lambda (len) (graph 'n-paths init-state final-state len)) (range (+ 1 k))))
             (lens-final-final
              (map (lambda (len) (graph 'n-paths final-state final-state len)) (range 1 (+ 1 k))))]
        (if (or (= 0 (apply + lens-init-final))
                (= 0 (apply + lens-final-final)))
            (nba-list-random-accepted-loop
             (- count 1) init-states final-states k graph accepted-seqs)
            (let* [(u-len (random-select-counts
                           (range (+ 1 k))
                           (map (lambda (x) (if (> x 0) 1 0)) lens-init-final)))
                   (v-len (random-select-counts
                           (range 1 (+ 1 k))
                           (map (lambda (x) (if (> x 0) 1 0)) lens-final-final)))
                   (u-part (random-path-labels graph init-state final-state u-len))
                   (v-part (random-path-labels graph final-state final-state v-len))]
              (nba-list-random-accepted-loop
               (- count 1) init-states final-states k graph (cons (list u-part v-part)
                                                                  accepted-seqs)))))))
          
  


; Given an NBA and a set of states, determine all states reachable
; from the given states.
(define (nba-reachable nba1 states)
         (aut-reachable (aut-f-aut nba1) states))

; Given an NBA and a state, determine all states reachable from the state
; by strings of length at least 1
(define (nba-reachable-nonempty nba1 state)
  (let* ((alphabet (aut-f-alphabet nba1))
         (aut1 (aut-f-aut nba1))
         (next-states 
          (remove-duplicates
           (apply append
                  (map (lambda (symbol)
                         (aut-next-states symbol state aut1))
                       alphabet)))))
    (nba-reachable nba1 next-states)))
 
; Given an NBA, make a list of the final states that can reach themselves
; by a string of length at least 1.  "Final" states lacking this property
; can be made non-final without changing the set of accepted words.

(define (nba-final-nonempty-loop nba1)
  (let* ((final-states (aut-f-final-states nba1)))
    (filter
     (lambda (state)
       (member state (nba-reachable-nonempty nba1 state)))
     final-states)))

; Given an NBA, trim it by removing any state that
; is not reachable from the initial state or doesn't reach a final
; state that has a nonempty loop.

(define (nba-trim nba1)
;  (displayln "nba-trim")
  (let* ((alphabet (aut-f-alphabet nba1))
         (states (aut-f-states nba1))
         (init-states (aut-f-init-states nba1))
         (init-states-reach (nba-reachable nba1 init-states))
         (trans (aut-f-trans nba1))
         (final-states (aut-f-final-states nba1))
         (loop-final-states (nba-final-nonempty-loop nba1))
         (reach-loop-final-states (aut-reaches (aut-f-aut nba1) loop-final-states))
         (new-states (fast-set-intersect init-states-reach reach-loop-final-states)))
;    (displayln "nba-trim 2")
    (aut-f
     (aut
      alphabet
      new-states
      (fast-set-intersect init-states new-states)
      (filter
       (lambda (entry1)
         (and (member (first (entry-key entry1)) new-states)
              (member (entry-value entry1) new-states)))
       trans))
     (fast-set-intersect loop-final-states new-states))))

; Create a random NONEMPTY reverse-deterministic NBA with
; a specified number of final states and missing transitions
; and trim and return it.  This is used in the generation of random SUBAs.

(define (random-reverse-det-nba-k
         alphabet number-of-states number-of-final-states number-missing)
;  (displayln "random-reverse-det-nba-k")
  (let* ((aut1 (random-reverse-det-aut 
  	       	alphabet number-of-states number-missing))
         (states (aut-states aut1))
         (new-nba (nba-trim (aut-f aut1 (pick-k number-of-final-states states)))))
    (if (empty? (aut-f-states new-nba))
        (random-reverse-det-nba-k
         alphabet number-of-states number-of-final-states number-missing)
        new-nba)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Convert a GNBA to an NBA
; input is an aut-f with a list of lists of final states
; output is an NBA, a (potentially larger) aut-f with a list of final states

(define (GNBA->NBA mach)
  (let* [(mach-aut (aut-f-aut mach))
         (final-state-sets (aut-f-final-states mach))]
    (cond
      [(empty? final-state-sets)
       (aut-f mach-aut (aut-f-states mach))]  ; all states are accepting
      [(= 1 (length (aut-f-final-states mach)))
       (aut-f mach-aut (first final-state-sets))] ; just one final set of states
      [else
       (let* [(alphabet (aut-f-alphabet mach))
              (states (aut-f-states mach))
              (initial-states (aut-f-init-states mach))
              (trans (aut-f-trans mach))
              (final-state-sets (aut-f-final-states mach))]
       
         (let* [(k (length final-state-sets))
                (new-states (c-product states (range k)))
                (new-initial-states (c-product initial-states (list 0)))
                (new-final-state-set (c-product (first final-state-sets) (list 0)))
                (new-trans (GNBA->NBA-new-trans trans final-state-sets))]
;          (displayln "more than one set of final states")
           (aut-f
            (aut
             alphabet
             new-states
             new-initial-states
             new-trans)
            new-final-state-set)))])))

(define (GNBA->NBA-new-trans trans final-state-sets)
  (let* [(k (length final-state-sets))]
    (apply append
           (map (lambda(final-state-set index)
                  (map (lambda(item)
                         (let* [(key (entry-key item))
                                (to-state (entry-value item))
                                (from-state (first key))
                                (symbol (second key))]
                           (if (member? from-state final-state-set)
                               (entry
                                (list (list from-state index) symbol)
                                (list to-state (modulo (+ 1 index) k)))
                               (entry
                                (list (list from-state index) symbol)
                                (list to-state index)))))
                       trans))
         final-state-sets
         (range k)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; procedures for writing an NBA to a file in the format required
; by NBA.jar.

; Function to translate states into numbers 1 through number of states.
(define (number-of-state state list-of-states)
  (+ 1 (index-of list-of-states state)))

; First line of the file will be a comment with the given identifier.
; This assumes defaults of example length <= 10, a million tests
; per equivalence query and at most 1,000 equivalence queries.

; Example:
; (write-NBA "identifier" name-of-nba "file_name.txt")

(define (write-NBA id nba1 file-name)
  (let* ((o-port (open-output-file file-name #:exists 'replace))
         (alphabet (aut-f-alphabet nba1))
         (states (aut-f-states nba1))
         (trans (aut-f-trans nba1))
         (final-states (aut-f-final-states nba1)))
    (display "// id = " o-port)
    (displayln id o-port)
    (displayln "// maximum length of a test in the statistical equivalence query" o-port)
    (displayln 10 o-port)
    (displayln "// number of tests the statistical equivalence query will check" o-port)
    (displayln 1000000 o-port)
    (displayln "// limit on the number of equivalence queries to run" o-port)
    (displayln 1000 o-port)
    (displayln "// number of states" o-port)
    (displayln (length states) o-port)
    (displayln "// alphabet" o-port)
    (for-each (lambda (symbol)
                (display symbol o-port)
                (display " " o-port))
              alphabet)
    (displayln "" o-port)
    (displayln "// final states" o-port)
    (for-each (lambda (state)
;                (display state)(display " ")(displayln states)
                (display (number-of-state state states) o-port)
                (display " " o-port))
              final-states)
    (displayln "" o-port)
    (displayln "// number of transitions" o-port)
    (displayln (length trans) o-port)
    (displayln "// transitions" o-port)
    (for-each (lambda (item)
                (let ((key (entry-key item))
                      (value (entry-value item)))
                  (display (number-of-state (first key) states) o-port)
                  (display " " o-port)
                  (display (second key) o-port)
                  (display " " o-port)
                  (displayln (number-of-state value states) o-port)))
              trans)
    (close-output-port o-port)))