;
; test-utils.scm
; Shared scheme test utilities.
;
(use-modules (srfi srfi-1))

(define pk (Predicate "kayfabe"))
(define (set-cnt! ATOM FV) (cog-set-value! ATOM (Predicate "kayfabe") FV))
(define (get-cnt ATOM) (inexact->exact (cog-value-ref (cog-value ATOM (Predicate "kayfabe")) 2)))

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

; ===================================================================
