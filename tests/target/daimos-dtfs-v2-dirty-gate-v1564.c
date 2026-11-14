/* Real booted PDP-6 KCORE/Type-551 DTVOL2 WRITE_INTENT negative gate.
 * Standalone testkit PID1 only; no shadow VFS or DTFS services.
 * C89 and ASCII. A valid DIRTY seal must not be accepted even RO. */
#include "u.h"

static kword_t dirty_device_v1564[U_PATH_WORDS];
static kword_t dirty_target_v1564[U_PATH_WORDS];
static struct sys_fsinfo dirty_info_v1564;

static int
dirty_step_v1564(const char *message)
{
    if (u_puts(1, "DTFSV2DIRTY V1564 ") != 0 ||
        u_puts(1, message) != 0 ||
        u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
dirty_fail_v1564(const char *message, int code)
{
    (void)dirty_step_v1564(message);
    return code;
}

int
main(int argc, kword_t **argv)
{
    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(dirty_device_v1564, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(dirty_target_v1564, U_PATH_WORDS, "/MOUNT/DT0") != 0)
        return dirty_fail_v1564("FAIL_SETUP", 1);
    if (dirty_step_v1564("START") != 0)
        return 2;

    if (dsys_dtfs_mount(dirty_device_v1564, dirty_target_v1564,
            SYS_DTFS_TYPE_NATIVE) == 0)
        return dirty_fail_v1564("FAIL_RW_ADMITTED", 3);
    if (dirty_step_v1564("RW_REFUSED") != 0)
        return 4;

    if (dsys_dtfs_mount(dirty_device_v1564, dirty_target_v1564,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) == 0)
        return dirty_fail_v1564("FAIL_DIRTY_RO_ADMITTED", 5);
    if (dirty_step_v1564("RO_REFUSED") != 0)
        return 6;

    /* The second public slot must not be published by a refused mount.
     * The TSFS directory /MOUNT/DT0 still exists as an unmounted target. */
    if (dsys_fsinfo(1U, &dirty_info_v1564) != 0 ||
        dsys_unmount(dirty_target_v1564) == 0)
        return dirty_fail_v1564("FAIL_GHOST_MOUNT", 7);
    if (dirty_step_v1564("UNPUBLISHED") != 0)
        return 8;

    if (dirty_step_v1564("PASS") != 0)
        return 9;
    return 0;
}
