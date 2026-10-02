#include "dsys.h"

#define WORD_MASK 0777777777777UL
#define BURN_SHORT 040000U
#define BURN_LONG  0400000U
#define RR_PHASES  8U
#define TEST_SIXCHAR(ch) \
        ((unsigned long)(((unsigned int)(ch) - 040U) & 077U))
#define TEST_SIX6(a,b,c,d,e,f) \
        ((TEST_SIXCHAR(a) << 30) | (TEST_SIXCHAR(b) << 24) | \
        (TEST_SIXCHAR(c) << 18) | (TEST_SIXCHAR(d) << 12) | \
        (TEST_SIXCHAR(e) << 6) | TEST_SIXCHAR(f))

static volatile kword_t private_tag;
static volatile kword_t private_accum;

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

static int
burn(unsigned int slot, unsigned int count)
{
        volatile kword_t stack_tag;
        kword_t expect;
        unsigned int i;

        expect = 0123456000000UL | (kword_t)slot;
        stack_tag = expect ^ 0777777UL;
        for (i = 0U; i < count; ++i) {
                private_accum = (private_accum + (kword_t)slot +
                    (kword_t)(i & 07U)) & WORD_MASK;
                if (private_tag != expect ||
                    stack_tag != (expect ^ 0777777UL))
                        return -1;
        }
        return 0;
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
        int nice;
        unsigned int slot;
        unsigned int phase;

        slot = (unsigned int)dsys_getpid();
        if (slot < 1U || slot > 5U) {
                (void)mark('!');
                (void)dsys_exit(1);
                return 1;
        }

        private_tag = 0123456000000UL | (kword_t)slot;
        private_accum = (kword_t)slot;
        if (slot == 1U && mark('<') != 0) {
                (void)dsys_exit(2);
                return 2;
        }
        if (mark('a' + (int)slot - 1) != 0) {
                (void)dsys_exit(2);
                return 2;
        }

        nice = 0;
        if (slot == 2U)
                nice = -10;
        else if (slot == 4U)
                nice = 10;
        if (dsys_nice(nice) != nice) {
                (void)mark('N');
                (void)dsys_exit(3);
                return 3;
        }

        /* Slot 1 deliberately stays CPU-bound long enough that the other
         * start markers must appear before it reaches its first checkpoint.
         */
        if (burn(slot, slot == 1U ? BURN_LONG : BURN_SHORT) != 0) {
                (void)mark('X');
                (void)dsys_exit(5);
                return 5;
        }
        (void)mark('A' + (int)slot - 1);

        /* Equal-nice slots 3 and 5 emit several checkpoints.  The target
         * regression checks that neither completes all checkpoints before the
         * other is allowed to run, proving timer-driven round robin on real
         * relocated user contexts rather than only the host policy scan.
         */
        for (phase = 0U; phase < RR_PHASES; ++phase) {
                if (burn(slot, BURN_SHORT) != 0) {
                        (void)mark('X');
                        (void)dsys_exit(6);
                        return 6;
                }
                if (slot == 3U)
                        (void)mark('x');
                else if (slot == 5U)
                        (void)mark('y');
        }

        /* Keep blocking I/O out of the nice-order cohort.  Slot 5 performs
         * the sleep/wakeup probe only after the equal-priority checkpoint
         * phase, so disk latency cannot falsify the -10/0/+10 CPU ordering. */
        if (slot == 5U) {
                if (disk_sleep_probe() != 0) {
                        (void)mark('F');
                        (void)dsys_exit(4);
                        return 4;
                }
                (void)mark('D');
        }

        /* Same final CPU workload.  Nice -10 should finish before nice 0,
         * while nice +10 should finish after the default-priority workers.
         */
        if (burn(slot, BURN_LONG) != 0) {
                (void)mark('X');
                (void)dsys_exit(7);
                return 7;
        }
        (void)mark('0' + (int)slot);
        (void)dsys_exit(0);
        return 0;
}
