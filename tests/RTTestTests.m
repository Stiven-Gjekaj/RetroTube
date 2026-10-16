// Tests of the test runner itself.

#import "RTTest.h"

RT_TEST(test_runner_compares_equal_objects) {
    RT_EQUAL(([NSString stringWithFormat:@"%d", 42]), @"42");
    RT_EQUAL_INT(6 * 7, 42);
    RT_EXPECT(YES);
}
