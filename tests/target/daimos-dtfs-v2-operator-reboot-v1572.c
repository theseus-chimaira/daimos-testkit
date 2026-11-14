/* v1572: cold boot exact production-sealed V2 tape, C89 and ASCII. */
#include "u.h"

static kword_t device_v1572[U_PATH_WORDS];
static kword_t mount_v1572[U_PATH_WORDS];
static kword_t file_v1572[U_PATH_WORDS];
static kword_t value_v1572[2];
static struct sys_fsinfo info_v1572;

static int
step_v1572(const char *message)
{
    if (u_puts(1, "DTFSBOOT V1572 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
fail_v1572(const char *message, int code)
{
    (void)step_v1572(message);
    return code;
}

int
main(int argc, kword_t **argv)
{
    int fd;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(device_v1572, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(mount_v1572, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(file_v1572, U_PATH_WORDS, "/MOUNT/DT0/TRUST") != 0)
        return fail_v1572("FAIL_SETUP", 1);
    if (step_v1572("START") != 0 ||
        dsys_dtfs_mount(device_v1572, mount_v1572,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) != 0 ||
        dsys_fsinfo(1U, &info_v1572) != 1 ||
        info_v1572.provider != 5UL)
        return fail_v1572("FAIL_RO_MOUNT", 2);
    fd = dsys_open(file_v1572, SYS_O_RDONLY);
    if (fd < 0 || dsys_read_words(fd, value_v1572, 2U) != 2 ||
        value_v1572[0] != 020000000UL ||
        value_v1572[1] != 020000001UL ||
        dsys_close(fd) != 0 ||
        step_v1572("READBACK") != 0 ||
        dsys_unmount(mount_v1572) != 0)
        return fail_v1572("FAIL_DATA", 3);
    if (dsys_dtfs_mount(device_v1572, mount_v1572,
            SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_fsinfo(1U, &info_v1572) != 1 ||
        dsys_unmount(mount_v1572) != 0 ||
        dsys_fsinfo(0U, &info_v1572) != 1 ||
        info_v1572.provider != 7UL)
        return fail_v1572("FAIL_RW_NO_WRITE", 4);
    return step_v1572("PASS") != 0 ? 5 : 0;
}
