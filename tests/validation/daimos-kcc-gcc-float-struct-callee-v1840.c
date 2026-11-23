/* Floating-containing aggregate return implementations for mixed links. */
#include "daimos-kcc-gcc-float-struct-v1840.h"
struct fd2_v1840
ret_fd2_v1840(double d)
{
    struct fd2_v1840 result;
    result.d = d;
    return result;
}
struct ff2_v1840
ret_ff2_v1840(float f, unsigned long tag)
{
    struct ff2_v1840 result;
    result.f = f;
    result.tag = tag;
    return result;
}
struct fd3_v1840
ret_fd3_v1840(double d, unsigned long tag)
{
    struct fd3_v1840 result;
    result.d = d;
    result.tag = tag;
    return result;
}
struct fd4_v1840
ret_fd4_v1840(float f, double d, unsigned long tag)
{
    struct fd4_v1840 result;
    result.f = f;
    result.d = d;
    result.tag = tag;
    return result;
}
struct fd5_v1840
ret_fd5_v1840(double d, unsigned long tag)
{
    struct fd5_v1840 result;
    unsigned int i;
    result.d = d;
    for (i = 0U; i < 3U; ++i)
        result.tag[i] = tag + i;
    return result;
}
struct fd8_v1840
ret_fd8_v1840(double d, unsigned long tag,
    unsigned long a, unsigned long b, unsigned long c)
{
    struct fd8_v1840 result;
    unsigned int i;
    result.d = d;
    for (i = 0U; i < 6U; ++i)
        result.tag[i] = tag + i;
    result.tag[3] = a;
    result.tag[4] = b;
    result.tag[5] = c;
    return result;
}
