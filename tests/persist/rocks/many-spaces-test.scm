;
; many-spaces-test.scm
; Unit test verifying the many-spaces.scm demo.
; This tests the ability to store multiple independent AtomSpaces
; into a single StorageNode, and restore them without content leakage.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-many-spaces-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup: create and populate multiple atomspaces, then store.

(define (setup-and-store)
	; Create the main space
	(define as-main (AtomSpace "main space"))
	(cog-set-atomspace! as-main)

	; Create three additional independent spaces
	; These exist in as-main to prevent garbage collection
	(define as-one (AtomSpace "foo"))
	(define as-two (AtomSpace "bar"))
	(define as-three (AtomSpace "bing"))

	; Create an index of spaces in the main space
	(Edge (Predicate "bundle") (List (Item "AtomSpace Bundle Alpha") as-one))
	(Edge (Predicate "bundle") (List (Item "AtomSpace Bundle Alpha") as-two))
	(Edge (Predicate "bundle") (List (Item "Bundle Beta") as-three))

	; Populate space one
	(cog-set-atomspace! as-one)
	(Concept "I am in Space One!")
	(Concept "Also in One")

	; Populate space two
	(cog-set-atomspace! as-two)
	(Concept "Resident of Two, here!")
	(List (Concept "two-a") (Concept "two-b"))

	; Populate space three
	(cog-set-atomspace! as-three)
	(EdgeLink (Predicate "three-ness") (Item "Just an old lump of coal"))
	(Concept "Three's company")

	; Return to main space and store everything
	(cog-set-atomspace! as-main)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-many-spaces-test"))
	(cog-open storage)
	(store-atomspace as-one)
	(store-atomspace as-two)
	(store-atomspace as-three)
	(store-atomspace as-main)
	(cog-close storage)

	; Return the spaces for verification before clear
	(list as-main as-one as-two as-three)
)

; -------------------------------------------------------------------
; Test 1: Basic store and reload of multiple spaces
; Verifies that each space can be stored and reloaded with correct content.

(define (test-basic-multispace)
	(setup-and-store)

	; Clear everything - start fresh
	(cog-set-atomspace! (cog-new-atomspace))

	; Recreate the main space and open storage
	(define as-main (AtomSpace "main space"))
	(cog-set-atomspace! as-main)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-many-spaces-test"))
	(cog-open storage)

	; Load and verify space two first (out of order)
	(define as-two (AtomSpace "bar"))
	(cog-set-atomspace! as-two)
	(load-atomspace as-two)

	(test-assert "two-has-resident"
		(not (null? (cog-node 'Concept "Resident of Two, here!"))))
	(test-assert "two-has-list"
		(not (null? (cog-link 'List (Concept "two-a") (Concept "two-b")))))

	; Verify space two does NOT have content from other spaces
	(test-assert "two-not-have-one-content"
		(null? (cog-node 'Concept "I am in Space One!")))
	(test-assert "two-not-have-three-content"
		(null? (cog-node 'Concept "Three's company")))

	; Load and verify space one
	(define as-one (AtomSpace "foo"))
	(cog-set-atomspace! as-one)
	(load-atomspace as-one)

	(test-assert "one-has-content"
		(not (null? (cog-node 'Concept "I am in Space One!"))))
	(test-assert "one-has-also"
		(not (null? (cog-node 'Concept "Also in One"))))

	; Verify space one does NOT have content from other spaces
	(test-assert "one-not-have-two-content"
		(null? (cog-node 'Concept "Resident of Two, here!")))

	; Load and verify space three
	(define as-three (AtomSpace "bing"))
	(cog-set-atomspace! as-three)
	(load-atomspace as-three)

	(test-assert "three-has-edge"
		(not (null? (cog-link 'EdgeLink
			(Predicate "three-ness")
			(Item "Just an old lump of coal")))))
	(test-assert "three-has-company"
		(not (null? (cog-node 'Concept "Three's company"))))

	(cog-close storage)
)

(define basic-multispace "test basic-multispace")
(test-begin basic-multispace)
(test-basic-multispace)
(test-end basic-multispace)

(whack "/tmp/cog-rocks-many-spaces-test")

; -------------------------------------------------------------------
; Test 2: Index structure in main space
; Verifies that the "index" Edge links in main space work correctly.

(define (test-space-index)
	(setup-and-store)

	; Clear and restart
	(cog-set-atomspace! (cog-new-atomspace))

	(define as-main (AtomSpace "main space"))
	(cog-set-atomspace! as-main)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-many-spaces-test"))
	(cog-open storage)

	; Load main space which contains the index
	(load-atomspace as-main)

	; Verify the bundle index exists
	(test-assert "bundle-predicate-exists"
		(not (null? (cog-node 'Predicate "bundle"))))
	(test-assert "bundle-alpha-item-exists"
		(not (null? (cog-node 'Item "AtomSpace Bundle Alpha"))))
	(test-assert "bundle-beta-item-exists"
		(not (null? (cog-node 'Item "Bundle Beta"))))

	; Verify the AtomSpace nodes are in the index
	(define as-one (AtomSpace "foo"))
	(define as-two (AtomSpace "bar"))
	(define as-three (AtomSpace "bing"))

	(test-assert "edge-to-foo-exists"
		(not (null? (cog-link 'Edge
			(Predicate "bundle")
			(List (Item "AtomSpace Bundle Alpha") as-one)))))
	(test-assert "edge-to-bar-exists"
		(not (null? (cog-link 'Edge
			(Predicate "bundle")
			(List (Item "AtomSpace Bundle Alpha") as-two)))))
	(test-assert "edge-to-bing-exists"
		(not (null? (cog-link 'Edge
			(Predicate "bundle")
			(List (Item "Bundle Beta") as-three)))))

	(cog-close storage)
)

(define space-index "test space-index")
(test-begin space-index)
(test-space-index)
(test-end space-index)

(whack "/tmp/cog-rocks-many-spaces-test")

; -------------------------------------------------------------------
; Test 3: No content leakage between spaces
; Verifies that loading one space doesn't put content in another.

(define (test-no-leakage)
	(setup-and-store)

	; Clear and restart
	(cog-set-atomspace! (cog-new-atomspace))

	(define as-main (AtomSpace "main space"))
	(cog-set-atomspace! as-main)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-many-spaces-test"))
	(cog-open storage)

	; Create all spaces but only load one
	(define as-one (AtomSpace "foo"))
	(define as-two (AtomSpace "bar"))
	(define as-three (AtomSpace "bing"))

	; Load only space one
	(load-atomspace as-one)

	; Verify space two doesn't have space one's content
	(cog-set-atomspace! as-two)
	(test-assert "two-no-one-content"
		(null? (cog-node 'Concept "I am in Space One!")))

	; Verify space three doesn't have space one's content
	(cog-set-atomspace! as-three)
	(test-assert "three-no-one-content"
		(null? (cog-node 'Concept "I am in Space One!")))

	; Now load space two and verify it has correct content
	(load-atomspace as-two)
	(cog-set-atomspace! as-two)
	(test-assert "two-loaded-has-content"
		(not (null? (cog-node 'Concept "Resident of Two, here!"))))

	; Verify space three doesn't have space two's content
	(cog-set-atomspace! as-three)
	(test-assert "three-no-two-content"
		(null? (cog-node 'Concept "Resident of Two, here!")))
	(test-assert "three-no-two-list"
		(null? (cog-link 'List (Concept "two-a") (Concept "two-b"))))

	(cog-close storage)
)

(define no-leakage "test no-leakage")
(test-begin no-leakage)
(test-no-leakage)
(test-end no-leakage)

(whack "/tmp/cog-rocks-many-spaces-test")

; -------------------------------------------------------------------
; Test 4: Load atomspace without argument uses current space
; Verifies that (load-atomspace) without arg loads the current space.

(define (test-load-current)
	(setup-and-store)

	; Clear and restart
	(cog-set-atomspace! (cog-new-atomspace))

	(define as-main (AtomSpace "main space"))
	(cog-set-atomspace! as-main)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-many-spaces-test"))
	(cog-open storage)

	; Create space three and set it as current
	(define as-three (AtomSpace "bing"))
	(cog-set-atomspace! as-three)

	; Verify it's empty
	(test-equal "three-initially-empty" '() (cog-get-all-roots))

	; Load without argument - should load current space (as-three)
	(load-atomspace)

	; Verify content was loaded
	(test-assert "three-loaded-via-no-arg"
		(not (null? (cog-node 'Concept "Three's company"))))
	(test-assert "three-has-edge-via-no-arg"
		(not (null? (cog-link 'EdgeLink
			(Predicate "three-ness")
			(Item "Just an old lump of coal")))))

	(cog-close storage)
)

(define load-current "test load-current")
(test-begin load-current)
(test-load-current)
(test-end load-current)

; ===================================================================
(whack "/tmp/cog-rocks-many-spaces-test")
(opencog-test-end)
