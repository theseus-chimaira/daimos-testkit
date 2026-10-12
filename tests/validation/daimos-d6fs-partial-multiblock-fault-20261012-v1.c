/* C99: first of two 128-word D6FS blocks succeeds; second is rejected. */
#include "u.h"
#define NWORDS 256U
#define FAULT_MARKER 0765432107654UL
static kword_t path[U_PATH_WORDS];
static kword_t words[NWORDS];
static kword_t check;
int main(void)
{
        int fd, rc;
        unsigned int i;
        if (u_s6_pack(path, U_PATH_WORDS, "/CONFIG/MBFAIL") != 0)
                return 1;
        for (i = 0U; i < NWORDS; ++i)
                words[i] = 012345600000UL + (kword_t)i;
        words[128] = FAULT_MARKER;
        fd = dsys_open(path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return 2;
        rc = dsys_write_words(fd, words, NWORDS);
        (void)dsys_close(fd);
        if (rc >= 0) {
                (void)u_puts(1, "MBFAIL-UNEXPECTED-SUCCESS");
                return 3;
        }
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return 4;
        check = 0UL;
        rc = dsys_read_words(fd, &check, 1U);
        (void)dsys_close(fd);
        if (rc != 0) {
                (void)u_puts(1, "MBFAIL-EOF-CHANGED");
                return 5;
        }
        (void)u_puts(1, "MBFAIL-ROLLBACK-PASS");
        (void)u_crlf(1);
        return 0;
}
