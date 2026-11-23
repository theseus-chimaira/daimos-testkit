/* Direct and indirect return, by-value argument and pointer mutation.
 * Checks whole-word padding and 9-bit byte positions across compilers. */
#include "daimos-kcc-gcc-natural-byte-aggregate-v1842.h"
volatile unsigned int fail_v1842;

static unsigned long
sum_local_v1842(const struct natural_v1842 *v)
{
    unsigned long sum;
    unsigned int i;
    sum = v->marker;
    for (i = 0U; i < 5U; ++i)
        sum += v->prefix[i];
    for (i = 0U; i < 3U; ++i)
        sum += v->suffix[i];
    return sum;
}
static int
probe_v1842(void)
{
    struct natural_v1842 first;
    struct natural_v1842 second;
    struct natural_v1842 (*volatile fn)(unsigned long) = make_nat_v1842;
    unsigned int i;

    if (sizeof(struct natural_v1842) != size_nat_v1842())
        return 1;
    first = make_nat_v1842(5UL);
    if (first.marker != 01005UL) return 2;
    for (i = 0U; i < 5U; ++i)
        if (first.prefix[i] != 6U + i) return 3;
    for (i = 0U; i < 3U; ++i)
        if (first.suffix[i] != 025U + i) return 4;
    if (sum_nat_v1842(first) != sum_local_v1842(&first)) return 5;
    update_nat_v1842(&first);
    if (first.prefix[4] != 11U || first.suffix[2] != 027U + 2U ||
        first.marker != 01010UL) return 6;
    if (sum_nat_v1842(first) != sum_local_v1842(&first)) return 7;
    second = fn(7UL);
    if (second.marker != 01007UL || second.prefix[0] != 8U ||
        second.prefix[4] != 12U || second.suffix[2] != 031U)
        return 8;
    if (sum_nat_v1842(second) != sum_local_v1842(&second)) return 9;
    if (first.marker != 01010UL || first.prefix[4] != 11U)
        return 10;
    return 0;
}
int
main(void)
{
    fail_v1842 = (unsigned int)probe_v1842();
    return (int)fail_v1842;
}
