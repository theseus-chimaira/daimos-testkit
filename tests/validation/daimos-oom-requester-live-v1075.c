/* PDP-6 full-guest requester-only physical OOM retirement, v1075.
 * The test is compiled as C89 for the guest.  OOM dispatch is enabled
 * exclusively in the disposable kernel built by the companion script.
 */
#include "dsys.h"
#include "../test_sixbit.h"

#ifndef V1075_TEST_OOM_ENABLED
#define V1075_TEST_OOM_ENABLED 1
#endif

#ifndef V1110_TEST_NEGATIVES
#define V1110_TEST_NEGATIVES 0
#endif

#ifndef V1112_TEST_FAILED_RUN
#define V1112_TEST_FAILED_RUN 0
#endif

#ifndef V1114_TEST_MM_SLOTS
#define V1114_TEST_MM_SLOTS 0
#endif

#ifndef V1115_TEST_MM_FRAGMENT
#define V1115_TEST_MM_FRAGMENT 0
#endif

#ifndef V1116_TEST_RUN_CAUSE
#define V1116_TEST_RUN_CAUSE 0
#endif

#ifndef V1120_TEST_PID_REUSE
#define V1120_TEST_PID_REUSE 0
#endif

#define V1120_PID_CYCLES 24U

#define V1075_PATH_WORDS 3U
#define V1075_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define V1075_ARG0_OFF (V1075_PATH_OFF + V1075_PATH_WORDS)
#define V1075_ARG1_OFF (V1075_ARG0_OFF + V1075_PATH_WORDS)
#define V1075_MAP_OFF (V1075_ARG1_OFF + 2U)
#define V1075_REQ_WORDS (V1075_MAP_OFF + 3U)
#define V1075_BRK_REQUEST 0776000UL
#define V1075_WITNESS_STATUS 052U
#define V1075_OOM_STATUS 1U

static volatile kword_t v1075_pressure[040000];
static kword_t v1075_path[] = {
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
run_child(int mode, int input_fd)
{
        kword_t block[V1075_REQ_WORDS];
        struct sys_run_v2 *req;
        unsigned int i;

        for (i = 0U; i < V1075_REQ_WORDS; ++i)
                block[i] = 0UL;
        req = (struct sys_run_v2 *)block;
        req->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            V1075_REQ_WORDS);
        req->flags = SYS_RUN_PGRP_INHERIT;
        req->argc = 2UL;
        req->fdmap_count = 3UL;
    for (i = 0U; i < V1075_PATH_WORDS; ++i) {
        block[V1075_PATH_OFF + i] = v1075_path[i];
        block[V1075_ARG0_OFF + i] = v1075_path[i];
    }
#if V1112_TEST_FAILED_RUN
    if (mode == 'X') {
        /* A syntactically valid, nonexistent absolute executable path.
         * A rejected RUN must not publish a PID or consume process RAM. */
        block[V1075_PATH_OFF + 1U] =
            TEST_SIX6('/', 'X', 'X', 'X', 'X', 'X');
        block[V1075_PATH_OFF + 2U] =
            TEST_SIX6('X', '/', 'X', 'X', 'X', 'X');
    }
#endif
        block[V1075_ARG1_OFF] = 1UL;
        block[V1075_ARG1_OFF + 1U] =
            TEST_SIX6(mode, ' ', ' ', ' ', ' ', ' ');
        block[V1075_MAP_OFF] = SYS_RUN_FD_MAP(0U,
            (unsigned int)input_fd);
        block[V1075_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[V1075_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        return dsys_run(req);
}

static void
wait_status(unsigned int pid, unsigned int expected)
{
        kword_t status;
        int actual;

        status = 0UL;
        actual = dsys_wait(pid, &status, 0U);
        if (actual != (int)pid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != expected)
                fail('S');
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo occupied;
        struct sys_meminfo after;
        kword_t pair;
        kword_t word;
        int reader;
        int writer;
        int witness;
        int requester;

        v1075_pressure[037777] = 01234567UL;
        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            argv[1][0] == 1UL) {
                if (argv[1][1] ==
                    TEST_SIX6('W', ' ', ' ', ' ', ' ', ' ')) {
                        /* Parent releases this witness only AFTER OOM. */
                        if (dsys_read_words(0, &word, 1U) != 0)
                                (void)dsys_exit(053);
                        (void)dsys_writechar(1, 'W');
                        (void)dsys_exit(V1075_WITNESS_STATUS);
                }
                if (argv[1][1] ==
                    TEST_SIX6('O', ' ', ' ', ' ', ' ', ' ')) {
                        if (dsys_brk(V1075_BRK_REQUEST) !=
                            (kword_t)-1L)
                                (void)dsys_exit(071);
                        /* The enabled OOM path must never return here. */
                        (void)dsys_writechar(1, 'D');
                        (void)dsys_exit(070);
                }
#if V1120_TEST_PID_REUSE
                if (argv[1][1] ==
                    TEST_SIX6('A', ' ', ' ', ' ', ' ', ' '))
                        (void)dsys_exit(062);
                if (argv[1][1] ==
                    TEST_SIX6('B', ' ', ' ', ' ', ' ', ' '))
                        (void)dsys_exit(063);
#endif
#if V1110_TEST_NEGATIVES
                if (argv[1][1] ==
                    TEST_SIX6('I', ' ', ' ', ' ', ' ', ' ')) {
                        kword_t original;

                        original = dsys_brk(0UL);
                        if (original == (kword_t)-1L ||
                            dsys_brk(1UL) != (kword_t)-1L ||
                            dsys_brk(0UL) != original)
                                (void)dsys_exit(075);
                        (void)dsys_writechar(1, 'I');
                        (void)dsys_exit(060);
                }
                if (argv[1][1] ==
                    TEST_SIX6('L', ' ', ' ', ' ', ' ', ' ')) {
                        kword_t original;

                        original = dsys_brk(0UL);
                        if (original == (kword_t)-1L ||
                            dsys_brk(0777777UL) != (kword_t)-1L ||
                            dsys_brk(0UL) != original)
                                (void)dsys_exit(076);
                        (void)dsys_writechar(1, 'L');
                        (void)dsys_exit(061);
                }
#endif
                (void)dsys_exit(054);
        }

        if (argc != 1 || dsys_getpid() != 1 ||
            dsys_meminfo(&before) != 0 ||
            before.total_words <= V1075_BRK_REQUEST)
                fail('0');
    (void)dsys_writechar(1, '<');

#if V1115_TEST_MM_FRAGMENT
    {
        kword_t original;

        original = dsys_brk(0UL);
        if (original == (kword_t)-1L || original >= 0200000UL)
                fail('f');
        /* The test-only sentinel allocates actual MM extents, then
         * frees alternate extents. Its real MM fit check requires
         * at least 64K total free but no 64K contiguous extent. */
        if (dsys_brk(0777773UL) != 1UL)
                fail('g');
        if (dsys_brk(0200000UL) != (kword_t)-1L)
                fail('h');
        /* Read the actual VM helper's AC2 from the preceding BRK.
         * A false -1 physical OOM must not retire this requester. */
        if (dsys_brk(0777771UL) != (kword_t)-2L)
                fail('j');
        if (dsys_brk(0UL) != original)
                fail('k');
        if (dsys_brk(0777772UL) != 0UL)
                fail('l');
        if (dsys_meminfo(&occupied) != 0 ||
            occupied.process_slots_used != before.process_slots_used ||
            occupied.process_words != before.process_words)
                fail('n');
        (void)dsys_writechar(1, 'F');
    }
#endif

#if V1114_TEST_MM_SLOTS
    /* The disposable kernel fills actual MM slots with private dynamic
     * extents. The ordinary RUN must fail cleanly while the table is
     * full; release all those exact extents before further syscalls. */
    if (dsys_brk(0777776UL) != 0UL)
            fail('m');
    requester = run_child('I', 0);
    if (requester != -1)
            fail('s');
#if V1116_TEST_RUN_CAUSE
    {
        kword_t vm_cause;
        kword_t uarea_cause;

        /* VM allocation and later child u-area allocation have distinct
         * pressure/reclaim opportunities. Exactly one stage must return
         * a genuine MM descriptor failure; the other is either successful
         * or was not entered. Both recorders are production-MM backed. */
        vm_cause = dsys_brk(0777770UL);
        uarea_cause = dsys_brk(0777774UL);
        if (!((vm_cause == (kword_t)-3L &&
               uarea_cause == (kword_t)-7L) ||
              (vm_cause == 0UL && uarea_cause == (kword_t)-3L)))
                fail('c');
    }
#endif
    if (dsys_brk(0777775UL) != 0UL)
            fail('u');
    if (dsys_meminfo(&occupied) != 0 ||
        occupied.process_slots_used != before.process_slots_used ||
        occupied.process_words != before.process_words)
            fail('q');
    (void)dsys_writechar(1, 'M');
#if V1116_TEST_RUN_CAUSE
    (void)dsys_writechar(1, 'C');
#endif
#endif

#if V1112_TEST_FAILED_RUN
    /* Invalid RUN cannot count as requester physical OOM. Check the
     * parent stays live and owns exactly its original memory/slots. */
    if (run_child('X', 0) != -1)
            fail('R');
    if (dsys_meminfo(&occupied) != 0 ||
        occupied.process_slots_used != before.process_slots_used ||
        occupied.process_words != before.process_words)
            fail('r');
    (void)dsys_writechar(1, 'R');
#endif

#if V1110_TEST_NEGATIVES
        /* These are validation failures, not physical OOM. Even the
         * opt-in fatal policy must let both children return normally. */
        requester = run_child('I', 0);
        if (requester <= 1)
                fail('I');
        wait_status((unsigned int)requester, 060U);
        requester = run_child('L', 0);
        if (requester <= 1)
                fail('L');
        wait_status((unsigned int)requester, 061U);
        if (dsys_meminfo(&occupied) != 0 ||
            occupied.process_slots_used != before.process_slots_used ||
            occupied.process_words != before.process_words)
                fail('V');
#endif

        pair = dsys_pipe();
        if (pair == ~0UL)
                fail('1');
        reader = (int)((pair >> 18U) & 0777777UL);
        writer = (int)(pair & 0777777UL);
        if (reader < 0 || reader >= 16 || writer < 0 ||
            writer >= 16 || reader == writer)
                fail('2');

        witness = run_child('W', reader);
        if (witness <= 1 || dsys_close(reader) != 0)
                fail('3');
        requester = run_child('O', 0);
        if (requester <= 1 || requester == witness)
                fail('4');
        wait_status((unsigned int)requester,
            V1075_TEST_OOM_ENABLED ? V1075_OOM_STATUS : 070U);
        (void)dsys_writechar(1, V1075_TEST_OOM_ENABLED ? 'K' : 'N');

        if (dsys_meminfo(&occupied) != 0 ||
            occupied.process_slots_used != before.process_slots_used + 1UL)
                fail('5');
        if (dsys_close(writer) != 0)
                fail('6');
        wait_status((unsigned int)witness, V1075_WITNESS_STATUS);
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words ||
            v1075_pressure[037777] != 01234567UL)
                fail('7');

#if V1120_TEST_PID_REUSE
        {
                struct sys_meminfo steady;
                unsigned int cycle;
                unsigned int reuse_count;
                int old_pid;
                int new_pid;

                /* The parent's WAIT has reaped the fatal requester and
                 * the independent witness.  Reuse is permitted only
                 * after the old slot, session/group and TTY owners are
                 * actually gone; PID is a slot number, not a generation.
                 * Never address an old PID while it names a new child. */
                steady = after;
                reuse_count = 0U;
                old_pid = -1;
                for (cycle = 0U; cycle < V1120_PID_CYCLES; ++cycle) {
                        new_pid = run_child((cycle & 1U) ? 'B' : 'A', 0);
                        if (new_pid <= 1)
                                fail('a');
                        if (new_pid == old_pid)
                                ++reuse_count;
                        wait_status((unsigned int)new_pid,
                            (cycle & 1U) ? 063U : 062U);
                        /* This exact numeric PID is now invalid until
                         * another live process claims the slot. */
                        word = 0UL;
                        if (dsys_wait((unsigned int)new_pid, &word,
                                SYS_WAIT_NOHANG) != -1 ||
                            dsys_procctl(SYS_PROCCTL_EVENT_PID,
                                SYS_EVENT_ARG((unsigned int)new_pid,
                                    SYS_EVENT_TERM)) != -1)
                                fail('b');
                        if (dsys_meminfo(&after) != 0 ||
                            after.process_slots_used !=
                                steady.process_slots_used ||
                            after.process_words != steady.process_words)
                                fail('c');
                        old_pid = new_pid;
                }
                if (reuse_count != V1120_PID_CYCLES - 1U)
                        fail('d');
                (void)dsys_writechar(1, 'Q');
        }
#endif

        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
