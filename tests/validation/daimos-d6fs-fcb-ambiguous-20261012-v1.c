/* C99: failed FCB publication must not expose an appended record. */
#include "u.h"
#define SEED 0123456701234UL
static kword_t path[U_PATH_WORDS];
static kword_t payload = 0765432107654UL;
static kword_t readback[2];
int main(void)
{
        int fd, rc;
        if (u_s6_pack(path, U_PATH_WORDS, "/CONFIG/FCBSEED") != 0)
                return 1;
        fd = dsys_open(path, SYS_O_WRONLY | SYS_O_APPEND);
        if (fd < 0)
                return 2;
        rc = dsys_write_words(fd, &payload, 1U);
        (void)dsys_close(fd);
        if (rc >= 0) {
                (void)u_puts(1, "FCBAMBIG-NO-ERROR");
                return 3;
        }
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return 4;
        rc = dsys_read_words(fd, readback, 2U);
        (void)dsys_close(fd);
        if (rc != 2 || readback[0] != SEED || readback[1] != payload) {
                (void)u_puts(1, "FCBAMBIG-COMMIT-CONTENT-FAIL");
                return 5;
        }
        (void)u_puts(1, "FCBAMBIG-COMMITTED-PASS");
        (void)u_crlf(1);
        return 0;
}
