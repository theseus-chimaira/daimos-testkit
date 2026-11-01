/* Full PDP-6 user workload: WRITECHAR/READCHAR share the PIPE word queue
 * and preserve EOF semantics and the existing word-read interface. */
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
        kword_t word;
        int rd;
        int wr;

        (void)argv;
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0)
                fail('1');
        (void)dsys_writechar(1, '<');
        if (new_pipe(&rd, &wr) != 0)
                fail('2');
        if (dsys_writechar(wr, 'A') != 0 || dsys_readchar(rd) != 'A')
                fail('3');
        /* Character IO is a one-word transfer, not packed SIXBIT data. */
        if (dsys_writechar(wr, 'B') != 0)
                fail('4');
        word = 0UL;
        if (dsys_read_words(rd, &word, 1U) != 1 || word != 'B')
                fail('5');
        word = 'C';
        if (dsys_write_words(wr, &word, 1U) != 1 ||
            dsys_readchar(rd) != 'C')
                fail('6');
        if (dsys_close(wr) != 0 || dsys_readchar(rd) != -2 ||
            dsys_close(rd) != 0)
                fail('7');
        if (dsys_meminfo(&after) != 0 ||
            before.file_slots_used != after.file_slots_used ||
            before.process_slots_used != after.process_slots_used)
                fail('8');
        (void)dsys_writechar(1, 'C');
        (void)dsys_halt();
        return 0;
}
