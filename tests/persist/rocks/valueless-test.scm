;
; valueless-test.scm
; Test ability to store and retrieve atoms without any values.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-valueless-test")

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

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-valueless-test"))
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

	; (cog-rocks-open "rocks:///tmp/cog-rocks-valueless-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	; Start with a blank slate.
	(cog-set-atomspace! (AtomSpace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-valueless-test"))
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
	(test-assert "yes-even-0" (not (nil? (cog-node 'Concept "even"))))
	(test-assert "no-odd-0" (nil? (cog-node 'Concept "odd")))
	(test-equal "even-0 as" base-space (cog-atomspace (cog-node 'Concept "even")))

	(cog-set-atomspace! mid1-space)
	(test-assert "yes-even-1" (not (nil? (cog-node 'Concept "even"))))
	(test-assert "yes-odd-1" (not (nil? (cog-node 'Concept "odd"))))
	(test-equal "even-1 as" base-space (cog-atomspace (cog-node 'Concept "even")))
	(test-equal "odd-1 as" mid1-space (cog-atomspace (cog-node 'Concept "odd")))

	(cog-set-atomspace! mid2-space)
	(test-assert "no-even-2" (nil? (cog-node 'Concept "even")))
	(test-assert "yes-odd-2" (not (nil? (cog-node 'Concept "odd"))))
	(test-equal "odd-2 as" mid1-space (cog-atomspace (cog-node 'Concept "odd")))

	(cog-set-atomspace! mid3-space)
	(test-assert "no-even-3" (nil? (cog-node 'Concept "even")))
	(test-assert "no-odd-3" (nil? (cog-node 'Concept "odd")))

	(cog-set-atomspace! mid4-space)
	(test-assert "yes-even-4" (not (nil? (cog-node 'Concept "even"))))
	(test-assert "no-odd-4" (nil? (cog-node 'Concept "odd")))
	(test-equal "even-4 as" mid4-space (cog-atomspace (cog-node 'Concept "even")))

	(cog-set-atomspace! mid5-space)
	(test-assert "yes-even-5" (not (nil? (cog-node 'Concept "even"))))
	(test-assert "yes-odd-5" (not (nil? (cog-node 'Concept "odd"))))
	(test-equal "even-5 as" mid4-space (cog-atomspace (cog-node 'Concept "even")))
	(test-equal "odd-5 as" mid5-space (cog-atomspace (cog-node 'Concept "odd")))

	(cog-set-atomspace! top-space)
	(test-assert "yes-even-6" (not (nil? (cog-node 'Concept "even"))))
	(test-assert "yes-odd-6" (not (nil? (cog-node 'Concept "odd"))))
	(test-equal "even-6 as" mid4-space (cog-atomspace (cog-node 'Concept "even")))
	(test-equal "odd-6 as" mid5-space (cog-atomspace (cog-node 'Concept "odd")))
)

(define valueless "test valueless atoms")
(test-begin valueless)
(test-valueless)
(test-end valueless)

; ===================================================================
(whack "/tmp/cog-rocks-valueless-test")
(opencog-test-end)
