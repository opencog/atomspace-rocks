;
; space-frames.scm
;
; This demo shows how to create a stack of AtomSpaces, each layered on
; top of the last, each containing slight different data. This stack can
; be saved, and then restored.
;
; The term "frame" is meant to recall the concept of a "stackframe" or a
; "Kripke frame": each frame is a changeset, a delta, of all changes to
; the AtomSpace, sitting atop of a stack (or DAG) of AtomSpace
; changesets underneath. So, much like git changesets, each layered on
; the last, and git branches, offering different merged histories of
; changes, with the ability to explore each changeset, individually.
;
; Why is this useful? Several examples:
;
; In logic, in theorem-proving, in logical inference and reasoning, one
; has a set of steps one goes through, to reach a particular conclusion.
; One starts with some initial set of assumptions (stored in the base
; AtomSpace, for example) and then applies a set of inference rules, one
; after the other, to reach a conclusion. At each step, one can apply
; different inferences, leading to different conclusions: there is a
; natural branching structure.  Some branches converge, others do not.
; AtomSpace frames allow you to take snapshots, and store them as you move
; along, and then revisit earlier snapshots, as needed. Different branches
; can be compared.
;
; Another example is context-based knowledge. Consider the graph of all
; knowledge in some situation: say, the set of things that are true, when
; one is indoors. How does this change when one is in a forest?  Things
; that are true in one situation can become false in another; things that
; seem probable and certain in one case may not be in another. Each
; AtomSpace Frame provides a place to record that context-specific
; knowledge: a different set of Atoms, and different Values attached to
; each Atom.

; -------------------------------------------------------------------
; General boilerplate & setup.

(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog persist) (opencog persist-rocks))

; -------------------------------------------------------------------
; Common setup, used by all tests.

(define (setup-and-store)
	(define base-space (cog-atomspace))
	(define mid1-space (cog-new-atomspace base-space))
	(define mid2-space (cog-new-atomspace mid1-space))
	(define surface-space (cog-new-atomspace mid2-space))

	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! base-space)
	(Concept "foo" (ctv 1 0 3))

	(cog-set-atomspace! mid1-space)
	(Concept "bar" (ctv 1 0 4))

	(cog-set-atomspace! mid2-space)
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 5))

	(cog-set-atomspace! surface-space)

	; Store the content. Store the Concepts as well as the link,
	; as otherwise, the TV's on the Concepts aren't stored.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-frames surface-space)
	(store-atom (ListLink (Concept "foo") (Concept "bar")))
	(store-atom (Concept "foo"))
	(store-atom (Concept "bar"))
	(cog-close storage)

	; Clear out the spaces, start with a clean slate.
	(cog-atomspace-clear surface-space)
	(cog-atomspace-clear mid2-space)
	(cog-atomspace-clear mid1-space)
	(cog-atomspace-clear base-space)
)

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; -------------------------------------------------------------------
; Test that deep links are found correctly.

(define (test-deep-link)
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
	(define mid2-space (cog-outgoing-atom surface-space 0))
	(define mid1-space (cog-outgoing-atom mid2-space 0))
	(define base-space (cog-outgoing-atom mid1-space 0))

	; Verify the ListLink is as expected.
	(cog-set-atomspace! mid2-space)
	(define lilly (ListLink (Concept "foo") (Concept "bar")))

	; Verify appropriate atomspace membership
	(test-equal "link-space" mid2-space (cog-atomspace lilly))
	(test-equal "foo-space" base-space (cog-atomspace (gar lilly)))
	(test-equal "bar-space" mid1-space (cog-atomspace (gdr lilly)))

	; Verify appropriate values
	(test-equal "base-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "mid1-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "mid2-tv" 5 (get-cnt lilly))
)

(define deep-link "test deep links")
(test-begin deep-link)
(test-deep-link)
(test-end deep-link)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
