/* Seed an intentional incomplete S6REC history tail, C99. */
#include "u.h"
static kword_t path[U_PATH_WORDS];
int main(void)
{
    static kword_t data[4] = {
        (1UL << 30) | 9UL,
        ((kword_t)('E'-040)<<30)|((kword_t)('C'-040)<<24)|
        ((kword_t)('H'-040)<<18)|((kword_t)('O'-040)<<12)|
        ((kword_t)('S'-040)),
        ((kword_t)('A'-040)<<30)|((kword_t)('F'-040)<<24)|
        ((kword_t)('E'-040)<<18),
        (1UL << 30) | 18UL /* Missing all three payload words. */
    };
    int fd;
    if (u_s6_pack(path, U_PATH_WORDS, "/.DSH_HISTORY") != 0)
        return 1;
    fd = dsys_open(path, SYS_O_WRONLY|SYS_O_CREAT|SYS_O_TRUNC);
    if (fd < 0)
        return 2;
    if (u_write_words_all(fd,data,4U) != 0 || dsys_close(fd) != 0)
        return 3;
    (void)u_puts(1,"HISTCOR-SEED-PASS");
    (void)u_crlf(1);
    return 0;
}
