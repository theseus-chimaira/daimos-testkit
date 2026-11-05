/* Full guest: real EXEC destroys old VM, then loader rejects replacement. */
#include "dsys.h"
#include "../test_sixbit.h"

#ifndef DAIMOS_V1126_NESTED
#define DAIMOS_V1126_NESTED 0
#endif

#ifndef DAIMOS_V1157_PROVIDER
#define DAIMOS_V1157_PROVIDER 0
#endif

#if DAIMOS_V1157_PROVIDER
#define E10_HOLDER_STATE_V1157 0777750UL
#define E10_HOLDER_RELEASE_V1157 0777751UL
#endif

#define EXEC_BLOCK_WORDS   (SYS_EXEC_V1_FIXED_WORDS + RUN_PATH_WORDS)
#define RUN_PATH_WORDS     3U
#define RUN_ARG_WORDS      2U
#define RUN_PATH_OFF       SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF       (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF       (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF        (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS    (RUN_MAP_OFF + 3U)

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
#if DAIMOS_V1126_NESTED
        /* Preserve diagnostic counters if another process owns an
         * unresolved fatal FILE retry. Exiting would wait for it. */
        (void)dsys_halt();
#endif
        (void)dsys_exit(0200);
}

static int
exec_self_v890(void)
{
        kword_t block[EXEC_BLOCK_WORDS];
        struct sys_exec_v1 *req;
        unsigned int i;

        for (i = 0U; i < EXEC_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        req = (struct sys_exec_v1 *)block;
        req->version_words =
            SYS_RUN_HEADER(SYS_EXEC_VERSION_1, EXEC_BLOCK_WORDS);
        req->argc = 0UL;
        req->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i)
                block[SYS_EXEC_V1_FIXED_WORDS + i] = init_path[i];
        return dsys_exec(req);
}

static int
spawn_exec(int invalid_fd, int apr_child, int holder_child)
{
        kword_t block[RUN_BLOCK_WORDS + 1U];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_NEW;
        run->argc = 2UL;
        run->fdmap_count = 3UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            holder_child ? TEST_SIX6('B', ' ', ' ', ' ', ' ', ' ') :
            apr_child ? TEST_SIX6('A', ' ', ' ', ' ', ' ', ' ') :
                        TEST_SIX6('E', ' ', ' ', ' ', ' ', ' ');
        for (i = 0U; i < 3U; ++i)
                block[RUN_MAP_OFF + i] = SYS_RUN_FD_MAP(i, i);
        if (invalid_fd)
                block[RUN_MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U, 15U);
        run->fdmap_count = invalid_fd ? 4UL : 3UL;
        run->version_words =
            SYS_RUN_HEADER(SYS_RUN_VERSION_2,
                RUN_BLOCK_WORDS + (invalid_fd ? 1U : 0U));
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        kword_t status;
        int child;
        unsigned int mode;
#if DAIMOS_V1126_NESTED
        struct sys_meminfo before;
        struct sys_meminfo after;
        int apr;
        int rejected;
        unsigned int i;
#endif
#if DAIMOS_V1157_PROVIDER
        int holder;
#endif

        mode = 0U;
        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL)
                mode = (unsigned int)(((argv[1][1] >> 30U) &
                    077UL) + 040U);
    if (mode == 'E') {
                (void)dsys_writechar(1, 'E');
                /* Valid UUO/EXEC argument; isolated kernel injects
                 * staged memory pressure followed by a failed loader
                 * only AFTER real vm_space_destroy commits. */
                (void)exec_self_v890();
                (void)dsys_writechar(1, '!');
                (void)dsys_exit(0277);
                return 0;
    }
#if DAIMOS_V1157_PROVIDER
        if (mode == 'B') {
                /* The disposable FS gateway parks this real owner after
                 * acquiring its serialized provider lease. */
                int fd;
                fd = dsys_open(init_path, SYS_O_RDONLY);
                if (fd >= 0)
                        (void)dsys_close(fd);
                (void)dsys_exit(066);
        }
#endif
#if DAIMOS_V1126_NESTED
        if (mode == 'A') {
                volatile kword_t *bad;
                (void)dsys_writechar(1, 'A');
                bad = (volatile kword_t *)0777777UL;
                (void)*bad;           /* actual APR protection fault */
                fail('A');            /* unreachable */
                return 0;
        }
#endif
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_writechar(1, '<') != 0)
                fail('1');
        child = spawn_exec(0, 0, 0);
        if (child <= 1)
                fail('2');
#if DAIMOS_V1126_NESTED
        /* The EXEC owner must have destroyed its VM and retained FILE
         * ownership before a separate APR-fatal child and failed RUN.
         * The isolated VFS refusal remains armed until the late RUN. */
        for (i = 0U; i < 40U; ++i) {
                unsigned int detail;
                detail = (unsigned int)dsys_procctl(
                    SYS_PROCCTL_GETTEARDOWN, (unsigned int)child);
                if (SYS_TEARDOWN_STAGE(detail) == SYS_TEARDOWN_FILE)
                        break;
                if (dsys_sleep(010U) != 0)
                        fail('T');
        }
        if (i == 40U)
                fail('t');
#if DAIMOS_V1157_PROVIDER
        holder = spawn_exec(0, 0, 1);
        if (holder <= child)
                fail('h');
        for (i = 0U; i < 64U; ++i) {
                if (dsys_brk(E10_HOLDER_STATE_V1157) == 1UL)
                        break;
                if (dsys_sleep(010U) != 0)
                        fail('i');
        }
        if (i == 64U)
                fail('j');
        (void)dsys_writechar(1, 'B');
#endif
        apr = spawn_exec(0, 1, 0);
        if (apr <= child)
                fail('a');
        status = 0UL;
        if (dsys_wait((unsigned int)apr, &status, 0U) != apr ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) !=
                (SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM))
                fail('b');
        if (dsys_meminfo(&before) != 0)
                fail('c');
        rejected = spawn_exec(1, 0, 0);
        if (rejected != -1)
                fail('d');
        if (dsys_meminfo(&after) != 0)
                fail('e');
#if DAIMOS_V1142_PHYSICAL_UAREA
        /* A genuine pinned child u-area cannot disappear at the return
         * from RUN. Wait for the scheduler's normal deferred finalizer.
         * Concurrent EXEC termination may also reduce live usage, so
         * compare upper bounds rather than requiring a stale equality. */
        for (i = 0U; i < 64U &&
             (after.process_slots_used > before.process_slots_used ||
              after.process_words > before.process_words); ++i) {
                if (dsys_sleep(010U) != 0 || dsys_meminfo(&after) != 0)
                        fail('m');
        }
        if (after.process_slots_used > before.process_slots_used ||
            after.process_words > before.process_words)
                fail('n');
#else
        if (after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words)
                fail('e');
#endif
        if (dsys_wait((unsigned int)apr, &status,
            SYS_WAIT_NOHANG) != -1)
                fail('f');
        (void)dsys_writechar(1, 'R');
#if DAIMOS_V1157_PROVIDER
        /* Release only after APR and the failed RUN. The holder then
         * resumes its own kernel stack and unlocks normally. */
        if (dsys_brk(E10_HOLDER_RELEASE_V1157) != 0UL)
                fail('k');
        if (dsys_wait((unsigned int)holder, &status, 0U) != holder ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 066U)
                fail('l');
        (void)dsys_writechar(1, 'U');
#endif
#endif
        status = 0UL;
#if DAIMOS_V1126_NESTED
        /* A failed publication cannot strand the real EXEC fatal owner.
         * Bound the observation so we can inspect actual FILE counters
         * instead of losing all samples to a host simulator timeout. */
        /* Allow more than two complete 01000-tick fatal FILE retry
         * intervals, not merely 256 ticks before calling it stuck. */
        for (i = 0U; i < 64U; ++i) {
                int waited;
                waited = dsys_wait((unsigned int)child, &status,
                                  SYS_WAIT_NOHANG);
                if (waited == child)
                        break;
                if (waited != 0)
                        fail('w');
                if (dsys_sleep(040U) != 0)
                        fail('s');
        }
        if (i == 64U) {
                unsigned int detail;
                detail = (unsigned int)dsys_procctl(
                    SYS_PROCCTL_GETTEARDOWN, (unsigned int)child);
                (void)dsys_writechar(1, '0' + SYS_TEARDOWN_STAGE(detail));
                fail('t');
        }
#else
        if (dsys_wait((unsigned int)child, &status, 0U) != child)
                fail('3');
#endif
        if (SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 1U)
                fail('4');
        if (dsys_writechar(1, 'H') != 0)
                fail('5');
        (void)dsys_exit(0);
        return 0;
}
