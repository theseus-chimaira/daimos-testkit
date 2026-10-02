#include "dsys.h"

#define WORD_MASK 0777777777777UL
#define LONG_BURN 04000000U

static volatile kword_t accum;

static void
burn(unsigned int slot)
{
        unsigned int i;

        for (i = 0U; i < LONG_BURN; ++i)
                accum = (accum + (kword_t)slot + (kword_t)(i & 07U)) &
                    WORD_MASK;
}

int
main(void)
{
        unsigned int slot;

        slot = (unsigned int)dsys_getpid();
        if (slot == 1U) {
                if (dsys_rtctl(SYS_RTCTL_ENABLE) != 0) {
                        (void)dsys_writechar(1, 'E');
                        (void)dsys_exit(1);
                }
                (void)dsys_writechar(1, '<');
                burn(slot);
                (void)dsys_writechar(1, 'X');
                (void)dsys_exit(0);
                return 0;
        }
        if (slot == 2U) {
                (void)dsys_writechar(1, 'b');
                (void)dsys_exit(0);
                return 0;
        }
        (void)dsys_writechar(1, '!');
        (void)dsys_exit(2);
        return 2;
}
