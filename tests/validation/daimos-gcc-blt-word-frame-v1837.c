/* C89 word-aligned BLT regression: whole-word stack and global arrays.
 * Numeric multiples of object size do not prove that an address is a
 * byte displacement.  Every assignment must copy the correct four words.
 */
struct quad_v1837 { unsigned long a, b, c, d; };
static struct quad_v1837 global_src_v1837[2];
static struct quad_v1837 global_dst_v1837[2];
volatile unsigned int fail_v1837;

static int
check_v1837(const struct quad_v1837 *p, unsigned long value)
{
    return p->a == value && p->b == value + 1UL &&
           p->c == value + 2UL && p->d == value + 3UL;
}

int
main(void)
{
    struct quad_v1837 local_v1837[2];
    unsigned int i;
    struct quad_v1837 *g;

    fail_v1837 = 0U;
    if (sizeof(struct quad_v1837) != 4U * sizeof(unsigned long))
        { fail_v1837 = 1U; return 1; }
    for (i = 0U; i < 2U; ++i) {
        g = &global_src_v1837[i];
        g->a = (unsigned long)i + 0100UL;
        g->b = g->a + 1UL;
        g->c = g->a + 2UL;
        g->d = g->a + 3UL;
    }

    global_dst_v1837[1] = global_src_v1837[1];
    if (!check_v1837(&global_dst_v1837[1], 0101UL))
        { fail_v1837 = 2U; return 2; }
    local_v1837[1] = global_src_v1837[1];
    if (!check_v1837(&local_v1837[1], 0101UL))
        { fail_v1837 = 3U; return 3; }
    local_v1837[0] = local_v1837[1];
    if (!check_v1837(&local_v1837[0], 0101UL))
        { fail_v1837 = 4U; return 4; }
    global_dst_v1837[0] = local_v1837[0];
    if (!check_v1837(&global_dst_v1837[0], 0101UL))
        { fail_v1837 = 5U; return 5; }
    local_v1837[1] = global_dst_v1837[1];
    if (!check_v1837(&local_v1837[1], 0101UL))
        { fail_v1837 = 6U; return 6; }
    global_src_v1837[1].a = 0777UL;
    if (!check_v1837(&local_v1837[1], 0101UL) ||
        !check_v1837(&global_dst_v1837[0], 0101UL))
        { fail_v1837 = 7U; return 7; }
    return 0;
}
