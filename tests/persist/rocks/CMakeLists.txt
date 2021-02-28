
# Unit tests

LINK_LIBRARIES(
	persist-rocks
   persist
   atomspace
)

# The nine unit tests, ported over from the
# atomspace/persist/sql/multi-driver unit tests.
# Same as the atomspace/persist/cog-storage unit tests.
ADD_CXXTEST(BasicSaveUTest)
ADD_CXXTEST(ValueSaveUTest)
ADD_CXXTEST(PersistUTest)
ADD_CXXTEST(FetchUTest)
TARGET_LINK_LIBRARIES(FetchUTest execution)
ADD_CXXTEST(BasicDeleteUTest)
ADD_CXXTEST(DeleteUTest)
ADD_CXXTEST(AlphaEquivUTest)
ADD_CXXTEST(MultiPersistUTest)
ADD_CXXTEST(QueryPersistUTest)
#
ADD_CXXTEST(LargeFlatUTest)
ADD_CXXTEST(LargeZipfUTest)
