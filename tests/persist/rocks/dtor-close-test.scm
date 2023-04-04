;
; Test for issue #19 -- Destructor not being called.

(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-rocks))

(define rsn (RocksStorageNode "rocks:///tmp/foo.rdb"))
(cog-open rsn)

; Create and store some data.
(List (Concept "A") (Concept "B"))
(Set (Concept "A") (Concept "B"))
(Set (Concept "A") (Concept "B") (Concept "C"))
(store-atomspace)

; Clear the local AtomSpace (the Atoms remain on disk, just not in RAM).
(cog-atomspace-clear)

; The above wipes out the StorageNode, the dtor should run and close
; the connection. But it doesn't ...

(define rsn (RocksStorageNode "rocks:///tmp/foo.rdb"))
(cog-open rsn)
(load-atomspace)

