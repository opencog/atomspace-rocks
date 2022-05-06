;
; frame-links-test.scm
; Test ability to restore complex link structures.
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
	(define mid4-space (cog-new-atomspace mid3-space))
	(define mid5-space (cog-new-atomspace mid4-space))
	(define surface-space (cog-new-atomspace mid5-space))

	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! base-space)
	(Concept "foo" (ctv 1 0 3))

	(cog-set-atomspace! mid1-space)
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 11))
	(Concept "foo" (ctv 1 0 33))
	(Concept "bar" (ctv 1 0 4))

	(cog-set-atomspace! mid2-space)
	(Concept "foo" (ctv 1 0 333))
	(Evaluation (Predicate "zing") (ctv 1 0 12)
		(ListLink (Concept "foo") (Concept "bar")))

	(cog-set-atomspace! mid3-space)
	(AndLink (ctv 1 0 13)
		(Evaluation (Predicate "zing")
			(ListLink (Concept "foo") (Concept "bar"))))

	(cog-set-atomspace! mid4-space)
	(Evaluation (Predicate "zing") (ctv 1 0 14)
		(ListLink (Concept "foo") (Concept "bar")))

	(cog-set-atomspace! mid5-space)
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 15))
	(Concept "foo" (ctv 1 0 555))

	(cog-set-atomspace! surface-space)

	; Store all content.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames surface-space)
	(cog-set-atomspace! base-space)
	(store-atomspace)
	(cog-set-atomspace! mid1-space)
	(store-atomspace)
	(cog-set-atomspace! mid2-space)
	(store-atomspace)
	(cog-set-atomspace! mid3-space)
	(store-atomspace)
	(cog-set-atomspace! mid4-space)
	(store-atomspace)
	(cog-set-atomspace! mid5-space)
	(store-atomspace)
	(cog-set-atomspace! surface-space)
	(store-atomspace)
	(cog-close storage)
)

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; -------------------------------------------------------------------
; Test that load of a single atom is done correctly.

(define (test-load-links)
	(setup-and-store)

	(cog-rocks-open "rocks:///tmp/cog-rocks-unit-test")
	(cog-rocks-stats)
	(cog-rocks-get "")
	(cog-rocks-close)

	; Start with a blank slate.
	(cog-set-atomspace! (cog-new-atomspace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(define top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	; Grab references into the inheritance hierarchy
	(define surface-space top-space)
	(define mid5-space (cog-outgoing-atom surface-space 0))
	(define mid4-space (cog-outgoing-atom mid5-space 0))
	(define mid3-space (cog-outgoing-atom mid4-space 0))
	(define mid2-space (cog-outgoing-atom mid3-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	; Verify appropriate atomspace membership
	(test-equal "foo-space" mid5-space (cog-atomspace (Concept "foo")))

	; The shadowed value should be the top-most value.
	(cog-set-atomspace! mid5-space)
	(test-equal "foo-mid5-tv" 555 (get-cnt (Concept "foo")))
	(test-equal "bar-mid5-tv" 4 (get-cnt (Concept "bar")))
	(define lill-5 (ListLink (Concept "foo") (Concept "bar")))
	(test-equal "lill-mid5-tv" 15 (get-cnt lill-5))
	(test-equal "lilfoo-mid5-tv" 555 (get-cnt (gar lill-5)))
	(test-equal "lilbar-mid5-tv" 4 (get-cnt (gdr lill-5)))

	(cog-set-atomspace! mid4-space)
	(test-equal "foo-mid4-tv" 333 (get-cnt (Concept "foo")))
	(test-equal "bar-mid4-tv" 4 (get-cnt (Concept "bar")))
	(define lill-4 (ListLink (Concept "foo") (Concept "bar")))
	(test-equal "lill-mid4-tv" 11 (get-cnt lill-4))
	(test-equal "lilfoo-mid4-tv" 333 (get-cnt (gar lill-4)))
	(test-equal "lilbar-mid4-tv" 4 (get-cnt (gdr lill-4)))

	(cog-set-atomspace! mid3-space)
	(test-equal "foo-mid3-tv" 333 (get-cnt (Concept "foo")))
	(test-equal "bar-mid3-tv" 4 (get-cnt (Concept "bar")))

	(cog-set-atomspace! mid2-space)
	(test-equal "foo-mid2-tv" 333 (get-cnt (Concept "foo")))
	(test-equal "bar-mid2-tv" 4 (get-cnt (Concept "bar")))
	(define lill-2 (ListLink (Concept "foo") (Concept "bar")))
	(test-equal "lill-mid2-tv" 11 (get-cnt lill-2))
	(test-equal "lilfoo-mid2-tv" 333 (get-cnt (gar lill-2)))
	(test-equal "lilbar-mid2-tv" 4 (get-cnt (gdr lill-2)))
	(define eval-2 (Evaluation (Predicate "zing") lill-2))
	(test-equal "eval-mid2-tv" 12 (get-cnt eval-2))

	(cog-set-atomspace! mid1-space)
	(test-equal "foo-mid1-tv" 33 (get-cnt (Concept "foo")))
	(test-equal "bar-mid1-tv" 4 (get-cnt (Concept "bar")))
	(define lill-1 (ListLink (Concept "foo") (Concept "bar")))
	(test-equal "lill-mid1-tv" 11 (get-cnt lill-1))
	(test-equal "lilfoo-mid1-tv" 33 (get-cnt (gar lill-1)))
	(test-equal "lilbar-mid1-tv" 4 (get-cnt (gdr lill-1)))

	(cog-set-atomspace! base-space)
	(test-equal "foo-base-tv" 3 (get-cnt (Concept "foo")))
)

(define load-links "test load-links")
(test-begin load-links)
(test-load-links)
(test-end load-links)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
