/* Full PDP-6 RUN rollback after a real pinned process VM MM free (v895).
 * A rejected child is never published.  Its deferred release must not
 * create a zombie or report a child through WAIT. */
#include "dsys.h"
#include "../test_sixbit.h"

#define RUN_PATH_WORDS 3U
#define RUN_ARG_WORDS  2U
#define RUN_PATH_OFF   SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF   (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF   (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF    (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_WORDS      (RUN_MAP_OFF + 4U)

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static void
fail(int ch)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_halt();
        for (;;) { }
}

static int
run_self(unsigned int mode, int invalid_fd)
{
        kword_t block[RUN_WORDS];
        struct sys_run_v2 *req;
        unsigned int i;
        unsigned int count;

        for (i = 0U; i < RUN_WORDS; ++i)
                block[i] = 0UL;
        req = (struct sys_run_v2 *)block;
        req->flags = SYS_RUN_PGRP_INHERIT;
        req->argc = 2UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] = TEST_SIX6(mode, ' ', ' ', ' ', ' ', ' ');
        count = 0U;
        block[RUN_MAP_OFF + count++] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + count++] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + count++] = SYS_RUN_FD_MAP(2U, 2U);
        if (invalid_fd)
                block[RUN_MAP_OFF + count++] = SYS_RUN_FD_MAP(3U, 15U);
        req->fdmap_count = (kword_t)count;
        req->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_MAP_OFF + count);
        return dsys_run(req);
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        kword_t status;
        int spinner;
        int rejected;
        int detail;
        int done;
        unsigned int i;

        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            argv[1][0] == 1UL &&
            argv[1][1] == TEST_SIX6('S', ' ', ' ', ' ', ' ', ' ')) {
                /* Distinct live user while slot zero performs MM retries. */
                for (i = 0U; i < 100U; ++i)
                        if (dsys_sleep(1U) != 0)
                                (void)dsys_exit(052);
                (void)dsys_writechar(1, 'B');
                (void)dsys_exit(043);
                return 043;
        }
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0)
                fail('1');
        (void)dsys_writechar(1, '<');
        spinner = run_self('S', 0);
        if (spinner <= 1)
                fail('2');
        /* The target gets the next free slot but RUN returns no PID. */
        rejected = spinner + 1;
        if (run_self('E', 1) != -1)
                fail('3');
        detail = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
            (unsigned int)rejected | SYS_TEARDOWN_DETAIL_FLAG);
        if ((detail & 3) != SYS_TEARDOWN_RUN_VM ||
            (detail >> SYS_TEARDOWN_RETRY_SHIFT) != 020U)
                fail('4');
        (void)dsys_writechar(1, 'R');
        done = 0;
        for (i = 0U; i < 220U; ++i) {
                if (dsys_sleep(1U) != 0)
                        fail('5');
                detail = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    (unsigned int)rejected);
                if (detail == -1) {
                        done = 1;
                        break;
                }
                if ((detail & 3) != SYS_TEARDOWN_RUN_VM)
                        fail('6');
        }
        if (!done)
                fail('7');
        if (dsys_wait((unsigned int)rejected, &status,
            SYS_WAIT_NOHANG) != -1)
                fail('8');
        (void)dsys_writechar(1, 'F');
        if (dsys_wait((unsigned int)spinner, &status, 0U) != spinner ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 043U)
                fail('9');
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words)
                fail('A');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
