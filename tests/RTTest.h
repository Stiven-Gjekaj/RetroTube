// RTTest: a small test runner that operates on macOS and on iOS 6.
// Each test is a function that RT_TEST makes and registers at load time.

#import <Foundation/Foundation.h>

typedef void (*RTTestFunction)(void);

void RTTestRegister(const char *name, RTTestFunction function);
void RTTestFail(const char *file, int line, NSString *message);
void RTTestSkip(void);

#define RT_TEST(name)                                                         \
    static void name(void);                                                   \
    __attribute__((constructor)) static void name##_register(void) {          \
        RTTestRegister(#name, name);                                          \
    }                                                                         \
    static void name(void)

#define RT_EXPECT(condition)                                                  \
    do {                                                                      \
        if (!(condition)) RTTestFail(__FILE__, __LINE__, @"expected: " #condition); \
    } while (0)

#define RT_EQUAL(actual, expected)                                            \
    do {                                                                      \
        id rt_a = (actual), rt_e = (expected);                                \
        if (!(rt_a == rt_e || [rt_a isEqual:rt_e]))                           \
            RTTestFail(__FILE__, __LINE__, [NSString stringWithFormat:        \
                @"%s is <%@>, expected <%@>", #actual, rt_a, rt_e]);           \
    } while (0)

#define RT_EQUAL_INT(actual, expected)                                        \
    do {                                                                      \
        long long rt_a = (long long)(actual), rt_e = (long long)(expected);   \
        if (rt_a != rt_e)                                                     \
            RTTestFail(__FILE__, __LINE__, [NSString stringWithFormat:        \
                @"%s is %lld, expected %lld", #actual, rt_a, rt_e]);           \
    } while (0)

// A live test uses the network. It runs only when RT_LIVE=1 is set.
#define RT_LIVE_ONLY()                                                        \
    do {                                                                      \
        const char *rt_live = getenv("RT_LIVE");                              \
        if (!rt_live || !*rt_live) {                                          \
            RTTestSkip();                                                     \
            return;                                                           \
        }                                                                     \
    } while (0)

// Runs the run loop until done is YES or the time is over.
BOOL RTTestWait(BOOL *done, NSTimeInterval seconds);
