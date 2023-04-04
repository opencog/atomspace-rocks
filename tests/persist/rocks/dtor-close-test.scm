;
; Test for issue #19 -- Destructor not being called.
; The fix is in the AtomSpace, but its easier to check here.

(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-unit-test")

(opencog-test-runner)

(define test-close-open "test dtor-close")
(test-begin test-close-open)

(define rsn (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
(cog-open rsn)

; Create and store some data.
(List (Concept "A") (Concept "B"))
(Set (Concept "A") (Concept "B"))
(Set (Concept "A") (Concept "B") (Concept "C"))
(store-atomspace)

; Clear the local AtomSpace (the Atoms remain on disk, just not in RAM).
(cog-atomspace-clear)

; The above wipes out the StorageNode, the dtor should run and close
; the connection. But it doesn't, because the persist module is holding
; in a global.
(test-equal #f (cog-atom? rsn))

(define rsn (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
(cog-open rsn)
(load-atomspace)

(test-equal #t (cog-atom? rsn))

(cog-close rsn)
(test-end test-close-open)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
