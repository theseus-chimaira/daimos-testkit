#include "dsys.h"
#include "proc.h"
#include "../test_sixbit.h"

#define READER_MODE          0121U
#define PRESSURE_MODE        0122U
#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_ENV_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_ENV_WORDS        3U
#define RUN_MAP_OFF          (RUN_ENV_OFF + RUN_ENV_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 3U)
#define WAIT_SPINS           020000U

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

/* The 48K test deliberately exceeds available process core across five
 * processes, without reducing the kernel stack reserve or changing swap
 * policy.  Every process must own and touch a real user image extent. */
static volatile kword_t pressure_area[015400];
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
        pressure_area[015377] = (kword_t)mode ^ 0123456701234UL;
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
        run->envc = 1UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        mode_ch = mode == READER_MODE ? 'R' : 'P';
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
        block[RUN_ENV_OFF] = 7UL;
        block[RUN_ENV_OFF + 1U] = TEST_SIX6('S','N','A','P','=','O');
        block[RUN_ENV_OFF + 2U] = TEST_SIX6('K',' ',' ',' ',' ',' ');
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

/** Create a counted SIXBIT absolute path without depending on any libc heap. */
static int
process_leaf_path_v74(unsigned int pid, const char *leaf, kword_t path[8])
{
        static const char prefix[] = "/MONITOR/PROCESSES/";
        char ascii[42];
        unsigned int i;
        unsigned int j;
        unsigned int n;
        unsigned int digits[3];

        for (i = 0U; i < 8U; ++i)
                path[i] = 0UL;
        n = 0U;
        for (i = 0U; prefix[i] != 0; ++i)
                ascii[n++] = prefix[i];
        if (pid >= 1000U)
                return -1;
        digits[0] = pid / 100U;
        digits[1] = (pid / 10U) % 10U;
        digits[2] = pid % 10U;
        if (digits[0] != 0U)
                ascii[n++] = (char)('0' + digits[0]);
        if (digits[0] != 0U || digits[1] != 0U)
                ascii[n++] = (char)('0' + digits[1]);
        ascii[n++] = (char)('0' + digits[2]);
        ascii[n++] = '/';
        for (i = 0U; leaf[i] != 0; ++i) {
                if (n >= 42U)
                        return -1;
                ascii[n++] = leaf[i];
        }
        path[0] = (kword_t)n;
        for (j = 0U; j < n; ++j)
                path[1U + j / 6U] |=
                    ((kword_t)(((unsigned int)ascii[j] - 040U) & 077U)) <<
                    (30U - (j % 6U) * 6U);
        return 0;
}

/* Each MonitorFS leaf is a stream of complete typed S6REC records.  Read
 * through the public userland syscall interface rather than private kernel
 * pointers, and require EOF after the expected final record. */
static int
check_records_v74(unsigned int pid, const char *leaf, const kword_t *expected,
    const unsigned int *spans, unsigned int count)
{
        kword_t path[8];
        kword_t got[4];
        unsigned int i;
        unsigned int j;
        unsigned int at;
        int fd;
        int result;

        if (process_leaf_path_v74(pid, leaf, path) != 0)
                return -1;
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 3)
                return -1;
        result = 0;
        at = 0U;
        for (i = 0U; i < count; ++i) {
                if (spans[i] > 4U ||
                    dsys_read_words(fd, got, 4U) != (int)spans[i]) {
                        result = -1;
                        break;
                }
                for (j = 0U; j < spans[i]; ++j) {
                        if (got[j] != expected[at + j]) {
                                result = -1;
                                break;
                        }
                }
                at += spans[i];
                if (result != 0)
                        break;
        }
        if (result == 0 && dsys_read_words(fd, got, 1U) != 0)
                result = -1;
        if (dsys_close(fd) != 0)
                result = -1;
        return result;
}

static int
swapped_metadata_valid_v74(unsigned int pid)
{
        static const kword_t state[] = {
                010000000004UL, TEST_SIX6('S','W','A','P',' ',' ')
        };
        static const kword_t name[] = {
                010000000004UL, TEST_SIX6('I','N','I','T',' ',' ')
        };
        static const kword_t command[] = {
                010000000014UL,
                TEST_SIX6('/','S','Y','S','T','E'),
                TEST_SIX6('M','/','I','N','I','T'),
                010000000001UL, TEST_SIX6('R',' ',' ',' ',' ',' ')
        };
        static const kword_t environment[] = {
                010000000007UL,
                TEST_SIX6('S','N','A','P','=','O'),
                TEST_SIX6('K',' ',' ',' ',' ',' ')
        };
        static const unsigned int one[] = {2U};
        static const unsigned int two[] = {3U, 2U};
        static const unsigned int env[] = {3U};

        if (check_records_v74(pid, "STATE", state, one, 1U) != 0)
                return -1;  /* Explicit SWAP, not an aggregate memory guess. */
        if (check_records_v74(pid, "NAME", name, one, 1U) != 0)
                return -2;
        if (check_records_v74(pid, "CMDLINE", command, two, 2U) != 0)
                return -3;
        if (check_records_v74(pid, "ENVIRONMENT", environment, env, 1U) != 0)
                return -4;
        return 0;
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
        /* The state leaf must say SWAP and all three snapshot-derived
         * metadata streams must be readable while VM base is absent. */
        got = swapped_metadata_valid_v74((unsigned int)reader);
        if (got != 0)
                fail('0' - got, 020);
        if (mark('S') != 0)
                fail('8', 022);
        if (mark('M') != 0)
                fail('m', 022);
        if (mark('X') != 0)
                fail('x', 022);       /* before release of blocked reader */

        {
                kword_t word;

                word = 'Z';
                if (dsys_write_words(target_w, &word, 1U) != 1)
                        fail('9', 023);
                if (mark('V') != 0)
                        fail('v', 023); /* pipe wake completed */
                if (dsys_close(target_w) != 0)
                        fail('9', 023);
        }
        if (mark('C') != 0)
                fail('c', 023);       /* writer closed, before WAIT */
        {
                struct sys_procinfo wake_info;

                if (dsys_procinfo((unsigned int)reader, &wake_info) != 0)
                        fail('i', 023);
                /* Debug discriminator: runnable (2), still sleeping (3),
                 * or already zombie (4).  Do not infer resident state. */
                if (mark((int)('0' + (int)wake_info.state)) != 0)
                        fail('j', 023);
        }
        /* Release and reap the pressure sleepers first, allowing their VM
         * extents and snapshot allocations to be reclaimed before WAIT on
         * the target.  Its earlier SWAP/MFS checks are already complete. */
        if (dsys_close(gate_w) != 0)
                fail('B', 026);
        if (mark('G') != 0)
                fail('h', 026);
        /* Drain/reap pressure sleepers first.  This also verifies that the
         * ordinary child-exit path runs while the target stays swapped. */
        status = 0UL;
        got = dsys_wait((unsigned int)pressure_a, &status, 0U);
        if (got != pressure_a || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 060U)
                fail('C', 027);
        if (mark('A') != 0)
                fail('A', 027);
        status = 0UL;
        got = dsys_wait((unsigned int)pressure_b, &status, 0U);
        if (got != pressure_b || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 060U)
                fail('E', 030);
        if (mark('B') != 0)
                fail('A', 030);
        status = 0UL;
        got = dsys_wait((unsigned int)pressure_c, &status, 0U);
        if (got != pressure_c || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 060U)
                fail('G', 030);
        if (mark('D') != 0)
                fail('A', 030);
        status = 0UL;
        got = dsys_wait((unsigned int)reader, &status, 0U);
        if (got != reader || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 070U)
                fail('D', 024);
        if (mark('W') != 0)
                fail('A', 025);

        /* Closing the final writer wakes all pressure children with EOF.
         * Either may itself have been swapped while the reader was restored. */
        if (mark('P') != 0)
                fail('F', 031);
        (void)dsys_exit(0);
        return 0;
}
