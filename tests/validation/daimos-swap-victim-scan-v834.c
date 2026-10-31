/* v834: verify bounded exchange selection when first victim is ineligible. */
#include <stdio.h>

static int scan(unsigned high, unsigned target, const unsigned char *ok)
{
    unsigned a;
    for (a = 1; a < high; ++a) {
        if (a != target && ok[a])
            return (int)a;
    }
    return -1;
}

int main(void)
{
    unsigned char ok[20] = {0};
    unsigned n = 0;
#define CHECK(h, t, expected) do { \
    ++n; \
    if (scan((h), (t), ok) != (expected)) { \
        fprintf(stderr, "v834 FAIL: case %u\n", n); \
        return 1; \
    } \
} while (0)
    CHECK(19, 2, -1);
    ok[1] = 1;
    CHECK(19, 1, -1);
    ok[11] = 1;
    CHECK(19, 1, 11);
    CHECK(19, 11, 1);
    ok[1] = 0;
    CHECK(19, 1, 11);
    CHECK(11, 1, -1);
    puts("v834 PASS: 6 bounded selection cases");
    return 0;
}
