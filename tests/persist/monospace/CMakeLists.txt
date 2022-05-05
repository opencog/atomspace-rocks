
# Unit tests

LINK_LIBRARIES(
	persist-monospace
   persist
   atomspace
)

# The nine unit tests, ported over from the
# atomspace/persist/sql/multi-driver unit tests.
# Same as the atomspace/persist/cog-storage unit tests.
ADD_CXXTEST(MonoBasicSaveUTest)
ADD_CXXTEST(MonoValueSaveUTest)
ADD_CXXTEST(MonoPersistUTest)
ADD_CXXTEST(MonoFetchUTest)
TARGET_LINK_LIBRARIES(MonoFetchUTest execution)
ADD_CXXTEST(MonoBasicDeleteUTest)
ADD_CXXTEST(MonoDeleteUTest)
ADD_CXXTEST(MonoAlphaEquivUTest)
ADD_CXXTEST(MonoMultiPersistUTest)
ADD_CXXTEST(MonoMultiDeleteUTest)
ADD_CXXTEST(MonoQueryPersistUTest)
#
ADD_CXXTEST(MonoLargeFlatUTest)
ADD_CXXTEST(MonoLargeZipfUTest)
