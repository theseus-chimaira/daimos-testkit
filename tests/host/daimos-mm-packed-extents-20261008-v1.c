/* C99 feasibility test: alternate DAIMOS physical-extent representations.
 * This is deliberately not a kernel implementation: it tests the precise
 * lossless ranges before changing the resident PDP-6 allocator/ABI. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define MASK18 UINT64_C(0777777)
#define MASK36 UINT64_C(0777777777777)

/* One-word representation: 18-bit base, 14-bit length in 16-word
 * quanta (zero denotes the full 16384 quanta), 2-bit allocation class,
 * and 2-bit pin state. No ownership field exists. */
static int
one_word(uint32_t base, uint32_t words, unsigned int type,
         unsigned int pins, uint64_t *result)
{
    uint32_t units;
    if (base > MASK18 || !words || (words & 15U) ||
        words > 262144U || words > 262144U - base ||
        type > 3U || pins > 3U)
        return -1;
    units = words / 16U;
    *result = (uint64_t)base | ((uint64_t)(units & 16383U) << 18) |
              ((uint64_t)type << 32) | ((uint64_t)pins << 34);
    return 0;
}

/* Alternative 1.5-word representation: retain exact 18+18 span and
 * 18-bit metadata, packed two per additional 36-bit word. This requires
 * restricting owner to 12 bits and pin count to 4 bits. */
static int
half_meta(unsigned int owner, unsigned int type, unsigned int pins,
          uint32_t *result)
{
    if (owner > 4095U || type > 3U || pins > 15U)
        return -1;
    *result = owner | (type << 12) | (pins << 14);
    return 0;
}

int
main(void)
{
    uint64_t desc, packed;
    uint32_t a, b, words, units;
    unsigned int base;
    for (base = 0; base < 262144U; base += 1024U) {
        words = 262144U - base;
        if (one_word(base, words, 3U, 2U, &desc))
            return 1;
        units = (unsigned int)((desc >> 18) & 16383U);
        if (!units)
            units = 16384U;
        if ((desc & MASK18) != base || units * 16U != words ||
            ((desc >> 32) & 3U) != 3U || ((desc >> 34) & 3U) != 2U)
            return 2;
    }
    if (!one_word(1U, 17U, 1U, 0U, &desc) ||
        !one_word(0U, 262145U, 1U, 0U, &desc) ||
        !one_word(0U, 16U, 1U, 4U, &desc))
        return 3;
    if (half_meta(1024U, 3U, 15U, &a) ||
        half_meta(4095U, 2U, 0U, &b))
        return 4;
    packed = (uint64_t)a | ((uint64_t)b << 18);
    if ((packed & MASK18) != a || ((packed >> 18) & MASK18) != b ||
        (packed & ~MASK36) != 0U ||
        !half_meta(4096U, 0U, 0U, &a) ||
        !half_meta(0U, 0U, 16U, &a))
        return 5;
    puts("PASS: one-word encoding round trips aligned extents, rejects loss");
    puts("PASS: 1.5-word metadata packs two entries, rejects overflow");
    puts("LIMIT: one-word layout has no owner and only 2 pin bits");
    puts("LIMIT: 1.5-word layout reduces owner to 12 and pins to 4 bits");
    return 0;
}
