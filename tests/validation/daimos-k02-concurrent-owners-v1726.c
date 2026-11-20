/* Full 256K PDP-6: two RUN children with overlapping cleanup owners.
 * Child B holds a refused D6FS FILE during child A's PIPE MM_BUSY retry.
 * Test-only kernel hooks assert the overlap; user code is strict C89.
 */
#include "dsys.h"
#include "../test_sixbit.h"

#define RUN_PATH_WORDS 3U
#define RUN_ARG_WORDS  2U
#define RUN_PATH_OFF   SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF   (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF   (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF    (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_MAP_MAX    6U
#define RUN_WORDS      (RUN_MAP_OFF + RUN_MAP_MAX)
#define PIPE_STATUS    051U
#define FILE_STATUS    052U

static kword_t init_path[RUN_PATH_WORDS] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static void
fail(int code)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, code);
        (void)dsys_halt();
        for (;;) { }
}

static int
new_pipe(int *rd, int *wr)
{
        kword_t pair;
        pair = dsys_pipe();
        if (pair == ~(kword_t)0UL)
                return -1;
        *rd = (int)((pair >> 18U) & 0777777UL);
        *wr = (int)(pair & 0777777UL);
        if (*rd < 0 || *rd >= 16 || *wr < 0 || *wr >= 16 ||
            *rd == *wr)
                return -1;
        return 0;
}

static int
spawn_mode(int mode, int rd, int wr, int ctrl_rd, int regular_fd)
{
        kword_t block[RUN_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;
        unsigned int nmap;

        for (i = 0U; i < RUN_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        if (mode == 'B')
                block[RUN_ARG1_OFF + 1U] =
                    TEST_SIX6('B', ' ', ' ', ' ', ' ', ' ');
        else
                block[RUN_ARG1_OFF + 1U] =
                    TEST_SIX6('A', ' ', ' ', ' ', ' ', ' ');
        for (i = 0U; i < 3U; ++i)
                block[RUN_MAP_OFF + i] = SYS_RUN_FD_MAP(i, i);
        nmap = 3U;
        if (mode == 'A') {
                block[RUN_MAP_OFF + nmap++] =
                    SYS_RUN_FD_MAP(3U, (unsigned int)rd);
                block[RUN_MAP_OFF + nmap++] =
                    SYS_RUN_FD_MAP(4U, (unsigned int)wr);
        }
        block[RUN_MAP_OFF + nmap++] =
            SYS_RUN_FD_MAP(5U, (unsigned int)ctrl_rd);
        if (mode == 'B')
                block[RUN_MAP_OFF + nmap++] =
                    SYS_RUN_FD_MAP(6U, (unsigned int)regular_fd);
        run->fdmap_count = nmap;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_MAP_OFF + nmap);
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        struct sys_meminfo live;
        kword_t status;
        int data_rd;
        int data_wr;
        int ctl_b_rd;
        int ctl_b_wr;
        int ctl_a_rd;
        int ctl_a_wr;
        int regular_fd;
        int bpid;
        int apid;
        int mode;

        mode = 0;
        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL)
                mode = (int)(((argv[1][1] >> 30U) & 077UL) + 040U);

        if (mode == 'B') {
                /* The first provider refusal must leave FD6 owned.
                 * Sleep in the live original child until A has run.
                 * The copied PIPE hook checks this exact overlap.
                 */
                if (dsys_getpid() != 2 || dsys_readchar(5) != 'G')
                        fail('b');
                if (dsys_exit(FILE_STATUS) != -1 ||
                    dsys_meminfo(&live) != 0 ||
                    live.file_slots_used != 1UL)
                        (void)dsys_halt();
                if (dsys_sleep(0400U) != 0)
                        (void)dsys_halt();
                if (dsys_exit(FILE_STATUS) != -1 ||
                    dsys_meminfo(&live) != 0 ||
                    live.file_slots_used != 1UL)
                        (void)dsys_halt();
                (void)dsys_exit(FILE_STATUS);
                (void)dsys_halt();
                return 1;
        }
        if (mode == 'A') {
                if (dsys_getpid() != 3 || dsys_readchar(5) != 'G')
                        fail('a');
                if (dsys_exit(PIPE_STATUS) != -1 ||
                    dsys_meminfo(&live) != 0 ||
                    live.file_slots_used != 1UL)
                        (void)dsys_halt();
                (void)dsys_exit(PIPE_STATUS);
                (void)dsys_halt();
                return 1;
        }
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0)
                fail('1');
        if (new_pipe(&data_rd, &data_wr) != 0 ||
            data_rd != 3 || data_wr != 4)
                fail('2');
        if (new_pipe(&ctl_b_rd, &ctl_b_wr) != 0 ||
            ctl_b_rd != 5 || ctl_b_wr != 6)
                fail('3');
        if (new_pipe(&ctl_a_rd, &ctl_a_wr) != 0 ||
            ctl_a_rd != 7 || ctl_a_wr != 8)
                fail('4');
        regular_fd = dsys_open(init_path, SYS_O_RDONLY);
        if (regular_fd != 9)
                fail('5');
        bpid = spawn_mode('B', -1, -1, ctl_b_rd, regular_fd);
        apid = spawn_mode('A', data_rd, data_wr, ctl_a_rd, -1);
        if (bpid != 2 || apid != 3)
                fail('6');
        if (dsys_close(data_rd) != 0 || dsys_close(data_wr) != 0 ||
            dsys_close(ctl_b_rd) != 0 ||
            dsys_close(ctl_a_rd) != 0 ||
            dsys_close(regular_fd) != 0)
                fail('7');
        /* Start B first. It retains its refused D6FS owner and sleeps,
         * allowing A to make two real PIPE MM final-release attempts.
         */
        /* Keep each control PIPE's parent writer open until its child
         * exits. Otherwise B's control PIPE would become the first
         * final-close MM object, masking A's data-PIPE ownership.
         */
        if (dsys_writechar(ctl_b_wr, 'G') != 0 ||
            dsys_sleep(040U) != 0)
                fail('8');
        if (dsys_writechar(ctl_a_wr, 'G') != 0)
                fail('9');
        status = 0UL;
        if (dsys_wait((unsigned int)apid, &status, 0U) != apid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != PIPE_STATUS)
                fail('A');
        if (dsys_close(ctl_a_wr) != 0 ||
            dsys_close(ctl_b_wr) != 0)
                fail('D');
        status = 0UL;
        if (dsys_wait((unsigned int)bpid, &status, 0U) != bpid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != FILE_STATUS)
                fail('B');
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words ||
            after.file_slots_used != before.file_slots_used)
                fail('C');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
