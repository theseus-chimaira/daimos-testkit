/* Full guest: permanently pinned u-area coexists with runnable users.
 * Only the copied kernel has the provider rejection and stop hook.
 */
#include "dsys.h"
#include "../test_sixbit.h"

/* v1101 also runs this guest with a genuine wrong-owner MM extent. */
#ifndef DAIMOS_MM_EXPECT_VALUE
#define DAIMOS_MM_EXPECT_VALUE 1U
#endif

#ifndef DAIMOS_V1125_FOREIGN
#define DAIMOS_V1125_FOREIGN 0
#endif

#define RUN_PATH_WORDS 3U
#define RUN_ARG_WORDS 2U
#define RUN_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS (RUN_MAP_OFF + 3U)

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
        (void)dsys_exit(0200);
}

static int
spawn_mode(char mode)
{
        kword_t block[RUN_BLOCK_WORDS];
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
            mode == 'F' ? TEST_SIX6('F', ' ', ' ', ' ', ' ', ' ') :
#if DAIMOS_V1125_FOREIGN
            mode == 'H' ? TEST_SIX6('H', ' ', ' ', ' ', ' ', ' ') :
#endif
                          TEST_SIX6('S', ' ', ' ', ' ', ' ', ' ');
        for (i = 0U; i < 3U; ++i)
                block[RUN_MAP_OFF + i] = SYS_RUN_FD_MAP(i, i);
        run->version_words =
            SYS_RUN_HEADER(SYS_RUN_VERSION_2, RUN_BLOCK_WORDS);
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        volatile kword_t *bad;
        unsigned int mode;
        unsigned int detail;
        int fault_child;
        int spinner_child;
#if DAIMOS_V1125_FOREIGN
        int holder_child;
#endif

        mode = 0U;
        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL)
                mode = (unsigned int)(((argv[1][1] >> 30U) &
                    077UL) + 040U);
        if (mode == 'F') {
#if DAIMOS_V1125_FOREIGN
                /* Allow the independent provider holder to enter its
                 * real serialized service before the APR fault. */
                if (dsys_sleep(0200U) != 0)
                        fail('T');
#endif
                (void)dsys_writechar(1, 'F');
                bad = (volatile kword_t *)0777777UL;
                (void)*bad;           /* genuine user APR protection fault */
                fail('F');
        }
        if (mode == 'S') {
                for (;;) {
                        if (dsys_sleep(020U) != 0)
                                fail('S');
                        (void)dsys_writechar(1, 'S');
                }
        }
#if DAIMOS_V1125_FOREIGN
        if (mode == 'H') {
                static kword_t path[] = {
                        12UL,
                        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
                        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
                };
                (void)dsys_open(path, SYS_O_RDONLY);
                fail('H');          /* must remain in held gateway */
        }
#endif
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_writechar(1, '<') != 0)
                fail('1');
        fault_child = spawn_mode('F');
        if (fault_child <= 1)
                fail('2');
        spinner_child = spawn_mode('S');
        if (spinner_child <= fault_child)
                fail('3');
#if DAIMOS_V1125_FOREIGN
        holder_child = spawn_mode('H');
        /* The disposable kernel hooks are bound to exact real slots. */
        if (fault_child != 2 || spinner_child != 3 || holder_child != 4)
                fail('H');
#endif
        if (dsys_sleep(02400U) != 0)
                fail('4');
        detail = (unsigned int)dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
            (unsigned int)fault_child);
        if (SYS_TEARDOWN_STAGE(detail) != SYS_TEARDOWN_MM ||
            SYS_TEARDOWN_RETRY_TICKS(detail) != 01000U)
                fail('5');
        detail = (unsigned int)dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
            SYS_TEARDOWN_DETAIL_ARG(fault_child));
        if (SYS_TEARDOWN_STAGE(detail) != SYS_TEARDOWN_MM ||
            SYS_TEARDOWN_MM_PINS(detail) != DAIMOS_MM_EXPECT_VALUE)
                fail('7');
        {
                kword_t status;
                status = 0UL;
                if (dsys_wait((unsigned int)fault_child, &status,
                    SYS_WAIT_NOHANG) != 0)
                        fail('8');
#if DAIMOS_V1125_FOREIGN
                /* Neither the active foreign gateway owner nor the
                 * independent spinner may have become a zombie.
                 * The faulted slot must not be recycled either. */
                if (dsys_wait((unsigned int)holder_child, &status,
                        SYS_WAIT_NOHANG) != 0 ||
                    dsys_wait((unsigned int)spinner_child, &status,
                        SYS_WAIT_NOHANG) != 0)
                        fail('9');
#endif
        }
        if (dsys_writechar(1, 'P') != 0)
                fail('6');
        /* Test-only kernel hook halts before PID 1 can leave. The failed
         * owner and its u-area must still be owned at this point. */
        (void)dsys_exit(0);
        return 0;
}
