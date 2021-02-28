;
; multiple-databases.scm
;
; Demo of using StorageNodes.
;
; This is an alternative to `cog-rocks-open` and allows multiple
; databases to be open at the same time.
;
; ----------------------------------------------
; Getting started, making the initial connection.
;
(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-rocks))

; Database specifications are just Nodes!
(define foo-store (RocksStorageNode "rocks:///tmp/foo.rdb"))
(define bar-store (RocksStorageNode "rocks:///tmp/bar.rdb"))

(cog-open foo-store)
(cog-open bar-store)

; -------------
; Storing Atoms
;
(cog-set-value! (Concept "a") (Predicate "a-key") (FloatValue 1 2 3))
(cog-set-value! (Concept "b") (Predicate "b-key") (FloatValue 4 5 6))

; Save each atom in a distinct AtomSpace
(store-atom (Concept "a") foo-store)
(store-atom (Concept "b") bar-store)

; Close the connections to each.
(cog-close foo-store)
(cog-close bar-store)

; -------------
; Erase everything in the AtomSpace. Do this to avoid confusion in
; the next steps. Alternately, quit guile, and restart guile.
(clear)

; -------------
; Loading Atoms
;
; The previous AtomSpace clear wiped out everything. Start all over.
(define foo-store (RocksStorageNode "rocks:///tmp/foo.rdb"))
(cog-open foo-store)
(load-atomspace foo-store)

; Verify that only (ConceptNode "a") is in the AtomSpace.
(cog-get-all-roots)

; Now open the second database
(define bar-store (RocksStorageNode "rocks:///tmp/bar.rdb"))
(cog-open bar-store)
(load-atomspace bar-store)

; Verify that both (Concept "a") and (Concept "b") are present.
(cog-get-all-roots)

; We're done.
(cog-close foo-store)
(cog-close bar-store)

; That's all! Thanks for paying attention!
; -------------
