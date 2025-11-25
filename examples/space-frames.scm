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
; the last, and, like git branches, offering different merged histories
; of changes, with the ability to explore each changeset, individually.
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
;
; One word of caution: Using frames can have significant impacts on
; performance. This is not so much in storage, as in the AtomSpace
; itself. If an atom is not immediately found in the top-most layer,
; then progressively deeper layers must be searched. This can add up.
; However, actual performance is very imlementation-dependent, and may
; have changed substantially since this note was written! YMMV!
;
; -------------------------------------------------------------------
; General boilerplate & setup.

(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog persist) (opencog persist-rocks))

; -------------------------------------------------------------------
; This function creates a stack of AtomSpaces, each layered on top of
; the last, and pokes some data into each. It's set up as a function,
; so that defines made here don't pollute later stages. Basically,
; we will create the AtomSpaces, put data into them, store them to disk,
; then destroy the in-RAM AtomSpaces, and then restore them from disk.

(define (setup-and-store)

	; Create a stak of five atomspaces.
	(define base-space (cog-atomspace))
	(define mid1-space (cog-new-atomspace base-space))
	(define mid2-space (cog-new-atomspace mid1-space))
	(define mid3-space (cog-new-atomspace mid2-space))
	(define surface-space (cog-new-atomspace mid3-space))

	; Save the entire stack of spaces. This only stores the spaces and
	; their relationship to one-anothr; it does NOT store the contents,
	(define storage (RocksStorageNode "rocks:///tmp/frame-demo"))
	(cog-open storage)
	(store-frames surface-space)

	; Splatter some atoms into the various spaces. Place some values on
	; each, so that later one, we can verify the the restored spaces.
	; Recall that `ctv` is short for `CountTruthValue`: its just a list
   ; of three numbers.
	(cog-set-atomspace! base-space)
	(Concept "foo" (ctv 1 0 3))
	(store-atom (Concept "foo"))

	(cog-set-atomspace! mid1-space)
	(Concept "bar" (ctv 1 0 4))
	(store-atom (Concept "bar"))

	(cog-set-atomspace! mid2-space)
	(store-atom (ListLink (Concept "foo") (Concept "bar") (ctv 1 0 5)))

	; Change the ctv on `foo`. This will hade the earlier value.
	(cog-set-atomspace! mid3-space)
	(Concept "foo" (ctv 6 22 42))
	(store-atom (Concept "foo"))

	; Close storage
	(cog-close storage)

	; Clear out the spaces, start with a clean slate. This is NOT really
	; needed, as the AtomSpace will disappear, go "poof", once the last
	; reference to them is garbagee collected. Since there are no
	; references outside of this function, they'll just be gone.
	(cog-atomspace-clear surface-space)
	(cog-atomspace-clear mid3-space)
	(cog-atomspace-clear mid2-space)
	(cog-atomspace-clear mid1-space)
	(cog-atomspace-clear base-space)
)

; -------------------------------------------------------------------
; Now restore the spaces, and verify that everything is as expected.

; Well, first, run the above, to store things.
(setup-and-store)

; Start with a blank slate.
(cog-set-atomspace! (cog-new-atomspace))

; Load everything; the spaces, the atoms, everything.
(define storage (RocksStorageNode "rocks:///tmp/frame-demo"))
(cog-open storage)

; Calling `load-frames` will return a list of all of the AtomSpaces
; at the top of the DAG of frames. In this cae, we had a simple stack,
; so there is only one single frame at the top, the top-space.
(define top-space (car (load-frames)))

; Change to this top, and load it's contents, and everything below it.
(cog-set-atomspace! top-space)
(load-atomspace)
(cog-close storage)

; Print out the full top-most atomspace. This will print a long,
; perhaps confusing string: it is a list of the AtomSpaces names,
; followed by a list of the subspaces.
(newline)
(format #t "The top space is:\n~A\n\n" top-space)

; Starting from the top-most space, walk downwards, and create scheme
; references to each space. This is not strictly needed, but it will
; help us bounce between the spaces, below.
(define surface-space top-space)
(define mid3-space (cog-outgoing-atom surface-space 0))
(define mid2-space (cog-outgoing-atom mid3-space 0))
(define mid1-space (cog-outgoing-atom mid2-space 0))
(define base-space (cog-outgoing-atom mid1-space 0))

; Verify the ListLink is as expected.
(cog-set-atomspace! mid2-space)
(define lilly (ListLink (Concept "foo") (Concept "bar")))
(format #t "The list link is: ~A\n" lilly)

; Handy-dandy printer.
(define (check-spaces MSG A B)
	(format #t "For ~A, expecting: ~A -- Got: ~A\n\n"
		MSG (cog-name A) (cog-name B)))

; Verify appropriate atomspace membership
(check-spaces "link-space" mid2-space (cog-atomspace lilly))
(check-spaces "foo-space" base-space (cog-atomspace (gar lilly)))
(check-spaces "bar-space" mid1-space (cog-atomspace (gdr lilly)))

; The above ListLink was first created in the mid2-space, and it
; captured the truth values on `foo` and `bar` as they were, in this
; space. But then, later on, in the top space, the value on `foo` was
; changed. Lets take a closer look at that.
(cog-set-atomspace! surface-space)
(define top-lilly (ListLink (Concept "foo") (Concept "bar")))
(format #t "The top-most list link is:\n~A\n" lilly)

; Another handy printer.
(define (check-equal MSG A B)
	(format #t "For ~A, expecting: ~A-- Got: ~A\n" MSG A B))

; Lets take a look at the TV on `foo` in the base space.
(cog-set-atomspace! base-space)
(check-equal "foo-tv in base" (ctv 1 0 3) (cog-tv (Concept "foo")))

; How aout on top?
(cog-set-atomspace! surface-space)
(check-equal "foo-tv on top" (ctv 6 22 42) (cog-tv (Concept "foo")))

; How about the others?
(check-equal "bar-tv" (ctv 1 0 4) (cog-tv (Concept "bar")))
(check-equal "lilly-tv" (ctv 1 0 5) (cog-tv lilly))
(check-equal "top-tv" (ctv 1 0 5) (cog-tv top-lilly))

(exit)
; The end!
; ===================================================================
