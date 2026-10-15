/* RLC's zero-argument Bool ABI returns its result through the first pointer.
 * Linking every declaration verifies that the compiled suite exports every test.
 * Each CTest invocation gets a separate native process, including on crashes. */
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

struct RuleTest {
    const char *name;
    void (*run)(bool *);
    bool expected_failure;
    const char *source;
};
#include "rule_test_cases.h"

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s test_name\n", argv[0]);
        return 2;
    }
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        const struct RuleTest *test = &cases[i];
        if (strcmp(test->name, argv[1]) != 0)
            continue;
        printf("RUN: %s\n", test->name);
        fflush(stdout);
        bool result = false;
        test->run(&result);
        if (test->expected_failure) {
            if (result) {
                printf("XPASS: %s; promote assertion and remove manifest entry\n", test->name);
                return 1;
            }
            printf("XFAIL: %s (%s)\n", test->name, test->source);
            return 77;
        }
        printf("%s: %s\n", result ? "PASS" : "FAIL", test->name);
        return result ? 0 : 1;
    }
    fprintf(stderr, "Unknown test: %s\n", argv[1]);
    return 2;
}
