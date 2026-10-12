/* C99: allocation bitmap write failure must preserve old readable EOF. */
#include "u.h"
static kword_t path[U_PATH_WORDS];
static kword_t word = 0123456701234UL;
int main(void)
{
        int fd, rc;
        if (u_s6_pack(path, U_PATH_WORDS, "/CONFIG/MAPFAULT") != 0)
                return 1;
        fd = dsys_open(path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return 2;
        rc = dsys_write_words(fd, &word, 1U);
        if (rc >= 0) {
                (void)u_puts(1, "FAULT-WRITE-UNEXPECTED-SUCCESS");
                return 3;
        }
        (void)dsys_close(fd);
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return 4;
        word = 0UL;
        rc = dsys_read_words(fd, &word, 1U);
        (void)dsys_close(fd);
        if (rc != 0) {
                (void)u_puts(1, "FAULT-EOF-CHANGED");
                return 5;
        }
        (void)u_puts(1, "FAULT-WRITE-ROLLBACK-PASS");
        (void)u_crlf(1);
        return 0;
}
