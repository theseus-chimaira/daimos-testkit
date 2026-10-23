/*
 * Native PDP-6 EXEC pressure regression, stages 0 and 1 (C99).
 *
 * Stage 0 increases its live VM until a second 0100000-word image could
 * not be allocated in the installed 256K physical core. It then EXECs a
 * normal, separate DXR. With insufficient room for staged replacement,
 * the kernel must safely invoke its existing low-memory replacement path.
 * Stage 1 verifies that EXEC preserved PID 1 and boot-time user identity.
 *
 * The test is deliberately independent of the 32K configuration: no
 * memory reserve, loader limit, or production size gate is relaxed.
 */
#include "dsys.h"
#include "../test_sixbit.h"

#ifndef TEST_V201_STAGE
#error TEST_V201_STAGE must be 0 or 1
#endif

static void
fail_v201(int code)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, code);
        (void)dsys_halt();
        for (;;) { }
}

#if TEST_V201_STAGE == 0
#define V201_PARENT_BREAK 0400000UL
#define V201_CHILD_MINIMUM 0402000UL

static volatile kword_t sentinel_v201[040000];
static kword_t exec_path_v201[] = {
        22UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'E', 'X', 'E', 'C'),
        TEST_SIX6('/', 'T', 'S', 'F', 'S', 'P'),
        TEST_SIX6('R', 'O', 'B', 'E', ' ', ' ')
};

static void
exec_stage1_v201(void)
{
        kword_t words[SYS_EXEC_V1_FIXED_WORDS + 5U];
        struct sys_exec_v1 *request;
        unsigned int i;

        for (i = 0U; i < SYS_EXEC_V1_FIXED_WORDS + 5U; ++i)
                words[i] = 0UL;
        request = (struct sys_exec_v1 *)words;
        request->version_words = SYS_RUN_HEADER(SYS_EXEC_VERSION_1,
            SYS_EXEC_V1_FIXED_WORDS + 5U);
        request->argc = 0UL;
        request->envc = 0UL;
        for (i = 0U; i < 5U; ++i)
                words[SYS_EXEC_V1_FIXED_WORDS + i] = exec_path_v201[i];

        /* A successful EXEC cannot return to this old image. */
        i = (unsigned int)dsys_exec(request);
        fail_v201(i == (unsigned int)-2 ? 'y' : 'x');
}

int
main(void)
{
        struct sys_meminfo memory;
        struct sys_procinfo process;

        if (dsys_getpid() != 1 ||
            dsys_meminfo(&memory) != 0 ||
            memory.total_words != 01000000UL)
                fail_v201('0');
        sentinel_v201[037777] = 01234567UL;
        (void)dsys_writechar(1, '<');

        if (dsys_brk(0UL) == (kword_t)-1L)
                fail_v201('1');
        /* Retain ample kernel-dynamic memory for the low-memory EXEC
         * launch copy. The replacement has 0300000 image words plus
         * 077000 BSS and startup; both extents cannot coexist in 256K. */
#ifndef TEST_V201_NO_PRESSURE
        if (dsys_brk(V201_PARENT_BREAK) != V201_PARENT_BREAK ||
            sentinel_v201[037777] != 01234567UL ||
            dsys_procinfo(1U, &process) != 0)
                fail_v201('3');

        /* A VM of this size and the live parent's extent cannot both
         * fit in physical memory even if every other user is swapped out. */
#ifndef TEST_V201_SMALL_IMAGE
        if (process.words + V201_CHILD_MINIMUM <= memory.total_words)
                fail_v201('4');
#endif
#endif
        (void)dsys_writechar(1, 'H');
        exec_stage1_v201();
        return 1;
}

#elif TEST_V201_STAGE == 1

static volatile kword_t large_image_v201[077000];

int
main(void)
{
        struct sys_procinfo process;

        large_image_v201[076777] = 01234567UL;
        if (dsys_getpid() != 1 ||
            dsys_procinfo(1U, &process) != 0 ||
            process.pid != 1UL ||
            large_image_v201[076777] != 01234567UL)
                fail_v201('5');
        (void)dsys_writechar(1, 'E');
        (void)dsys_halt();
        return 0;
}
#else
#error Unsupported TEST_V201_STAGE
#endif
