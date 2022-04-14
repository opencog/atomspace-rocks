;
; space-frame-test.scm
; Test ability to store multiple atomspaces.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(opencog-test-runner)

; Delete the directory `dirname` and everything in it.
; I don't understand why scheme doesn't provide this, built-in.
(define (whack dirname)
	(define (unlink dir)
		(define fname (readdir dir))
		(when (not (eof-object? fname))
			(let ((fpath (string-append dirname "/" fname)))
				(when (equal? 'regular (stat:type (stat fpath)))
					(delete-file fpath))
				(unlink dir))))

	(when (access? dirname F_OK)
		(let ((dir (opendir dirname)))
			(unlink dir)
			(closedir dir)
			(rmdir dirname))))

(whack "/tmp/cog-rocks-unit-test")

; -------------------------------------------------------------------
; Common setup, used by all tests.

(define base-space (cog-atomspace))
(define mid1-space (cog-new-atomspace base-space))
(define mid2-space (cog-new-atomspace mid1-space))
(define surface-space (cog-new-atomspace mid2-space))

(define (setup-and-store)
	; Splatter some atoms into the various spaces.
	(cog-set-atomspace! base-space)
	(Concept "foo" (ctv 1 0 3))

	(cog-set-atomspace! mid1-space)
	(Concept "bar" (ctv 1 0 4))

	(cog-set-atomspace! mid2-space)
	(ListLink (Concept "foo") (Concept "bar") (ctv 1 0 5))

	(cog-set-atomspace! surface-space)

	; Store the content. Store the Concepts as well as the link,
	; as otherwise, the TV's on the Concepts aren't stored.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(store-atom (ListLink (Concept "foo") (Concept "bar")))
	(store-atom (Concept "foo"))
	(store-atom (Concept "bar"))
	(cog-close storage)

	; Clear out the spaces, start with a clean slate.
	(cog-atomspace-clear surface-space)
	(cog-atomspace-clear mid2-space)
	(cog-atomspace-clear mid1-space)
	(cog-atomspace-clear base-space)
)

; Destroy the atomspaces
(define (zap-spaces)
	(set! surface-space #f)
	(set! mid2-space #f)
	(set! mid1-space #f)
	(set! base-space #f)
)

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; -------------------------------------------------------------------
; Test that deep links are found correctly.

(define (test-deep-link)
	(setup-and-store)

	; Load everything.
	(cog-set-atomspace! surface-space)
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(load-atomspace)
	(cog-close storage)

	; Work on the current surface, but expect to find the deeper ListLink.
	(define lilly (ListLink (Concept "foo") (Concept "bar")))

	; Verify appropriate atomspace membership
	(test-equal "link-space" mid2-space (cog-atomspace lilly))
	(test-equal "foo-space" base-space (cog-atomspace (gar lilly)))
	(test-equal "bar-space" mid1-space (cog-atomspace (gdr lilly)))

	; Verify appropriate values
	(test-equal "base-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "mid1-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "mid2-tv" 5 (get-cnt lilly))
)

(define deep-link "test deep links")
(test-begin deep-link)
(test-deep-link)
(test-end deep-link)

; -------------------------------------------------------------------
; Same as above, except without the pre-existing atomspace hierachty.

(define (test-fresh-link)
	(setup-and-store)
	(zap-spaces)

	(define new-base (cog-new-atomspace))
	(cog-set-atomspace! new-base)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)

	; Load all of the AtomSpaces.
	(define surface (load-frames))
	(cog-set-atomspace! surface)

	; Now load the AtomSpace itself
	(load-atomspace)
	(cog-close storage)

	; Work on the current surface, but expect to find the deeper ListLink.
	(define lilly (ListLink (Concept "foo") (Concept "bar")))

	; Verify appropriate atomspace membership
	; Note that the new surface corresponds to the older mid2-space.
	; This is because the old surface-space was never actually stored
	; and thus is never restored. The top-most space of the restored
	; hiearchy is the old mid2-space.
	(define mid-space (cog-outgoing-atom surface 0))
	(test-equal "link-space" surface (cog-atomspace lilly))
	(test-equal "foo-space" new-base (cog-atomspace (gar lilly)))
	(test-equal "bar-space" mid-space (cog-atomspace (gdr lilly)))

	; Verify appropriate values
	(test-equal "base-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "mid1-tv" 4 (get-cnt (cog-node 'Concept "bar")))
	(test-equal "mid2-tv" 5 (get-cnt lilly))
)

(define fresh-link "test fresh link restore")
(test-begin fresh-link)
(test-fresh-link)
(test-end fresh-link)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
