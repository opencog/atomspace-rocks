;
; load-dump.scm
;
; Demo showing how to load, or dump, large segments of the AtomSpace,
; including the ENTIRE AtomSpace. Caution: for large AtomSpaces, loading
; everything can be slow, and is generally not needed. Thus, one can
; load portions of the AtomSpace:
;
; load-referers ATOM -- to load only those graphs containing ATOM
; load-atoms-of-type TYPE -- to load only atoms of type TYPE
; load-atomspace -- load everything.
;
; store-referers ATOM -- store all graphs that contain ATOM
; store-atomspace -- store everything.
;
; -------------------------------
; Basic initialization and set-up
;
(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-rocks))

; ---------------------------------------
; Create some Atoms; attach some Values to them.
;
; Lets create some Atoms, and then store everything.
(cog-set-value! (Concept "foo") (Predicate "some place")
	(FloatValue 0.1 0.2))
(cog-set-value! (Concept "bar") (Predicate "some place")
	(FloatValue 0.3 0.4))
(Set (List (Set (List (Concept "bazzzz")))))
(cog-set-value! (Concept "bazzzz") (Predicate "other place")
	(FloatValue 0.5 0.6))

; ---------------------------------------
; Open a database, and store the entire AtomSpace.
;
(define rsn (RocksStorageNode "rocks:///tmp/foo.rdb"))
(cog-open rsn)
(store-atomspace)
(cog-close rsn)

; Remove everything in the AtomSpace ...
(cog-atomspace-clear)

; Verify the AtomSpace is empty
(cog-get-all-roots)

; Reconnect to the database, and fetch everything in it.
; The StorageNode needs to be re-declaredm since the `clear`,
; above, wiped it out.
(set! rsn (RocksStorageNode "rocks:///tmp/foo.rdb"))
(cog-open rsn)
(load-atomspace)
(cog-close rsn)

; Verify that everything came back
(cog-get-all-roots)

; That's all folks!  Thanks for paying attention!
; -----------------------------------------------
