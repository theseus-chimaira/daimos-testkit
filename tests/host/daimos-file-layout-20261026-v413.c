/* 36-bit FILE layout migration test; host-only, C99, no target RAM. */
#include <stdint.h>
#include <stdio.h>

#define WORD36 UINT64_C(0777777777777)
#define NODE_MASK UINT64_C(077707777777)
#define META_MASK UINT64_C(0700070000000)
#define ACCESS_R (UINT64_C(1) << 35)
#define ACCESS_W (UINT64_C(1) << 34)
#define DIR_APPEND (UINT64_C(1) << 33)
#define LOCK_SHIFT 21U
#define LOCK_MASK (UINT64_C(3) << LOCK_SHIFT)

static uint64_t node(unsigned int provider, unsigned int mount,
    unsigned int kind, unsigned int index)
{
        return ((uint64_t)provider << 30) | ((uint64_t)mount << 24) |
            ((uint64_t)kind << 18) | (uint64_t)index;
}

int main(void)
{
        unsigned int mount, state;
        uint64_t a, b, flags;
        if ((NODE_MASK & META_MASK) || (NODE_MASK | META_MASK) != WORD36)
                return 1;
        for (mount = 0; mount <= 63U; ++mount) {
                a = node(7U, mount, 1U, 0777777U);
                for (state = 0; state != 4U; ++state) {
                        flags = ACCESS_R | ACCESS_W | DIR_APPEND |
                            ((uint64_t)state << LOCK_SHIFT);
                        b = a | flags;
                        if ((b & NODE_MASK) != a ||
                            (b & META_MASK) != flags ||
                            ((b >> 24) & 63U) != mount ||
                            ((b & LOCK_MASK) >> LOCK_SHIFT) != state)
                                return 2;
                }
                if (mount && a == node(7U, 0U, 1U, 0777777U))
                        return 3;
        }
        puts("FILE v413 bit-layout test PASS (64 mounts, 4 lock states)");
        return 0;
}
