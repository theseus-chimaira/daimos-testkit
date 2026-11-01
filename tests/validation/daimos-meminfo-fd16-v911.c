/* Native PDP-6: SYS_MEMINFO must count every one of 16 FILE slots. */
#include "dsys.h"

#define TEST_FD_LIMIT 16

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
        struct sys_meminfo initial;
        struct sys_meminfo current;
        int fds[TEST_FD_LIMIT];
        unsigned int count;
        int fd;

        (void)argv;
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&initial) != 0 ||
            initial.file_slots_total != TEST_FD_LIMIT ||
            initial.file_slots_used >= TEST_FD_LIMIT)
                fail('1');
        if (dsys_writechar(1, '<') != 0)
                fail('2');

        /* Fill all descriptors, including the last physical FILE slot. */
        count = 0U;
        for (;;) {
                fd = dsys_dup(1);
                if (fd < 0)
                        break;
                if (fd >= TEST_FD_LIMIT || count >= TEST_FD_LIMIT)
                        fail('3');
                fds[count++] = fd;
                if (dsys_meminfo(&current) != 0 ||
                    current.file_slots_used != initial.file_slots_used + count ||
                    current.file_slots_total != TEST_FD_LIMIT ||
                    current.process_slots_used != initial.process_slots_used)
                        fail('4');
        }
        if (count == 0U || fds[count - 1U] != TEST_FD_LIMIT - 1 ||
            current.file_slots_used != TEST_FD_LIMIT)
                fail('5');

        while (count != 0U) {
                --count;
                if (dsys_close(fds[count]) != 0)
                        fail('6');
        }
        if (dsys_meminfo(&current) != 0 ||
            current.file_slots_used != initial.file_slots_used ||
            current.process_slots_used != initial.process_slots_used)
                fail('7');
        (void)dsys_writechar(1, 'F');
        (void)dsys_halt();
        return 0;
}
