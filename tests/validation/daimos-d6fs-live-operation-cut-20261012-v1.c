/* C99/PDP-6: trigger an interrupted file append after its data write.
 * All physical failure injection is in the test-only backing assembler.
 */
#include "u.h"
#define SEED 0123456701234UL
static kword_t file_path[U_PATH_WORDS];
static kword_t new_word = 0765432107654UL;
int main(void)
{
        int fd;
        (void)u_puts(1, "OPERATION-CUT-START");
        (void)u_crlf(1);
        if (u_s6_pack(file_path, U_PATH_WORDS, "/CONFIG/FCBSEED") != 0)
                return 1;
        fd = dsys_open(file_path, SYS_O_WRONLY | SYS_O_APPEND);
        if (fd < 0)
                return 2;
        /* With an active fault injector, execution halts inside the backing
         * callback and must never reach the following message. */
        (void)dsys_write_words(fd, &new_word, 1U);
        (void)dsys_close(fd);
        (void)u_puts(1, "OPERATION-CUT-NOT-TRIGGERED");
        (void)u_crlf(1);
        return 3;
}
