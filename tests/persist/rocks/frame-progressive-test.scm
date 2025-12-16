#! /usr/bin/env guile
-s
!#
;
; frame-progressive-test.scm
;
; Verify that frames can be constructed and saved progressively,
; including proper atom deletion during the progress.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-frame-progressive-test")

(define (get-val ATOM NAME) (inexact->exact
	(cog-value-ref (cog-value ATOM (Predicate NAME)) 2)))

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

;; Modify and store some atoms.
;; These atoms are in COW spaces, and thus, in order for the store
;; to work correctly, we must store the COW atom, returned by the
;; value setter.  This is unintuitive to the casual user!
(define (store-stuff N)
	(define x (Concept "foo"))
	(define x1 (cog-set-value! x (Predicate "gee") (FloatValue 1 0 N)))
	(store-atom x1)

	(define y (Concept "bar"))
	(define y1 (cog-set-value! y (Predicate "gosh") (FloatValue 1 0 (+ 1 N))))
	(store-atom y1)

	(define z (List x y))
	(define z1 (cog-set-value! z (Predicate "bang") (FloatValue 1 0 (+ 2 N))))
	(store-atom z1)

	(define w (List z x))
	(define w1 (cog-set-value! w (Predicate "bash") (FloatValue 1 0 (+ 3 N))))
	(store-atom w1)
)

; Recursive calls to above
(define (recompute N NLOOP)
	(when (< 0 NLOOP)
		(store-stuff N)
		(cog-set-atomspace! (AtomSpace (cog-atomspace)))
		(cog-delete-recursive! (Concept "bar"))
		(cog-extract-recursive! (Concept "bar"))
		(cog-set-atomspace! (AtomSpace (cog-atomspace)))
		(recompute (+ N 3) (- NLOOP 1)))
)

(define (progressive-store N)

	; The base space is the current space.
	(define base-space (cog-atomspace))

	; Open storage immediately.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-progressive-test"))
	(cog-open storage)

	; We plan to store multiple atomspaces.
	; Let this be stated in advance.
	(cog-atomspace-cow! #t)
	(store-frames base-space)

	; Repeatedly add and remove the same atom
	(recompute 1 N)

	(cog-close storage)
)

; Verify expected contents
(define (progressive-check N)

	; In the top space, foo should be present, but bar and link absent.
	(define x (cog-node 'Concept "foo"))
	(define y (cog-node 'Concept "bar"))
	(test-assert "foo-present" (cog-atom? x))
	(test-assert "bar-absent" (not (cog-atom? y)))

	(test-equal "foo-tv" (+ (* 3 N) 1) (get-val x "gee"))

	(define z (cog-link 'List (Concept "foo") (Concept "bar")))
	(test-assert "link-absent" (not (cog-atom? z)))

	(define w (cog-link 'List (Link (Concept "foo") (Concept "bar"))
                             (Concept "foo")))
	(test-assert "l2-absent" (not (cog-atom? w)))

	; Next one down should have all three atoms
	(define downli (cog-atomspace-env))
	(test-equal "num-childs" 1 (length downli))
	(cog-set-atomspace! (car downli))

	(define x2 (cog-node 'Concept "foo"))
	(define y2 (cog-node 'Concept "bar"))
	(test-equal "foo-as-before" x x2)
	(test-assert "bar-present" (cog-atom? y2))
	(test-equal "bar-tv" (+ (* 3 N) 2) (get-val y2 "gosh"))

	(define z2 (cog-link 'List x2 y2))
	(test-assert "link-present" (cog-atom? z2))
	(test-equal "link-tv" (+ (* 3 N) 3) (get-val z2 "bang"))

	(define w2 (cog-link 'List z2 x2))
	(test-assert "l2-present" (cog-atom? w2))
	(test-equal "l2-tv" (+ (* 3 N) 4) (get-val w2 "bash"))

	; Recurse downwards
	(define downext (cog-atomspace-env))
	(when (equal? 1 (length downext))
		(cog-set-atomspace! (car downext))
		(progressive-check (- N 1)))
)

; ===================================================================

; Test that progressive changes work correctly.
(define (test-progressive)

	; Number of AtomSpaces to create.
	; Currently limited by the excessively verbose frame-storage
	; format, which eats way too much disk space for deep stacks.
	(define STACK-DEPTH 500)

	; Write a bunch of atoms
	(progressive-store STACK-DEPTH)

	; Set a brand new current space
	(define new-base (AtomSpace))
	(cog-set-atomspace! new-base)

	; (cog-rocks-open "rocks:///tmp/cog-rocks-frame-progressive-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-progressive-test"))
	(cog-open storage)

	; Load all of the AtomSpace Frames.
	(define top-space (car (load-frames)))

	; Load all atoms in all frames
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	; Check the rest of them, recursing downwards.
	(progressive-check (- STACK-DEPTH 1))
)

(define progressive-work "test progressive work")
(test-begin progressive-work)
(test-progressive)
(test-end progressive-work)
(force-output (current-output-port))

; ===================================================================
(whack "/tmp/cog-rocks-frame-progressive-test")
(opencog-test-end)
