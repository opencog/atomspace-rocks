;
; frame-delete-test.scm
;
; Verify that deleted atoms will cover underlying atoms in nested
; atomspaces. Tests both `cog-extract!` and `cog-delete!` Variant of
; the `cover-delete-test.scm` from the atomspace repo, modified to
; test storage.
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

(define (setup-and-store DELETE)

	; The base space is the current space.
	(define base-space (cog-atomspace))
	(define mid1-space (cog-new-atomspace base-space))
	(define mid2-space (cog-new-atomspace mid1-space))
	(define mid3-space (cog-new-atomspace mid2-space))
	(define surface-space (cog-new-atomspace mid3-space))

	; (format #t "setup space top ~A\n" (cog-name surface-space))
	; (format #t "setup space mid ~A\n" (cog-name mid3-space))
	; (format #t "setup space mid ~A\n" (cog-name mid2-space))
	; (format #t "setup space mid ~A\n" (cog-name mid1-space))
	; (format #t "setup space base ~A\n" (cog-name base-space))

	(cog-set-atomspace! surface-space)
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames surface-space)

	; Repeatedly add and remove the same atom
	(cog-set-atomspace! base-space)
	(Concept "foo" (ctv 1 0 3))

	(cog-set-atomspace! mid1-space)
	(DELETE (Concept "foo"))

	(cog-set-atomspace! mid2-space)
	(Concept "foo" (ctv 1 0 5))

	(cog-set-atomspace! mid3-space)
	(DELETE (Concept "foo"))

	(cog-set-atomspace! surface-space)
	(Concept "foo" (ctv 1 0 7))

	; Store the content. Store the Concepts as well as the link,
	; as otherwise, the TV's on the Concepts aren't stored.
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

	; Return the surface space
	surface-space
)

; ===================================================================

; Test that changes to deep deletions work correctly.
(define (test-deep DELETE)

	; Set a brand new current space
	(cog-set-atomspace! (cog-new-atomspace))

	(setup-and-store DELETE)
#! ============
	; (cog-rocks-open "rocks:///tmp/cog-rocks-unit-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Load all of the AtomSpace Frames.
	(define top-space (car (load-frames)))

	; Load all atoms in all frames
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	; Grab references into the inheritance hierarchy
	(define surface-space top-space)
	(define mid3-space (cog-outgoing-atom surface-space 0))
	(define mid2-space (cog-outgoing-atom mid3-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

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
======= !#
)

(define deep-extract "test deep extract")
(test-begin deep-extract)
(test-deep cog-extract!)
(test-end deep-extract)

#! ===========
(whack "/tmp/cog-rocks-unit-test")

(define deep-delete "test deep delete")
(test-begin deep-delete)
(test-deep cog-delete!)
(test-end deep-delete)

(whack "/tmp/cog-rocks-unit-test")

; ===================================================================
; Building on the above, verify that values work

(define (setup-deep-change DELETE)

	; This uses the spaces built prviously.
	; The previous spaces were built on the current space.
	(define surface-space (setup-and-store DELETE))
	(define mid3-space (cog-outgoing-atom surface-space 0))
	(define mid2-space (cog-outgoing-atom mid3-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	(cog-set-atomspace! surface-space)
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Repeatedly add and remove the same atom
	(cog-set-atomspace! base-space)
	(cog-set-tv! (Concept "foo") (ctv 1 0 2))

	(cog-set-atomspace! mid2-space)
	(cog-set-tv! (Concept "foo") (ctv 1 0 4))

	(cog-set-atomspace! surface-space)
	(cog-set-tv! (Concept "foo") (ctv 1 0 6))

	; Store the changed content. Toggle through all the atomspaces,
	; as otherwise, the TV's on the Concepts aren't stored.
	; Do NOT store frames a second time! This will mess it up.
	; (store-frames surface-space)
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

(define (test-deep-change DELETE)

	; Define a brand new space on which the other
	; atomspaces will be built.
	(cog-set-atomspace! (cog-new-atomspace))

	(setup-deep-change DELETE)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Load all of the AtomSpace Frames.
	(define top-space (car (load-frames)))

	; Load all atoms in all frames
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	; Grab references into the inheritance hierarchy
	(define surface-space top-space)
	(define mid3-space (cog-outgoing-atom surface-space 0))
	(define mid2-space (cog-outgoing-atom mid3-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	; -----------------------------------
	; Should be present in the base space.
	(cog-set-atomspace! base-space)
	(test-assert "base-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "base-tv" 2 (get-cnt (cog-node 'Concept "foo")))

	; Should be absent in the next level.
	(cog-set-atomspace! mid1-space)
	(test-assert "mid1-space" (nil? (cog-node 'Concept "foo")))

	; Test remaining levels.
	(cog-set-atomspace! mid2-space)
	(test-assert "mid2-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "mid2-tv" 4 (get-cnt (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid3-space)
	(test-assert "mid3-space" (nil? (cog-node 'Concept "foo")))

	(cog-set-atomspace! surface-space)
	(test-assert "surface-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "surface-tv" 6 (get-cnt (cog-node 'Concept "foo")))
)

(define deep-change-extract "test deep change-extract")
(test-begin deep-change-extract)
(test-deep-change cog-extract!)
(test-end deep-change-extract)

(whack "/tmp/cog-rocks-unit-test")

(define deep-change-delete "test deep change-delete")
(test-begin deep-change-delete)
(test-deep-change cog-delete!)
(test-end deep-change-delete)

(whack "/tmp/cog-rocks-unit-test")
; ===================================================================
; Test that deep link deletions work correctly.

(define (setup-link-check DELETE-REC)

	; Grab references into the inheritance hierarchy
	(define surface-space (cog-atomspace))
	(define mid3-space (cog-outgoing-atom surface-space 0))
	(define mid2-space (cog-outgoing-atom mid3-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	(cog-set-atomspace! surface-space)
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames surface-space)

	; Repeatedly add and remove the same atom
	(cog-set-atomspace! base-space)
	(Concept "bar")
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 10))

	(cog-set-atomspace! mid1-space)
	(DELETE-REC (Concept "foo"))

	(cog-set-atomspace! mid2-space)
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 20))

	(cog-set-atomspace! mid3-space)
	(DELETE-REC (Concept "foo"))

	(cog-set-atomspace! surface-space)
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 30))

	; Store the changed content. Toggle through all the atomspaces,
	; as otherwise, the TV's on the Atoms aren't stored.
	; Do NOT store frames a second time! This will mess it up.
	; (store-frames surface-space)
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

(define (test-deep-link DELETE-REC)

	; Assume that we start the test with the same
	; top atomspace as before.
	; We are merely making delts to it.
	(setup-link-check DELETE-REC)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Load all of the AtomSpace Frames.
	(define top-space (car (load-frames)))

	; Load all atoms in all frames
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	; Grab references into the inheritance hierarchy
	(define surface-space top-space)
	(define mid3-space (cog-outgoing-atom surface-space 0))
	(define mid2-space (cog-outgoing-atom mid3-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	; -----------------------------------
	; Should be present in the base space.
	(cog-set-atomspace! base-space)
	(test-assert "base-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "base-tv" 2 (get-cnt (Concept "foo")))
	(test-equal "base-litv" 10 (get-cnt
		(ListLink (Concept "foo") (Concept "bar"))))

	; Should be absent in the next level.
	(cog-set-atomspace! mid1-space)
	(test-assert "mid1-space" (nil? (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid2-space)
	(test-assert "mid2-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "mid2-tv" 4 (get-cnt (Concept "foo")))
	(test-equal "mid2-litv" 20 (get-cnt
		(ListLink (Concept "foo") (Concept "bar"))))

	(cog-set-atomspace! mid3-space)
	(test-assert "mid3-space" (nil? (cog-node 'Concept "foo")))

	(cog-set-atomspace! surface-space)
	(test-assert "surface-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "surface-tv" 6 (get-cnt (Concept "foo")))
	(test-equal "surface-litv" 30 (get-cnt
		(ListLink (Concept "foo") (Concept "bar"))))
)

(whack "/tmp/cog-rocks-unit-test")
(define deep-link-extract "test deep link-extract")
(test-begin deep-link-extract)
(test-deep-link cog-extract-recursive!)
(test-end deep-link-extract)

(whack "/tmp/cog-rocks-unit-test")
(define deep-link-delete "test deep link-delete")
(test-begin deep-link-delete)
(test-deep-link cog-delete-recursive!)
(test-end deep-link-delete)

=== !#
; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
