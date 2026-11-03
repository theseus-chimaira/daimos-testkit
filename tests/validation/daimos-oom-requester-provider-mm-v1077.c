/* PDP-6 full-guest requester-only physical OOM and provider retries, v1077.
 * The test is compiled as C89 for the guest.  OOM dispatch is enabled
 * exclusively in the disposable kernel built by the companion script.
 */
#include "dsys.h"
#include "../test_sixbit.h"

#ifndef V1077_TEST_OOM_ENABLED
#define V1077_TEST_OOM_ENABLED 1
#endif

#define V1077_PATH_WORDS 3U
#define V1077_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define V1077_ARG0_OFF (V1077_PATH_OFF + V1077_PATH_WORDS)
#define V1077_ARG1_OFF (V1077_ARG0_OFF + V1077_PATH_WORDS)
#define V1077_MAP_OFF (V1077_ARG1_OFF + 2U)
#define V1077_REQ_WORDS (V1077_MAP_OFF + 3U)
#define V1077_BRK_REQUEST 0776000UL
#define V1077_WITNESS_STATUS 052U
#define V1077_OOM_STATUS 1U

static volatile kword_t v1077_pressure[040000];
static kword_t v1077_path[] = {
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
        kword_t block[V1077_REQ_WORDS];
        struct sys_run_v2 *req;
        unsigned int i;

        for (i = 0U; i < V1077_REQ_WORDS; ++i)
                block[i] = 0UL;
        req = (struct sys_run_v2 *)block;
        req->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            V1077_REQ_WORDS);
        req->flags = SYS_RUN_PGRP_INHERIT;
        req->argc = 2UL;
        req->fdmap_count = 3UL;
        for (i = 0U; i < V1077_PATH_WORDS; ++i) {
                block[V1077_PATH_OFF + i] = v1077_path[i];
                block[V1077_ARG0_OFF + i] = v1077_path[i];
        }
        block[V1077_ARG1_OFF] = 1UL;
        block[V1077_ARG1_OFF + 1U] =
            TEST_SIX6(mode, ' ', ' ', ' ', ' ', ' ');
        block[V1077_MAP_OFF] = SYS_RUN_FD_MAP(0U,
            (unsigned int)input_fd);
        block[V1077_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[V1077_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
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

        v1077_pressure[037777] = 01234567UL;
        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            argv[1][0] == 1UL) {
                if (argv[1][1] ==
                    TEST_SIX6('W', ' ', ' ', ' ', ' ', ' ')) {
                        /* Parent releases this witness only AFTER OOM. */
                        if (dsys_read_words(0, &word, 1U) != 0)
                                (void)dsys_exit(053);
                        (void)dsys_writechar(1, 'W');
                        (void)dsys_exit(V1077_WITNESS_STATUS);
                }
                if (argv[1][1] ==
                    TEST_SIX6('O', ' ', ' ', ' ', ' ', ' ')) {
                        /* Keep a real D6FS vnode open across OOM.
                         * Fatal cleanup must retry SYNC before releasing
                         * the VM or U-Area allocation. */
                        if (dsys_open(v1077_path, SYS_O_RDONLY) < 0)
                                (void)dsys_exit(072);
                        if (dsys_brk(V1077_BRK_REQUEST) !=
                            (kword_t)-1L)
                                (void)dsys_exit(071);
                        /* The enabled OOM path must never return here. */
                        (void)dsys_writechar(1, 'D');
                        (void)dsys_exit(070);
                }
                (void)dsys_exit(054);
        }

        if (argc != 1 || dsys_getpid() != 1 ||
            dsys_meminfo(&before) != 0 ||
            before.total_words <= V1077_BRK_REQUEST)
                fail('0');
        (void)dsys_writechar(1, '<');

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
            V1077_TEST_OOM_ENABLED ? V1077_OOM_STATUS : 070U);
        (void)dsys_writechar(1, V1077_TEST_OOM_ENABLED ? 'K' : 'N');

        if (dsys_meminfo(&occupied) != 0 ||
            occupied.process_slots_used != before.process_slots_used + 1UL)
                fail('5');
        if (dsys_close(writer) != 0)
                fail('6');
        wait_status((unsigned int)witness, V1077_WITNESS_STATUS);
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words ||
            v1077_pressure[037777] != 01234567UL)
                fail('7');

        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
