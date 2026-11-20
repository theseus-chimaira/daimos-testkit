/* Full PDP-6 K02 test: a RUN child owns the final anonymous PIPE refs.
 * Its first EXIT must fail with a real MM pin on the final PIPE release.
 * The still-live child retries EXIT and its parent receives normal WAIT.
 * All code is C89 with the kernel's existing 36-bit kword_t interface. */
#include "dsys.h"
#include "../test_sixbit.h"

#define PATH_WORDS      3U
#define ARG_WORDS       2U
#define PATH_OFF        SYS_RUN_V2_FIXED_WORDS
#define ARG0_OFF        (PATH_OFF + PATH_WORDS)
#define ARG1_OFF        (ARG0_OFF + PATH_WORDS)
#define MAP_OFF         (ARG1_OFF + ARG_WORDS)
#define MAP_COUNT       6U
#define BLOCK_WORDS     (MAP_OFF + MAP_COUNT)
#define CHILD_STATUS    065U

static kword_t init_path[] = {
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
        if (*rd < 0 || *rd >= 16 || *wr < 0 || *wr >= 16 || *rd == *wr)
                return -1;
        return 0;
}

static int
spawn_child(int rd, int wr, int control_rd)
{
        kword_t block[BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->argc = 2UL;
        run->envc = 0UL;
        run->fdmap_count = MAP_COUNT;
        for (i = 0U; i < PATH_WORDS; ++i) {
                block[PATH_OFF + i] = init_path[i];
                block[ARG0_OFF + i] = init_path[i];
        }
        block[ARG1_OFF] = 1UL;
        block[ARG1_OFF + 1U] = TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ');
        block[MAP_OFF + 0U] = SYS_RUN_FD_MAP(0U, 0U);
        block[MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        block[MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U, (unsigned int)rd);
        block[MAP_OFF + 4U] = SYS_RUN_FD_MAP(4U, (unsigned int)wr);
        block[MAP_OFF + 5U] = SYS_RUN_FD_MAP(5U,
            (unsigned int)control_rd);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            BLOCK_WORDS);
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        kword_t status;
        int rd;
        int wr;
        int ctrl_rd;
        int ctrl_wr;
        int child;

        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL &&
            argv[1][1] == TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ')) {
                /* RUN may schedule this child immediately. The control
                 * message is sent only after the parent has relinquished
                 * both original PIPE descriptors. */
                if (dsys_getpid() <= 1 || dsys_readchar(5) != 'G')
                        (void)dsys_halt();
                if (dsys_exit(CHILD_STATUS) != -1)
                        (void)dsys_halt();
                /* First EXIT closed all successful entries, but retained
                 * the final PIPE FD after MM_BUSY. Second EXIT retries
                 * only the retained owner and never returns on success. */
                (void)dsys_exit(CHILD_STATUS);
                (void)dsys_halt();
                return 1;
        }

        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0)
                fail('1');
        if (new_pipe(&rd, &wr) != 0 || rd != 3 || wr != 4)
                fail('2');
        if (new_pipe(&ctrl_rd, &ctrl_wr) != 0 ||
            ctrl_rd != 5 || ctrl_wr != 6)
                fail('3');
        child = spawn_child(rd, wr, ctrl_rd);
        if (child <= 1)
                fail('4');
        if (dsys_close(rd) != 0 || dsys_close(wr) != 0 ||
            dsys_close(ctrl_rd) != 0)
                fail('5');
        /* An independent parent remains runnable while the child waits
         * for its control PIPE, and all real PIPE references are shared
         * through the production RUN reference-acquisition path. */
        if (dsys_writechar(ctrl_wr, 'G') != 0 ||
            dsys_close(ctrl_wr) != 0)
                fail('6');
        status = 0UL;
        if (dsys_wait((unsigned int)child, &status, 0U) != child ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != CHILD_STATUS)
                fail('7');
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words ||
            after.file_slots_used != before.file_slots_used)
                fail('8');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
