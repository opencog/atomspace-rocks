#! /usr/bin/env -S guile -s
!#
;
; space-x-test.scm
; Test x-shaped inheritance patterns for multiple atomspaces.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-space-x-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

(define (setup-and-store)
	(define left-space (AtomSpace "left space"))
	(define right-space (AtomSpace "right space"))
	(define mid-space (AtomSpace "mid space" (list left-space right-space)))
	(define top1-space (AtomSpace "top1" mid-space))
	(define top2-space (AtomSpace "top2" mid-space))

	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! left-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 3))

	; Put different variants of the same atom in two parallel spaces
	(cog-set-atomspace! right-space)
	(set-cnt! (Concept "bar") (FloatValue 1 0 4))

	(cog-set-atomspace! mid-space)
	(set-cnt! (ListLink (Concept "foo") (Concept "bar")) (FloatValue 1 0 8))

	(cog-set-atomspace! top1-space)
	(set-cnt! (Concept "bar") (FloatValue 1 0 5))

	(cog-set-atomspace! top2-space)
	(set-cnt! (Concept "bar") (FloatValue 1 0 6))

	; Store the content. Store the Concepts as well as the link,
	; as otherwise, the TV's on the Concepts aren't stored.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-space-x-test"))
	(cog-open storage)
	(store-frames top1-space)
	(store-frames top2-space)
	(cog-set-atomspace! top1-space)
	(store-atom (Concept "bar"))
	(cog-set-atomspace! top2-space)
	(store-atom (Concept "bar"))
	(store-atom (Concept "foo"))
	(cog-set-atomspace! mid-space)
	(store-atom (ListLink (Concept "foo") (Concept "bar")))
	(store-atom (Concept "bar"))
	(cog-close storage)
)

; -------------------------------------------------------------------
; Test ability to restore the above.

(define (test-exe)
	(setup-and-store)

	; (cog-rocks-open "rocks:///tmp/cog-rocks-space-x-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	(define new-base (AtomSpace))
	(cog-set-atomspace! new-base)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-space-x-test"))
	(cog-open storage)

	; Load all of the Frames.
	(define top-spaces (load-frames))
	; (format #t "The top spaces are ~A\n" top-spaces)
	(define top1-space (first top-spaces))
	(define top2-space (second top-spaces))

	; Load all of the AtomSpaces.
	(cog-set-atomspace! top1-space)
	(load-atomspace)
	(cog-set-atomspace! top2-space)
	(load-atomspace)

	(cog-close storage)

	(test-assert "exe-top-unequal" (not (equal? top1-space top2-space)))

	(define mid1-space (cog-outgoing-atom top1-space 0))
	(define mid2-space (cog-outgoing-atom top2-space 0))
	(test-assert "exe-mid-equal" (equal? mid1-space mid2-space))

	; Verify that an x pattern was created.
	(define left-space (cog-outgoing-atom mid1-space 0))
	(define right-space (cog-outgoing-atom mid2-space 1))
	(test-assert "exe-bot-unequal" (not (equal? left-space right-space)))
	(test-assert "exe-name" (not (equal?
		(cog-name top1-space)
		(cog-name top2-space))))

	(cog-set-atomspace! mid2-space)
	; Work on the current surface, but expect to find the deeper ListLink.
	(define lilly (cog-link 'ListLink (Concept "foo") (Concept "bar")))

	; Verify appropriate atomspace membership
	(test-equal "mid-space" mid1-space (cog-atomspace lilly))
	(test-equal "foo-space" left-space (cog-atomspace (gar lilly)))
	(test-equal "bar-space" right-space (cog-atomspace (gdr lilly)))

	; Verify appropriate values
	(test-equal "left-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "right-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "mid-tv" 8 (get-cnt lilly))

	(cog-set-atomspace! top1-space)
	(test-equal "top1-tv" 5 (get-cnt (cog-node 'Concept "bar")))
	(cog-set-atomspace! top2-space)
	(test-equal "top2-tv" 6 (get-cnt (cog-node 'Concept "bar")))

	; Verify that the shadowed TV's are getting copied.
	(define lill2 (ListLink (Concept "foo") (Concept "bar")))

	(test-equal "top2-link-space" top2-space (cog-atomspace lill2))
	(test-equal "foo-space" left-space (cog-atomspace (gar lill2)))
	(test-equal "top2-bar-space" top2-space (cog-atomspace (gdr lill2)))

	; Verify appropriate values
	(test-equal "bot-left-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "top2-bar-tv" 6 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "top2-link-tv" 8 (get-cnt lill2))
)

(define exe "test exe pattern")
(test-begin exe)
(test-exe)
(test-end exe)

; ===================================================================
(whack "/tmp/cog-rocks-space-x-test")
(opencog-test-end)
