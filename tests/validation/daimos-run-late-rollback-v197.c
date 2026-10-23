/*
 * Native PDP-6 RUN allocation/rollback stress (C99, v197).
 *
 * A missing parent fd in the fourth explicit mapping is checked only after
 * RUN has loaded the executable, created a process u-area and prepared its
 * startup data. Repeating this failure with three live blocked children
 * must never publish a process or retain the failed VM/u-area resources.
 * Once the children have been reaped, ordinary RUN must still work.
 */
#include "dsys.h"
#include "../test_sixbit.h"

#define RUN_PATH_WORDS     3U
#define RUN_ARG_WORDS      2U
#define RUN_PATH_OFF       SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF       (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF       (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF        (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS    (RUN_MAP_OFF + 4U)
#define BLOCKED_CHILDREN   3U
#define FAILED_RUNS        16U
#define CHILD_EXIT_STATUS  051U

/* Nontrivial VM extents make failed-load release observable to the MM. */
static volatile kword_t vm_pressure[040000];

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
run_self(unsigned int mode, int input_fd, int reject_fdmap)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *req;
        unsigned int i;
        unsigned int n;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
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
        n = 0U;
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(0U,
            (unsigned int)input_fd);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(2U, 2U);
        if (reject_fdmap)
                block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(3U, 15U);
        req->fdmap_count = (kword_t)n;
        req->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_MAP_OFF + n);
        return dsys_run(req);
}

static int
wait_exit(unsigned int pid)
{
        kword_t status;
        int result;

        status = 0UL;
        result = dsys_wait(pid, &status, 0U);
        return result == (int)pid &&
            SYS_WAIT_STATUS_KIND(status) == SYS_WAIT_EXITED &&
            SYS_WAIT_STATUS_VALUE(status) == CHILD_EXIT_STATUS ? 0 : -1;
}

#ifdef TEST_VM_OOM_V198
#include "daimos-run-vm-oom-v198.h"
#endif

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo base;
        struct sys_meminfo occupied;
        struct sys_meminfo current;
        int children[BLOCKED_CHILDREN];
        kword_t pair;
        kword_t word;
        unsigned int i;
        int reader;
        int writer;
        int pid;

        vm_pressure[037777] = 01234567UL;
        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            argv[1][0] == 1UL) {
                if (argv[1][1] == TEST_SIX6('B', ' ', ' ', ' ', ' ', ' ')) {
                        /* Block until parent closes the last pipe writer. */
                        if (dsys_read_words(0, &word, 1U) != 0)
                                (void)dsys_exit(052);
                }
                (void)dsys_exit(CHILD_EXIT_STATUS);
                return CHILD_EXIT_STATUS;
        }
        if (argc != 1)
                fail('0');
        if (dsys_getpid() != 1)
                fail('1');
        if (dsys_meminfo(&base) != 0)
                fail('2');
        if (base.process_slots_used == 0UL)
                fail('3');
        (void)dsys_writechar(1, '<');

        pair = dsys_pipe();
        if (pair == ~0UL)
                fail('1');
        reader = (int)((pair >> 18U) & 0777777UL);
        writer = (int)(pair & 0777777UL);
        if (reader < 0 || reader >= 16 || writer < 0 || writer >= 16 ||
            reader == writer)
                fail('2');

        for (i = 0U; i < BLOCKED_CHILDREN; ++i) {
                pid = run_self('B', reader, 0);
                if (pid <= 1)
                        fail('3');
                children[i] = pid;
        }
        if (dsys_close(reader) != 0 || dsys_meminfo(&occupied) != 0 ||
            occupied.process_slots_used !=
                base.process_slots_used + BLOCKED_CHILDREN)
                fail('4');

        /* Each invalid descriptor is detected AFTER VM, startup and u-area
         * allocation. Check that no failed slot or process extent remains
         * published. This is not an independent audit of dynamic MM extents. */
        for (i = 0U; i < FAILED_RUNS; ++i) {
                if (run_self('E', 1, 1) != -1)
                        fail('5');
                if (dsys_meminfo(&current) != 0 ||
                    current.process_slots_used != occupied.process_slots_used ||
                    current.process_words != occupied.process_words)
                        fail('6');
        }
        (void)dsys_writechar(1, 'R');

#ifdef TEST_VM_OOM_V198
        check_vm_oom_v198(&occupied);
#endif

        if (dsys_close(writer) != 0)
                fail('7');
        for (i = 0U; i < BLOCKED_CHILDREN; ++i) {
                if (wait_exit((unsigned int)children[i]) != 0)
                        fail('8');
        }
        if (dsys_meminfo(&current) != 0 ||
            current.process_slots_used != base.process_slots_used ||
            current.process_words != base.process_words)
                fail('9');
        (void)dsys_writechar(1, 'C');

        pid = run_self('E', 1, 0);
        if (pid <= 1 || wait_exit((unsigned int)pid) != 0)
                fail('A');
        if (dsys_meminfo(&current) != 0 ||
            current.process_slots_used != base.process_slots_used ||
            current.process_words != base.process_words)
                fail('B');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
