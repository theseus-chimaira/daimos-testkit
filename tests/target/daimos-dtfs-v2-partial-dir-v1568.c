/* v1568: real PDP-6 DTVOL2/DIRTY directory partial-write test.
 *
 * Only an isolated test KCORE/MRES permits one DTC3 V2 mounted write.
 * The actual Type-551 DIRTY arm, directory write, error propagation,
 * poisoned owner and post-error TSFS root access are production code.
 * C89; ASCII only. */
#include "u.h"

static kword_t dir_device_v1568[U_PATH_WORDS];
static kword_t dir_target_v1568[U_PATH_WORDS];
static kword_t dir_first_v1568[U_PATH_WORDS];
static kword_t dir_second_v1568[U_PATH_WORDS];
static struct sys_fsinfo dir_info_v1568;

static int
dir_step_v1568(const char *message)
{
    if (u_puts(1, "DTFSDIR V1568 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
dir_fail_v1568(const char *message, int code)
{
    (void)dir_step_v1568(message);
    return code;
}

int
main(int argc, kword_t **argv)
{
    int fd;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(dir_device_v1568, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(dir_target_v1568, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(dir_first_v1568, U_PATH_WORDS,
            "/MOUNT/DT0/FIRST") != 0 ||
        u_s6_pack(dir_second_v1568, U_PATH_WORDS,
            "/MOUNT/DT0/SECOND") != 0)
        return dir_fail_v1568("FAIL_SETUP", 1);
    if (dir_step_v1568("START") != 0 ||
        dsys_dtfs_mount(dir_device_v1568, dir_target_v1568,
            SYS_DTFS_TYPE_NATIVE) == 0 ||
        dsys_dtfs_mount(dir_device_v1568, dir_target_v1568,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) != 0 ||
        dsys_fsinfo(1U, &dir_info_v1568) != 1 ||
        dir_info_v1568.provider != 5UL)
        return dir_fail_v1568("FAIL_MOUNT", 2);

    fd = dsys_open(dir_first_v1568, SYS_O_CREAT | SYS_O_RDWR);
    if (fd < 0 || dsys_close(fd) != 0)
        return dir_fail_v1568("FAIL_FIRST_CREATE", 3);
    if (dir_step_v1568("DIRTY_ARMED") != 0 ||
        dir_step_v1568("READY_ARM") != 0)
        return dir_fail_v1568("FAIL_ARM_CHECKPOINT", 4);

    /* New directory entry writes RBN0144. Diagnostic Type-551 cuts the
     * live physical write after ONE changed word, not at a fake VFS
     * callback. The second name needs more than one physical word. */
    fd = dsys_open(dir_second_v1568, SYS_O_CREAT | SYS_O_RDWR);
    if (fd >= 0)
        return dir_fail_v1568("FAIL_PARTIAL_ACCEPTED", 5);
    if (dir_step_v1568("WRITE_FAILED") != 0 ||
        dir_step_v1568("READY_VERIFY") != 0)
        return dir_fail_v1568("FAIL_VERIFY_CHECKPOINT", 6);

    if (dsys_fsinfo(1U, &dir_info_v1568) >= 0 ||
        dsys_chdir(dir_target_v1568) == 0 ||
        dsys_unmount(dir_target_v1568) == 0 ||
        dsys_fsinfo(0U, &dir_info_v1568) != 1 ||
        dir_info_v1568.provider != 7UL)
        return dir_fail_v1568("FAIL_STICKY_ROOT", 7);
    if (dir_step_v1568("STICKY_CONFIRMED") != 0)
        return 8;
    return dir_step_v1568("PASS") != 0 ? 9 : 0;
}
