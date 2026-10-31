/* v822: resource-only exchange admission model.
 * Real transaction admission must also verify ownership, pins,
 * transition locks, exact contiguous disk allocation, and PURE backing.
 */
#include <stdio.h>

struct resources {
    unsigned a_words, b_words;
    unsigned a_blocks, b_blocks;
    unsigned contiguous_ram_after_a;
    unsigned contiguous_disk_after_b;
};

static int eligible(const struct resources *r)
{
    if (!r->a_words || !r->b_words || !r->a_blocks || !r->b_blocks)
        return 0;
    if ((r->a_words & 01777U) || (r->b_words & 01777U))
        return 0;
    if (r->b_words > r->a_words &&
        r->b_words - r->a_words > r->contiguous_ram_after_a)
        return 0;
    if (r->a_blocks > r->b_blocks &&
        r->a_blocks - r->b_blocks > r->contiguous_disk_after_b)
        return 0;
    return 1;
}

int main(void)
{
    struct resources r = { 064000U, 064000U, 208U, 208U, 0U, 0U };
    unsigned tests = 0;
#define CHECK(expect) do { \
    ++tests; \
    if (eligible(&r) != (expect)) { \
        fprintf(stderr, "v822: failed case %u\n", tests); \
        return 1; \
    } \
} while (0)
    /* The v758 capacity deadlock: no second full backing extent needed. */
    CHECK(1);
    r.b_words = 066000U; CHECK(0);
    r.contiguous_ram_after_a = 02000U; CHECK(1);
    r.a_blocks = 220U; CHECK(0);
    r.contiguous_disk_after_b = 12U; CHECK(1);
    r.contiguous_disk_after_b = 11U; CHECK(0);
    r.a_blocks = 200U; CHECK(1);
    r.b_words = 064000U; CHECK(1);
    r.b_words = 064001U; CHECK(0);
    r.b_words = 0U; CHECK(0);
    printf("v822 PASS: %u resource-admission cases\n", tests);
    return 0;
}
