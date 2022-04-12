;
; space-frame-test.scm
; Test ability to store multiple atomspaces.
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(opencog-test-runner)

; -------------------------------------------------------------------
; Common setup, used by all tests.

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

; Store the content
(define storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
(cog-open storage)
(store-atom (ListLink (Concept "foo") (Concept "bar")))
(cog-close storage)

; Clear out the spaces, start with a clean slate.
(cog-atomspace-clear surface-space)
(cog-atomspace-clear mid2-space)
(cog-atomspace-clear mid1-space)
(cog-atomspace-clear base-space)

; -------------------------------------------------------------------
; Test that deep links are found correctly.

(define deep-link "test deep links")
(test-begin deep-link)

; Load everything.
(cog-set-atomspace! surface-space)
(set! storage (RocksStorageNode "rocks:///tmp/cog-rocks-unit-test"))
(cog-open storage)
(load-atomspace)
(cog-close storage)

; Wwork on the current surface, but expect to find the deeper ListLink.
(define lilly (ListLink (Concept "foo") (Concept "bar")))

(test-equal "link-space" mid2-space (cog-atomspace lilly))
(test-equal "foo-space" base-space (cog-atomspace (gar lilly)))
(test-equal "bar-space" mid1-space (cog-atomspace (gdr lilly)))

(test-end deep-link)
