/*
 * KCORE v1531: privileged recovery of a partially untrusted DTFS mount.
 *
 * This booted PDP-6 PID1 uses the real UUO-077 extension. The host
 * physically detaches DTC3 to cause a write failure, reattaches the
 * original stamped medium (which MUST be refused for retirement),
 * then installs a DIFFERENT independently stamped native DTFS volume.
 * Explicit FD drop and all-process mount owner checks precede retirement.
 * No data is copied from the uncertain volume or declared repaired.
 *
 * C89, ASCII; test code only (production paths unchanged).
 */
#include "u.h"

static kword_t rec_device_v1531[U_PATH_WORDS];
static kword_t rec_target_v1531[U_PATH_WORDS];
static kword_t rec_file_v1531[U_PATH_WORDS];
static kword_t rec_root_v1531[U_PATH_WORDS];
static struct sys_fsinfo rec_info_v1531;

static int
rec_step_v1531(const char *s)
{
    if (u_puts(1, "DTFSADMIN V1531 ") != 0 ||
        u_puts(1, s) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
rec_fail_v1531(const char *s, int code)
{
    (void)rec_step_v1531(s);
    return code;
}

static int
rec_ack_v1531(void)
{
    unsigned int i;
    int c;

    for (i = 0U; i != 4U; ++i) {
        c = dsys_readchar(0);
        if (c == 'A')
            return 0;
        if (c != '\r' && c != '\n')
            return -1;
    }
    return -1;
}

int
main(int argc, kword_t **argv)
{
    int fd;
    kword_t data;
    struct vfs_stat st;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(rec_device_v1531, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(rec_target_v1531, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(rec_file_v1531, U_PATH_WORDS,
            "/MOUNT/DT0/POISON") != 0 ||
        u_s6_pack(rec_root_v1531, U_PATH_WORDS, "/") != 0)
        return rec_fail_v1531("FAIL_SETUP", 1);
    if (rec_step_v1531("START") != 0 ||
        dsys_dtfs_mount(rec_device_v1531, rec_target_v1531,
            SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_fsinfo(1U, &rec_info_v1531) != 1 ||
        rec_info_v1531.provider != 5UL)
        return rec_fail_v1531("FAIL_MOUNT", 2);

    fd = dsys_open(rec_file_v1531, SYS_O_CREAT | SYS_O_RDWR);
    data = 01234567UL;
    if (fd < 0 || dsys_write_words(fd, &data, 1U) != 1 ||
        dsys_chmod(rec_file_v1531, 0U) != 0 ||
        dsys_chdir(rec_target_v1531) != 0)
        return rec_fail_v1531("FAIL_SEED", 3);
    /* Destructive recovery is not a synonym for ordinary CLOSE/UNMOUNT. */
    if (dsys_dtfs_recover_v1531(SYS_DTFS_DROP_FD_V1531,
            (unsigned int)fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 0U) == 0)
        return rec_fail_v1531("FAIL_CLEAN_ACCEPTED", 4);

    if (rec_step_v1531("READY_DETACH") != 0 ||
        rec_ack_v1531() != 0)
        return rec_fail_v1531("FAIL_DETACH_ACK", 5);
    if (dsys_chmod(rec_file_v1531, 0111U) == 0 ||
        dsys_fsinfo(1U, &rec_info_v1531) >= 0)
        return rec_fail_v1531("FAIL_WRITE_STICKY", 6);
    if (rec_step_v1531("WRITE_FAILED") != 0 ||
        rec_step_v1531("READY_RETURN") != 0 ||
        rec_ack_v1531() != 0)
        return rec_fail_v1531("FAIL_RETURN_ACK", 7);

    if (dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0)
        return rec_fail_v1531("FAIL_OWNER_BUSY", 8);
    if (dsys_close(fd) == 0)
        return rec_fail_v1531("FAIL_NORMAL_CLOSE", 9);
    if (dsys_dtfs_recover_v1531(SYS_DTFS_DROP_FD_V1531,
            (unsigned int)fd) != 0 ||
        dsys_close(fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_DROP_FD_V1531,
            (unsigned int)fd) == 0)
        return rec_fail_v1531("FAIL_EXPLICIT_DROP", 10);
    if (dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0)
        return rec_fail_v1531("FAIL_CWD_OWNER", 11);
    if (dsys_chdir(rec_root_v1531) != 0)
        return rec_fail_v1531("FAIL_CWD_RELEASE", 12);

    /* After dropping all owners, the SAME damaged original still cannot
     * be retired. A fresh different RBN0 ID and valid directory are both
     * required by the private physical Type-551 replacement verifier. */
    if (dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0 ||
        dsys_fsinfo(1U, &rec_info_v1531) >= 0)
        return rec_fail_v1531("FAIL_SAME_ID_ACCEPTED", 13);
    if (rec_step_v1531("SAME_REJECTED") != 0 ||
        rec_step_v1531("READY_REPLACE") != 0 ||
        rec_ack_v1531() != 0)
        return rec_fail_v1531("FAIL_REPLACE_ACK", 14);

    if (dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 0U) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) != 0 ||
        dsys_fsinfo(1U, &rec_info_v1531) != 0)
        return rec_fail_v1531("FAIL_REPLACE_RETIRE", 15);
    if (rec_step_v1531("RETIRED") != 0 ||
        dsys_dtfs_mount(rec_device_v1531, rec_target_v1531,
            SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_fsinfo(1U, &rec_info_v1531) != 1 ||
        rec_info_v1531.provider != 5UL ||
        dsys_stat(rec_file_v1531, &st) == 0)
        return rec_fail_v1531("FAIL_NEW_MOUNT", 16);
    if (dsys_unmount(rec_target_v1531) != 0 ||
        dsys_fsinfo(1U, &rec_info_v1531) != 0 ||
        dsys_fsinfo(0U, &rec_info_v1531) != 1 ||
        rec_info_v1531.provider != 7UL)
        return rec_fail_v1531("FAIL_NEW_RETIRE_ROOT", 17);
    return rec_step_v1531("PASS") != 0 ? 18 : 0;
}
