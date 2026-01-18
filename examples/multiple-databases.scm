;
; multiple-databases.scm
;
; Demo of using multiple StorageNodes at the same time.
;
; ----------------------------------------------
; Getting started, making the initial connection.
;
(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-rocks))

; Database specifications are just Nodes!
(define foo-store (RocksStorageNode "rocks:///tmp/foo.rdb"))
(define bar-store (RocksStorageNode "rocks:///tmp/bar.rdb"))

(cog-set-value! foo-store (*-open-*))
(cog-set-value! bar-store (*-open-*))

; -------------
; Storing Atoms
;
(cog-set-value! (Concept "a") (Predicate "a-key") (FloatValue 1 2 3))
(cog-set-value! (Concept "b") (Predicate "b-key") (FloatValue 4 5 6))

; Save each atom in a distinct database
(cog-set-value! foo-store (*-store-atom-*) (Concept "a"))
(cog-set-value! bar-store (*-store-atom-*) (Concept "b"))

; Close the connections to each.
(cog-set-value! foo-store (*-close-*))
(cog-set-value! bar-store (*-close-*))

; -------------
; Erase everything in the AtomSpace. Do this to avoid confusion in
; the next steps. Alternately, quit guile, and restart guile.
(cog-atomspace-clear)

; -------------
; Loading Atoms
;
; The previous AtomSpace clear wiped out everything. Start all over.
(define foo-store (RocksStorageNode "rocks:///tmp/foo.rdb"))
(cog-set-value! foo-store (*-open-*))
(cog-set-value! foo-store (*-load-atomspace-*) (cog-atomspace))

; Verify that only (ConceptNode "a") is in the AtomSpace.
(cog-get-all-roots)

; Now open the second database
(define bar-store (RocksStorageNode "rocks:///tmp/bar.rdb"))
(cog-set-value! bar-store (*-open-*))
(cog-set-value! bar-store (*-load-atomspace-*) (cog-atomspace))

; Verify that both (Concept "a") and (Concept "b") are present.
(cog-get-all-roots)

; We're done.
(cog-set-value! foo-store (*-close-*))
(cog-set-value! bar-store (*-close-*))

; That's all! Thanks for paying attention!
; -------------
