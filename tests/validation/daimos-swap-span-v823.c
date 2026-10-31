/* Boundary model for proc_swap_exchange_stage_v784 writable extents. */
#include <stdio.h>

static int fits(unsigned total_words, unsigned offset, unsigned blocks)
{
    unsigned sectors;
    if (!total_words || (total_words & 0177U)) return 0;
    sectors = total_words >> 7;
    if (offset > sectors) return 0;
    return blocks > 0 && blocks <= sectors - offset;
}

int main(void)
{
    unsigned cases = 0;
#define CHECK(w, o, n, expected) do { \
    ++cases; \
    if (fits((w), (o), (n)) != (expected)) { \
        fprintf(stderr, "v823: FAIL case %u\n", cases); \
        return 1; \
    } \
} while (0)
    CHECK(064000U, 0U, 208U, 1);
    CHECK(064000U, 1U, 207U, 1);
    CHECK(064000U, 1U, 208U, 0);
    CHECK(04000U, 014U, 4U, 1);
    CHECK(04000U, 014U, 5U, 0);
    CHECK(04000U, 020U, 1U, 0);
    CHECK(04000U, 021U, 1U, 0);
    CHECK(04001U, 0U, 1U, 0);
    CHECK(0U, 0U, 1U, 0);
    printf("v823 PASS: %u writable-span boundary cases\n", cases);
    return 0;
}
