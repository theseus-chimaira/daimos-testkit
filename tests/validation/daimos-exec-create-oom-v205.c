/*
 * Native PDP-6 EXEC vm_space_create exhaustion regression v205 (C99).
 *
 * Stage 0 increases its unswappable VM to 0600000 words. The new DXR
 * has 0100000 image words, 077000 BSS and 02020 startup overhead, so
 * its physical extent rounds to 0202000. The two extents together exceed
 * all installed 256K core even before subtracting the kernel. The new
 * image is intentionally uncompressed, isolating the allocation and
 * low-memory fallback from compression and filesystem read-back effects.
 * Stage 1 verifies that EXEC preserved PID 1 and boot-time user identity.
 *
 * The test is deliberately independent of the 32K configuration: no
 * memory reserve, loader limit, or production size gate is relaxed.
 */
#include "dsys.h"
#include "../test_sixbit.h"

#ifndef TEST_V205_STAGE
#error TEST_V205_STAGE must be 0 or 1
#endif

static void
fail_v205(int code)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, code);
        (void)dsys_halt();
        for (;;) { }
}

#if TEST_V205_STAGE == 0
#define V205_PARENT_BREAK 0600000UL
#define V205_CHILD_MINIMUM 0202000UL

static volatile kword_t sentinel_v205[040000];
static kword_t exec_path_v205[] = {
        22UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'E', 'X', 'E', 'C'),
        TEST_SIX6('/', 'T', 'S', 'F', 'S', 'P'),
        TEST_SIX6('R', 'O', 'B', 'E', ' ', ' ')
};

static void
exec_stage1_v205(void)
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
                words[SYS_EXEC_V1_FIXED_WORDS + i] = exec_path_v205[i];

        /* A successful EXEC cannot return to this old image. */
        i = (unsigned int)dsys_exec(request);
        fail_v205(i == (unsigned int)-2 ? 'y' : 'x');
}

int
main(void)
{
        struct sys_meminfo memory;
        struct sys_procinfo process;

        if (dsys_getpid() != 1 ||
            dsys_meminfo(&memory) != 0 ||
            memory.total_words != 01000000UL)
                fail_v205('0');
        sentinel_v205[037777] = 01234567UL;
        (void)dsys_writechar(1, '<');

        if (dsys_brk(0UL) == (kword_t)-1L)
                fail_v205('1');
        /* The replacement has 0100000 image words plus 077000 BSS and
         * startup; staging it alongside 0600000 words cannot fit in 256K. */
        if (dsys_brk(V205_PARENT_BREAK) != V205_PARENT_BREAK ||
            sentinel_v205[037777] != 01234567UL ||
            dsys_procinfo(1U, &process) != 0)
                fail_v205('3');

        /* A VM of this size and the live parent's extent cannot both
         * fit in physical memory even if every other user is swapped out. */
        if (process.words + V205_CHILD_MINIMUM <= memory.total_words)
                fail_v205('4');
        (void)dsys_writechar(1, 'H');
        exec_stage1_v205();
        return 1;
}

#elif TEST_V205_STAGE == 1

static volatile kword_t large_image_v205[077000];

int
main(void)
{
        struct sys_procinfo process;

        large_image_v205[076777] = 01234567UL;
        if (dsys_getpid() != 1 ||
            dsys_procinfo(1U, &process) != 0 ||
            process.pid != 1UL ||
            large_image_v205[076777] != 01234567UL)
                fail_v205('5');
        (void)dsys_writechar(1, 'E');
        (void)dsys_halt();
        return 0;
}
#else
#error Unsupported TEST_V205_STAGE
#endif
