;
; promote-test.scm
; Verify that plain stores can be upgraded to frame stores.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))
(use-modules (opencog persist-mono))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-unit-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

(define (setup-and-store)

	; Splatter some atoms into the atomspace.
	(Concept "foo" (ctv 1 0 3))
	(Concept "bar" (ctv 1 0 4))
	(ListLink (Concept "bar") (ctv 1 0 5))
	(ListLink (Concept "foo") (List (Concept "bar")) (ctv 1 0 6))

	; Store the content. Store only the top-most link.
	(define mstorage (MonoStorageNode "monospace:///tmp/cog-rocks-unit-test"))
	(cog-open mstorage)
	(store-atom (Concept "foo"))
	(store-atom (Concept "bar"))
	(store-atom (ListLink (Concept "foo") (List (Concept "bar"))))
	(cog-close mstorage)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames (cog-atomspace))
	(cog-set-atomspace! (cog-new-atomspace (cog-atomspace)))
	(store-atom (Concept "foo" (ctv 1 0 7)))
	(store-atom (Concept "bar"))
	(store-atom (ListLink (Concept "foo") (List (Concept "bar")) (ctv 1 0 8)))
	(cog-close storage)

	; Clear out the space, start with a clean slate.
	(cog-atomspace-clear (cog-atomspace))
)

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; -------------------------------------------------------------------
; Test that only the top link was stored.

(define (test-promotion)
	(setup-and-store)

	; Start with a blank slate.
	(cog-atomspace-clear (cog-atomspace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	; (cog-rocks-stats storage)
	; (cog-rocks-print storage "")
	(define top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	(cog-set-atomspace! top-space)

	; Verify the ListLink is as expected.
	(define lilly (ListLink (Concept "foo") (List (Concept "bar"))))

	; Verify appropriate values
	(test-equal "link-tv" 8 (get-cnt lilly))
	(test-equal "foo-tv" 7 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "bar-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "link-bar-tv" 0 (get-cnt (cog-link 'List (Concept "bar"))))

	; drop down one
	(cog-set-atomspace! (gar top-space))

	(test-equal "link-tv" 6 (get-cnt
		(cog-link 'List (Concept "foo") (List (Concept "bar")))))
	(test-equal "foo-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "bar-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "link-bar-tv" 0 (get-cnt (cog-link 'List (Concept "bar"))))

)

(define promotion "test promotion")
(test-begin promotion)
(test-promotion)
(test-end promotion)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
