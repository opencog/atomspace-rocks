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

; Note three slashes, not two!
(cog-rocks-open "rocks:///tmp/foo.rdb")

; ---------------------------------------
; Create and store Atoms to the database.
;
; Lets create some Atoms, and then store everything.
(Concept "foo" (stv 0.1 0.2))
(Concept "bar" (stv 0.3 0.4))
(Set (List (Set (List (Concept "bazzzz" (stv 0.5 0.6))))))
(store-atomspace)

; Log out ...
(cog-rocks-close)

; Remove everything in the AtomSpace ...
(cog-atomspace-clear)

; Verify the AtomSpace is empty
(cog-get-all-roots)

; Reconnect to the database, and fetch everything in it.
(cog-rocks-open "rocks:///tmp/foo.rdb")
(load-atomspace)

; Verify that everything came back
(cog-get-all-roots)

; That's all folks!  Thanks for paying attention!
; -----------------------------------------------
