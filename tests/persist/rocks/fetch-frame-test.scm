;
; fetch-frame-test.scm
; Test ability of specific fetch methods w/ multiple atomspaces.
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
	(Concept "foo" (ctv 1 0 33))
	(Concept "bar" (ctv 1 0 4))

	(cog-set-atomspace! mid2-space)
	(Concept "foo" (ctv 1 0 333))
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 5))

	(cog-set-atomspace! surface-space)

	; Store the content. Store the Concepts as well as the link,
	; as otherwise, the TV's on the Concepts aren't stored.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames surface-space)
	(store-atom (ListLink (Concept "foo") (Concept "bar")))
	(store-atom (Concept "bar"))
	(store-atom (Concept "foo"))
	(cog-set-atomspace! mid1-space)
	(store-atom (Concept "foo"))
	(cog-set-atomspace! base-space)
	(store-atom (Concept "foo"))

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

(define (test-load-of-type)
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
	(define top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(load-atoms-of-type 'Concept)
	(cog-close storage)

	; Grab references into the inheritance hierarchy
	(define surface-space top-space)
	(define mid2-space (cog-outgoing-atom surface-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	; Create brand new ListLink.
	(cog-set-atomspace! mid2-space)
	(define lilly (ListLink (Concept "foo") (Concept "bar")))

	; Verify appropriate atomspace membership
	(test-equal "link-space" mid2-space (cog-atomspace lilly))
	(test-equal "foo-space" mid2-space (cog-atomspace (gar lilly)))
	(test-equal "bar-space" mid1-space (cog-atomspace (gdr lilly)))

	; Verify appropriate values
	(test-equal "foo-mid2-tv" 333 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "bar-tv" 4 (get-cnt (cog-node 'Concept "bar")))

	(cog-set-atomspace! mid1-space)
	(test-equal "foo-mid1-tv" 33 (get-cnt (cog-node 'Concept "foo")))

	(cog-set-atomspace! base-space)
	(test-equal "foo-base-tv" 3 (get-cnt (cog-node 'Concept "foo")))
)

(define load-of-type "test load-of-type")
(test-begin load-of-type)
(test-load-of-type)
(test-end load-of-type)

(whack "/tmp/cog-rocks-unit-test")

; -------------------------------------------------------------------
; Test that incoming-set fetches work correctly.

(define (test-load-incoming)
	(setup-and-store)

	(cog-rocks-open "rocks:///tmp/cog-rocks-unit-test")
	(cog-rocks-stats)
	(cog-rocks-get "")
	(cog-rocks-close)

	; Start with a blank slate.
	(cog-set-atomspace! (cog-new-atomspace))

	; Load incoming set of just one atom.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(define top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(fetch-incoming-set (Concept "foo"))

	(cog-close storage)

	; Grab references into the inheritance hierarchy
	(define surface-space top-space)
	(define mid2-space (cog-outgoing-atom surface-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

(format #t "duuude space=~A\n" (cog-get-all-roots))

	(define lilly (ListLink (Concept "foo") (Concept "bar")))
(format #t "duuude lully=~A\n" lilly)
	(test-equal "lilly-tv" 5 (get-cnt lilly))
)

(define load-incoming "test load-incoming")
(test-begin load-incoming)
(test-load-incoming)
(test-end load-incoming)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
