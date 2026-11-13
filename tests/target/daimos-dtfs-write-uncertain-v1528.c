/*
 * Booted PDP-6 P0-B physical WRITE_UNCERTAIN containment, v1528.
 *
 * PID1 mounts stamped DTC3 read/write, creates and opens a native file,
 * and warms its directory. The host then physically detaches DTC3.
 * A real chmod/metadata commit attempts a Type-551 write, which must
 * fail. Reattaching the identical 72-bit volume must NOT make old
 * file, FSINFO or unmount operations succeed. The mount is retained.
 *
 * This deliberately does not assert actual partial-block corruption or
 * administrative recovery; those require separate positive evidence.
 * Testkit only. C89 and ASCII.
 */
#include "u.h"

static kword_t write_device_v1528[U_PATH_WORDS];
static kword_t write_target_v1528[U_PATH_WORDS];
static kword_t write_file_v1528[U_PATH_WORDS];
static struct sys_fsinfo write_info_v1528;
static struct vfs_stat write_stat_v1528;

static int
write_step_v1528(const char *message)
{
    if (u_puts(1, "DTFSWRITE V1528 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
write_fail_v1528(const char *message, int code)
{
    (void)write_step_v1528(message);
    return code;
}

static int
write_wait_v1528(void)
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
    int fd;
    kword_t payload;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(write_device_v1528, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(write_target_v1528, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(write_file_v1528, U_PATH_WORDS,
            "/MOUNT/DT0/FAULT") != 0)
        return write_fail_v1528("FAIL_SETUP", 1);
    if (write_step_v1528("START") != 0 ||
        dsys_dtfs_mount(write_device_v1528, write_target_v1528,
            SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_fsinfo(1U, &write_info_v1528) != 1 ||
        write_info_v1528.provider != 5UL)
        return write_fail_v1528("FAIL_MOUNT_RW", 2);

    fd = dsys_open(write_file_v1528,
        SYS_O_CREAT | SYS_O_RDWR);
    if (fd < 0)
        return write_fail_v1528("FAIL_CREATE", 3);
    payload = 01234567UL;
    if (dsys_write_words(fd, &payload, 1U) != 1 ||
        dsys_chmod(write_file_v1528, 0U) != 0 ||
        dsys_stat(write_file_v1528, &write_stat_v1528) != 0 ||
        write_stat_v1528.size_words != 1UL)
        return write_fail_v1528("FAIL_SEED", 4);
    if (write_step_v1528("READY_DETACH") != 0 ||
        write_wait_v1528() != 0)
        return write_fail_v1528("FAIL_DETACH_ACK", 5);

    /*
     * The directory is already in dtfs_cache_mount from the successful
     * STAT. CHMOD changes the executable map bit and commits the native
     * directory through dtfs_dtc_write even though DTC3 is detached.
     */
    if (dsys_chmod(write_file_v1528, 0111U) == 0)
        return write_fail_v1528("FAIL_WRITE_ACCEPTED", 6);
    if (write_step_v1528("WRITE_FAILED") != 0 ||
        write_step_v1528("READY_RESTORE") != 0 ||
        write_wait_v1528() != 0)
        return write_fail_v1528("FAIL_RETURN_ACK", 7);

    /*
     * If the failure only set READ_SUSPECT, full same-ID return would
     * clear it as in v1527. All three must remain refused, however:
     * WRITE_UNCERTAIN is sticky and retains the published mount.
     */
    if (dsys_fsinfo(1U, &write_info_v1528) >= 0)
        return write_fail_v1528("FAIL_STICKY_FSINFO", 8);
    if (dsys_stat(write_file_v1528, &write_stat_v1528) == 0)
        return write_fail_v1528("FAIL_STICKY_STAT", 9);
    /*
     * FILE close itself performs vfs_sync before releasing a descriptor.
     * On a poisoned DTFS mount this must refuse and retain the owner.
     * Do not treat a failed CLOSE as if the descriptor were discarded.
     */
    if (dsys_close(fd) == 0 || dsys_close(fd) == 0)
        return write_fail_v1528("FAIL_CLOSED_POISONED_FILE", 10);
    if (dsys_unmount(write_target_v1528) == 0)
        return write_fail_v1528("FAIL_UNSAFE_UNMOUNT", 11);

    /* A failed SYNC must retain the original mount slot. */
    if (write_step_v1528("WRITE_STICKY") != 0)
        return 12;
    return write_step_v1528("PASS") != 0 ? 13 : 0;
}
