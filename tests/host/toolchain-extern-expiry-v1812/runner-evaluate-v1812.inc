/* Appended after the actual source of p10run.c, with main renamed. */
#include <stdio.h>
#include <string.h>

static int check_v1812(const struct options *o, const char *name,
                       const char *output, int should_fail)
{
    int rc;
    rc = evaluate(o, output);
    if ((rc != 0) != should_fail) {
        fprintf(stderr, "FAIL v1812: %s returned %d\n", name, rc);
        return 1;
    }
    printf("PASS v1812: %s\n", name);
    return 0;
}

int main(void)
{
    struct options o;
    struct expectation ex;
    const char *good;
    const char *stopped_steps;
    const char *stopped_time;
    const char *wrong;
    int failures;

    memset(&o, 0, sizeof(o));
    memset(&ex, 0, sizeof(ex));
    strcpy(ex.name, "__test_exit");
    o.expects.v = &ex;
    o.expects.n = 1;
    good = "__P10RUN_EXPECT__ __test_exit 1004 000000000000\n"
           "1004: 000000000000\n";
    stopped_steps = "Step expired\n"
                    "__P10RUN_EXPECT__ __test_exit 1004 000000000000\n"
                    "1004: 000000000000\n";
    stopped_time = "tImE eXpIrEd\n"
                   "__P10RUN_EXPECT__ __test_exit 1004 000000000000\n"
                   "1004: 000000000000\n";
    wrong = "__P10RUN_EXPECT__ __test_exit 1004 000000000000\n"
            "1004: 000000000001\n";
    failures = 0;
    failures += check_v1812(&o, "completed guest with zero exit", good, 0);
    failures += check_v1812(&o, "step expiry with stale zero exit",
                            stopped_steps, 1);
    failures += check_v1812(&o, "time expiry with stale zero exit",
                            stopped_time, 1);
    failures += check_v1812(&o, "wrong exit value", wrong, 1);
    failures += check_v1812(&o, "low-core breakpoint",
                            "Breakpoint, PC: 000020\n"
                            "__P10RUN_EXPECT__ __test_exit 1004 000000000000\n"
                            "1004: 000000000000\n", 1);
    if (failures != 0)
        return 1;
    puts("PASS v1812: P10RUN transcript classification");
    return 0;
}
