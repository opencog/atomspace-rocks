;
; fetch-store.scm
;
; Demo of basic fetching individual atoms from the database,
; as well as storing (saving) them for later.
;
; ----------------------------------------------
; Getting started, making the initial connection.
;
(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-rocks))

; Note three slashes, not two!
(cog-rocks-open "rocks:///tmp/foo.rdb")

; --------------
; Storing and Loading Atoms
;
; Start by creating some data - an Atom with some values on it:
(cog-set-value! (Concept "a") (Predicate "flo") (FloatValue 1 2 3))
(cog-set-value! (Concept "a") (Predicate "blo") (FloatValue 4 5 6))
(store-atom (Concept "a"))

; Take a look at it:
(cog-keys->alist (Concept "a"))

; Save it:
(store-atom (Concept "a"))

; Delete it from the AtomSpace:
(cog-extract! (Concept "a"))

; Verify the AtomSpace is empty:
(cog-get-all-roots)

; Load it back:
(fetch-atom (Concept "a"))

; Verify that all of the keys arrived:
(cog-keys->alist (Concept "a"))

; That's all! Thanks for paying attention!
; ----------------------------------------
