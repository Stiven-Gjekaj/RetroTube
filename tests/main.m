// Runs each registered test and prints one line for each failure.
// The exit status is 0 when all tests pass.

#import "RTTest.h"

#define RT_MAX_TESTS 512

static const char *gNames[RT_MAX_TESTS];
static RTTestFunction gFunctions[RT_MAX_TESTS];
static int gCount;
static int gFailures;
static const char *gCurrent;

void RTTestRegister(const char *name, RTTestFunction function) {
    if (gCount < RT_MAX_TESTS) {
        gNames[gCount] = name;
        gFunctions[gCount] = function;
        gCount++;
    }
}

void RTTestFail(const char *file, int line, NSString *message) {
    gFailures++;
    const char *base = strrchr(file, '/');
    printf("FAIL %s (%s:%d): %s\n", gCurrent, base ? base + 1 : file, line, message.UTF8String);
}

int main(int argc, char **argv) {
    int failedTests = 0;
    for (int i = 0; i < gCount; i++) {
        if (argc > 1 && !strstr(gNames[i], argv[1])) continue;
        @autoreleasepool {
            int before = gFailures;
            gCurrent = gNames[i];
            gFunctions[i]();
            if (gFailures != before) failedTests++;
        }
    }
    printf("%d tests, %d failed\n", gCount, failedTests);
    return failedTests == 0 ? 0 : 1;
}
