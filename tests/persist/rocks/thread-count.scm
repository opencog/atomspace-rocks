;
; thread-count.scm
;
; Part of ThreadCountUTest.cxxtest
;
(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-rocks))

(define sto (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
(define (open-sto) (cog-open sto))
(define (close-sto) (cog-close sto))

; Increment and store.
(define (observe TXTA TXTB)
	(define ca (Concept TXTA))
	(define cb (Concept TXTB))
	(define edge (Edge (Predicate "foo") (List ca cb)))
	(cog-inc-count! ca 1)
	(cog-inc-count! cb 1)
	(cog-inc-count! edge 1)
	(store-atom ca)
	(store-atom cb)
	(store-atom edge)
)

; Same as above, but with AtomSpace push-pop weirdness.
(define (pushy TXTA TXTB)
	(define base-as (cog-push-atomspace))
	(define ca (Concept TXTA))
	(define cb (Concept TXTB))
	(define edge (Edge (Predicate "foo") (List ca cb)))

	(cog-set-atomspace! base-as)
	(cog-inc-count! ca 1)
	(cog-inc-count! cb 1)
	(cog-inc-count! edge 1)
	(store-atom ca)
	(store-atom cb)
	(store-atom edge)

	(cog-pop-atomspace)
)

; Fetch, increment and store.
(define (fetchy TXTA TXTB)
	(define ca (Concept TXTA))
	(define cb (Concept TXTB))
	(define edge (Edge (Predicate "foo") (List ca cb)))
	(fetch-atom ca)
	(fetch-atom cb)
	(fetch-atom edge)
	(cog-inc-count! ca 1)
	(cog-inc-count! cb 1)
	(cog-inc-count! edge 1)
	(store-atom ca)
	(store-atom cb)
	(store-atom edge)
)

; ---------- the end --------
