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

	(define z (Link x y))
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

(define (progressive-store)

	; The base space is the current space.
	(define base-space (cog-atomspace))
	; Open storage immediately.

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Repeatedly add and remove the same atom
	(recompute 1 500)

	(cog-close storage)
)

; ===================================================================

; Test that progressive changes work correctly.
(define (test-progressive)

	; Write a bunch of atoms
	(progressive-store)

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

#! =======
	(test-equal "base-check" base-space new-base)

	; Should be present in the base space.
	(cog-set-atomspace! base-space)
	(test-assert "base-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "base-tv" 3 (get-cnt (cog-node 'Concept "foo")))

	; Should be absent in the next level.
	(cog-set-atomspace! mid1-space)
	(test-assert "mid1-absent" (nil? (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid2-space)
	(test-assert "mid2-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "mid2-tv" 5 (get-cnt (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid3-space)
	(test-assert "mid3-absent" (nil? (cog-node 'Concept "foo")))

	(cog-set-atomspace! surface-space)
	(test-assert "surface-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "surface-tv" 7 (get-cnt (cog-node 'Concept "foo")))
=== !#
)

(define progressive-work "test progressive work")
(test-begin progressive-work)
(test-progressive)
(test-end progressive-work)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
