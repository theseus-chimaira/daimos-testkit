/* GCC caller / KCC callee, and KCC caller / GCC callee.
 * Verify register-sized and hidden-buffer aggregate returns, direct and
 * indirect. Each failing check has a unique result to locate ABI issues. */
#include "daimos-kcc-gcc-struct-return-v1836.h"
volatile unsigned int fail_v1836;

static int
run_v1836(void)
{
    struct ret1_v1836 r1;
    struct ret2_v1836 r2;
    struct ret3_v1836 r3;
    struct ret4_v1836 r4;
    struct ret5_v1836 r5;
    struct ret8_v1836 r8;
    struct ret1_v1836 (*volatile fp1)(unsigned long) = abi_ret1_v1836;
    struct ret2_v1836 (*volatile fp2)(unsigned long) = abi_ret2_v1836;
    struct ret3_v1836 (*volatile fp3)(unsigned long) = abi_ret3_v1836;
    struct ret4_v1836 (*volatile fp4)(unsigned long) = abi_ret4_v1836;
    struct ret5_v1836 (*volatile fp5)(unsigned long) = abi_ret5_v1836;
    struct ret8_v1836 (*volatile fp8)(unsigned long) = abi_ret8_v1836;
    unsigned int i;

    if (sizeof(r1) != sizeof(unsigned long) ||
        sizeof(r2) != 2U * sizeof(unsigned long) ||
        sizeof(r3) != 3U * sizeof(unsigned long) ||
        sizeof(r4) != 4U * sizeof(unsigned long) ||
        sizeof(r5) != 5U * sizeof(unsigned long) ||
        sizeof(r8) != 8U * sizeof(unsigned long)) return 1;
    r1 = abi_ret1_v1836(1UL);
    if (r1.a != 011UL) return 2;
    r1 = fp1(2UL);
    if (r1.a != 012UL) return 3;
    r2 = abi_ret2_v1836(3UL);
    if (r2.a != 023UL || r2.b != 024UL) return 4;
    r2 = fp2(4UL);
    if (r2.a != 024UL || r2.b != 025UL) return 5;
    r3 = abi_ret3_v1836(5UL);
    if (r3.a != 035UL || r3.b != 036UL || r3.c != 037UL) return 6;
    r3 = fp3(6UL);
    if (r3.a != 036UL || r3.b != 037UL || r3.c != 040UL) return 7;
    r4 = abi_ret4_v1836(7UL);
    if (r4.a != 047UL || r4.b != 050UL || r4.c != 051UL ||
        r4.d != 052UL) return 8;
    r4 = fp4(010UL);
    if (r4.a != 050UL || r4.b != 051UL || r4.c != 052UL ||
        r4.d != 053UL) return 9;
    r5 = abi_ret5_v1836(011UL);
    for (i = 0U; i < 5U; ++i)
        if (r5.a[i] != 061UL + i) return 10;
    r5 = fp5(012UL);
    for (i = 0U; i < 5U; ++i)
        if (r5.a[i] != 062UL + i) return 11;
    r8 = abi_ret8_v1836(013UL);
    for (i = 0U; i < 8U; ++i)
        if (r8.a[i] != 0113UL + i) return 12;
    r8 = fp8(014UL);
    for (i = 0U; i < 8U; ++i)
        if (r8.a[i] != 0114UL + i) return 13;
    return 0;
}

int
main(void)
{
    fail_v1836 = (unsigned int)run_v1836();
    return (int)fail_v1836;
}
