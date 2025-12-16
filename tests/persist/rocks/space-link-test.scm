#! /usr/bin/env guile
-s
!#
;
; space-link-test.scm
; Test ability to store Links containing AtomSpaces.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-space-link-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Test that Links can hold AtomSpaces.

(define (test-space-link)

	; Create a ListLink holding an AtomSpace
	(List (Item "Bundle Alpha") (AtomSpace "foobar"))

	; Store it
	(define rsn (RocksStorageNode "rocks:///tmp/cog-rocks-space-link-test"))
	(cog-open rsn)
	(store-atomspace)
	(cog-close rsn)

	; Start fresh
	(cog-atomspace-clear)

	; Load
	(set! rsn (RocksStorageNode "rocks:///tmp/cog-rocks-space-link-test"))
	(cog-open rsn)
	(load-atomspace)
	(cog-close rsn)
	(cog-prt-atomspace)

	; Was the Item loaded?
	(test-assert "bundle" (cog-atom? (cog-node 'Item "Bundle Alpha")))

	; We'd like to check this way, but it is currently not practical
	; or advisable to do this. ... It raises difficult questions.
	; (test-assert "space" (cog-atom? (cog-node 'AtomSpace "foobar")))

	; Was the ListLink loaded?
	(test-assert "link-space" (cog-atom?
		(cog-link 'List (Item "Bundle Alpha") (AtomSpace "foobar"))))

	; DB contents verification:
	; (cog-rocks-open "rocks:///tmp/cog-rocks-space-link-test")
	; (cog-rocks-get "n@")
	; rkey: >>n@(AtomSpace "foo")<<
	; (cog-rocks-get "l@")
	; rkey: >>l@(ListLink (ItemNode "Bundle Alpha")(AtomSpace "foobar"))<<
)

(define space-link "test space links")
(test-begin space-link)
(test-space-link)
(test-end space-link)

; ===================================================================
(whack "/tmp/cog-rocks-space-link-test")
(opencog-test-end)
