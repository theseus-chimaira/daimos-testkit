/* v1572: unmodified production DTVOL2 RW under operator reel retention.
 * Real PDP-6/Type-551 and original VFS/DTFS/BCACHE/MM services, C89.
 * The reel is never externally exchanged during this mounted run.
 */
#include "u.h"

static kword_t device_v1572[U_PATH_WORDS];
static kword_t mount_v1572[U_PATH_WORDS];
static kword_t file_v1572[U_PATH_WORDS];
static kword_t new_file_v1572[U_PATH_WORDS];
static kword_t root_v1572[U_PATH_WORDS];
static kword_t first_v1572[2];
static kword_t second_v1572[2];
static kword_t read_v1572[2];
static struct sys_fsinfo info_v1572;
static struct vfs_stat stat_v1572;

static int
step_v1572(const char *message)
{
    if (u_puts(1, "DTFSOP V1572 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
fail_v1572(const char *message, int value)
{
    (void)step_v1572(message);
    return value;
}

#ifdef DAIMOS_DTFS_V1572_DIAG
static int
ack_v1572(void)
{
    unsigned int i;
    int c;

    for (i = 0U; i < 4U; ++i) {
        c = dsys_readchar(0);
        if (c == 'A')
            return 0;
        if (c != '\r' && c != '\n')
            return -1;
    }
    return -1;
}
#endif

int
main(int argc, kword_t **argv)
{
    int fd;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(device_v1572, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(mount_v1572, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(file_v1572, U_PATH_WORDS, "/MOUNT/DT0/TRUST") != 0 ||
        u_s6_pack(new_file_v1572, U_PATH_WORDS,
            "/MOUNT/DT0/BLOCK") != 0 ||
        u_s6_pack(root_v1572, U_PATH_WORDS, "/") != 0)
        return fail_v1572("FAIL_SETUP", 1);

    if (step_v1572("START") != 0 ||
        dsys_dtfs_mount(device_v1572, mount_v1572,
            SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_fsinfo(1U, &info_v1572) != 1 ||
        info_v1572.provider != 5UL ||
        step_v1572("RW_MOUNTED") != 0)
        return fail_v1572("FAIL_RW_MOUNT", 2);

    first_v1572[0] = 010000000UL;
    first_v1572[1] = 010000001UL;
    second_v1572[0] = 020000000UL;
    second_v1572[1] = 020000001UL;
    fd = dsys_open(file_v1572, SYS_O_CREAT | SYS_O_RDWR);
    if (fd < 0 || dsys_truncate(file_v1572, 2U) != 0 ||
        dsys_write_words(fd, first_v1572, 2U) != 2)
        return fail_v1572("FAIL_FIRST_WRITE", 3);
#ifdef DAIMOS_DTFS_V1572_DIAG
    if (step_v1572("READY_SECOND") != 0 || ack_v1572() != 0)
        return fail_v1572("FAIL_FIRST_ACK", 3);
#endif
    if (dsys_seek(fd, 0UL, SYS_SEEK_SET) != 0UL ||
        dsys_write_words(fd, second_v1572, 2U) != 2 ||
        step_v1572("DIRTY_WRITES") != 0)
        return fail_v1572("FAIL_WRITE", 3);

    if (dsys_seek(fd, 0UL, SYS_SEEK_SET) != 0UL ||
        dsys_read_words(fd, read_v1572, 2U) != 2 ||
        read_v1572[0] != second_v1572[0] ||
        read_v1572[1] != second_v1572[1] ||
        dsys_stat(file_v1572, &stat_v1572) != 0 ||
        stat_v1572.size_words != 2UL ||
        dsys_close(fd) != 0 ||
        step_v1572("READBACK") != 0)
        return fail_v1572("FAIL_READBACK", 4);
#ifdef DAIMOS_DTFS_V1572_DIAG
    if (step_v1572("READY_CLEAN") != 0 || ack_v1572() != 0)
        return fail_v1572("FAIL_CLEAN_ACK", 4);
#endif

    /* Physical DIRTY->CLEAN is mandatory before owner retirement. */
    if (dsys_unmount(mount_v1572) != 0 ||
        dsys_fsinfo(1U, &info_v1572) != 0 ||
        step_v1572("CLEAN_UNMOUNT") != 0)
        return fail_v1572("FAIL_CLEAN", 5);

    /* Read-only remount must not arm another on-media write. */
    if (dsys_dtfs_mount(device_v1572, mount_v1572,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) != 0)
        return fail_v1572("FAIL_RO_MOUNT", 6);
    if (dsys_fsinfo(1U, &info_v1572) != 1 ||
        info_v1572.provider != 5UL)
        return fail_v1572("FAIL_RO_FSINFO", 6);
    /* O_CREAT on an ALREADY PRESENT file can be non-mutating; only a
     * genuinely NEW file must be refused as an RO namespace mutation. */
    if (dsys_open(new_file_v1572, SYS_O_CREAT | SYS_O_RDWR) >= 0)
        return fail_v1572("FAIL_RO_CREATED", 6);
    if (step_v1572("RO_REMOUNT") != 0)
        return fail_v1572("FAIL_RO_STAGE", 6);
    fd = dsys_open(file_v1572, SYS_O_RDONLY);
    if (fd < 0 || dsys_read_words(fd, read_v1572, 2U) != 2 ||
        read_v1572[0] != second_v1572[0] ||
        read_v1572[1] != second_v1572[1] ||
        dsys_close(fd) != 0 || dsys_unmount(mount_v1572) != 0 ||
        dsys_fsinfo(0U, &info_v1572) != 1 ||
        info_v1572.provider != 7UL)
        return fail_v1572("FAIL_RO_READ", 7);
    return step_v1572("PASS") != 0 ? 8 : 0;
}
