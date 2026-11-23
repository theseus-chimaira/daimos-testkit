/* Aggregate-return entry points compiled by the opposite C compiler. */
#include "daimos-kcc-gcc-struct-return-v1836.h"
struct ret1_v1836
abi_ret1_v1836(unsigned long n)
{
    struct ret1_v1836 r;
    r.a = n + 010UL;
    return r;
}
struct ret2_v1836
abi_ret2_v1836(unsigned long n)
{
    struct ret2_v1836 r;
    r.a = n + 020UL;
    r.b = n + 021UL;
    return r;
}
struct ret3_v1836
abi_ret3_v1836(unsigned long n)
{
    struct ret3_v1836 r;
    r.a = n + 030UL;
    r.b = n + 031UL;
    r.c = n + 032UL;
    return r;
}
struct ret4_v1836
abi_ret4_v1836(unsigned long n)
{
    struct ret4_v1836 r;
    r.a = n + 040UL;
    r.b = n + 041UL;
    r.c = n + 042UL;
    r.d = n + 043UL;
    return r;
}
struct ret5_v1836
abi_ret5_v1836(unsigned long n)
{
    struct ret5_v1836 r;
    unsigned int i;
    for (i = 0U; i < 5U; ++i)
        r.a[i] = n + 050UL + i;
    return r;
}
struct ret8_v1836
abi_ret8_v1836(unsigned long n)
{
    struct ret8_v1836 r;
    unsigned int i;
    for (i = 0U; i < 8U; ++i)
        r.a[i] = n + 0100UL + i;
    return r;
}
