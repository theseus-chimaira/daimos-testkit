#include "dsys.h"
#include <pdp10-sixbit.h>

/*
 * Regression for two D6FS shrink bugs:
 *  - d6fs_file_block() must return -1 after the final extent instead of
 *    falling through into the next routine;
 *  - shrinking must preserve the retained extent count while clearing only
 *    discarded extent slots.
 *
 * The historical failure appeared as O_TRUNC failing on an ordinary file
 * after its first write, which in turn broke repeated resident DAS output.
 */

static kword_t path[] = {
    10UL,
    PDP10_SIX6('/','T','E','M','P','/'),
    PDP10_SIX6('G','R','O','W',' ',' ')
};

static kword_t words[01000];
static kword_t check[2];

static void
put_text(const char *s)
{
    while (*s != 0) {
        (void)dsys_writechar(1, (int)(unsigned char)*s);
        ++s;
    }
}

static void
fail(char stage)
{
    put_text("D6FS TRUNCATE REGROW FAIL ");
    (void)dsys_writechar(1, stage);
    put_text("\r\n");
    (void)dsys_halt();
}

int
main(void)
{
    struct vfs_stat st;
    unsigned int i;
    int fd;

    for (i = 0U; i < 01000U; ++i)
        words[i] = (kword_t)(i + 1U);

    fd = dsys_open(path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
    if (fd < 0)
        fail('A');
    if (dsys_write_words(fd, words, 01000U) != 01000)
        fail('B');
    if (dsys_close(fd) != 0)
        fail('C');

    fd = dsys_open(path, SYS_O_RDWR | SYS_O_TRUNC);
    if (fd < 0)
        fail('D');
    if (dsys_close(fd) != 0)
        fail('E');

    if (dsys_stat(path, &st) != 0 || st.size_words != 0UL)
        fail('F');

    fd = dsys_open(path, SYS_O_RDWR);
    if (fd < 0)
        fail('G');
    if (dsys_write_words(fd, words, 2U) != 2)
        fail('H');
    if (dsys_seek(fd, 0U, SYS_SEEK_SET) != 0U)
        fail('I');
    if (dsys_read_words(fd, check, 2U) != 2)
        fail('J');
    if (dsys_close(fd) != 0)
        fail('K');
    if (check[0] != words[0] || check[1] != words[1])
        fail('L');
    if (dsys_stat(path, &st) != 0 || st.size_words != 2UL)
        fail('M');

    put_text("D6FS TRUNCATE REGROW PASS\r\n");
    (void)dsys_halt();
    return 0;
}
