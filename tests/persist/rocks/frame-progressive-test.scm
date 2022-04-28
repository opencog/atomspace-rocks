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
		(store-stuff N)
		(cog-set-atomspace! (cog-new-atomspace (cog-atomspace)))
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

	; Repeatedly add and remove the same atom
	(recompute 1 N)

	(cog-close storage)
)

; Verify expected contents
(define (progressive-check N)

(format #t "duuude start aaspace=~A uu=~A\n" (cog-name (cog-atomspace)) (cog-atomspace-uuid))
	(define x (cog-node 'Concept "foo"))
	(define y (cog-node 'Concept "bar"))
	(test-assert "foo-present" (cog-atom? x))
	(test-assert "bar-present" (cog-atom? y))

	(define M (- N 1))
(format #t "duuude foo=~A ex=~A\n" (get-val x "gee") (* 3 M))
	(test-equal "foo-tv" (+ (* 3 M) 1) (get-val x "gee"))
	(test-equal "bar-tv" (+ (* 3 M) 2) (get-val y "gosh"))

	(define z (cog-link 'List x y))
	(test-assert "link-present" (cog-atom? z))
	(test-equal "link-tv" (+ (* 3 M) 3) (get-val z "bang"))

	; Next one down shuld be missing atoms.
	(define downli (cog-atomspace-env))
	(test-equal "num-childs" 1 (length downli))
	(cog-set-atomspace! (car downli))
	(define y2 (cog-node 'Concept "bar"))
	(test-assert "bar-absent" (nil? y2))

	(define z2 (cog-link 'List (Concept "foo") (Concept "bar")))
	(test-assert "link-absent" (nil? z2))

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

	; (cog-rocks-open "rocks:///tmp/cog-rocks-unit-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Load all of the AtomSpace Frames.
	(define top-space (load-frames))

	; Load all atoms in all frames
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	(progressive-check STACK-DEPTH)
)

(define progressive-work "test progressive work")
(test-begin progressive-work)
(test-progressive)
(test-end progressive-work)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
