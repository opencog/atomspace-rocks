;
; space-episodic.scm -- Unit test for RocksStorageNode w/AtomSpaces
;
; This is a modified copy of the `episodic-space.scm` demo in the main
; AtomSpace examples directory. The `file-episodic.scm` variant of this
; tests the FileStorageNode. Its in the main AtomSpace repo tests dir.
;
(use-modules (opencog) (opencog persist) (opencog persist-rocks))
(use-modules (opencog test-runner))

; ---------------------------------------------------------------------
(opencog-test-runner)
(define tname "store_episodes")
(test-begin tname)

; Get a reference to the current AtomSpace; this is our main space.
(define base-space (cog-atomspace))
(ConceptNode "foo")
(cog-set-value! (ConceptNode "foo") (Predicate "bunch o numbers")
		(FloatValue 1 2 3.14159 4 5 6))
(cog-set-value! (ConceptNode "foo") (Predicate "some words")
		(StringValue "once" "upon" "a" "time"))
(cog-set-value! (ConceptNode "foo") (Predicate "some atoms")
		(LinkValue (Concept "dog") (Concept "cat") (Concept "mouse")))

(cog-set-value! (ConceptNode "foo") (Predicate "real life")
		(AtomSpace "happy thoughts"))

(cog-set-value! (ConceptNode "foo") (Predicate "repressed mem")
		(AtomSpace "crushing defeat"))

; Populate the subspaces
(cog-set-atomspace!
	(cog-value (ConceptNode "foo") (Predicate "real life")))

; Add some content.
(ListLink (Concept "mom") (Concept "dad"))
(ListLink (Concept "first crush") (Concept "Gilanda"))
(ListLink (Concept "stack blocks"))

; Switch to the other AtomSpace.
(cog-set-atomspace! base-space)
(cog-set-atomspace!
	(cog-value (ConceptNode "foo") (Predicate "repressed mem")))

(ListLink (Concept "misdemeanor") (Concept "vandalism"))
(ListLink (Concept "furious") (Concept "anger"))

; Return to the main space.
(cog-set-atomspace! base-space)

(format #t "Atom counts in subspaces are ~A ~A ~A\n"
	(count-all)
	(count-all (cog-value (ConceptNode "foo") (Predicate "real life")))
	(count-all (cog-value (ConceptNode "foo") (Predicate "repressed mem"))))

; Verify contents
(test-assert "base-count" (equal? 11 (count-all)))
(test-assert "space1-count" (equal? 8
	(count-all (cog-value (ConceptNode "foo") (Predicate "real life")))))
(test-assert "space2-count" (equal? 6
	(count-all (cog-value (ConceptNode "foo") (Predicate "repressed mem")))))

; Dump all three AtomSpaces to the same file.
(define rsn (RocksStorageNode "rocks:///tmp/cog-rocks-space-episodic-test"))
(cog-open rsn)
(store-atomspace)
(store-atomspace (AtomSpace "happy thoughts"))
(store-atomspace (AtomSpace "crushing defeat"))
(cog-close rsn)

; Verify that the contents are as expected
(cog-prt-atomspace)
(cog-prt-atomspace (AtomSpace "happy thoughts"))
(cog-prt-atomspace (AtomSpace "crushing defeat"))

; Clobber temps
(set! rsn #f)
(gc) (gc)

(cog-atomspace-clear)

; ---------------------------------------------------------------------

; Load everything from the DB.

(define gsn (RocksStorageNode "rocks:///tmp/cog-rocks-space-episodic-test"))

(cog-open gsn)
(load-atomspace)
(format #t "Loaded Atom counts ~A ~A ~A\n"
	(count-all)
	(count-all (cog-value (ConceptNode "foo") (Predicate "real life")))
	(count-all (cog-value (ConceptNode "foo") (Predicate "repressed mem"))))

; 11 loaded plus one RocksStorageNode plus (Predicate "*-TruthValueKey-*")
; Plus two more: (Predicate "*-store-atomspace-*")
; and (Predicate "*-load-atomspace-*") and *-open-* and *-close-*

(test-assert "base-count" (equal? 16 (count-all)))
(test-assert "space1-count" (equal? 0
	(count-all (cog-value (ConceptNode "foo") (Predicate "real life")))))
(test-assert "space2-count" (equal? 0
	(count-all (cog-value (ConceptNode "foo") (Predicate "repressed mem")))))

; Now, restore the two batches of episodic memories.
(load-atomspace (AtomSpace "happy thoughts"))
(load-atomspace (AtomSpace "crushing defeat"))
(cog-close gsn)

(test-assert "base-count" (equal? 17 (count-all)))
(test-assert "space1-count" (equal? 8
	(count-all (cog-value (ConceptNode "foo") (Predicate "real life")))))
(test-assert "space2-count" (equal? 6
	(count-all (cog-value (ConceptNode "foo") (Predicate "repressed mem")))))

; Verify that the contents are as expected
(cog-prt-atomspace)
(cog-prt-atomspace (AtomSpace "happy thoughts"))
(cog-prt-atomspace (AtomSpace "crushing defeat"))

; --------------------------
; Clean up.

(test-end tname)

(opencog-test-end)
