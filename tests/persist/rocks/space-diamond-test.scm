;
; space-diamond-test.scm
; Test diamond-shaped inheritance patterns for multiple atomspaces.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-unit-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

(define (setup-and-store)
	(define base-space (cog-atomspace))
	(define left-space (cog-new-atomspace base-space))
	(define right-space (cog-new-atomspace base-space))
	(define top-space (cog-new-atomspace (list left-space right-space)))

	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! base-space)
	(Concept "foo" (ctv 1 0 3))

	; Put different variants of the same atom in two parallel spaces
	(cog-set-atomspace! left-space)
	(Concept "bar" (ctv 1 0 4))

	(cog-set-atomspace! right-space)
	(Concept "bar" (ctv 1 0 6))

	(cog-set-atomspace! top-space)
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 8))

	; Store the content. Store the Concepts as well as the link,
	; as otherwise, the TV's on the Concepts aren't stored.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-atom (ListLink (Concept "foo") (Concept "bar")))
	(store-atom (Concept "foo"))

	; Store the two variants, with the explict spaces in which
	; they come from.
	(cog-set-atomspace! left-space)
	(store-atom (Concept "bar"))
	(cog-set-atomspace! right-space)
	(store-atom (Concept "bar"))
	(cog-close storage)
)

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; -------------------------------------------------------------------
; Test ability to restor the above.

(define (test-diamond)
	(setup-and-store)

	(define new-base (cog-new-atomspace))
	(cog-set-atomspace! new-base)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Load all of the AtomSpaces.
	(define top-space (load-frames))
	(cog-set-atomspace! top-space)

	; Now load the AtomSpace itself
	(load-atomspace)
	(cog-close storage)

	; Verify that a diamond pattern was created.
	(define left-space (cog-outgoing-atom top-space 0))
	(define right-space (cog-outgoing-atom top-space 1))
	(define left-bottom (cog-outgoing-atom left-space 0))
	(define right-bottom (cog-outgoing-atom right-space 0))
	(test-equal "base-equal" left-bottom right-bottom)
	(test-equal "base-equal" left-bottom new-base)

	; Work on the current surface, but expect to find the deeper ListLink.
	(define lilly (ListLink (Concept "foo") (Concept "bar")))

	; Verify appropriate atomspace membership
	(test-equal "top-space" top-space (cog-atomspace lilly))
	(test-equal "foo-space" new-base (cog-atomspace (gar lilly)))
	(test-equal "bar-space" left-space (cog-atomspace (gdr lilly)))

	; Verify appropriate values
	(test-equal "base-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "mid1-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "mid2-tv" 8 (get-cnt lilly))
)

(define diamond "test diamond pattern")
(test-begin diamond)
(test-diamond)
(test-end diamond)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
