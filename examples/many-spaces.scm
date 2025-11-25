;
; many-spaces,scm -- Storing many AtomSpaces into one StorageNode.
;
; A StorageNode can hold more than one AtomSpace at a time. In this
; demo, they are all independent of one another. They are disjoint.
; The space-frames.scm demo offers a different idea: stacking one on
; top another, so that the stacked spaces hold changes (deltas) to the
; spaces below. Here, in this demo, they are just merely disjoint and
; unrelated.
;
(use-modules (opencog) (opencog persist) (opencog persist-rocks))

; ---------------------------------------------------------------
; Create four AtomSpaces. One will be called the "main space"; it's
; not actually special, but plays a convenient role for the demo.
(define as-main (AtomSpace "main space"))
(define as-one (AtomSpace "foo"))
(define as-two (AtomSpace "bar"))
(define as-three (AtomSpace "bing"))

; Make sure we are running in the main space. Create an index of the
; spaces above. Ths is not required; however, if you plan to store many
; AtomSpaces together, you might want to record what you've packaged up.
(cog-set-atomspace! as-main)
(Edge (Predicate "bundle") (List (Item "AtomSpace Bundle Alpha") as-one))
(Edge (Predicate "bundle") (List (Item "AtomSpace Bundle Alpha") as-two))
(Edge (Predicate "bundle") (List (Item "Bundle Beta") as-three))

(cog-prt-atomspace)
(cog-set-atomspace! as-one)
(Concept "I am in as One!")
(cog-prt-atomspace)

(cog-set-atomspace! as-two)
(Concept "Resident of Two, here!")
(cog-prt-atomspace)

(cog-set-atomspace! as-three)
(EdgeLink (Predicate "three-ness") (Item "Just an old lump of coal"))
(cog-prt-atomspace)

(cog-set-atomspace! as-main)

(define rsn (RocksStorageNode "rocks:///tmp/bundle-demo"))
(cog-open rsn)
; (store-frames as-one)
(store-atomspace as-one)
; (store-frames as-two)
; (store-frames as-three)
(store-atomspace as-two)
(cog-close rsn)

(cog-atomspace-clear)
; -------------------------------------------------
(use-modules (opencog) (opencog persist) (opencog persist-rocks))

(define as-main (cog-atomspace))
(define rsn (RocksStorageNode "rocks:///tmp/bundle-demo"))
(cog-open rsn)
; (load-frames)

(cog-prt-atomspace)

(define as-two (AtomSpace "bar"))
(cog-set-atomspace! as-two)
(load-atomspace as-two)
(cog-prt-atomspace)

(cog-set-atomspace! as-main)
(cog-prt-atomspace)

(define as-one (AtomSpace "foo"))
; (cog-set-atomspace! as-one)
(load-atomspace as-one)
(cog-prt-atomspace)

(cog-set-atomspace! as-one)
(cog-prt-atomspace)

(cog-set-atomspace! as-two)
(cog-prt-atomspace)

(cog-set-atomspace! as-main)
(cog-prt-atomspace)


