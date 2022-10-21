;
; value-store-test.scm
; Verify that only the top values are stored.
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

	; Splatter some atoms into the atomspace.
	(Concept "foo" (ctv 1 0 3))
	(Concept "bar" (ctv 1 0 4))
	(ListLink (Concept "bar") (ctv 1 0 5))
	(ListLink (Concept "foo") (List (Concept "bar")) (ctv 1 0 6))

	; Store the content. Store only the top-most link.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-atom (ListLink (Concept "foo") (List (Concept "bar"))))
	(cog-close storage)

	; Clear out the space, start with a clean slate.
	(cog-atomspace-clear (cog-atomspace))
)

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; -------------------------------------------------------------------
; Test that only the top link was stored.

(define (test-store-link)
	(setup-and-store)

	; Start with a blank slate.
	(cog-atomspace-clear (cog-atomspace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	; (cog-rocks-stats storage)
	; (cog-rocks-print storage "")
	(load-atomspace)
	(cog-close storage)

	; Verify the ListLink is as expected.
	(define lilly (ListLink (Concept "foo") (List (Concept "bar"))))

	; Verify appropriate values
	(test-equal "link-tv" 6 (get-cnt lilly))
	(test-equal "foo-tv" 0 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "bar-tv" 0 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "link-bar-tv" 0 (get-cnt (cog-link 'List (Concept "bar"))))
)

(define store-link "test store link")
(test-begin store-link)
(test-store-link)
(test-end store-link)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
