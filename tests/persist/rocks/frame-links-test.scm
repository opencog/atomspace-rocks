;
; frame-links-test.scm
; Test ability to restore complex link structures.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-frame-links-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

(define (setup-and-store)
	(define base-space (cog-atomspace))
	(define mid1-space (AtomSpace base-space))
	(define mid2-space (AtomSpace mid1-space))
	(define mid3-space (AtomSpace mid2-space))
	(define mid4-space (AtomSpace mid3-space))
	(define mid5-space (AtomSpace mid4-space))
	(define surface-space (AtomSpace mid5-space))

	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! base-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 3))

	(cog-set-atomspace! mid1-space)
	(set-cnt! (ListLink (Concept "foo") (Concept "bar")) (FloatValue 1 0 11))
	(set-cnt! (Concept "foo") (FloatValue 1 0 33))
	(set-cnt! (Concept "bar") (FloatValue 1 0 4))

	(cog-set-atomspace! mid2-space)
	(set-cnt! (Concept "foo") (FloatValue 1 0 333))
	(set-cnt! (Evaluation (Predicate "zing")
		(ListLink (Concept "foo") (Concept "bar"))) (FloatValue 1 0 12))

	(cog-set-atomspace! mid3-space)
	(set-cnt! (AndLink
		(Evaluation (Predicate "zing")
			(ListLink (Concept "foo") (Concept "bar")))) (FloatValue 1 0 13))

	(cog-set-atomspace! mid4-space)
	(set-cnt! (Evaluation (Predicate "zing")
		(ListLink (Concept "foo") (Concept "bar"))) (FloatValue 1 0 14))

	(cog-set-atomspace! mid5-space)
	(set-cnt! (ListLink (Concept "foo") (Concept "bar")) (FloatValue 1 0 15))
	(set-cnt! (Concept "foo") (FloatValue 1 0 555))

	(cog-set-atomspace! surface-space)

	; Store all content.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-links-test"))
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

; -------------------------------------------------------------------
; Test that load of a series of nested links is done correctly.

(define (test-load-links)
	(setup-and-store)

	; (cog-rocks-open "rocks:///tmp/cog-rocks-frame-links-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	; Start with a blank slate.
	(cog-set-atomspace! (AtomSpace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-frame-links-test"))
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
	; (format #t "mid5 space=~A\n" (cog-get-all-roots))
	(test-equal "foo-mid5-tv" 555 (get-cnt (Concept "foo")))
	(test-equal "bar-mid5-tv" 4 (get-cnt (Concept "bar")))
	(define lill-5 (ListLink (Concept "foo") (Concept "bar")))
	(test-equal "lill-mid5-tv" 15 (get-cnt lill-5))
	(test-equal "lilfoo-mid5-tv" 555 (get-cnt (gar lill-5)))
	(test-equal "lilbar-mid5-tv" 4 (get-cnt (gdr lill-5)))
	(define eval-5 (Evaluation (Predicate "zing") lill-5))
	(test-equal "eval-mid5-tv" 14 (get-cnt eval-5))
	(test-equal "evlil-mid5-tv" 15 (get-cnt (gdr eval-5)))
	(test-equal "lil-evlil-5" lill-5 (gdr eval-5))
	(define and-5 (And eval-5))
	(test-equal "and-mid5-tv" 13 (get-cnt and-5))
	(test-equal "andev-mid5-tv" 14 (get-cnt (gar and-5)))
	(test-equal "eva-and-5" eval-5 (gar and-5))

	(cog-set-atomspace! mid4-space)
	; (format #t "mid4 space=~A\n" (cog-get-all-roots))
	(test-equal "foo-mid4-tv" 333 (get-cnt (Concept "foo")))
	(test-equal "bar-mid4-tv" 4 (get-cnt (Concept "bar")))
	(define lill-4 (ListLink (Concept "foo") (Concept "bar")))
	(test-equal "lill-mid4-tv" 11 (get-cnt lill-4))
	(test-equal "lilfoo-mid4-tv" 333 (get-cnt (gar lill-4)))
	(test-equal "lilbar-mid4-tv" 4 (get-cnt (gdr lill-4)))
	(define eval-4 (Evaluation (Predicate "zing") lill-4))
	(test-equal "eval-mid4-tv" 14 (get-cnt eval-4))
	(test-equal "evlil-mid4-tv" 11 (get-cnt (gdr eval-4)))
	(test-equal "lil-evlil-4" lill-4 (gdr eval-4))
	(define and-4 (And eval-4))
	(test-equal "and-mid4-tv" 13 (get-cnt and-4))
	(test-equal "andev-mid4-tv" 14 (get-cnt (gar and-4)))
	(test-equal "eva-and-4" eval-4 (gar and-4))

	(cog-set-atomspace! mid3-space)
	; (format #t "mid3 space=~A\n" (cog-get-all-roots))
	(test-equal "foo-mid3-tv" 333 (get-cnt (Concept "foo")))
	(test-equal "bar-mid3-tv" 4 (get-cnt (Concept "bar")))
	(define lill-3 (ListLink (Concept "foo") (Concept "bar")))
	(test-equal "lill-mid3-tv" 11 (get-cnt lill-3))
	(test-equal "lilfoo-mid3-tv" 333 (get-cnt (gar lill-3)))
	(test-equal "lilbar-mid3-tv" 4 (get-cnt (gdr lill-3)))
	(define eval-3 (Evaluation (Predicate "zing") lill-3))
	(test-equal "eval-mid3-tv" 12 (get-cnt eval-3))
	(test-equal "evlil-mid3-tv" 11 (get-cnt (gdr eval-3)))
	(test-equal "lil-evlil-3" lill-3 (gdr eval-3))
	(define and-3 (And eval-3))
	(test-equal "and-mid3-tv" 13 (get-cnt and-3))
	(test-equal "andev-mid3-tv" 12 (get-cnt (gar and-3)))
	(test-equal "eva-and-3" eval-3 (gar and-3))

	(cog-set-atomspace! mid2-space)
	; (format #t "mid2 space=~A\n" (cog-get-all-roots))
	(test-equal "foo-mid2-tv" 333 (get-cnt (Concept "foo")))
	(test-equal "bar-mid2-tv" 4 (get-cnt (Concept "bar")))
	(define lill-2 (ListLink (Concept "foo") (Concept "bar")))
	(test-equal "lill-mid2-tv" 11 (get-cnt lill-2))
	(test-equal "lilfoo-mid2-tv" 333 (get-cnt (gar lill-2)))
	(test-equal "lilbar-mid2-tv" 4 (get-cnt (gdr lill-2)))
	(define eval-2 (Evaluation (Predicate "zing") lill-2))
	(test-equal "eval-mid2-tv" 12 (get-cnt eval-2))
	(test-equal "evlil-mid2-tv" 11 (get-cnt (gdr eval-2)))
	(test-equal "lil-evlil-2" lill-2 (gdr eval-2))

	(cog-set-atomspace! mid1-space)
	; (format #t "mid1 space=~A\n" (cog-get-all-roots))
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
(whack "/tmp/cog-rocks-frame-links-test")
(opencog-test-end)
