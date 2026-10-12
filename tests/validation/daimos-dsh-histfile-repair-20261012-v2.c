/* Target PDP-6 regression: verify automatic HISTFILE damaged-tail repair.
 * Executed as the second command following startup and one Ctrl-P recall.
 * The DSH records the command before executing it.
 */
#include "u.h"
#include "text.h"

#define REPAIR_TEST_WORDS 31U

static int
read_record(struct u_text_reader *reader, kword_t *buf, int expected)
{
        return u_text_gets6(reader, buf, REPAIR_TEST_WORDS) == expected;
}

int
main(void)
{
        static kword_t path[U_PATH_WORDS];
        static kword_t rec[REPAIR_TEST_WORDS];
        struct u_text_reader reader;
        struct vfs_stat st;
        int fd;
        int ok;

        if (u_s6_pack(path, U_PATH_WORDS, "/.DSH_HISTORY") != 0 ||
            dsys_stat(path, &st) != 0 || st.type != VFS_TYPE_REG)
                return 1;
        /* Two 9-character entries occupy 3 words apiece; this 20-character
         * command occupies another 5. Damaged old tail must be absent. */
        if (st.size_words != 11UL)
                return 2;
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return 3;
        (void)u_text_open_fd(&reader, fd);
        ok = read_record(&reader, rec, 9) &&
            read_record(&reader, rec, 9) &&
            read_record(&reader, rec, 20) &&
            u_text_gets6(&reader, rec, REPAIR_TEST_WORDS) == U_TEXT_EOF;
        u_text_close(&reader);
        if (!ok)
                return 4;
        (void)u_puts(1, "HISTCOR-REPAIR-PASS");
        (void)u_crlf(1);
        return 0;
}
