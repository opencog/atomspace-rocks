
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
ADD_CXXTEST(MultiDeleteUTest)
ADD_CXXTEST(QueryPersistUTest)
#
ADD_GUILE_TEST(ValueStore value-store-test.scm)
ADD_GUILE_TEST(SpaceFrame space-frame-test.scm)
ADD_GUILE_TEST(ValueFrame value-frame-test.scm)
ADD_GUILE_TEST(SpaceDiamond space-diamond-test.scm)
ADD_GUILE_TEST(SpaceWye space-wye-test.scm)
ADD_GUILE_TEST(SpaceX space-x-test.scm)
ADD_GUILE_TEST(SpaceDelete space-delete-test.scm)
ADD_GUILE_TEST(FetchFrame fetch-frame-test.scm)
ADD_GUILE_TEST(FrameDelete frame-delete-test.scm)
ADD_GUILE_TEST(FrameProgressive frame-progressive-test.scm)
ADD_GUILE_TEST(FrameLinks frame-links-test.scm)
ADD_GUILE_TEST(FrameValues frame-values-test.scm)
#
ADD_CXXTEST(LargeFlatUTest)
ADD_CXXTEST(LargeZipfUTest)
