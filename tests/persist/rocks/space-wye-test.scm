;
; space-wye-test.scm
; Test wye-shaped inheritance patterns for multiple atomspaces.
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
	(define left-space (cog-atomspace))
	(define right-space (cog-new-atomspace))
	(define top-space (cog-new-atomspace (list left-space right-space)))

	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! left-space)
	(Concept "foo" (ctv 1 0 3))

	; Put different variants of the same atom in two parallel spaces
	(cog-set-atomspace! right-space)
	(Concept "bar" (ctv 1 0 4))

	(cog-set-atomspace! top-space)
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 8))

	; Store the content. Store the Concepts as well as the link,
	; as otherwise, the TV's on the Concepts aren't stored.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames top-space)
	(store-atom (ListLink (Concept "foo") (Concept "bar")))
	(store-atom (Concept "foo"))
	(store-atom (Concept "bar"))
	(cog-close storage)
)

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; -------------------------------------------------------------------
; Test ability to restore the above.

(define (test-wye)
	(setup-and-store)

	; (cog-rocks-open "rocks:///tmp/cog-rocks-unit-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	(define new-base (cog-new-atomspace))
	(cog-set-atomspace! new-base)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Load all of the AtomSpaces.
	(define top-space (car (load-frames)))
	(cog-set-atomspace! top-space)

	; Now load the AtomSpace itself
	(load-atomspace)
	(cog-close storage)

	; Verify that a wye pattern was created.
	(define left-space (cog-outgoing-atom top-space 0))
	(define right-space (cog-outgoing-atom top-space 1))
	(test-assert "wye-unequal" (not (equal? left-space right-space)))
	(test-assert "wye-uuid" (not (equal?
		(cog-atomspace-uuid left-space)
		(cog-atomspace-uuid right-space))))

	; Work on the current surface, but expect to find the deeper ListLink.
	(define lilly (ListLink (Concept "foo") (Concept "bar")))

	; Verify appropriate atomspace membership
	(test-equal "top-space" top-space (cog-atomspace lilly))
	(test-equal "foo-space" left-space (cog-atomspace (gar lilly)))
	(test-equal "bar-space" right-space (cog-atomspace (gdr lilly)))

	; Verify appropriate values
	(test-equal "base-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "mid1-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "mid2-tv" 8 (get-cnt lilly))
)

(define wye "test wye pattern")
(test-begin wye)
(test-wye)
(test-end wye)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
