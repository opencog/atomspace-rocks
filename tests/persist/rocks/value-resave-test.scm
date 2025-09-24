;
; value-resave-test.scm
; Store, delete and then store again a value.
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

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames (cog-atomspace))

	; Splatter some atoms into the various spaces.
	(Concept "foo" (ctv 1 0 3))
	(Concept "bar" (ctv 1 0 4))

	(define base-space (cog-atomspace))
	(define mid1-space (cog-new-atomspace base-space))

	(cog-set-atomspace! mid1-space)
	(List (Concept "foo") (Concept "bar") (ctv 1 0 5))
	(store-atom (ListLink (Concept "foo") (Concept "bar")))

	(define mid2-space (cog-new-atomspace mid1-space))
	(cog-set-atomspace! mid2-space)

	; Delete it (which writes to DB),
	; but then restore it (which writes again).
	(cog-delete-recursive! (Concept "foo"))
	(Concept "foo" (ctv 1 0 6))
	(store-atom (Concept "foo"))

	(define mid3-space (cog-new-atomspace mid2-space))
	(cog-set-atomspace! mid3-space)
	(List (Concept "foo") (Concept "bar") (ctv 1 0 7))
	(store-atom (ListLink (Concept "foo") (Concept "bar")))

	(define surface-space (cog-new-atomspace mid3-space))
	(cog-set-atomspace! surface-space)
	(store-frames surface-space)

	(cog-close storage)

	; Clear out the spaces, start with a clean slate.
	(cog-atomspace-clear surface-space)
	(cog-atomspace-clear mid3-space)
	(cog-atomspace-clear mid2-space)
	(cog-atomspace-clear mid1-space)
	(cog-atomspace-clear base-space)
)

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; -------------------------------------------------------------------
; Test that deep links are found correctly.

(define (test-resave-value)
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
	(cog-set-atomspace! top-space)
	(define lilly (ListLink (Concept "foo") (Concept "bar")))

	; Verify appropriate atomspace membership
	(test-equal "link-space" mid3-space (cog-atomspace lilly))
	(test-equal "foo-space" mid2-space (cog-atomspace (gar lilly)))
	(test-equal "bar-space" base-space (cog-atomspace (gdr lilly)))

	; Verify appropriate values
	(test-equal "link-top-tv" 7 (get-cnt lilly))
	(test-equal "foo-top-tv" 6 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "bar-tv" #f (cog-tv (cog-node 'Concept "bar")))

	; ----------------------------------
	(cog-set-atomspace! mid2-space)
	(test-assert "no-link-2" (nil?
		(cog-link 'List (Concept "foo") (Concept "bar"))))
	(test-equal "foo2-space" mid2-space (cog-atomspace (cog-node 'Concept "foo")))
	(test-equal "bar2-space" base-space (cog-atomspace (cog-node 'Concept "bar")))

	(test-equal "foo2-tv" 6 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "bar-tv" #f (cog-tv (cog-node 'Concept "bar")))

	; ----------------------------------
	(cog-set-atomspace! mid1-space)
	(test-equal "foo1-space" base-space (cog-atomspace (cog-node 'Concept "foo")))
	(test-equal "bar1-space" base-space (cog-atomspace (cog-node 'Concept "bar")))
	(test-equal "link1-space" mid1-space
		(cog-atomspace (cog-link 'List (Concept "foo") (Concept "bar"))))

	(test-equal "foo1-tv" #f (cog-tv (cog-node 'Concept "foo")))
	(test-equal "bar-tv" #f (cog-tv (cog-node 'Concept "bar")))
	(test-equal "link-1-tv" 5
		(get-cnt (cog-link 'List (Concept "foo") (Concept "bar"))))

)

(define resave-value "test resave links")
(test-begin resave-value)
(test-resave-value)
(test-end resave-value)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
