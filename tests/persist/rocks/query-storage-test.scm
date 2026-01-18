#! /usr/bin/env guile
-s
!#
;
; query-storage-test.scm
; Unit test verifying the query-storage.scm demo.
; This tests the executation of "remote" queries, of searching for
; data without loading it into the current AtomSpace. The API remains
; a bit experimental, so take failures of this unit test with a grain
; of salt; it might need to be modified to match API changes.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-query-storage-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup: populate atomspace and store to disk.

(define (setup-and-store)
	; Create test atoms
	(List (Concept "A") (Concept "B"))
	(Set (Concept "A") (Concept "B"))
	(Set (Concept "A") (Concept "B") (Concept "C"))
	(Evaluation (Predicate "foo")
		(List (Concept "B") (Concept "C") (Concept "oh boy!")))

	; Store to disk
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-query-storage-test"))
	(cog-set-value! storage (*-open-*))
	(cog-set-value! storage (*-store-atomspace-*) (cog-atomspace))
	(cog-set-value! storage (*-close-*))

	; Clear and reopen
	(cog-atomspace-clear)
	storage
)

; -------------------------------------------------------------------
; Test 1: Basic Meet Query
; Verifies that fetch-query with MeetLink returns correct results
; and that matched structures are NOT brought into the atomspace.

(define (test-basic-meet)
	(setup-and-store)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-query-storage-test"))
	(cog-set-value! storage (*-open-*))

	; Define query to find tail of (List A ?)
	(define get-tail (Meet (List (Concept "A") (Variable "tail"))))
	(define results-key (Predicate "results"))

	; Run query
	(cog-set-value! storage (*-fetch-query-*) get-tail results-key)
	(define result (cog-value get-tail results-key))

	; Verify result contains (Concept "B")
	(test-assert "meet-result-exists" result)
	(test-equal "meet-result-is-B"
		(list (Concept "B"))
		(cog-value->list result))

	; Verify (Concept "B") is in atomspace
	(define roots (cog-get-all-roots))
	(test-assert "B-in-atomspace" (member (Concept "B") roots))

	; Verify ListLink(A,B) is NOT in atomspace (key feature of fetch-query)
	(test-assert "ListLink-not-in-atomspace"
		(not (member (List (Concept "A") (Concept "B")) roots)))

	(cog-set-value! storage (*-close-*))
)

(define basic-meet "test basic-meet")
(test-begin basic-meet)
(test-basic-meet)
(test-end basic-meet)

(whack "/tmp/cog-rocks-query-storage-test")

; -------------------------------------------------------------------
; Test 2: Query Caching
; Verifies that query results are cached and can be refreshed.

(define (test-query-caching)
	(setup-and-store)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-query-storage-test"))
	(cog-set-value! storage (*-open-*))

	(define get-tail (Meet (List (Concept "A") (Variable "tail"))))
	(define results-key (Predicate "results"))

	; Initial query - should return B
	(cog-set-value! storage (*-fetch-query-*) get-tail results-key)
	(define result1 (cog-value get-tail results-key))
	(test-equal "initial-result-B"
		(list (Concept "B"))
		(cog-value->list result1))

	; Add new data and store
	(List (Concept "A") (Concept "F"))
	(cog-set-value! storage (*-store-atomspace-*) (cog-atomspace))
	(cog-extract-recursive! (Concept "F"))

	; Re-run query - should get cached (stale) result
	(cog-set-value! storage (*-fetch-query-*) get-tail results-key)
	(define cached-result (cog-value get-tail results-key))
	(test-equal "cached-result-still-B"
		(list (Concept "B"))
		(cog-value->list cached-result))

	; Clear cache and re-run
	(cog-set-value! get-tail results-key #f)
	(cog-set-value! storage (*-store-value-*) get-tail results-key)
	(cog-set-value! storage (*-fetch-query-*) get-tail results-key)
	(define fresh-result (cog-value get-tail results-key))
	(define fresh-list (cog-value->list fresh-result))

	; Now should have both B and F
	(test-assert "fresh-contains-B" (member (Concept "B") fresh-list))
	(test-assert "fresh-contains-F" (member (Concept "F") fresh-list))

	(cog-set-value! storage (*-close-*))
)

(define query-caching "test query-caching")
(test-begin query-caching)
(test-query-caching)
(test-end query-caching)

(whack "/tmp/cog-rocks-query-storage-test")

; -------------------------------------------------------------------
; Test 3: Query Metadata and Fresh Flag
; Verifies that the #t fresh flag forces re-computation and
; metadata (timestamp) is returned.

(define (test-query-metadata)
	(setup-and-store)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-query-storage-test"))
	(cog-set-value! storage (*-open-*))

	(define get-tail (Meet (List (Concept "A") (Variable "tail"))))
	(define results-key (Predicate "results"))

	; Initial query
	(cog-set-value! storage (*-fetch-query-*) get-tail results-key)

	; Add new data
	(List (Concept "A") (Concept "G"))
	(cog-set-value! storage (*-store-atomspace-*) (cog-atomspace))
	(cog-extract-recursive! (Concept "G"))

	; Stale cache - should NOT have G yet
	(cog-set-value! storage (*-fetch-query-*) get-tail results-key)
	(define stale-result (cog-value get-tail results-key))
	(define stale-list (cog-value->list stale-result))
	(test-assert "stale-missing-G"
		(not (member (Concept "G") stale-list)))

	; Request fresh with metadata
	(define metadata (Predicate "my metadata"))
	(cog-set-value! storage (*-fetch-query-*) (LinkValue (cog-atomspace) get-tail results-key metadata (BoolValue #t)))

	(define fresh-result (cog-value get-tail results-key))
	(define fresh-list (cog-value->list fresh-result))
	(test-assert "fresh-contains-G" (member (Concept "G") fresh-list))

	; Check metadata exists and is a timestamp
	(cog-set-value! storage (*-fetch-value-*) get-tail metadata)
	(define meta-value (cog-value get-tail metadata))
	(test-assert "metadata-exists" meta-value)
	(test-assert "metadata-is-float"
		(equal? (cog-type meta-value) 'FloatValue))

	; Timestamp should be a reasonable Unix time (> year 2020)
	(define timestamp (car (cog-value->list meta-value)))
	(test-assert "timestamp-reasonable" (> timestamp 1577836800))

	(cog-set-value! storage (*-close-*))
)

(define query-metadata "test query-metadata")
(test-begin query-metadata)
(test-query-metadata)
(test-end query-metadata)

(whack "/tmp/cog-rocks-query-storage-test")

; -------------------------------------------------------------------
; Test 4: JoinLink (MaximalJoin) - Generalized Incoming Set
; Verifies that MaximalJoin fetches all structures containing an atom.

(define (test-join-link)
	(setup-and-store)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-query-storage-test"))
	(cog-set-value! storage (*-open-*))

	(define results-key (Predicate "results"))

	; Find all structures containing (Concept "B")
	(define b-holders (MaximalJoin (Concept "B")))
	(cog-set-value! storage (*-fetch-query-*) b-holders results-key)
	(define result (cog-value b-holders results-key))

	(test-assert "join-result-exists" result)
	(define join-list (cog-value->list result))

	; Should contain all structures with B
	(test-assert "join-contains-ListAB"
		(member (List (Concept "A") (Concept "B")) join-list))
	(test-assert "join-contains-SetAB"
		(member (Set (Concept "A") (Concept "B")) join-list))
	(test-assert "join-contains-SetABC"
		(member (Set (Concept "A") (Concept "B") (Concept "C")) join-list))

	; Verify atoms landed in atomspace (unlike MeetLink)
	(define roots (cog-get-all-roots))
	(test-assert "ListAB-in-atomspace"
		(member (List (Concept "A") (Concept "B")) roots))
	(test-assert "SetAB-in-atomspace"
		(member (Set (Concept "A") (Concept "B")) roots))

	(cog-set-value! storage (*-close-*))
)

(define join-link "test join-link")
(test-begin join-link)
(test-join-link)
(test-end join-link)

(whack "/tmp/cog-rocks-query-storage-test")

; -------------------------------------------------------------------
; Test 5: QueryLink - Graph Rewriting
; Verifies that QueryLink performs pattern matching and rewriting.

(define (test-query-link)
	(setup-and-store)

	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-query-storage-test"))
	(cog-set-value! storage (*-open-*))

	(define results-key (Predicate "results"))

	; Define rewrite query: find tails of (List A ?) and create (Ordered tail by tail)
	(define tail-by-tail (Query
		(TypedVariable (Variable "tail") (Type 'Concept))
		(Present (List (Concept "A") (Variable "tail")))
		(OrderedLink (Variable "tail") (Concept "by") (Variable "tail"))
	))

	(cog-set-value! storage (*-fetch-query-*) tail-by-tail results-key)
	(define result (cog-value tail-by-tail results-key))

	(test-assert "querylink-result-exists" result)
	(define rewrite-list (cog-value->list result))

	; Should contain rewrite for B (the only tail of List(A,?))
	(test-assert "querylink-contains-B-by-B"
		(member (OrderedLink (Concept "B") (Concept "by") (Concept "B"))
			rewrite-list))

	(cog-set-value! storage (*-close-*))
)

(define query-link "test query-link")
(test-begin query-link)
(test-query-link)
(test-end query-link)

; ===================================================================
(whack "/tmp/cog-rocks-query-storage-test")
(opencog-test-end)
