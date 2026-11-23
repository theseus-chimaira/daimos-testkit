/* Callee compiled independently by GCC or KCC. */
#include "daimos-kcc-gcc-natural-byte-aggregate-v1842.h"
struct natural_v1842
make_nat_v1842(unsigned long seed)
{
    struct natural_v1842 v;
    unsigned int i;
    for (i = 0U; i < 5U; ++i)
        v.prefix[i] = (unsigned char)(seed + 1UL + i);
    v.marker = seed + 01000UL;
    for (i = 0U; i < 3U; ++i)
        v.suffix[i] = (unsigned char)(seed + 020UL + i);
    return v;
}
unsigned long
sum_nat_v1842(struct natural_v1842 v)
{
    unsigned long sum;
    unsigned int i;
    sum = v.marker;
    for (i = 0U; i < 5U; ++i)
        sum += v.prefix[i];
    for (i = 0U; i < 3U; ++i)
        sum += v.suffix[i];
    return sum;
}
unsigned long
size_nat_v1842(void)
{
    return (unsigned long)sizeof(struct natural_v1842);
}
void
update_nat_v1842(struct natural_v1842 *v)
{
    v->prefix[4] = (unsigned char)(v->prefix[4] + 1U);
    v->suffix[2] = (unsigned char)(v->suffix[2] + 2U);
    v->marker += 3UL;
}
