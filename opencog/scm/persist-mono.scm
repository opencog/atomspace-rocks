;
; OpenCog RocksDB Single-AtomSpace Persistence module
;

(define-module (opencog persist-mono))

(use-modules (opencog))
(use-modules (opencog rocks-config))
; Load the C library that calls the classserver to load the types.
(load-extension
	(string-append opencog-ext-path-persist-rocks-types "libpersist-rocks-types")
		"persist_rocks_types_init")

; Load the persist-rocks types scheme bindings
(load-from-path "opencog/persist/rocks-types/persist_rocks_types.scm")

(load-extension
	(string-append opencog-ext-path-persist-mono "libpersist-monospace")
	"opencog_persist_mono_init")

(export cog-mono-clear-stats cog-mono-close cog-mono-open
cog-mono-stats cog-mono-print)

; --------------------------------------------------------------

(set-procedure-property! cog-mono-clear-stats 'documentation
"
 cog-mono-clear-stats MSN - reset the performance statistics counters.
    This will zero out the various counters used to track the
    performance of the RocksDB backend.  Statistics will continue to
    be accumulated.

    MSN must be a MonoStorageNode, and it must be open for reading.
")

(set-procedure-property! cog-mono-close 'documentation
"
 cog-mono-close - close the currently open RocksDB backend.
    Close open connections to the currently-open backend, after flushing
    any pending writes in the write queues. After the close, atoms can
    no longer be stored to or fetched from the database.
")

(set-procedure-property! cog-mono-open 'documentation
"
 cog-mono-open URL - Open a connection to a RocksDB.

  The URL must be of the form:
     mono://path/to/file

  Examples of use with valid URL's:
     (cog-mono-open \"mono://var/local/opencog/data/mono.db\")
")

(set-procedure-property! cog-mono-stats 'documentation
"
 cog-mono-stats MSN - report performance statistics.
    This will cause some database performance statistics to be printed
    to the stdout of the server. These statistics can be quite arcane
    and are useful primarily to the developers of the backend.

    MSN must be a MonoStorageNode, and it must be open for reading.
")

(set-procedure-property! cog-mono-print 'documentation
"
 cog-mono-print MSN PREFIX - internal-use-only debugging utility.
    MSN must be a MonoStorageNode.
    PREFIX must be a prefix, for example \"a@\" or \"n@\" and so on.
")
