/* GCC callback ABI regression: KCC qsort invokes GCC comparator. */
#include <p10stdio-daimos-v1.h>

extern void qsort(void *, unsigned int, unsigned int,
    int (*)(const void *, const void *));
extern unsigned long dsys_brk(unsigned long);

struct record_v1829 {
    long key;
    long tag;
};

static unsigned int calls_v1829;

static int
compare_v1829(const void *left, const void *right)
{
    const struct record_v1829 *a = (const struct record_v1829 *)left;
    const struct record_v1829 *b = (const struct record_v1829 *)right;
    ++calls_v1829;
    if (a->key < b->key)
        return -1;
    if (a->key > b->key)
        return 1;
    return 0;
}

int
main(void)
{
    struct record_v1829 records[9];
    unsigned long before;
    unsigned int i;
    static const long keys[9] = {7L, -4L, 9L, 0L, 3L,
        -1L, 8L, 2L, -9L};
    static const long sorted[9] = {-9L, -4L, -1L, 0L, 2L,
        3L, 7L, 8L, 9L};

    for (i = 0U; i < 9U; ++i) {
        records[i].key = keys[i];
        records[i].tag = keys[i] ^ 012345L;
    }
    before = dsys_brk(0UL);
    if (before == (unsigned long)-1L)
        return 11;
    qsort(records, 9U, sizeof(records[0]), compare_v1829);
    if (calls_v1829 < 8U)
        return 12;
    for (i = 0U; i < 9U; ++i) {
        if (records[i].key != sorted[i] ||
            records[i].tag != (sorted[i] ^ 012345L))
            return 13;
    }
    if (dsys_brk(0UL) != before)
        return 14;
    /* No callback and no change for empty and singleton arrays. */
    calls_v1829 = 0U;
    qsort(records, 0U, sizeof(records[0]), compare_v1829);
    qsort(records, 1U, sizeof(records[0]), compare_v1829);
    if (calls_v1829 != 0U)
        return 15;
    if (printf("GCC-QSORT-V1829-PASS\n") < 0)
        return 16;
    return 0;
}
