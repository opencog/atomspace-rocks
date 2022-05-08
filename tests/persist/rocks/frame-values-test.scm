;
; frame-values-test.scm
; Test ability to change and delete values.
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
	(cog-set-value! (Concept "foo") (Predicate "key-0")
		(ctv 1 0 0))

	(cog-set-atomspace! mid1-space)
	(cog-set-value! (Concept "foo") (Predicate "key-1")
		(ctv 1 0 1))

	(cog-set-atomspace! mid2-space)
	(cog-set-value! (Concept "foo") (Predicate "key-2")
		(ctv 1 0 2))

	(cog-set-atomspace! mid3-space)
	(cog-set-value! (Concept "foo") (Predicate "key-3")
		(ctv 1 0 3))

	(cog-set-atomspace! mid4-space)
	(cog-set-value! (Concept "foo") (Predicate "key-0") #f)

	(cog-set-atomspace! mid5-space)
	(cog-set-value! (Concept "foo") (Predicate "key-1") #f)

	(cog-set-atomspace! surface-space)
	(cog-set-value! (Concept "foo") (Predicate "key-2") #f)

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
(define (get-val KEY) (inexact->exact 
	(cog-value-ref (cog-value (Concept "foo") KEY) 2)))
(define (get-nov KEY) (cog-value (Concept "foo") KEY))

; -------------------------------------------------------------------
; Test that load of a single atom is done correctly.

(define (test-load-values)
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
	(test-equal "top-space" top-space (cog-atomspace (Concept "foo")))
	(test-equal "mid6-keylist" 1 (length (cog-keys (Concept "foo"))))
	(test-equal "mid6-key-0" #f (get-nov (Predicate "key-0")))
	(test-equal "mid6-key-1" #f (get-nov (Predicate "key-1")))
	(test-equal "mid6-key-2" #f (get-nov (Predicate "key-2")))
	(test-equal "mid6-key-3" 3 (get-val (Predicate "key-3")))

	; The shadowed value should be the top-most value.
	(cog-set-atomspace! mid5-space)
	; (format #t "mid5-keysset=~A\n" (cog-keys (Concept "foo")))
	(test-equal "mid5-keylist" 2 (length (cog-keys (Concept "foo"))))
	(test-equal "mid5-key-0" #f (get-nov (Predicate "key-0")))
	(test-equal "mid5-key-1" #f (get-nov (Predicate "key-1")))
	(test-equal "mid5-key-2" 2 (get-val (Predicate "key-2")))
	(test-equal "mid5-key-3" 3 (get-val (Predicate "key-3")))

	(cog-set-atomspace! mid4-space)
	; (format #t "mid4-keyset=~A\n" (cog-keys (Concept "foo")))
	(test-equal "mid4-keylist" 3 (length (cog-keys (Concept "foo"))))
	(test-equal "mid4-key-0" #f (get-nov (Predicate "key-0")))
	(test-equal "mid4-key-1" 1 (get-val (Predicate "key-1")))
	(test-equal "mid4-key-2" 2 (get-val (Predicate "key-2")))
	(test-equal "mid4-key-3" 3 (get-val (Predicate "key-3")))

	(cog-set-atomspace! mid3-space)
	(test-equal "mid3-keylist" 4 (length (cog-keys (Concept "foo"))))
	(test-equal "mid3-key-0" 0 (get-val (Predicate "key-0")))
	(test-equal "mid3-key-1" 1 (get-val (Predicate "key-1")))
	(test-equal "mid3-key-2" 2 (get-val (Predicate "key-2")))
	(test-equal "mid3-key-3" 3 (get-val (Predicate "key-3")))

	(cog-set-atomspace! mid2-space)
	(test-equal "mid2-keylist" 3 (length (cog-keys (Concept "foo"))))
	(test-equal "mid2-key-0" 0 (get-val (Predicate "key-0")))
	(test-equal "mid2-key-1" 1 (get-val (Predicate "key-1")))
	(test-equal "mid2-key-2" 2 (get-val (Predicate "key-2")))
	(test-equal "mid2-key-3" #f (get-nov (Predicate "key-3")))

	(cog-set-atomspace! mid1-space)
	(test-equal "mid1-keylist" 2 (length (cog-keys (Concept "foo"))))
	(test-equal "mid1-key-0" 0 (get-val (Predicate "key-0")))
	(test-equal "mid1-key-1" 1 (get-val (Predicate "key-1")))
	(test-equal "mid1-key-2" #f (get-nov (Predicate "key-2")))
	(test-equal "mid1-key-3" #f (get-nov (Predicate "key-3")))

	(cog-set-atomspace! base-space)
	(test-equal "mid0-keylist" 1 (length (cog-keys (Concept "foo"))))
	(test-equal "mid0-key-0" 0 (get-val (Predicate "key-0")))
	(test-equal "mid0-key-1" #f (get-nov (Predicate "key-1")))
	(test-equal "mid0-key-2" #f (get-nov (Predicate "key-2")))
	(test-equal "mid0-key-3" #f (get-nov (Predicate "key-3")))
)

(define load-values "test load-values")
(test-begin load-values)
(test-load-values)
(test-end load-values)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
