/*
 * v1538: booted PDP-6 selected TSFS root outage, not synthetic I/O.
 * The host detaches all selected root DECtapes only after READY_DETACH.
 * Returning a negative stat instead of halting is a test failure.
 */
#include "u.h"

static kword_t path_init_v1538[U_PATH_WORDS];
static kword_t path_system_v1538[U_PATH_WORDS];
static kword_t path_config_v1538[U_PATH_WORDS];
static kword_t root_data_v1538[0200];
static struct vfs_stat stat_v1538;

static int
rootloss_stage_v1538(const char *message)
{
    if (u_puts(1, "ROOTLOSS V1538 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
rootloss_ack_v1538(void)
{
    unsigned int i;
    int ch;

    for (i = 0U; i < 4U; ++i) {
        ch = dsys_readchar(0);
        if (ch == 'A')
            return 0;
        if (ch != '\r' && ch != '\n')
            return -1;
    }
    return -1;
}

int
main(int argc, kword_t **argv)
{
    unsigned int i;
    int fd;
    (void)argv;

    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(path_init_v1538, U_PATH_WORDS, "/SYSTEM/INIT") != 0 ||
        u_s6_pack(path_system_v1538, U_PATH_WORDS, "/SYSTEM") != 0 ||
        u_s6_pack(path_config_v1538, U_PATH_WORDS, "/CONFIG") != 0 ||
        rootloss_stage_v1538("START") != 0 ||
        dsys_stat(path_init_v1538, &stat_v1538) != 0 ||
        dsys_stat(path_system_v1538, &stat_v1538) != 0 ||
        dsys_stat(path_config_v1538, &stat_v1538) != 0)
        return 1;

    if (rootloss_stage_v1538("READY_DETACH") != 0 ||
        rootloss_ack_v1538() != 0)
        return 2;

    /* Directory and file metadata may remain in small shared caches after
     * a detach. Force a genuine file-data read rather than relying on STAT
     * to miss metadata caches. INIT is a real nonempty root executable.
     * The first failed physical I/O must stop in KCORE, never return -1.
     */
    fd = dsys_open(path_init_v1538, SYS_O_RDONLY);
    if (fd < 0) {
        (void)rootloss_stage_v1538("FAIL_RETURNED_OPEN");
        return 3;
    }
    for (i = 0U; i < 16U; ++i) {
        int rc;

        rc = dsys_read_words(fd, root_data_v1538, 0200U);
        if (rc <= 0) {
            (void)rootloss_stage_v1538("FAIL_RETURNED_DATA");
            return 4;
        }
    }

    /* Last resort: alternate root metadata lookups to evict any stale
     * metadata cache entries and provoke a new on-media table read.
     */
    for (i = 0U; i < 18U; ++i) {
        kword_t *path;
        int rc;

        if (i % 3U == 0U)
            path = path_init_v1538;
        else if (i % 3U == 1U)
            path = path_system_v1538;
        else
            path = path_config_v1538;
        rc = dsys_stat(path, &stat_v1538);
        if (rc != 0) {
            (void)rootloss_stage_v1538("FAIL_RETURNED_IO");
            return 5;
        }
    }
    (void)rootloss_stage_v1538("FAIL_NO_HALT");
    return 6;
}
