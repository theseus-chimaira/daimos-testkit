/* FILE v415 design-contract regression. Host C99; no target code or RAM. */
#include <stdint.h>
#include <stdio.h>

#define NODE_MASK UINT64_C(077707777777)
#define META_MASK UINT64_C(0700070000000)
#define READ_BIT (UINT64_C(1) << 35)
#define WRITE_BIT (UINT64_C(1) << 34)
#define APPEND_BIT (UINT64_C(1) << 33)
#define LOCK_MASK (UINT64_C(3) << 21)
#define FILE_COUNT 16U

struct descriptor { uint64_t word0, offset; };

static uint64_t
vnode(unsigned int provider, unsigned int mount, unsigned int kind,
    unsigned int index)
{
        return ((uint64_t)provider << 30) | ((uint64_t)mount << 24) |
            ((uint64_t)kind << 18) | (uint64_t)index;
}

static unsigned int
is_pipe(uint64_t descriptor)
{
        /* Provider 7, mount 0, local kind 1, never a TSFS mount. */
        return ((descriptor & NODE_MASK) >> 18) ==
            (vnode(7U, 0U, 1U, 0U) >> 18);
}

static void
flock_local(struct descriptor *fds, uint64_t target, unsigned int mode)
{
        unsigned int i;
        for (i = 0; i < FILE_COUNT; ++i)
                if ((fds[i].word0 & NODE_MASK) == target &&
                    (fds[i].word0 & LOCK_MASK) != 0U)
                        fds[i].word0 = (fds[i].word0 & ~LOCK_MASK) |
                            ((uint64_t)mode << 21);
}

int
main(void)
{
        struct descriptor fds[FILE_COUNT] = {{0U, 0U}};
        uint64_t n, attrs, other, high;
        unsigned int mount, state;

        if ((META_MASK & NODE_MASK) != 0U)
                return 1;
        for (mount = 0; mount < 64U; ++mount) {
                n = vnode(7U, mount, 1U, 0123456U);
                for (state = 0U; state < 4U; ++state) {
                        attrs = READ_BIT | WRITE_BIT | APPEND_BIT |
                            ((uint64_t)state << 21);
                        if (((n | attrs) & NODE_MASK) != n ||
                            ((n | attrs) & META_MASK) != attrs)
                                return 2;
                }
                if ((mount == 0U) != (is_pipe(n) != 0U))
                        return 3;
        }
        n = vnode(6U, 26U, 1U, 1U);
        other = vnode(6U, 27U, 1U, 1U);
        high = vnode(6U, 63U, 1U, 1U);
        fds[0].word0 = n | READ_BIT | (UINT64_C(1) << 21);
        fds[0].offset = UINT64_C(0777777777777);
        fds[1] = fds[0];       /* DUP copies offset by value. */
        fds[2].word0 = n | WRITE_BIT | APPEND_BIT | (UINT64_C(1) << 21);
        fds[3].word0 = other | READ_BIT | (UINT64_C(1) << 21);
        fds[4].word0 = high | READ_BIT | (UINT64_C(1) << 21);
        fds[1].offset = 5U;
        if (fds[0].offset != UINT64_C(0777777777777))
                return 4;
        flock_local(fds, n, 3U);
        if ((fds[0].word0 & LOCK_MASK) != LOCK_MASK ||
            (fds[1].word0 & LOCK_MASK) != LOCK_MASK ||
            (fds[2].word0 & LOCK_MASK) != LOCK_MASK ||
            (fds[3].word0 & LOCK_MASK) != (UINT64_C(1) << 21) ||
            (fds[4].word0 & LOCK_MASK) != (UINT64_C(1) << 21))
                return 5;
        flock_local(fds, n, 1U);
        if ((fds[2].word0 & LOCK_MASK) != (UINT64_C(1) << 21) ||
            (fds[2].word0 & (WRITE_BIT | APPEND_BIT)) !=
                (WRITE_BIT | APPEND_BIT))
                return 6;
        puts("FILE v415 contract PASS: 64 mounts, PIPE/TSFS, lock, offset");
        return 0;
}
