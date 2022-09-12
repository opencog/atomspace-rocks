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
	; (load-atomspace)
	(cog-close storage)
)

(define deep-extract "test deep extract")
(test-begin deep-extract)
(test-deep cog-extract!)
(test-end deep-extract)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
