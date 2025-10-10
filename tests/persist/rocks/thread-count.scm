;
; thread-count.scm
;
; Part of ThreadCountUTest.cxxtest
;
(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-rocks))

(use-modules (ice-9 threads))

(define sto (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
(define (open-sto) (cog-open sto))
(define (close-sto) (cog-close sto))

(define (do-inc-cnt! ATOM CNT)
	(cog-inc-value! ATOM (Predicate "kayfabe") CNT 2))

; Increment and store. Increments are atomic.
(define (observe TXTA TXTB)
	(define ca (Concept TXTA))
	(define cb (Concept TXTB))
	(define edge (Edge (Predicate "foo") (List ca cb)))
	(do-inc-cnt! ca 1)
	(do-inc-cnt! cb 1)
	(do-inc-cnt! edge 1)
	(store-atom ca)
	(store-atom cb)
	(store-atom edge)
)

; Same as above, but with AtomSpace push-pop weirdness.
; XXX FIXME This is failing and it really shouldn't and
; I can't be bothered to fix it right now.
(define (pushy TXTA TXTB)
	(define base-as (cog-push-atomspace))
	(define ca (Concept TXTA))
	(define cb (Concept TXTB))
	(define edge (Edge (Predicate "foo") (List ca cb)))

	(cog-set-atomspace! base-as)
	(do-inc-cnt! ca 1)
	(do-inc-cnt! cb 1)
	(do-inc-cnt! edge 1)
	(store-atom ca)
	(store-atom cb)
	(store-atom edge)

	(cog-pop-atomspace)
)

(define mtx (make-mutex))

; Fetch, increment and store.
(define (fetchy TXTA TXTB)
	(define ca (Concept TXTA))
	(define cb (Concept TXTB))
	(define edge (Edge (Predicate "foo") (List ca cb)))

	; Provide a safe fetch that does not race.
	(lock-mutex mtx)
	(fetch-atom edge)
	(do-inc-cnt! edge 1)
	(store-atom edge)
	(unlock-mutex mtx)

	; These will race and ruin the counts.
	(fetch-atom ca)
	(fetch-atom cb)
	(do-inc-cnt! ca 1)
	(do-inc-cnt! cb 1)
	(store-atom ca)
	(store-atom cb)
)

; ---------- the end --------
