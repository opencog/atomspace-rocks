;
; OpenCog RocksDB Persistence module
;

(define-module (opencog persist-rocks))

(use-modules (opencog))
(use-modules (opencog rocks-config))
(load-extension
	(string-append opencog-ext-path-persist-rocks "libpersist-rocks")
	"opencog_persist_rocks_init")

(export cog-rocks-clear-stats cog-rocks-close cog-rocks-open
cog-rocks-stats cog-rocks-get cog-rocks-print
cog-rocks-check cog-rocks-scrub
)

; --------------------------------------------------------------

(set-procedure-property! cog-rocks-clear-stats 'documentation
"
 cog-rocks-clear-stats RSN - reset the performance statistics counters.

    This will zero out the various counters used to track the
    performance of the RocksDB backend.  Statistics will continue
    to be accumulated. RSN must be a RocksStorageNode, and it must
    be open.
")

(set-procedure-property! cog-rocks-close 'documentation
"
 cog-rocks-close - close the currently open RocksDB backend.

    Close open connections to the currently-open backend, after flushing
    any pending writes in the write queues. After the close, atoms can
    no longer be stored to or fetched from the database.

    As a side-effect, this will extract from the AtomSpace the
    RocksStorageNode holding the URL of the DB. This might be surprising.
")

(set-procedure-property! cog-rocks-open 'documentation
"
 cog-rocks-open URL - Open a connection to a RocksDB.

   The URL must be of the form:
      rocks://path/to/file

   This will create a RocksStorageNode holding the URL, and place it
   in the current AtomSpace.

   Examples of use with valid URL's:
      (cog-rocks-open \"rocks://var/local/opencog/data/rocks.db\")
")

(set-procedure-property! cog-rocks-stats 'documentation
"
 cog-rocks-stats RSN - report performance statistics.

    This will cause some database performance statistics to be printed
    to the stdout of the server. These statistics can be quite arcane
    and are useful primarily to the developers of the backend.

    RSN must be a RocksStorageNode, and it must be open.
")

(set-procedure-property! cog-rocks-get 'documentation
"
 cog-rocks-get PREFIX - internal-use-only debugging utility.

    PREFIX must be a prefix, for example \"a@\" or \"n@\" and so on.

    The DB must have been previously opened with `cog-rocks-open`.
    You probably want to use `cog-rocks-print` instead; it's simpler.
")

(set-procedure-property! cog-rocks-print 'documentation
"
 cog-rocks-print RSN PREFIX - internal-use-only debugging utility.

    RSN must be a RocksStorageNode.
    PREFIX must be a prefix, for example \"a@\" or \"n@\" and so on.
")

(set-procedure-property! cog-rocks-check 'documentation
"
 cog-rocks-check RSN - internal-use-only debugging utility.

    RSN must be a RocksStorageNode.

    Check self-consistency of the database.
")

(set-procedure-property! cog-rocks-scrub 'documentation
"
 cog-rocks-scrub RSN - Perform garbage collection.

    RSN must be a RocksStorageNode.

    After frame deletions, the databae might contain records of Atoms
    that are not in any frame. This function will delete them.
")
