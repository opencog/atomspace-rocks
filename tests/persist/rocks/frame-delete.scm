;
; frame-delete.scm
;
; Verify that deleted atoms will cover underlying atoms in nested
; atomspaces. Variant of the `cover-delete-test.scm` from the atomspace
; repo, modified to test storage.
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

(define (setup-and-store)
	(define base-space (cog-atomspace))
	(define mid1-space (cog-new-atomspace base-space))
	(define mid2-space (cog-new-atomspace mid1-space))
	(define mid3-space (cog-new-atomspace mid2-space))
	(define surface-space (cog-new-atomspace mid3-space))

	; Repeatedly add and remove the same atom
	(cog-set-atomspace! base-space)
	(Concept "foo" (ctv 1 0 3))

	(cog-set-atomspace! mid1-space)
	(cog-extract! (Concept "foo"))

	(cog-set-atomspace! mid2-space)
	(Concept "foo" (ctv 1 0 5))

	(cog-set-atomspace! mid3-space)
	(cog-extract! (Concept "foo"))

	(cog-set-atomspace! surface-space)
	(Concept "foo" (ctv 1 0 7))

	; Store the content. Store the Concepts as well as the link,
	; as otherwise, the TV's on the Concepts aren't stored.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames surface-space)
	(cog-set-atomspace! base-space)
	(store-atomspace)
	(cog-set-atomspace! mid1-space)
	(store-atomspace)
	(cog-set-atomspace! mid2-space)
	(store-atomspace)
	(cog-set-atomspace! mid3-space)
	(store-atomspace)
	(cog-set-atomspace! surface-space)
	(store-atomspace)
	(cog-close storage)
)

; ===================================================================

; Test that deep deletions work correctly.
(define (test-deep-delete)

	(setup-and-store)
	(define new-base (cog-new-atomspace))
	(cog-set-atomspace! new-base)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Load all of the AtomSpaces.
	(define top-space (load-frames))

	; Now load the AtomSpace itself
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-set-atomspace! base-space)
	(load-atomspace)
	(cog-set-atomspace! mid1-space)
	(load-atomspace)
	(cog-set-atomspace! mid3-space)
	(load-atomspace)
	(cog-set-atomspace! mid2-space)
	(load-atomspace)

	(cog-close storage)

	; Restore the inheritance hierarchy
	(define surface-space top-space)
	(define mid3-space (cog-outgoing-atom surface-space 0))
	(define mid2-space (cog-outgoing-atom mid3-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	(test-equal "base-check" base-space new-base)

	; Should be present in the base space.
	(cog-set-atomspace! base-space)
	(test-assert "base-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "base-tv" 3 (get-cnt (cog-node 'Concept "foo")))

	; Should be absent in the next level.
	(cog-set-atomspace! mid1-space)
	(test-assert "mid1-space" (nil? (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid2-space)
	(test-assert "mid2-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "mid2-tv" 5 (get-cnt (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid3-space)
	(test-assert "mid3-space" (nil? (cog-node 'Concept "foo")))

	(cog-set-atomspace! surface-space)
	(test-assert "surface-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "surface-tv" 7 (get-cnt (cog-node 'Concept "foo")))
)

(define deep-delete "test deep delete")
(test-begin deep-delete)
(test-deep-delete)
(test-end deep-delete)

(whack "/tmp/cog-rocks-unit-test")
#! ========
; ===================================================================
; Building on the above, verify that values work

(define deep-change "test deep change-delete")
(test-begin deep-change)

; Repeatedly add and remove the same atom
(cog-set-atomspace! base-space)
(cog-set-tv! (Concept "foo") (ctv 1 0 2))

(cog-set-atomspace! mid2-space)
(cog-set-tv! (Concept "foo") (ctv 1 0 4))

(cog-set-atomspace! surface-space)
(cog-set-tv! (Concept "foo") (ctv 1 0 6))

; -----------------------------------
; Should be present in the base space.
(cog-set-atomspace! base-space)
(test-assert "base-space" (cog-atom? (cog-node 'Concept "foo")))
(test-equal "base-tv" 2 (inexact->exact (cog-count (cog-node 'Concept "foo"))))

; Should be absent in the next level.
(cog-set-atomspace! mid1-space)
(test-assert "mid1-space" (nil? (cog-node 'Concept "foo")))

(cog-set-atomspace! mid2-space)
(test-assert "mid2-space" (cog-atom? (cog-node 'Concept "foo")))
(test-equal "mid2-tv" 4 (inexact->exact (cog-count (cog-node 'Concept "foo"))))

(cog-set-atomspace! mid3-space)
(test-assert "mid3-space" (nil? (cog-node 'Concept "foo")))

(cog-set-atomspace! surface-space)
(test-assert "surface-space" (cog-atom? (cog-node 'Concept "foo")))
(test-equal "surface-tv" 6 (inexact->exact (cog-count (cog-node 'Concept "foo"))))

(test-end deep-change)

; ===================================================================
; Test that deep link deletions work correctly.

(define deep-link-delete "test deep link-delete")
(test-begin deep-link-delete)

; Repeatedly add and remove the same atom
(cog-set-atomspace! base-space)
(Concept "bar")
(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 10))

(cog-set-atomspace! mid1-space)
(cog-extract-recursive! (Concept "foo"))

(cog-set-atomspace! mid2-space)
(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 20))

(cog-set-atomspace! mid3-space)
(cog-extract-recursive! (Concept "foo"))

(cog-set-atomspace! surface-space)
(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 30))

; -----------------------------------
; Should be present in the base space.
(cog-set-atomspace! base-space)
(test-assert "base-space" (cog-atom? (cog-node 'Concept "foo")))
(test-equal "base-tv" 2 (inexact->exact (cog-count (Concept "foo"))))
(test-equal "base-litv" 10 (inexact->exact (cog-count
    (ListLink (Concept "foo") (Concept "bar")))))

; Should be absent in the next level.
(cog-set-atomspace! mid1-space)
(test-assert "mid1-space" (nil? (cog-node 'Concept "foo")))

(cog-set-atomspace! mid2-space)
(test-assert "mid2-space" (cog-atom? (cog-node 'Concept "foo")))
(test-equal "mid2-tv" 4 (inexact->exact (cog-count (Concept "foo"))))
(test-equal "mid2-litv" 20 (inexact->exact (cog-count
    (ListLink (Concept "foo") (Concept "bar")))))

(cog-set-atomspace! mid3-space)
(test-assert "mid3-space" (nil? (cog-node 'Concept "foo")))

(cog-set-atomspace! surface-space)
(test-assert "surface-space" (cog-atom? (cog-node 'Concept "foo")))
(test-equal "surface-tv" 6 (inexact->exact (cog-count (Concept "foo"))))
(test-equal "surface-litv" 30 (inexact->exact (cog-count
    (ListLink (Concept "foo") (Concept "bar")))))

(test-end deep-link-delete)
=== !#

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
