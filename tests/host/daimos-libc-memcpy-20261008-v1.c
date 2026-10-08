/* Host semantic test of DAIMOS characterwise memcpy. C99. */
#include <stdio.h>
extern void *memcpy(void *dst, const void *src, unsigned int count);
int main(void)
{
    unsigned char src[40], dst[40];
    unsigned int i;
    for (i=0; i<40; ++i) { src[i] = (unsigned char)(i * 7U); dst[i]=0xa5U; }
    if (memcpy(dst+3, src+5, 20U) != dst+3) return 1;
    for (i=0; i<40; ++i)
        if (dst[i] != (i>=3 && i<23 ? src[i+2] : 0xa5U)) return 2;
    if (memcpy(dst, src, 0U) != dst) return 3;
    if (dst[0] != 0xa5U) return 4;
    puts("daimos-libc-memcpy-20261008-v1: PASS");
    return 0;
}
