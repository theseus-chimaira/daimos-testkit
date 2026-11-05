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

#ifndef V1150_TEST_HELD_PROVIDER
#define V1150_TEST_HELD_PROVIDER 0
#endif

#ifndef V1151_TEST_ENDURANCE
#define V1151_TEST_ENDURANCE 0
#endif

#ifndef V1156_TEST_DISK_FULL
#define V1156_TEST_DISK_FULL 0
#endif

#ifndef V1158_TEST_COMBINED
#define V1158_TEST_COMBINED 0
#endif

#ifndef V1159_TEST_PROTECTED
#define V1159_TEST_PROTECTED 0
#endif

#define V1156_BACKING_FILL 0777760UL
#define V1156_BACKING_FREE 0777761UL

#define V1151_OOM_WAVES 32U
#define V1151_PID_LIFETIMES 256U
#define V1151_MIN_PI6_TICKS 1024U
#define V1151_MM_COUNT_PROBE 0777770UL
#define V1151_SWAP_USED_PROBE 0777771UL
#define V1151_TIMER_PROBE 0777772UL
#define V1151_OOM_COUNT_PROBE 0777773UL
#define V1151_BCACHE_BASE_PROBE 0777774UL

#if V1151_TEST_ENDURANCE
#define V1120_PID_CYCLES V1151_PID_LIFETIMES
#else
#define V1120_PID_CYCLES 24U
#endif

#define V1075_PATH_WORDS 3U
#define V1075_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define V1075_ARG0_OFF (V1075_PATH_OFF + V1075_PATH_WORDS)
#define V1075_ARG1_OFF (V1075_ARG0_OFF + V1075_PATH_WORDS)
#define V1075_MAP_OFF (V1075_ARG1_OFF + 2U)
#define V1075_REQ_WORDS (V1075_MAP_OFF + 3U + V1150_TEST_HELD_PROVIDER + V1158_TEST_COMBINED)
#define V1075_BRK_REQUEST 0776000UL
#define V1075_WITNESS_STATUS 052U
#define V1075_OOM_STATUS 1U

static volatile kword_t v1075_pressure[040000];
static kword_t v1075_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

#if V1150_TEST_HELD_PROVIDER
static int v1150_ack_writer;

static int
v1150_pipe(int *read_fd, int *write_fd)
{
        kword_t pair;

        pair = dsys_pipe();
        if (pair == ~(kword_t)0UL)
                return -1;
        *read_fd = (int)((pair >> 18U) & 0777777UL);
        *write_fd = (int)(pair & 0777777UL);
        return 0;
}
#endif

#if V1158_TEST_COMBINED
static int v1158_ack_writer;
#endif

static void
fail(int ch)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_halt();
        for (;;) { }
}

#if V1151_TEST_ENDURANCE
/* Only the failure path prints diagnostic counters; normal test output
 * stays unchanged. Twelve octal digits represent one PDP-6 word. */
static void
v1151_print_octal(kword_t value)
{
        int shift;

        for (shift = 33; shift >= 0; shift -= 3)
                (void)dsys_writechar(1,
                    (int)('0' + ((value >> shift) & 7UL)));
}

static void
v1151_diff(int label, kword_t expected, kword_t actual,
    unsigned int wave)
{
        (void)dsys_writechar(1, 'D');
        (void)dsys_writechar(1, label);
        (void)dsys_writechar(1, '[');
        v1151_print_octal((kword_t)wave);
        (void)dsys_writechar(1, ']');
        v1151_print_octal(expected);
        (void)dsys_writechar(1, '/');
        v1151_print_octal(actual);
        fail(label);
}
#endif

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
#if V1150_TEST_HELD_PROVIDER
        if (mode == 'O') {
                req->fdmap_count = 4UL;
                block[V1075_MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U,
                    (unsigned int)v1150_ack_writer);
        } else {
                /* RUN V2 length must match the three actual FD maps;
                 * the extra O-only storage is not part of this request. */
                req->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
                    V1075_MAP_OFF + 3U);
        }
#endif
#if V1158_TEST_COMBINED
        if (mode == 'W') {
                req->fdmap_count = 4UL;
                block[V1075_MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U,
                    (unsigned int)v1158_ack_writer);
        } else {
                req->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
                    V1075_MAP_OFF + 3U);
        }
#endif
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
#if V1158_TEST_COMBINED
        int ack_pair_reader;
        int ack_pair_writer;
#endif
#if V1150_TEST_HELD_PROVIDER
        int release_r;
        int release_w;
        int ack_r;
        int ack_w;
        int holder;
        int gateway_waiter;
        int spinner;
        unsigned int probe;
#endif

        v1075_pressure[037777] = 01234567UL;
        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            argv[1][0] == 1UL) {
                if (argv[1][1] ==
                    TEST_SIX6('W', ' ', ' ', ' ', ' ', ' ')) {
#if V1158_TEST_COMBINED
                        struct sys_meminfo run_before;
                        struct sys_meminfo run_after;
                        kword_t vm_cause;
                        kword_t uarea_cause;

                        /* This independent live process, not INIT, is
                         * the RUN parent. Fill actual MM descriptors,
                         * exercise child VM/u-area admission failure,
                         * restore descriptors, and stay alive until the
                         * OTHER child has encountered real BRK OOM. */
                        if (dsys_meminfo(&run_before) != 0 ||
                            dsys_brk(0777776UL) != 0UL ||
                            run_child('I', 0) != -1)
                                (void)dsys_exit(066);
                        vm_cause = dsys_brk(0777770UL);
                        uarea_cause = dsys_brk(0777774UL);
                        if (dsys_brk(0777775UL) != 0UL ||
                            dsys_meminfo(&run_after) != 0 ||
                            run_after.process_slots_used !=
                                run_before.process_slots_used ||
                            run_after.process_words !=
                                run_before.process_words ||
                            !((vm_cause == (kword_t)-3L &&
                               uarea_cause == (kword_t)-7L) ||
                              (vm_cause == 0UL &&
                               uarea_cause == (kword_t)-3L)))
                                (void)dsys_exit(066);
                        word = 'A';
                        if (dsys_write_words(3, &word, 1U) != 1 ||
                            dsys_close(3) != 0)
                                (void)dsys_exit(067);
#endif
                        /* Parent releases this witness only AFTER OOM. */
                        if (dsys_read_words(0, &word, 1U) != 0)
                                (void)dsys_exit(053);
                        (void)dsys_writechar(1, 'W');
                        (void)dsys_exit(V1075_WITNESS_STATUS);
                }
                if (argv[1][1] ==
                    TEST_SIX6('O', ' ', ' ', ' ', ' ', ' ')) {
#if V1150_TEST_HELD_PROVIDER
                        int fd;
                        kword_t ready;

                        /* Open a genuine provider FILE before the lease
                         * is held; the OOM close must later retry it. */
                        fd = dsys_open(v1075_path, SYS_O_RDONLY);
                        if (fd < 0)
                                (void)dsys_exit(072);
                        ready = 'A';
                        if (dsys_write_words(3, &ready, 1U) != 1 ||
                            dsys_close(3) != 0 ||
                            dsys_read_words(0, &ready, 1U) != 1 ||
                            ready != 'X')
                                (void)dsys_exit(073);
#endif
                        if (dsys_brk(V1075_BRK_REQUEST) !=
                            (kword_t)-1L)
                                (void)dsys_exit(071);
                        /* The enabled OOM path must never return here. */
                        (void)dsys_writechar(1, 'D');
                        (void)dsys_exit(070);
                }
#if V1151_TEST_ENDURANCE
                if (argv[1][1] ==
                    TEST_SIX6('T', ' ', ' ', ' ', ' ', ' ')) {
                        kword_t original;
                        kword_t expanded;

                        original = dsys_brk(0UL);
                        expanded = original + 01000UL;
                        if (original == (kword_t)-1L ||
                            expanded > 0777777UL ||
                            dsys_brk(expanded) != expanded ||
                            dsys_brk(original) != original)
                                (void)dsys_exit(065);
                        (void)dsys_exit(064);
                }
#endif
#if V1150_TEST_HELD_PROVIDER
                if (argv[1][1] ==
                    TEST_SIX6('H', ' ', ' ', ' ', ' ', ' ')) {
                        int fd;

                        if (dsys_sleep(010U) != 0)
                                (void)dsys_exit(074);
                        fd = dsys_open(v1075_path, SYS_O_RDONLY);
                        if (fd >= 0)
                                (void)dsys_close(fd);
                        (void)dsys_exit(064);
                }
                if (argv[1][1] ==
                    TEST_SIX6('G', ' ', ' ', ' ', ' ', ' ')) {
                        int fd;

                        if (dsys_sleep(0200U) != 0)
                                (void)dsys_exit(075);
                        fd = dsys_open(v1075_path, SYS_O_RDONLY);
                        if (fd >= 0)
                                (void)dsys_close(fd);
                        (void)dsys_exit(063);
                }
                if (argv[1][1] ==
                    TEST_SIX6('S', ' ', ' ', ' ', ' ', ' ')) {
                        for (;;) {
                                if (dsys_sleep(2U) != 0)
                                        (void)dsys_exit(076);
                        }
                }
#endif
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

#if V1158_TEST_COMBINED
        pair = dsys_pipe();
        if (pair == ~(kword_t)0UL)
                fail('a');
        ack_pair_reader = (int)((pair >> 18U) & 0777777UL);
        ack_pair_writer = (int)(pair & 0777777UL);
        v1158_ack_writer = ack_pair_writer;
#endif

        witness = run_child('W', reader);
        if (witness <= 1 || dsys_close(reader) != 0)
                fail('3');
#if V1158_TEST_COMBINED
        if (dsys_close(ack_pair_writer) != 0 ||
            dsys_read_words(ack_pair_reader, &word, 1U) != 1 ||
            word != 'A' || dsys_close(ack_pair_reader) != 0)
                fail('b');
        word = 0UL;
        if (dsys_wait((unsigned int)witness, &word,
                SYS_WAIT_NOHANG) != 0)
                fail('c');
        (void)dsys_writechar(1, 'A');
#endif
#if V1150_TEST_HELD_PROVIDER
        if (v1150_pipe(&release_r, &release_w) != 0 ||
            v1150_pipe(&ack_r, &ack_w) != 0)
                fail('e');
        v1150_ack_writer = ack_w;
        requester = run_child('O', release_r);
        if (requester != 3 || dsys_close(release_r) != 0 ||
            dsys_close(ack_w) != 0 ||
            dsys_read_words(ack_r, &word, 1U) != 1 || word != 'A' ||
            dsys_close(ack_r) != 0)
                fail('i');
        /* Complete every RUN before the provider lease is occupied. */
        gateway_waiter = run_child('G', 0);
        spinner = run_child('S', 0);
        holder = run_child('H', 0);
        if (gateway_waiter != 4 || spinner != 5 || holder != 6)
                fail('j');
        if (dsys_sleep(0400U) != 0)
                fail('k');
        word = 'X';
        if (dsys_write_words(release_w, &word, 1U) != 1 ||
            dsys_close(release_w) != 0)
                fail('l');
        /* A later INIT sleep releases the held provider only after
         * the real BRK error and repeated FILE-close failures. */
        for (probe = 0U; probe < 3U; ++probe) {
                if (dsys_sleep(0100U) != 0)
                        fail('p');
        }
#else
        requester = run_child('O', 0);
#endif
        if (requester <= 1 || requester == witness)
                fail('4');
        wait_status((unsigned int)requester,
            V1075_TEST_OOM_ENABLED ? V1075_OOM_STATUS : 070U);
#if V1159_TEST_PROTECTED
        /* INIT itself must still be executing, and the pipe witness
         * must not have received a termination event during OOM. */
        if (dsys_getpid() != 1 ||
            dsys_wait((unsigned int)witness, &word,
                SYS_WAIT_NOHANG) != 0)
                fail('Z');
#endif
#if V1150_TEST_HELD_PROVIDER
        wait_status((unsigned int)holder, 064U);
        wait_status((unsigned int)gateway_waiter, 063U);
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
                SYS_EVENT_ARG((unsigned int)spinner, SYS_EVENT_TERM)) != 0)
                fail('q');
        wait_status((unsigned int)spinner, 0400001U);
#endif
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

#if V1156_TEST_DISK_FULL
        {
                kword_t original;
                kword_t expanded;

                /* The test-only kernel fills the REAL backing bitmap,
                 * then makes a second real allocation, checking -1,
                 * unchanged counters and the untouched destination.
                 * A full DISK pool must never mean fatal physical OOM. */
                original = dsys_brk(0UL);
                if (original == (kword_t)-1L ||
                    dsys_storagectl(SYS_STORAGECTL_SWAP) != 0 ||
                    dsys_brk(V1156_BACKING_FILL) != 0UL)
                        fail('y');
                (void)dsys_writechar(1, 'B');
                expanded = original + 01000UL;
                if (expanded >= V1156_BACKING_FILL ||
                    dsys_brk(expanded) != expanded ||
                    dsys_brk(original) != original ||
                    dsys_brk(0777777UL) != (kword_t)-1L ||
                    dsys_brk(0UL) != original)
                        fail('z');
                (void)dsys_writechar(1, 'M');
                if (dsys_brk(V1156_BACKING_FREE) != 0UL ||
                    dsys_storagectl(0U) != 0 ||
                    dsys_meminfo(&after) != 0 ||
                    after.process_slots_used != before.process_slots_used ||
                    after.process_words != before.process_words ||
                    after.file_slots_used != before.file_slots_used)
                        fail('v');
                (void)dsys_writechar(1, 'R');
        }
#endif

#if V1151_TEST_ENDURANCE
        {
                struct sys_meminfo steady;
                kword_t extents;
                kword_t backing;
                kword_t clock_start;
                kword_t clock_end;
                kword_t oom_count;
                kword_t cache_base;
                kword_t live_extents;
                kword_t observed_extents;
                kword_t observed_cache;
                unsigned int wave;
                unsigned int cache_seen;
                unsigned int cache_reclaimed;
                int successful;

                steady = after;
                extents = dsys_brk(V1151_MM_COUNT_PROBE);
                backing = dsys_brk(V1151_SWAP_USED_PROBE);
                clock_start = dsys_brk(V1151_TIMER_PROBE);
                oom_count = dsys_brk(V1151_OOM_COUNT_PROBE);
                cache_base = dsys_brk(V1151_BCACHE_BASE_PROBE);
                if (extents == (kword_t)-1L ||
                    backing == (kword_t)-1L ||
                    clock_start == (kword_t)-1L || oom_count != 1UL ||
                    cache_base == (kword_t)-1L ||
                    extents < (cache_base != 0UL))
                        fail('e');
                /* The one clean BCACHE slab is an intentional, bounded,
                 * reclaimable 0201-word MM owner-6 extent. It may exist
                 * between file reads, but is not a leaked process extent.
                 * Compare all other MM owners exactly after every WAIT. */
                live_extents = extents - (cache_base != 0UL);
                cache_seen = (cache_base != 0UL);
                cache_reclaimed = 0U;
                for (wave = 0U; wave < V1151_OOM_WAVES; ++wave) {
                        requester = run_child('O', 0);
                        if (requester <= 1)
                                fail('f');
                        wait_status((unsigned int)requester,
                            V1075_TEST_OOM_ENABLED ?
                            V1075_OOM_STATUS : 070U);
                        if (dsys_brk(V1151_OOM_COUNT_PROBE) !=
                            oom_count + wave + 1U)
                                fail('m');
                        word = 0UL;
                        if (dsys_wait((unsigned int)requester, &word,
                                SYS_WAIT_NOHANG) != -1 ||
                            dsys_procctl(SYS_PROCCTL_EVENT_PID,
                                SYS_EVENT_ARG((unsigned int)requester,
                                    SYS_EVENT_TERM)) != -1)
                                fail('g');
                        if (dsys_meminfo(&after) != 0 ||
                            after.process_slots_used !=
                                steady.process_slots_used ||
                            after.process_words != steady.process_words ||
                            after.file_slots_used != steady.file_slots_used ||
                            dsys_brk(V1151_SWAP_USED_PROBE) != backing)
                                fail('h');
                        observed_cache =
                            dsys_brk(V1151_BCACHE_BASE_PROBE);
                        observed_extents = dsys_brk(V1151_MM_COUNT_PROBE);
                        if (observed_cache != 0UL)
                                fail('r'); /* real OOM must reclaim it */
                        if (cache_seen != 0U)
                                ++cache_reclaimed;
                        if (observed_extents != live_extents)
                                v1151_diff('x', live_extents,
                                    observed_extents, wave);
                        /* Reuse the recovered memory for a fresh child
                         * which must successfully grow and shrink BRK. */
                        successful = run_child('T', 0);
                        if (successful <= 1)
                                fail('i');
                        wait_status((unsigned int)successful, 064U);
                        if (dsys_meminfo(&after) != 0)
                                fail('j');
                        if (after.process_slots_used !=
                            steady.process_slots_used)
                                v1151_diff('s', steady.process_slots_used,
                                    after.process_slots_used, wave);
                        if (after.process_words != steady.process_words)
                                v1151_diff('w', steady.process_words,
                                    after.process_words, wave);
                        if (after.file_slots_used != steady.file_slots_used)
                                v1151_diff('f', steady.file_slots_used,
                                    after.file_slots_used, wave);
                        observed_cache =
                            dsys_brk(V1151_BCACHE_BASE_PROBE);
                        observed_extents = dsys_brk(V1151_MM_COUNT_PROBE);
                        if (observed_cache != 0UL)
                                cache_seen = 1U;
                        /* Cache residency accounts for at most one
                         * extra descriptor; every other owner must be
                         * returned by the successful child. */
                        if (observed_extents !=
                            live_extents + (observed_cache != 0UL))
                                v1151_diff('x',
                                    live_extents + (observed_cache != 0UL),
                                    observed_extents, wave);
                        if (dsys_brk(V1151_SWAP_USED_PROBE) != backing)
                                fail('b');
                }
                if (cache_seen == 0U || cache_reclaimed == 0U)
                        fail('z');
                if (dsys_sleep(02001U) != 0)
                        fail('k');
                clock_end = dsys_brk(V1151_TIMER_PROBE);
                if (((clock_end - clock_start) & 0377777UL) <
                    V1151_MIN_PI6_TICKS)
                        fail('l');
                (void)dsys_writechar(1, 'E');
        }
#endif

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
