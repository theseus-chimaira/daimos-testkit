/* K04 v1796: fatal TERM keeps a regular FILE on its private stack.
 * A disposable VFS SYNC hook rejects the actual child FD6 vnode.
 * EXIT is never called explicitly by the victim; a deferred TERM
 * enters proc_fatal_close_current_v879 via the ordinary user return.
 * C89, ASCII, no new resident production kernel state. */
#include "dsys.h"
#include "../test_sixbit.h"

#define PATH_WORDS 3U
#define ARG_WORDS 2U
#define PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define ARG0_OFF (PATH_OFF + PATH_WORDS)
#define ARG1_OFF (ARG0_OFF + PATH_WORDS)
#define MAP_OFF (ARG1_OFF + ARG_WORDS)
#define MAP_COUNT 5U
#define BLOCK_WORDS (MAP_OFF + MAP_COUNT)

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static void
fail(unsigned int why)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, (int)why);
        (void)dsys_halt();
        for (;;) { }
}

static int
new_pipe(int *reader, int *writer)
{
        kword_t both;

        both = dsys_pipe();
        if (both == ~(kword_t)0UL)
                return -1;
        *reader = (int)((both >> 18U) & 0777777UL);
        *writer = (int)(both & 0777777UL);
        if (*reader < 0 || *reader >= 16 || *writer < 0 ||
            *writer >= 16 || *reader == *writer)
                return -1;
        return 0;
}

static int
spawn_child(int regular_fd, int control_reader)
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
        block[MAP_OFF + 3U] = SYS_RUN_FD_MAP(5U,
            (unsigned int)control_reader);
        block[MAP_OFF + 4U] = SYS_RUN_FD_MAP(6U,
            (unsigned int)regular_fd);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            BLOCK_WORDS);
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        struct sys_procinfo child_info;
        kword_t status;
        int regular_fd;
        int ctrl_rd;
        int ctrl_wr;
        int child;
        int td;
        int detail;
        unsigned int i;
        unsigned int saw_file;

        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL &&
            argv[1][1] == TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ')) {
                /* Stay alive on a genuinely interruptible PIPE read.
                 * A parent TERM wakes the owner into its fatal-close
                 * continuation, not normal SYS_EXIT. */
                if (dsys_getpid() != 2)
                        fail('c');
                (void)dsys_readchar(5);
                fail('r');
        }

        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0)
                fail('1');
        regular_fd = dsys_open(init_path, SYS_O_RDONLY);
        if (regular_fd != 3)
                fail('2');
        if (new_pipe(&ctrl_rd, &ctrl_wr) != 0 ||
            ctrl_rd != 4 || ctrl_wr != 5)
                fail('3');
        child = spawn_child(regular_fd, ctrl_rd);
        if (child != 2)
                fail('4');
        if (dsys_close(regular_fd) != 0 ||
            dsys_close(ctrl_rd) != 0)
                fail('5');
        /* Keep the last PIPE writer alive so the child remains blocked.
         * A foreign TERM before this wait becomes active may take the
         * direct remote-close path instead of a private fatal stack.
         * Observe the real scheduler SLEEP state first (code 3). */
        for (i = 0U; i < 100U; ++i) {
                if (dsys_procinfo((unsigned int)child, &child_info) == 0 &&
                    child_info.state == 3UL)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 100U)
                fail('s');
        (void)dsys_writechar(1, 'S');
        /* The pending TERM is delivered by the waiting child's own
         * user-return continuation after its PIPE wait wakes. */
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(child, SYS_EVENT_TERM)) != 0)
                fail('6');

        saw_file = 0U;
        for (i = 0U; i < 90U; ++i) {
                td = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                                  SYS_TEARDOWN_PREVM_QUERY_ARG(child));
                detail = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                                      SYS_TEARDOWN_DETAIL_ARG(child));
                if (td >= 0 &&
                    SYS_TEARDOWN_STAGE((unsigned int)td) ==
                    SYS_TEARDOWN_FILE &&
                    detail >= 0 &&
                    SYS_TEARDOWN_DETAIL_FILE_ERROR((unsigned int)detail)
                    == 5U) {
                        saw_file = 1U;
                        break;
                }
                (void)dsys_sleep(4U);
        }
        if (!saw_file)
                fail('7');
        (void)dsys_writechar(1, 'F');
        /* A second foreign fatal event may not claim the blocked FILE
         * owner's private executive continuation. */
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(child, SYS_EVENT_TERM)) != -1)
                fail('8');

        /* WAIT is legal only once all FILEs have closed successfully,
         * HUP completed, and the normal finalizer published EXIT. */
        status = 0UL;
        if (dsys_wait((unsigned int)child, &status, 0U) != child)
                fail('9');
        if (dsys_close(ctrl_wr) != 0)
                fail('a');
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words ||
            after.file_slots_used != before.file_slots_used)
                fail('b');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
