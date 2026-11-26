/* Native protection and instruction-trap cleanup with a surviving parent. */
#include "dsys.h"
#include "../../test_sixbit.h"

#define PATH_WORDS 3U
#define ARG_WORDS 2U
#define PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define ARG0_OFF (PATH_OFF + PATH_WORDS)
#define ARG1_OFF (ARG0_OFF + PATH_WORDS)
#define MAP_OFF (ARG1_OFF + ARG_WORDS)
#define RUN_WORDS (MAP_OFF + 3U)
#define FATAL_STATUS 0400001U

static volatile kword_t parent_word;
static const kword_t init_path[PATH_WORDS] = {
        12UL, TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

extern void child_unassigned_v1974(void);

static int
spawn(int mode)
{
        kword_t block[RUN_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, RUN_WORDS);
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->argc = 2UL;
        run->fdmap_count = 3UL;
        for (i = 0U; i < PATH_WORDS; ++i) {
                block[PATH_OFF + i] = init_path[i];
                block[ARG0_OFF + i] = init_path[i];
        }
        block[ARG1_OFF] = 1UL;
        block[ARG1_OFF + 1U] = TEST_SIX6(mode, ' ', ' ', ' ', ' ', ' ');
        block[MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        return dsys_run(run);
}

static int
child(int mode)
{
        volatile kword_t *bad = (volatile kword_t *)(unsigned long)077777U;
        volatile kword_t value;

        if (mode == 'R') {
                value = *bad;
                (void)value;
        } else if (mode == 'W') {
                *bad = 0123456701234UL;
        } else if (mode == 'I') {
                child_unassigned_v1974();
        } else if (mode == 'N') {
                return 037;
        }
        (void)dsys_writechar(1, '!');
        return 1;
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo initial, final;
        volatile kword_t stack_word;
        kword_t status;
        int pid;
        unsigned int i;
#ifdef TEST_KA10
        static const char modes[] = "RWIN";
#else
        static const char modes[] = "RWN";
#endif

        if (argc == 2 && argv[1][0] == 1UL)
                return child((int)((argv[1][1] >> 30U) & 077U) + 040);
        if (argc != 1 || dsys_getpid() != 1 ||
            dsys_meminfo(&initial) != 0 || initial.process_slots_used != 2UL)
                return 2;
        (void)dsys_writechar(1, '<');
        parent_word = 0123456701234UL;
        stack_word = 0765432107654UL;
        for (i = 0U; modes[i] != 0; ++i) {
                pid = spawn(modes[i]);
                if (pid <= 1 || dsys_wait((unsigned int)pid, &status, 0U) != pid ||
                    SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                    SYS_WAIT_STATUS_VALUE(status) !=
                    (modes[i] == 'N' ? 037U : FATAL_STATUS) ||
                    parent_word != 0123456701234UL ||
                    stack_word != 0765432107654UL ||
                    dsys_meminfo(&final) != 0 ||
                    final.process_slots_used != initial.process_slots_used ||
                    final.process_words != initial.process_words ||
                    final.file_slots_used != initial.file_slots_used) {
                        (void)dsys_writechar(1, '!');
                        (void)dsys_writechar(1, modes[i]);
                        return 3;
                }
                (void)dsys_writechar(1, modes[i]);
        }
        (void)dsys_writechar(1, 'P');
        return 0;
}
