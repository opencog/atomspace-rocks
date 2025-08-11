;
; space-delete-test.scm
; Test ability to delete an atomspace.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-unit-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

(define (setup-and-store)
	(define base-space (cog-atomspace))
	(define mid1-space (cog-new-atomspace base-space))
	(define mid2-space (cog-new-atomspace mid1-space))
	(define surface-space (cog-new-atomspace mid2-space))

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
	(store-frames surface-space)
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

; -------------------------------------------------------------------
; Delete the top-most frame in storage.

(define (delete-top-frame)

	; Start with a blank slate.
	(cog-set-atomspace! (cog-new-atomspace))

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	; (cog-rocks-print storage "")

	(define top-space (car (load-frames)))
	(delete-frame! top-space)
	(cog-close storage)
)

; -------------------------------------------------------------------
; Test that frames can be deleted.

(define (get-cnt ATOM) (inexact->exact (cog-count ATOM)))

; Return depth of the atomspace.
(define (count-depth space cnt)
	(if (< 0 (length (cog-outgoing-set space)))
		(count-depth (gar space) (+ 1 cnt))
		cnt))

(define (test-delete-frame)
	(setup-and-store)

	; (cog-rocks-open "rocks:///tmp/cog-rocks-unit-test")
	; (cog-rocks-stats)
	; (cog-rocks-get "")
	; (cog-rocks-close)

	; Start with a blank slate.
	; FYI, `keep-me-around` is some subtle non-obvious hackery,
	; We put the StorageNode into this AtomSpace, but if we're
	; not careful, the various cog-set-atomspace! will leave it
	; with a reference count of zero. If it gets garbage collected,
	; well, the StorageNode disappears too, Oh No! So create a
	; reference, and (this is important) **make sure** the ref
	; is actually referenced at the very end, i.e. so that it does
	; not accidentally go out of scope!
	(define keep-me-around (cog-new-atomspace))
	(cog-set-atomspace! keep-me-around)

	; Load everything.
	(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
	(cog-open storage)
	(define top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	(test-equal "top-depth" 4 (count-depth top-space 1))

	(delete-top-frame)

	; Load everything. Again.
	(cog-set-atomspace! (cog-new-atomspace))
	(cog-open storage)
	(set! top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	(test-equal "top-depth" 3 (count-depth top-space 1))

	(delete-top-frame)

	; Load everything. Again.
	(cog-set-atomspace! (cog-new-atomspace))
	(cog-open storage)
	(set! top-space (car (load-frames)))
	(cog-set-atomspace! top-space)
	(load-atomspace)
	(cog-close storage)

	(test-equal "top-depth" 2 (count-depth top-space 1))

	; Grab references into the inheritance hierarchy
	(define mid1-space top-space)
	(define base-space (cog-outgoing-atom mid1-space 0))

	(test-assert "lily-gone" (nil? (cog-link 'ListLink
		(Concept "foo") (Concept "bar"))))

	; Verify appropriate atomspace membership
	(test-equal "foo-space" base-space (cog-atomspace (cog-node 'Concept "foo")))
	(test-equal "bar-space" mid1-space (cog-atomspace (cog-node 'Concept "bar")))

	; Verify appropriate values
	(test-equal "base-tv" 3 (get-cnt (cog-node 'Concept "foo")))
	(test-equal "mid1-tv" 4 (get-cnt (cog-node 'Concept "bar")))

	; Make sure the first atomspace remains in scope!
	(format #t "The keeper is ~A\n" keep-me-around)
)

(define delete-frame "test deletion of frames")
(test-begin delete-frame)
(test-delete-frame)
(test-end delete-frame)

; ===================================================================
(whack "/tmp/cog-rocks-unit-test")
(opencog-test-end)
