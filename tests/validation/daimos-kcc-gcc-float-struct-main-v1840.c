/* Verify returned floating values and integer neighbors in both directions.
 * All floating input constants are exactly representable binary fractions.
 */
#include "daimos-kcc-gcc-float-struct-v1840.h"
volatile unsigned int fail_v1840;
static int
probe_v1840(void)
{
    struct fd2_v1840 d2;
    struct ff2_v1840 f2;
    struct fd3_v1840 d3;
    struct fd4_v1840 d4;
    struct fd5_v1840 d5;
    struct fd8_v1840 d8;
    struct fd4_v1840 (*volatile fp4)(float, double, unsigned long) =
        ret_fd4_v1840;
    struct fd5_v1840 (*volatile fp5)(double, unsigned long) =
        ret_fd5_v1840;
    unsigned int i;

    if (sizeof(d2) != 2U * sizeof(unsigned long) ||
        sizeof(f2) != 2U * sizeof(unsigned long) ||
        sizeof(d3) != 3U * sizeof(unsigned long) ||
        sizeof(d4) != 4U * sizeof(unsigned long) ||
        sizeof(d5) != 5U * sizeof(unsigned long) ||
        sizeof(d8) != 8U * sizeof(unsigned long)) return 1;
    d2 = ret_fd2_v1840(2.0);
    if (d2.d != 2.0) return 2;
    f2 = ret_ff2_v1840(1.5f, 07771UL);
    if (f2.f != 1.5f || f2.tag != 07771UL) return 3;
    d3 = ret_fd3_v1840(-4.0, 01122UL);
    if (d3.d != -4.0 || d3.tag != 01122UL) return 4;
    d4 = ret_fd4_v1840(0.5f, 8.0, 01345UL);
    if (d4.f != 0.5f || d4.d != 8.0 || d4.tag != 01345UL)
        return 5;
    d4 = fp4(-1.5f, -2.0, 01346UL);
    if (d4.f != -1.5f || d4.d != -2.0 || d4.tag != 01346UL)
        return 6;
    d5 = ret_fd5_v1840(-8.0, 02000UL);
    if (d5.d != -8.0) return 7;
    for (i = 0U; i < 3U; ++i)
        if (d5.tag[i] != 02000UL + i) return 8;
    d5 = fp5(0.25, 02100UL);
    if (d5.d != 0.25) return 9;
    for (i = 0U; i < 3U; ++i)
        if (d5.tag[i] != 02100UL + i) return 10;
    d8 = ret_fd8_v1840(16.0, 03000UL, 04111UL, 05222UL, 06333UL);
    if (d8.d != 16.0) return 11;
    for (i = 0U; i < 3U; ++i)
        if (d8.tag[i] != 03000UL + i) return 12;
    if (d8.tag[3] != 04111UL || d8.tag[4] != 05222UL ||
        d8.tag[5] != 06333UL) return 13;
    return 0;
}
int
main(void)
{
    fail_v1840 = (unsigned int)probe_v1840();
    return (int)fail_v1840;
}
