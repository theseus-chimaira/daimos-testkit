#include "dsys.h"
#include "proc.h"

#define READER_MODE          0121U
#define PRESSURE_MODE        0122U
#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 3U)
#define WAIT_SPINS           020000U
#define TEST_SIXCHAR(ch) \
        ((unsigned long)(((unsigned int)(ch) - 040U) & 077U))
#define TEST_SIX6(a,b,c,d,e,f) \
        ((TEST_SIXCHAR(a) << 30) | (TEST_SIXCHAR(b) << 24) | \
        (TEST_SIXCHAR(c) << 18) | (TEST_SIXCHAR(d) << 12) | \
        (TEST_SIXCHAR(e) << 6) | TEST_SIXCHAR(f))

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

/* Force each test process into a large, but still 32K-usable, user extent.
 * Parent + reader + one pressure child fit; the second sleeping pressure
 * child crosses the current lowmem resident threshold and forces reclaim. */
static volatile kword_t pressure_area[010400];
static volatile kword_t burn_word;

static int
mark(int ch)
{
        return dsys_writechar(1, ch);
}

static void
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

static void
touch_image(unsigned int mode)
{
        pressure_area[0] = (kword_t)mode;
        pressure_area[010377] = (kword_t)mode ^ 0123456701234UL;
}

static void
burn(void)
{
        unsigned int i;

        for (i = 0U; i < 0400U; ++i)
                burn_word = (burn_word + (kword_t)i + 1UL) & 0777777777777UL;
}

static int
new_pipe(int *read_fd, int *write_fd)
{
        kword_t pair;

        pair = dsys_pipe();
        if (pair == ~0UL)
                return -1;
        *read_fd = (int)((pair >> 18U) & 0777777UL);
        *write_fd = (int)(pair & 0777777UL);
        return *read_fd >= 0 && *read_fd < 16 && *write_fd >= 0 &&
            *write_fd < 16 && *read_fd != *write_fd ? 0 : -1;
}

static int
spawn_child(unsigned int mode, int read_fd)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;
        int mode_ch;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->pgrp = 0UL;
        run->fdmap_count = 3UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        mode_ch = mode == READER_MODE ? 'R' : 'P';
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, (unsigned int)read_fd);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_BLOCK_WORDS);
        return dsys_run(run);
}

static unsigned int
startup_mode(int argc, kword_t **argv)
{
        unsigned int ch;

        if (argc == 1)
                return 1U;
        if (argc != 2 || argv == 0 || argv[1] == 0 ||
            (argv[1][0] & 0777777UL) != 1UL)
                return 0U;
        ch = (unsigned int)(((argv[1][1] >> 30U) & 077UL) + 040U);
        if (ch == 'R') return READER_MODE;
        if (ch == 'P') return PRESSURE_MODE;
        return 0U;
}

static int
wait_state(unsigned int pid, unsigned int state)
{
        struct sys_procinfo info;
        unsigned int i;

        for (i = 0U; i < WAIT_SPINS; ++i) {
                if (dsys_procinfo(pid, &info) == 0 && info.state == state)
                        return 0;
                burn();
        }
        return -1;
}

static int
reader_swap_pressure_active(unsigned int reader, unsigned int pressure_a,
    unsigned int pressure_b, unsigned int pressure_c)
{
        struct sys_meminfo mem;
        struct sys_procinfo a;
        struct sys_procinfo b;
        struct sys_procinfo c;
        struct sys_procinfo d;
        struct sys_procinfo e;
        kword_t all_resident;

        if (dsys_meminfo(&mem) != 0 ||
            dsys_procinfo(1U, &a) != 0 ||
            dsys_procinfo(reader, &b) != 0 ||
            dsys_procinfo(pressure_a, &c) != 0 ||
            dsys_procinfo(pressure_b, &d) != 0 ||
            dsys_procinfo(pressure_c, &e) != 0)
                return -1;
        all_resident = a.words + b.words + c.words + d.words + e.words +
            5UL * PROC_UAREA_WORDS;
        /*
         * The reader has aged for two victim-selection quanta before any
         * pressure child is created, so it is the first eligible sleeper.
         * Current reclaim may evict additional sleepers before this query;
         * require at least one complete logical image to be nonresident
         * instead of assuming every pressure child remains resident.
         */
        return b.words != 0UL && all_resident >= mem.process_words + b.words ?
            1 : 0;
}

int
main(int argc, kword_t **argv)
{
        kword_t status;
        int target_r;
        int target_w;
        int gate_r;
        int gate_w;
        int reader;
        int pressure_a;
        int pressure_b;
        int pressure_c;
        int got;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        touch_image(mode);

        if (mode == READER_MODE) {
                kword_t word;

                if (mark('r') != 0)
                        (void)dsys_exit(071);
                if (dsys_read_words(0, &word, 1U) != 1 || word != 'Z')
                        (void)dsys_exit(072);
                (void)dsys_exit(070);
                return 070;
        }
        if (mode == PRESSURE_MODE) {
                kword_t word;

                if (mark('p') != 0)
                        (void)dsys_exit(061);
                if (dsys_read_words(0, &word, 1U) != 0)
                        (void)dsys_exit(062);
                (void)dsys_exit(060);
                return 060;
        }
        if (mode != 1U)
                fail('0', 010);
        if (dsys_storagectl(SYS_STORAGECTL_SWAP) != 0)
                fail('s', 010);

        if (new_pipe(&target_r, &target_w) != 0 ||
            new_pipe(&gate_r, &gate_w) != 0)
                fail('1', 011);
        reader = spawn_child(READER_MODE, target_r);
        if (reader <= 1)
                fail('r', 012);
        if (dsys_close(target_r) != 0)
                fail('c', 012);
        if (wait_state((unsigned int)reader, 3U) != 0)
                fail('3', 013);
        if (mark('a') != 0)
                fail('4', 014);

        /* Victim ranking ages sleepers on the 64-tick boundary.  Give the
         * blocked reader two complete age quanta before creating later
         * sleepers so pressure deterministically selects the reader. */
        if (dsys_sleep(0200U) != 0)
                fail('t', 014);

        pressure_a = spawn_child(PRESSURE_MODE, gate_r);
        if (pressure_a <= reader)
                fail('5', 015);
        if (wait_state((unsigned int)pressure_a, 3U) != 0)
                fail('6', 016);
        if (mark('b') != 0)
                fail('7', 017);
        pressure_b = spawn_child(PRESSURE_MODE, gate_r);
        if (pressure_b <= 1 || pressure_b == pressure_a || pressure_b == reader)
                fail('c', 020);
        pressure_c = spawn_child(PRESSURE_MODE, gate_r);
        if (pressure_c <= 1 || pressure_c == pressure_a ||
            pressure_c == pressure_b || pressure_c == reader)
                fail('e', 020);
        if (dsys_close(gate_r) != 0)
                fail('g', 020);
        if (wait_state((unsigned int)pressure_b, 3U) != 0)
                fail('d', 021);
        if (wait_state((unsigned int)pressure_c, 3U) != 0)
                fail('f', 021);
        if (reader_swap_pressure_active((unsigned int)reader,
            (unsigned int)pressure_a, (unsigned int)pressure_b,
            (unsigned int)pressure_c) != 1)
                fail('S', 020);
        if (mark('S') != 0)
                fail('8', 022);

        {
                kword_t word;

                word = 'Z';
                if (dsys_write_words(target_w, &word, 1U) != 1 ||
            dsys_close(target_w) != 0)
                        fail('9', 023);
        }
        status = 0UL;
        got = dsys_wait((unsigned int)reader, &status, 0U);
        if (got != reader || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 070U)
                fail('D', 024);
        if (mark('W') != 0)
                fail('A', 025);

        /* Closing the final writer wakes all pressure children with EOF.
         * Either may itself have been swapped while the reader was restored. */
        if (dsys_close(gate_w) != 0)
                fail('B', 026);
        status = 0UL;
        got = dsys_wait((unsigned int)pressure_a, &status, 0U);
        if (got != pressure_a ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 060U)
                fail('C', 027);
        status = 0UL;
        got = dsys_wait((unsigned int)pressure_b, &status, 0U);
        if (got != pressure_b ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 060U)
                fail('E', 030);
        status = 0UL;
        got = dsys_wait((unsigned int)pressure_c, &status, 0U);
        if (got != pressure_c ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 060U)
                fail('G', 030);

        if (mark('P') != 0)
                fail('F', 031);
        (void)dsys_exit(0);
        return 0;
}
