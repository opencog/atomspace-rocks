;
; value-frame-test.scm
; Cross-over of space-frame-test.scm and value-store-test.scm
; Test that only limited values are stored.
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
	(define mid1-space (cog-new-atomspace base-space))
	(define mid2-space (cog-new-atomspace mid1-space))
	(define mid3-space (cog-new-atomspace mid2-space))
	(define surface-space (cog-new-atomspace mid3-space))

	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! base-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 3))

	(cog-set-atomspace! mid1-space)
	(set-cnt! (Concept "bar") (FloatValue 1 0 4))

	(cog-set-atomspace! mid2-space)
	(set-cnt! (List (Concept "bar")) (FloatValue 1 0 5))

	(cog-set-atomspace! mid3-space)
	(set-cnt! (List (Concept "foo") (List (Concept "bar"))) (FloatValue 1 0 6))

	(cog-set-atomspace! surface-space)

	; Store only the top link, nothing else.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames surface-space)
	(store-atom (ListLink (Concept "foo") (List (Concept "bar"))))
	(cog-close storage)

	; Clear out the spaces, start with a clean slate.
	(cog-atomspace-clear surface-space)
	(cog-atomspace-clear mid3-space)
	(cog-atomspace-clear mid2-space)
	(cog-atomspace-clear mid1-space)
	(cog-atomspace-clear base-space)
)

; -------------------------------------------------------------------
; Test that deep links are found correctly.

(define (test-save-value)
	(setup-and-store)

	; Start with a blank slate.
	(cog-set-atomspace! (cog-new-atomspace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(define top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(load-atomspace)
	; (cog-rocks-stats storage)
	; (cog-rocks-print storage "")
	(cog-close storage)

	; Grab references into the inheritance hierarchy
	(define surface-space top-space)
	(define mid3-space (cog-outgoing-atom surface-space 0))
	(define mid2-space (cog-outgoing-atom mid3-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	; Verify the ListLink is as expected.
	(cog-set-atomspace! surface-space)
	(define lilly (ListLink (Concept "foo") (List (Concept "bar"))))

	; Verify appropriate atomspace membership
	(test-equal "link-space" mid3-space (cog-atomspace lilly))
	(test-equal "foo-space" base-space (cog-atomspace (gar lilly)))
	(test-equal "link-bar-space" mid2-space (cog-atomspace (gdr lilly)))
	(test-equal "bar-space" mid1-space (cog-atomspace (gadr lilly)))

	; Verify appropriate values
	(test-equal "base-tv" #f (cog-value (cog-node 'Concept "foo") pk))
	(test-equal "mid1-tv" #f (cog-value (cog-node 'Concept "bar") pk))
	(test-equal "mid2-tv" #f (cog-value (cog-link 'List (Concept "bar")) pk))
	(test-equal "mid3-tv" 6 (get-cnt lilly))
)

(define save-value "test save links")
(test-begin save-value)
(test-save-value)
(test-end save-value)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
