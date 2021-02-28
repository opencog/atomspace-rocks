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

; Take a look at it:
(cog-keys->alist (Concept "a"))

; Save it:
(store-atom (Concept "a"))

; Delete it from the AtomSpace (but not from RocksDB):
(cog-extract! (Concept "a"))

; Verify the AtomSpace no longer contains `(Concept "a")`.
; It will still contain the two keys that were used; they might
; be in use by other Atoms and so cannot be safely removed.
(cog-get-all-roots)

; Fetch one of the Values, but not the other:
(fetch-value (Concept "a") (Predicate "blo"))

; Take a look at it:
(cog-keys->alist (Concept "a"))

; Change the value (but don't store it)
(cog-set-value! (Concept "a") (Predicate "blo") (StringValue "a" "b" "c"))

; Load all key-value pairs on (Concept "a")
(fetch-atom (Concept "a"))

; Verify that all of the keys arrived. Notice that the "new" Value
; on (Predicate "blo") was clobbered by the one fetched from the
; database.
(cog-keys->alist (Concept "a"))

; p.s. "flo blo" is how they say "flow blue" in Texas.
; That's all! Thanks for paying attention!
; ----------------------------------------
