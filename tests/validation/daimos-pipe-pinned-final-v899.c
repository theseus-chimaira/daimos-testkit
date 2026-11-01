/* Full PDP-6: a real MM pin must leave the last PIPE FILE descriptor
 * and its reference counts intact until unpin/retry completes. */
#include "dsys.h"

static void
fail(int code)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, code);
        (void)dsys_halt();
        for (;;) { }
}

static int
new_pipe(int *rd, int *wr)
{
        kword_t pair;
        pair = dsys_pipe();
        if (pair == ~(kword_t)0UL)
                return -1;
        *rd = (int)((pair >> 18U) & 0777777UL);
        *wr = (int)(pair & 0777777UL);
        if (*rd < 0 || *rd >= 16 || *wr < 0 || *wr >= 16 || *rd == *wr)
                return -1;
        return 0;
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        int rd;
        int wr;
        kword_t word;

        (void)argv;
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0)
                fail('1');
        (void)dsys_writechar(1, '<');
        if (new_pipe(&rd, &wr) != 0)
                fail('2');
        if (dsys_close(wr) != 0)
                fail('3');
        /* The copied-kernel hook pins the exact final object before
         * the production mm_free. PIPE must not drop the FD or refs. */
        if (dsys_close(rd) != -1)
                fail('4');
        /* A PIPE is a word stream. Verify that the retained read end
         * remains usable, now reporting EOF after the writer closed.
         * This is independent of byte-oriented VFS_READCHAR support. */
        word = 0UL;
        if (dsys_read_words(rd, &word, 1U) != 0)
                fail('5');
        /* The next close unpins, then real mm_free must succeed. */
        if (dsys_close(rd) != 0)
                fail('6');
        if (dsys_close(rd) != -1)
                fail('7');
        if (new_pipe(&rd, &wr) != 0 ||
            dsys_close(wr) != 0 || dsys_close(rd) != 0)
                fail('8');
        if (dsys_meminfo(&after) != 0 ||
            after.file_slots_used != before.file_slots_used ||
            after.process_slots_used != before.process_slots_used)
                fail('9');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
