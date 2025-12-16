#! /usr/bin/env guile
-s
!#
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
(whack "/tmp/cog-rocks-frame-delete-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

(define (setup-and-store DELETE)

	; The base space is the current space.
	; (define base-space (cog-atomspace))
	(define base-space (AtomSpace "base space"))
	(define mid1-space (AtomSpace "mid-1" base-space))
	(define mid2-space (AtomSpace "mid-2" mid1-space))
	(define mid3-space (AtomSpace "mid-3" mid2-space))
	(define surface-space (AtomSpace "surf" mid3-space))

	; (format #t "setup space top ~A\n" (cog-name surface-space))
	; (format #t "setup space mid ~A\n" (cog-name mid3-space))
	; (format #t "setup space mid ~A\n" (cog-name mid2-space))
	; (format #t "setup space mid ~A\n" (cog-name mid1-space))
	; (format #t "setup space base ~A\n" (cog-name base-space))

	(cog-set-atomspace! surface-space)
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-delete-test"))
	(cog-open storage)
	(store-frames surface-space)

	; Repeatedly add and remove the same atom
	(cog-set-atomspace! base-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 3))

	(cog-set-atomspace! mid1-space)
	(DELETE (Concept "foo"))

	(cog-set-atomspace! mid2-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 5))

	(cog-set-atomspace! mid3-space)
	(DELETE (Concept "foo"))

	(cog-set-atomspace! surface-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 7))

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
	(cog-set-atomspace! (AtomSpace))

	(setup-and-store DELETE)

	; (cog-rocks-open "rocks:///tmp/cog-rocks-frame-delete-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-delete-test"))
	(cog-open storage)

	; Load all of the AtomSpace Frames.
	; There are two frames at the top, and we want the newer one.
	; The second one is the root space; it doesn't have the stack.
	; This is awkward. I don't entirely like it. For now, it works.
	(define the-frames (load-frames))
	; (format #t "The frames are ~A\n" the-frames)
	(define top-space (car the-frames))

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
	(test-assert "mid1-absent" (not (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid2-space)
	(test-assert "mid2-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "mid2-tv" 5 (get-cnt (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid3-space)
	(test-assert "mid3-absent" (not (cog-node 'Concept "foo")))

	(cog-set-atomspace! surface-space)
	(test-assert "surface-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "surface-tv" 7 (get-cnt (cog-node 'Concept "foo")))
)

(define deep-extract "test deep extract")
(test-begin deep-extract)
(test-deep cog-extract!)
(test-end deep-extract)

(whack "/tmp/cog-rocks-frame-delete-test")

(define deep-delete "test deep delete")
(test-begin deep-delete)
(test-deep (lambda (x) (cog-delete! x) (cog-extract! x)))
(test-end deep-delete)

(whack "/tmp/cog-rocks-frame-delete-test")

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
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-delete-test"))
	(cog-open storage)

	; Repeatedly add and remove the same atom
	(cog-set-atomspace! base-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 2))

	(cog-set-atomspace! mid2-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 4))

	(cog-set-atomspace! surface-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 6))

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
	(cog-set-atomspace! (AtomSpace))

	(setup-deep-change DELETE)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-delete-test"))
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
	(test-assert "mid1-space" (not (cog-node 'Concept "foo")))

	; Test remaining levels.
	(cog-set-atomspace! mid2-space)
	(test-assert "mid2-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "mid2-tv" 4 (get-cnt (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid3-space)
	(test-assert "mid3-space" (not (cog-node 'Concept "foo")))

	(cog-set-atomspace! surface-space)
	(test-assert "surface-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "surface-tv" 6 (get-cnt (cog-node 'Concept "foo")))
)

(define deep-change-extract "test deep change-extract")
(test-begin deep-change-extract)
(test-deep-change cog-extract!)
(test-end deep-change-extract)

(whack "/tmp/cog-rocks-frame-delete-test")

(define deep-change-delete "test deep change-delete")
(test-begin deep-change-delete)
(test-deep-change (lambda (x) (cog-delete! x) (cog-extract! x)))
(test-end deep-change-delete)

(whack "/tmp/cog-rocks-frame-delete-test")
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
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-delete-test"))
	(cog-open storage)
	(store-frames surface-space)

	; Repeatedly add and remove the same atom
	(cog-set-atomspace! base-space)
	(Concept "bar")
	(set-cnt! (ListLink (Concept "foo") (Concept "bar")) (FloatValue 1 0 10))

	(cog-set-atomspace! mid1-space)
	(DELETE-REC (Concept "foo"))

	(cog-set-atomspace! mid2-space)
	(set-cnt! (ListLink (Concept "foo") (Concept "bar")) (FloatValue 1 0 20))

	(cog-set-atomspace! mid3-space)
	(DELETE-REC (Concept "foo"))

	(cog-set-atomspace! surface-space)
	(set-cnt! (ListLink (Concept "foo") (Concept "bar")) (FloatValue 1 0 30))

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
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-delete-test"))
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
	(test-assert "mid1-space" (not (cog-node 'Concept "foo")))

	(cog-set-atomspace! mid2-space)
	(test-assert "mid2-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "mid2-tv" 4 (get-cnt (Concept "foo")))
	(test-equal "mid2-litv" 20 (get-cnt
		(ListLink (Concept "foo") (Concept "bar"))))

	(cog-set-atomspace! mid3-space)
	(test-assert "mid3-space" (not (cog-node 'Concept "foo")))

	(cog-set-atomspace! surface-space)
	(test-assert "surface-space" (cog-atom? (cog-node 'Concept "foo")))
	(test-equal "surface-tv" 6 (get-cnt (Concept "foo")))
	(test-equal "surface-litv" 30 (get-cnt
		(ListLink (Concept "foo") (Concept "bar"))))
)

(whack "/tmp/cog-rocks-frame-delete-test")
(define deep-link-extract "test deep link-extract")
(test-begin deep-link-extract)
(test-deep-link cog-extract-recursive!)
(test-end deep-link-extract)

(whack "/tmp/cog-rocks-frame-delete-test")
(define deep-link-delete "test deep link-delete")
(test-begin deep-link-delete)
(test-deep-link (lambda (x) (cog-delete-recursive! x) (cog-extract-recursive! x)))
(test-end deep-link-delete)

; ===================================================================
(whack "/tmp/cog-rocks-frame-delete-test")
(opencog-test-end)
