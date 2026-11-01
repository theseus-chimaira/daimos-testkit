/* Full PDP-6: both DPY replacement extents pinned and ownership retained.
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
        struct sys_meminfo during;
        struct sys_meminfo after;
        int fd;
        unsigned int i;

        (void)argv;
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_writechar(1, '<') != 0)
                fail('1');
        for (i = 0U; i < DPY_WORDS; ++i)
                frame[i] = 0353535353535UL;
        fd = dsys_open(dpy_path, SYS_O_WRONLY);
        if (fd < 0)
                fail('2');
        if (dsys_write_words(fd, frame, DPY_WORDS) != (int)DPY_WORDS ||
            dsys_meminfo(&during) != 0)
                fail('3');
        /* Let real PI6 ticks and PI7 BLKO completions replay this list. */
        (void)dsys_sleep(12U);
        /* Replacement fails its old free AND new rollback free. */
        if (dsys_write_words(fd, frame, DPY_WORDS) != -5)
                fail('4');
        (void)dsys_sleep(12U);
        /* Pending unpublished extent rejects another write and CLOSE. */
        if (dsys_write_words(fd, frame, DPY_WORDS) != -5)
                fail('5');
        (void)dsys_sleep(12U);
        if (dsys_close(fd) != -5 || dsys_meminfo(&after) != 0)
                fail('6');
        /* Compare FILE/process ownership before and after refused CLOSEs.
         * These calls must not release the FD or consume another slot. */
        if (after.file_slots_used != during.file_slots_used ||
            after.process_slots_used != during.process_slots_used)
                fail('7');
        (void)dsys_writechar(1, 'D');
        (void)dsys_halt();
        return 0;
}
