#include "dsys.h"

#define WORD_MASK 0777777777777UL
#define RT_BURN    01000000U
#define PEER_BURN  04000000U
#define TEST_SIXCHAR(ch) \
        ((unsigned long)(((unsigned int)(ch) - 040U) & 077U))
#define TEST_SIX6(a,b,c,d,e,f) \
        ((TEST_SIXCHAR(a) << 30) | (TEST_SIXCHAR(b) << 24) | \
        (TEST_SIXCHAR(c) << 18) | (TEST_SIXCHAR(d) << 12) | \
        (TEST_SIXCHAR(e) << 6) | TEST_SIXCHAR(f))

static volatile kword_t accum;

static const kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static int
mark(int ch)
{
        return dsys_writechar(1, ch);
}

static void
burn(unsigned int slot, unsigned int count)
{
        unsigned int i;

        for (i = 0U; i < count; ++i)
                accum = (accum + (kword_t)slot + (kword_t)(i & 07U)) &
                    WORD_MASK;
}

static int
disk_sleep_probe(void)
{
        kword_t word;
        int fd;
        int n;

        fd = dsys_open((kword_t *)init_path, SYS_O_RDONLY);
        if (fd < 0)
                return -1;
        n = dsys_read_words(fd, &word, 1U);
        if (dsys_close(fd) != 0)
                return -1;
        return n == 1 ? 0 : -1;
}

int
main(void)
{
        unsigned int slot;

        slot = (unsigned int)dsys_getpid();
        if (slot == 1U) {
                (void)mark('<');
                if (dsys_rtctl(SYS_RTCTL_ENABLE) != 0) {
                        (void)mark('E');
                        (void)dsys_exit(1);
                }
                burn(slot, RT_BURN);
                (void)mark('R');

                (void)mark('S');
                if (disk_sleep_probe() != 0) {
                        (void)mark('I');
                        (void)dsys_exit(2);
                }
                (void)mark('W');

                if (dsys_rtctl(SYS_RTCTL_YIELD) != 0) {
                        (void)mark('Y');
                        (void)dsys_exit(3);
                }
                (void)mark('y');

                if (dsys_rtctl(SYS_RTCTL_ENABLE) != 0 ||
                    dsys_rtctl(SYS_RTCTL_DISABLE) != 0) {
                        (void)mark('D');
                        (void)dsys_exit(4);
                }
                (void)mark('d');

                if (dsys_rtctl(SYS_RTCTL_ENABLE) != 0) {
                        (void)mark('E');
                        (void)dsys_exit(5);
                }
                (void)mark('X');
                (void)dsys_exit(0);
                return 0;
        }

        if (slot == 2U || slot == 3U) {
                (void)mark(slot == 2U ? 'b' : 'c');
                if (slot == 2U) {
                        if (dsys_rtctl(SYS_RTCTL_ENABLE) == 0) {
                                (void)mark('O');
                                (void)dsys_rtctl(SYS_RTCTL_DISABLE);
                                (void)dsys_exit(6);
                        }
                        (void)mark('q');
                }
                burn(slot, PEER_BURN);
                (void)mark(slot == 2U ? '2' : '3');
                (void)dsys_exit(0);
                return 0;
        }

        (void)mark('!');
        (void)dsys_exit(7);
        return 7;
}
