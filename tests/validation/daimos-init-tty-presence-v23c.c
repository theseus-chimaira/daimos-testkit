/* Host regression for the exact C99 INIT presence-check function.
 * The companion script extracts its implementation from production init.c.
 * This verifies all TTY class boundaries and controller-probe outcomes. */
#include "text.h"

#include <stdio.h>
#include <string.h>

static unsigned int present;
static unsigned int calls;
static const char *path_seen;
static int fail_pack;
static int fail_stat;
static int invalid_type;

int
u_s6_pack(kword_t *dst, unsigned int words, const char *src)
{
        if (dst == 0 || words != U_PATH_WORDS || src == 0 || fail_pack)
                return -1;
        dst[0] = 0;
        path_seen = src;
        return 0;
}

int
dsys_stat(kword_t *path, struct vfs_stat *st)
{
        unsigned int bit;

        ++calls;
        if (path == 0 || st == 0 || path_seen == 0 || fail_stat)
                return -1;
        bit = 0U;
        if (strcmp(path_seen, "/DEV/CTY0") == 0)
                bit = 1U;
        else if (strcmp(path_seen, "/DEV/DCS0") == 0)
                bit = 2U;
        else if (strcmp(path_seen, "/DEV/GE0") == 0)
                bit = 4U;
        else
                return -1;
        if ((present & bit) == 0U)
                return -1;
        st->type = invalid_type ? VFS_TYPE_REG : VFS_TYPE_CHAR;
        return 0;
}

/* The production source body is inserted by the test runner here. */
#include "daimos-init-tty-presence-v23c-leaf.inc"

static int
check(unsigned int tty, unsigned int expected, const char *path)
{
        unsigned int before;

        before = calls;
        if ((unsigned int)init_tty_input_present_v23c(tty) != expected)
                return -1;
        if (tty <= SYS_TTY_ID_MAX) {
                if (calls != before + (fail_pack ? 0U : 1U) ||
                    strcmp(path_seen, path) != 0)
                        return -1;
        } else if (calls != before)
                return -1;
        return 0;
}

int
main(void)
{
        present = 7U;
        if (check(0U, 1U, "/DEV/CTY0") != 0 ||
            check(1U, 1U, "/DEV/DCS0") != 0 ||
            check(16U, 1U, "/DEV/DCS0") != 0 ||
            check(17U, 1U, "/DEV/GE0") != 0 ||
            check(20U, 1U, "/DEV/GE0") != 0 ||
            check(21U, 0U, 0) != 0)
                return 1;
        present = 1U;                 /* CTY only, as on AAP */
        if (check(0U, 1U, "/DEV/CTY0") != 0 ||
            check(1U, 0U, "/DEV/DCS0") != 0 ||
            check(17U, 0U, "/DEV/GE0") != 0)
                return 2;
        present = 0U;
        if (check(0U, 0U, "/DEV/CTY0") != 0)
                return 3;
        present = 1U;
        fail_stat = 1;
        if (check(0U, 0U, "/DEV/CTY0") != 0)
                return 4;
        fail_stat = 0;
        invalid_type = 1;
        if (check(0U, 0U, "/DEV/CTY0") != 0)
                return 5;
        invalid_type = 0;
        fail_pack = 1;
        if (check(0U, 0U, "/DEV/CTY0") != 0)
                return 6;
        puts("init-tty-presence-v23c: PASS (CTY/DCS/GE, missing hardware, invalid type and syscall failures)");
        return 0;
}
