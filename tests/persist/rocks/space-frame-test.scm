;
; space-frame-test.scm
; Test ability to store and retreive multiple atomspaces.
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
	(define surface-space (cog-new-atomspace mid2-space))

	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! base-space)
	(Concept "foo" (ctv 1 0 3))

	(cog-set-atomspace! mid1-space)
	(Concept "bar" (ctv 1 0 4))

	(cog-set-atomspace! mid2-space)
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 5))

	(cog-set-atomspace! surface-space)

	; Store the content. Store the Concepts as well as the link,
	; as otherwise, the TV's on the Concepts aren't stored.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames surface-space)
	(store-atom (ListLink (Concept "foo") (Concept "bar")))
	(store-atom (Concept "foo"))
	(store-atom (Concept "bar"))
	(cog-close storage)

	; Clear out the spaces, start with a clean slate.
	(cog-atomspace-clear surface-space)
	(cog-atomspace-clear mid2-space)
	(cog-atomspace-clear mid1-space)
	(cog-atomspace-clear base-space)
)

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; -------------------------------------------------------------------
; Test that deep links are found correctly.

(define (test-deep-link)
	(setup-and-store)

	; (cog-rocks-open "rocks:///tmp/cog-rocks-unit-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	; Start with a blank slate.
	(cog-set-atomspace! (cog-new-atomspace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(define top-space (load-frames))
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	; Grab references into the inheritance hierarchy
	(define surface-space top-space)
	(define mid2-space (cog-outgoing-atom surface-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	; Verify the ListLink is as expected.
	(cog-set-atomspace! mid2-space)
	(define lilly (ListLink (Concept "foo") (Concept "bar")))

	; Verify appropriate atomspace membership
	(test-equal "link-space" mid2-space (cog-atomspace lilly))
	(test-equal "foo-space" base-space (cog-atomspace (gar lilly)))
	(test-equal "bar-space" mid1-space (cog-atomspace (gdr lilly)))

	; Verify appropriate values
	(test-equal "base-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "mid1-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "mid2-tv" 5 (get-cnt lilly))
)

(define deep-link "test deep links")
(test-begin deep-link)
(test-deep-link)
(test-end deep-link)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
