;
; Test for issue #19 -- Destructor not being called.
; The fix is in the AtomSpace, but its easier to check here.

(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-dtor-close-test")

(opencog-test-runner)

(define test-close-open "test dtor-close")
(test-begin test-close-open)

(define rsn (RocksStorageNode "rocks:///tmp/cog-rocks-dtor-close-test"))
(cog-open rsn)

; Create and store some data.
(List (Concept "A") (Concept "B"))
(Set (Concept "A") (Concept "B"))
(Set (Concept "A") (Concept "B") (Concept "C"))
(store-atomspace)

; The user should call (cog-close rsn) right now, but doesn't.
; And this is what we're testing, here: some quasi-reasonable
; behavior, even if the user screws up.
;
; Clear the local AtomSpace (the Atoms remain on disk, just not in RAM).
; This removes the Atom from the AtomSpace, but it remains live, because
; the scheme smob 'rsn' still points to it.
(cog-atomspace-clear)

; In addition to 'rsn' pointing at the Atom, the persist module retains
; a global pointer to the current (still open!) StorageNode. To close,
; two things must happen:
; (1) decrement the Atom use count by one, by clobbering the Handle
;     in the scheme smob rsn
; (2) decrement the Atom use count by one, by clobbering the Handle
;     in the persist module.
; Only after both happen (so that the use count goes to zero), will the
; StorageNode dtor run, closing the connection.
;
; Step (2) happens when the (cog-open) below is called. But that leaves
; the use count at one, and so the DB connection remains open, and this
; second open segfaults, because the DB lock is still held. So we have
; to also force (1) to happen. There are two ways to do this:
; (a) Dereference the handle to the Atom held in opencog/guile somehow.
;     Most such dereferences will clobber the three-word *(SMOB) pointer,
;     which is an instance of ValuePtr, thus decrementing the use count.
;     For example, attempting to print the Atom will clobber it.
; (b) (set! rsn #f) and run (gc) to force the Handle to be gc'ed.
;
; Either (a) or (b) will work. We chose (a) for this test.
;
; Touch the Atom. Is it in this AtomSpace? No it isn't.
; This is the one guile operation that can be performed on a guile
; handle that will NOT decrement the use count. It stays alive, because
; it can still be used to insert the Atom is some other AtomSpace.
(test-equal #f (cog-atom rsn))

; Asking if the rsn guile SMOB is an Atom will reference the SMOB,
; which will clobber the Handle, because it is not in any AtomSpace.
; The clobber will decrement the use count.
;
; Why should `cog-atom?` clobber the reference? Because a common use
; case is to cog-extract/delete some Atom, and then use cog-atom?
; to determine if the Atom is actually deleted.
(test-equal #f (cog-atom? rsn))

; Accessing it by printing it will clobber the guile smob pointer.
; Well, we already clobbered it with the `cog-atom?` above, so we
; don't need this. Anyway, we need ither abovem or the print below,
; or some other access.
;
; Note that the define, further below, will not clobber it, but only
; release it. A round of gc's would be needed for the actual release.
; Blech. Either will work.
; (format #t "The rsn right now is: ~A\n" rsn)

; The above clobber means the guile rsn smob no longer points
; to an Atom.  There is still a global pointer to it, in the
; persist module, and so the destructor has not yet run. The
; use-count on the thing is now one. It will drop to zero, when
; the cog-open below clobbers the old global pointer.
(test-equal #f (cog-atom? rsn))

(define rsn (RocksStorageNode "rocks:///tmp/cog-rocks-dtor-close-test"))
(cog-open rsn)
(load-atomspace)

(test-equal #t (cog-atom? rsn))

(cog-close rsn)
(test-end test-close-open)

; ===================================================================
(whack "/tmp/cog-rocks-dtor-close-test")
(opencog-test-end)
