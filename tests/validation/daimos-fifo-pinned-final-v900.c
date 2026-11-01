/* Full PDP-6: a pinned named FIFO must remain linked and readable
 * after an unsuccessful last FILE close, until unpin and retry. */
#include "dsys.h"
#include "../test_sixbit.h"

static kword_t fifo_path[] = {
        10UL,
        TEST_SIX6('/', 'T', 'E', 'M', 'P', '/'),
        TEST_SIX6('F', 'I', 'F', 'O', ' ', ' ')
};

static void
fail(int code)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, code);
        (void)dsys_halt();
        for (;;) { }
}

static int
send_word(int fd, kword_t data)
{
        return dsys_write_words(fd, &data, 1U) == 1 ? 0 : -1;
}

static int
recv_word(int fd, kword_t expected)
{
        kword_t data;
        data = 0UL;
        return dsys_read_words(fd, &data, 1U) == 1 &&
            data == expected ? 0 : -1;
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        int fd;
        int fd2;

        (void)argv;
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0)
                fail('1');
        (void)dsys_writechar(1, '<');
        if (dsys_mkfifo(fifo_path, 0640U) != 0)
                fail('2');
        fd = dsys_open(fifo_path, SYS_O_RDWR);
        if (fd < 0 || send_word(fd, 0123456000001UL) != 0 ||
            recv_word(fd, 0123456000001UL) != 0)
                fail('3');
        /* The test kernel pins the FIFO's actual MM extent at the first
         * last-reference free. The descriptor must remain live and the
         * original named stream must be put back on the active list. */
        if (dsys_close(fd) != -1)
                fail('4');
        fd2 = dsys_open(fifo_path, SYS_O_RDWR);
        if (fd2 < 0 || fd2 == fd ||
            send_word(fd, 0123456000002UL) != 0 ||
            recv_word(fd2, 0123456000002UL) != 0)
                fail('5');
        if (dsys_close(fd2) != 0)
                fail('6');
        /* The second last-reference close unpins that exact object and
         * releases its extent, without a duplicate FIFO unlink. */
        if (dsys_close(fd) != 0 || dsys_close(fd) != -1)
                fail('7');
        fd = dsys_open(fifo_path, SYS_O_RDWR);
        if (fd < 0 || send_word(fd, 0123456000003UL) != 0 ||
            recv_word(fd, 0123456000003UL) != 0 ||
            dsys_close(fd) != 0)
                fail('8');
        if (dsys_unlink(fifo_path) != 0 || dsys_meminfo(&after) != 0 ||
            before.file_slots_used != after.file_slots_used ||
            before.process_slots_used != after.process_slots_used)
                fail('9');
        (void)dsys_writechar(1, 'F');
        (void)dsys_halt();
        return 0;
}
