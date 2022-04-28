;
; frame-progressive-test.scm
;
; Verify that frames can be constructed and saved progressively,
; including proper atom deletion durig the progress.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-unit-test")

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))
(define (get-val ATOM NAME) (inexact->exact
	(cog-value-ref (cog-value ATOM (Predicate NAME)) 2)))

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

;; Modify and store some atoms.
(define (store-stuff N)
	(define x (Concept "foo"))
	(cog-set-value! x (Predicate "gee") (ctv 1 0 N))
	(store-atom x)

	(define y (Concept "bar"))
	(cog-set-value! y (Predicate "gosh") (ctv 1 0 (+ 1 N)))
	(store-atom y)

	(define z (List x y))
	(cog-set-value! z (Predicate "bang") (ctv 1 0 (+ 2 N)))
	(store-atom z)
)

; Recursive calls to above
(define (recompute N NLOOP)
	(when (< 0 NLOOP)
(format #t "duude space with stuff=~A\n" (cog-name (cog-atomspace)))
		(store-stuff N)
		(cog-set-atomspace! (cog-new-atomspace (cog-atomspace)))
(format #t "duude space w/o stuff=~A\n" (cog-name (cog-atomspace)))
		(cog-delete-recursive! (Concept "bar"))
		(cog-set-atomspace! (cog-new-atomspace (cog-atomspace)))
		(recompute (+ N 3) (- NLOOP 1)))
)

(define (progressive-store N)

	; The base space is the current space.
	(define base-space (cog-atomspace))

	; Open storage immediately.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; We plan to store multiple atomspaces.
	; Let this be stated in advance.
	(store-frames base-space)

	; Repeatedly add and remove the same atom
	(recompute 1 N)

	(cog-close storage)
)

; Verify expected contents
(define (progressive-check N)

(format #t "duuude start aaspace=~A uu=~A\n" (cog-name (cog-atomspace)) (cog-atomspace-uuid))

	; In the top space, foo should be present, but bar and link absent.
	(define x (cog-node 'Concept "foo"))
	(define y (cog-node 'Concept "bar"))
	(test-assert "foo-present" (cog-atom? x))
	(test-assert "bar-absent" (not (cog-atom? y)))

(format #t "duuude foo=~A ex=~A\n" (get-val x "gee") (* 3 N))
	(test-equal "foo-tv" (+ (* 3 N) 1) (get-val x "gee"))

	(define z (cog-link 'List (Concept "foo") (Concept "bar")))
	(test-assert "link-absent" (not (cog-atom? z)))

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
	(define STACK-DEPTH 2)

	; Write a bunch of atoms
	(progressive-store STACK-DEPTH)

	; Set a brand new current space
	(define new-base (cog-new-atomspace))
	(cog-set-atomspace! new-base)

	(cog-rocks-open "rocks:///tmp/cog-rocks-unit-test")
	(cog-rocks-stats)
	(cog-rocks-get "")
	(cog-rocks-close)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Load all of the AtomSpace Frames.
	(define top-space (load-frames))

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

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
