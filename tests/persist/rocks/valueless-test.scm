;
; valueless-test.scm
; Test ability to store and retreive atoms without any values.
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

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames surface-space)

	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! base-space)
	(store-atom (Concept "even"))

	(cog-set-atomspace! mid1-space)
	(store-atom (Concept "odd"))

	(cog-set-atomspace! mid2-space)
	(cog-delete! (Concept "even"))

	(cog-set-atomspace! mid3-space)
	(cog-delete! (Concept "odd"))

	(cog-set-atomspace! mid4-space)
	(store-atom (Concept "even"))

	(cog-set-atomspace! mid5-space)
	(store-atom (Concept "odd"))

	(cog-close storage)

	; Clear out the spaces, start with a clean slate.
	(cog-atomspace-clear surface-space)
	(cog-atomspace-clear mid5-space)
	(cog-atomspace-clear mid4-space)
	(cog-atomspace-clear mid3-space)
	(cog-atomspace-clear mid2-space)
	(cog-atomspace-clear mid1-space)
	(cog-atomspace-clear base-space)
)

; -------------------------------------------------------------------
; Test that atoms appear and disappear where they should.

(define (test-valueless)
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

	; Verify that atoms appear and disappear properly.
	(cog-set-atomspace! base-space)
	(test-assert "yes-even-0" (cog-atom 'Concept "even"))
	(test-assert "no-odd-0" (nil? (cog-atom 'Concept "odd")))
	(test-equal "even-0" base-space (cog-atomspace (cog-atom 'Concept "even")))
)

(define valueless "test valueless atoms")
(test-begin valueless)
(test-valueless)
(test-end valueless)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
