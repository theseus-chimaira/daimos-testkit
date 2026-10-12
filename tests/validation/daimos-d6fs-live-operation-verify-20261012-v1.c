/* C99/PDP-6: after an interrupted append, old EOF and contents survive. */
#include "u.h"
#define SEED 0123456701234UL
static kword_t file_path[U_PATH_WORDS];
static kword_t readback[2];
int main(void)
{
        int fd, count;
        if (u_s6_pack(file_path, U_PATH_WORDS, "/CONFIG/FCBSEED") != 0)
                return 1;
        fd = dsys_open(file_path, SYS_O_RDONLY);
        if (fd < 0)
                return 2;
        count = dsys_read_words(fd, readback, 2U);
        (void)dsys_close(fd);
        if (count != 1 || readback[0] != SEED) {
                (void)u_puts(1, "CUT-OLD-FILE-CORRUPT");
                (void)u_crlf(1);
                return 3;
        }
        (void)u_puts(1, "CUT-OLD-EOF-AND-DATA-PASS");
        (void)u_crlf(1);
        return 0;
}
