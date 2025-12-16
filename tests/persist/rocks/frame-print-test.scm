#! /usr/bin/env guile
-s
!#
;
; frame-print-test.scm
; Test for crash (null-pointer deref) for a simple usercase.
;
; The crash was in AtomSpace code.
; See https://github.com/opencog/atomspace-rocks/issues/20
; for details.
; The fix is in https://github.com/opencog/atomspace/pull/3037
;
(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog test-runner))
(use-modules (opencog persist) (opencog persist-rocks))

(include "test-utils.scm")
(whack "/tmp/cog-rocks-frame-print-test")

(opencog-test-runner)

; -------------------------------------------------------------------
; Test that load of a series of nested links is done correctly.

(define (test-print)

	(define a (AtomSpace))
	(define b (AtomSpace))
	(define c (AtomSpace a b))

	(cog-set-atomspace! a)
	(Concept "I'm in A")
	(cog-prt-atomspace)

	(cog-set-atomspace! b)
	(Concept "I'm in B")
	(cog-prt-atomspace)

	(cog-set-atomspace! c)
	(define rsn (RocksStorageNode "rocks:///tmp/cog-rocks-frame-print-test"))
	(cog-open rsn)
	(store-atomspace)
	(cog-prt-atomspace)

	(cog-close rsn)
)

(define test-name "test print")
(test-begin test-name)
(test-print)
(test-end test-name)

; ===================================================================
(whack "/tmp/cog-rocks-frame-print-test")
(opencog-test-end)
