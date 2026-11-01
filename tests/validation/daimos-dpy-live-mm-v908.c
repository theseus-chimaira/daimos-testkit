/* Full PDP-6: live DPY raw replay survives MM_BUSY at final CLOSE.
 * This workload runs only with test-only instrumentation in a copied kernel. */
#include "dsys.h"
#include "../test_sixbit.h"

#define DPY_WORDS 32U

static kword_t dpy_path[] = {
        9UL,
        TEST_SIX6('/', 'D', 'E', 'V', '/', 'D'),
        TEST_SIX6('P', 'Y', '0', ' ', ' ', ' ')
};
static kword_t frame[DPY_WORDS];

static void
fail(int code)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, code);
        (void)dsys_halt();
        for (;;) { }
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        int fd;
        int next_fd;
        unsigned int i;

        (void)argv;
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0 ||
            dsys_writechar(1, '<') != 0)
                fail('1');
        for (i = 0U; i < DPY_WORDS; ++i)
                frame[i] = 0353535353535UL;
        fd = dsys_open(dpy_path, SYS_O_WRONLY);
        if (fd < 0)
                fail('2');
        if (dsys_write_words(fd, frame, DPY_WORDS) != (int)DPY_WORDS)
                fail('3');
        /* Let real PI6 ticks and PI7 BLKO completions replay this list. */
        (void)dsys_sleep(12U);
        /* Test-only MM hook pins the real DPY extent on this final close. */
        if (dsys_close(fd) != -5)
                fail('4');
        /* The FILE descriptor and original list remain live after MM_BUSY. */
        (void)dsys_sleep(12U);
        if (dsys_close(fd) != 0 || dsys_close(fd) != -1)
                fail('5');
        /* Test that a subsequent program can allocate/release another list. */
        next_fd = dsys_open(dpy_path, SYS_O_WRONLY);
        if (next_fd < 0 ||
            dsys_write_words(next_fd, frame, DPY_WORDS) != (int)DPY_WORDS)
                fail('6');
        (void)dsys_sleep(12U);
        if (dsys_close(next_fd) != 0 || dsys_meminfo(&after) != 0)
                fail('7');
        if (before.file_slots_used != after.file_slots_used ||
            before.process_slots_used != after.process_slots_used)
                fail('8');
        (void)dsys_writechar(1, 'D');
        (void)dsys_halt();
        return 0;
}
