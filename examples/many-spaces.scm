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
(cog-set-atomspace! as-main)

; The remaining three spaces are declared *after* setting the main
; space. This has the effect of causing them "exist" in the main space,
; but not otherwise having any sort of parent-child or inheritance or
; stacking semantics. They are placed in the main space, only so that
; they are not accidentally garbage-collected during the demo.
(define as-one (AtomSpace "foo"))
(define as-two (AtomSpace "bar"))
(define as-three (AtomSpace "bing"))

; Create an "index" of the spaces above. This is not required; however,
; if you plan to store many AtomSpaces together, you might want to record
; what you've packaged up. This is one possible way.
(Edge (Predicate "bundle") (List (Item "AtomSpace Bundle Alpha") as-one))
(Edge (Predicate "bundle") (List (Item "AtomSpace Bundle Alpha") as-two))
(Edge (Predicate "bundle") (List (Item "Bundle Beta") as-three))

; Verify that the the main space contains what you think it contains.
(cog-prt-atomspace)

; Now populate the various spaces with unique content.
; The prints help verify that contents are not bleeding over from one
; space to another. The result of the print should be what you think it
; should be.
(cog-set-atomspace! as-one)
(Concept "I am in Space One!")
(cog-prt-atomspace)

(cog-set-atomspace! as-two)
(Concept "Resident of Two, here!")
(cog-prt-atomspace)

(cog-set-atomspace! as-three)
(EdgeLink (Predicate "three-ness") (Item "Just an old lump of coal"))
(cog-prt-atomspace)

; Return to the main space
(cog-set-atomspace! as-main)

; Store the various AtmoSpaces. Here, they are stored in one big gulp,
; but it doesn't have to be done this way: they can be dribbled in.
; An initial call to `(*-store-frames-*)` can sometimes be optional, but is
; strongly recommended to avoid confusion. It effectively tells the
; StorageNode to expect multiple AtomSpaces to be stored. Here, it is
; optional ONLY because `as-main` was NOT stored first! The StorageNode
; notices that the very first stored AtomSpace differs from the space
; that the StorageNode is declared in, and thus deduces its will need to
; work in a multi-space mode.
(define rsn (RocksStorageNode "rocks:///tmp/bundle-demo"))
(cog-set-value! rsn (*-open-*))
; (cog-set-value! rsn (*-store-frames-*) as-main)
(cog-set-value! rsn (*-store-atomspace-*) as-one)
(cog-set-value! rsn (*-store-atomspace-*) as-two)
(cog-set-value! rsn (*-store-atomspace-*) as-three)
(cog-set-value! rsn (*-store-atomspace-*) as-main)
(cog-set-value! rsn (*-close-*))

; -------------------------------------------------
; Done with the store. Now exist guile completely, and restart. Or,
; if you are truly lazy, just clear the main AtomSpace. The demo is
; more convincing, if you just exit and restart.
(cog-atomspace-clear)

; -------------------------------------------------
; Restart.
(use-modules (opencog) (opencog persist) (opencog persist-rocks))

; The spaces are identified by the names that they are given. So, on
; restart, be sure to recreate with the same name; else confusion will
; result.
(define as-main (AtomSpace "main space"))
(cog-set-atomspace! as-main)

; Define the database location, and open it.
(define rsn (RocksStorageNode "rocks:///tmp/bundle-demo"))
(cog-set-value! rsn (*-open-*))

; Print the current main space. It should be nearly empty, but for the
; StorageNode declaration, and ObjectNode messages being sent to it.
(cog-prt-atomspace)

; Restore the second space first. The point here is that the restore
; order does not matter. Print it out and make sure it has the contents
; you think it should.
(define as-two (AtomSpace "bar"))
(cog-set-atomspace! as-two)
(cog-set-value! rsn (*-load-atomspace-*) as-two)
(cog-prt-atomspace)

; Lets go back to the main space. Make sure there was no leakage.
(cog-set-atomspace! as-main)
(cog-prt-atomspace)

; Now get the next one. Unlike the last time, we don't set it as the
; current space. That's OK, it will still load correctly. Note that the
; print will happen in the main space, and not the loaded space.
(define as-one (AtomSpace "foo"))
;;; (cog-set-atomspace! as-one) ; Skip me!
(cog-set-value! rsn (*-load-atomspace-*) as-one)
(cog-prt-atomspace)

; Switch spaces and print. Make sure these are what you expect.
(cog-set-atomspace! as-one)
(cog-prt-atomspace)

(cog-set-atomspace! as-two)
(cog-prt-atomspace)

(cog-set-atomspace! as-main)
(cog-prt-atomspace)

; Now load the main space. This will have the "indexes" that were
; created earlier.
(cog-set-value! rsn (*-load-atomspace-*) as-main)
(cog-prt-atomspace)

; What about the third space? It's currently empty ...
(define as-three (AtomSpace "bing"))
(cog-set-atomspace! as-three)
(cog-prt-atomspace)

; Load it, and see. When `(*-load-atomspace-*)` is used, the atomspace
; to load must be specified.
(cog-set-value! rsn (*-load-atomspace-*) (cog-atomspace))
(cog-prt-atomspace)

; Tidy conclusion.
(cog-set-value! rsn (*-close-*))

; The End. That's All, Folks!
; -------------------------------------------------------------------
