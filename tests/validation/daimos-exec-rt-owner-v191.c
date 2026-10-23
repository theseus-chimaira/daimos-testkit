/*
 * Native PDP-6 RT_REQUIRED EXEC transaction test, built in three stages.
 * Stage 0 tests failed-load rollback, stage 1 RT admission, stage 2 release.
 * This creates only test files under /TEMP; no kernel instrumentation.
 */
#include "u.h"

#ifndef TEST_RT_STAGE
#error TEST_RT_STAGE must be defined
#endif

#define EXEC_TEST_WORDS (SYS_EXEC_V1_FIXED_WORDS + U_PATH_WORDS)

static void
fail(int code)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, code);
        (void)dsys_halt();
        for (;;) { }
}

#if TEST_RT_STAGE < 2
static int
replace_with(const char *path)
{
        kword_t words[EXEC_TEST_WORDS];
        struct sys_exec_v1 *req;
        unsigned int i;
        unsigned int path_words;

        for (i = 0U; i < EXEC_TEST_WORDS; ++i)
                words[i] = 0UL;
        if (u_s6_pack(&words[SYS_EXEC_V1_FIXED_WORDS], U_PATH_WORDS,
            path) != 0)
                return -1;
        path_words = 1U +
            ((unsigned int)words[SYS_EXEC_V1_FIXED_WORDS] + 5U) / 6U;
        req = (struct sys_exec_v1 *)words;
        req->version_words = SYS_RUN_HEADER(SYS_EXEC_VERSION_1,
            SYS_EXEC_V1_FIXED_WORDS + path_words);
        req->argc = 0UL;
        req->envc = 0UL;
        return dsys_exec(req);
}
#endif

#if TEST_RT_STAGE == 0
static void
make_broken_rt_image(void)
{
        kword_t target[U_PATH_WORDS];
        kword_t header[2];
        int fd;

        if (u_s6_pack(target, U_PATH_WORDS, "/TEMP/BADRT") != 0)
                fail('P');

        /* The same DXR1 encoding emitted by dlink: SIXBIT /DXR/ in LH,
         * valid entry zero, one image word, and RT_REQUIRED in header RH.
         * There is deliberately no image or relocation-map payload.
         * Admission must occur before the loader rejects the file shape.
         */
        header[0] = ((kword_t)0447062UL << 18U);
        header[1] = ((kword_t)1UL << 18U) | 0400000UL;
        fd = dsys_open(target, FILE_O_CREAT | FILE_O_WRITE | FILE_O_TRUNC);
        if (fd < 0)
                fail('C');
        if (dsys_write_words(fd, header, 2U) != 2 ||
            dsys_close(fd) != 0 || dsys_chmod(target, 0555U) != 0)
                fail('W');
}

int
main(void)
{
        if (dsys_getpid() != 1)
                fail('0');
        make_broken_rt_image();
        (void)dsys_writechar(1, '<');

        /* Fresh claim must be undone when image loading fails. */
        if (dsys_rtctl(SYS_RTCTL_DISABLE) != -1 ||
            replace_with("/TEMP/BADRT") != -1 ||
            dsys_rtctl(SYS_RTCTL_DISABLE) != -1)
                fail('1');
        (void)dsys_writechar(1, 'a');

        /* A preexisting owner must not be released by failed EXEC. */
        if (dsys_rtctl(SYS_RTCTL_ENABLE) != 0)
                fail('2');
        if (dsys_rtctl(SYS_RTCTL_DISABLE) != 0)
                fail('A');
        if (dsys_rtctl(SYS_RTCTL_ENABLE) != 0)
                fail('B');
        if (replace_with("/TEMP/BADRT") != -1)
                fail('3');
        if (dsys_rtctl(SYS_RTCTL_DISABLE) != 0)
                fail('4');
        (void)dsys_writechar(1, 'b');

        (void)replace_with("/SYSTEM/EXEC/TSFSPROBE");
        fail('5');
        return 1;
}
#elif TEST_RT_STAGE == 1
int
main(void)
{
        if (dsys_getpid() != 1 ||
            dsys_rtctl(SYS_RTCTL_DISABLE) != 0 ||
            dsys_rtctl(SYS_RTCTL_ENABLE) != 0)
                fail('6');
        (void)dsys_writechar(1, 'R');
        (void)replace_with("/SYSTEM/EXEC/DSH");
        fail('7');
        return 1;
}
#elif TEST_RT_STAGE == 2
int
main(void)
{
        if (dsys_getpid() != 1 ||
            dsys_rtctl(SYS_RTCTL_DISABLE) != -1 ||
            dsys_rtctl(SYS_RTCTL_ENABLE) != 0 ||
            dsys_rtctl(SYS_RTCTL_DISABLE) != 0)
                fail('8');
        (void)dsys_writechar(1, 'N');
        (void)dsys_halt();
        return 0;
}
#else
#error Invalid TEST_RT_STAGE
#endif
