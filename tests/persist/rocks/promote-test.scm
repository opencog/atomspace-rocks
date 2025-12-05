#! /usr/bin/env -S guile -s
!#
;
; promote-test.scm
; Verify that plain stores can be upgraded to frame stores.
; Also verify frame deletion (simplest case only)
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))
(use-modules (opencog persist-mono))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-promote-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

(define (setup-and-store)

	; Splatter some atoms into the atomspace.
	(set-cnt! (Concept "foo") (FloatValue 1 0 3))
	(set-cnt! (Concept "bar") (FloatValue 1 0 4))
	(set-cnt! (ListLink (Concept "bar")) (FloatValue 1 0 5))
	(set-cnt! (ListLink (Concept "foo") (List (Concept "bar"))) (FloatValue 1 0 6))

	; Store the content. Store only the top-most link.
	(define mstorage (MonoStorageNode "monospace:///tmp/cog-rocks-promote-test"))
	(cog-open mstorage)
	(store-atom (Concept "foo"))
	(store-atom (Concept "bar"))
	(store-atom (ListLink (Concept "foo") (List (Concept "bar"))))
	(cog-close mstorage)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-promote-test"))
	(cog-open storage)
	(store-frames (cog-atomspace))
	(cog-set-atomspace! (AtomSpace (cog-atomspace)))
	(set-cnt! (Concept "foo") (FloatValue 1 0 7))
	(store-atom (Concept "foo"))
	(store-atom (Concept "bar"))
	(set-cnt! (ListLink (Concept "foo") (List (Concept "bar"))) (FloatValue 1 0 8))
	(store-atom (ListLink (Concept "foo") (List (Concept "bar"))))
	(cog-close storage)

	; Clear out the space, start with a clean slate.
	(cog-atomspace-clear (cog-atomspace))
)

; -------------------------------------------------------------------
; Test that only the top link was stored.

(define (test-promotion)
	(setup-and-store)

	; Start with a blank slate.
	(cog-atomspace-clear (cog-atomspace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-promote-test"))
	(cog-open storage)
	; (cog-rocks-stats storage)
	; (cog-rocks-print storage "")
	(define top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	; Verify the ListLink is as expected.
	(define lilly (ListLink (Concept "foo") (List (Concept "bar"))))

	; Verify appropriate values
	(test-equal "link-tv" 8 (get-cnt lilly))
	(test-equal "foo-tv" 7 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "bar-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "link-bar-tv" #f (cog-value (cog-link 'List (Concept "bar")) pk))

	; drop down one
	(cog-set-atomspace! (gar top-space))

	(test-equal "link-tv" 6 (get-cnt
		(cog-link 'List (Concept "foo") (List (Concept "bar")))))
	(test-equal "foo-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "bar-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "link-bar-tv" #f (cog-value (cog-link 'List (Concept "bar")) pk))
)

(define (kill-top-store)

	; Start with a blank slate.
	(cog-atomspace-clear (cog-atomspace))

	; Load enough to get started.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-promote-test"))
	(cog-open storage)
	; (cog-rocks-stats storage)
	; (cog-rocks-print storage "")
	(define top-space (car (load-frames)))
	(delete-frame! top-space)
	(cog-close storage)
)

; Verify what's left a the bottom
(define (test-remainder)

	; Start with a blank slate.
	(cog-atomspace-clear (cog-atomspace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-promote-test"))
	(cog-open storage)
	; (cog-rocks-stats storage)
	; (cog-rocks-print storage "")
	(define top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	; Verify the ListLink is as expected.
	(define lilly (ListLink (Concept "foo") (List (Concept "bar"))))

	(test-equal "link-tv" 6 (get-cnt lilly))
	(test-equal "foo-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "bar-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "link-bar-tv" #f (cog-value (cog-link 'List (Concept "bar")) pk))
)


(define promotion "test promotion")
(test-begin promotion)
(test-promotion)
(kill-top-store)
(test-remainder)
(test-end promotion)

; ===================================================================
(whack "/tmp/cog-rocks-promote-test")
(opencog-test-end)
