/* Actual PDP-6/Type-551 partial RBN0 CLEAN write and sticky refusal.
 * Only the disposable test image has an arm-on-first-unmount hook.
 * All physical DIRTY/clean I/O, VFS rollback and provider policy after
 * that hook are real production source. C89, ASCII. */
#include "u.h"

static kword_t clean_device_v1567[U_PATH_WORDS];
static kword_t clean_target_v1567[U_PATH_WORDS];
static struct sys_fsinfo clean_info_v1567;

static int
clean_step_v1567(const char *message)
{
    if (u_puts(1, "DTFSCLEAN V1567 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
clean_fail_v1567(const char *message, int code)
{
    (void)clean_step_v1567(message);
    return code;
}

int
main(int argc, kword_t **argv)
{
    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(clean_device_v1567, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(clean_target_v1567, U_PATH_WORDS, "/MOUNT/DT0") != 0)
        return clean_fail_v1567("FAIL_SETUP", 1);
    if (clean_step_v1567("START") != 0)
        return 2;

    /* The untouched production V2 RW mount veto still goes first. */
    if (dsys_dtfs_mount(clean_device_v1567, clean_target_v1567,
            SYS_DTFS_TYPE_NATIVE) == 0 ||
        dsys_dtfs_mount(clean_device_v1567, clean_target_v1567,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) != 0 ||
        dsys_fsinfo(1U, &clean_info_v1567) != 1)
        return clean_fail_v1567("FAIL_ADMISSION", 3);
    if (clean_step_v1567("RW_REFUSED") != 0 ||
        clean_step_v1567("MOUNTED") != 0)
        return 4;

    /* In this disposable image, the FIRST unmount uses the authentic
     * v1551/v1552 Type-551 physical DIRTY mark/readback, then returns
     * refusal without doing CLEAN, leaving the original mount alive.
     * No provider or controller is stubbed, and no production file is
     * altered by this injection. */
    if (dsys_unmount(clean_target_v1567) == 0 ||
        dsys_fsinfo(1U, &clean_info_v1567) != 1 ||
        clean_info_v1567.provider != 5UL)
        return clean_fail_v1567("FAIL_ARM", 5);
    if (clean_step_v1567("DIRTY_ARMED") != 0 ||
        clean_step_v1567("READY_PARTIAL") != 0)
        return 6;

    /* The host stops at a linked, exact KCORE breakpoint just BEFORE
     * the second unmount's production CLEAN provider call. It flushes
     * DIRTY RBN0, verifies its 72-bit ID, attaches the same medium,
     * installs the one-word Type-551 physical failure and resumes.
     * This uses no console input, asynchronous timing or fake I/O. */

    /* SECOND unmount executes the real v1566 physical CLEAN writer.
     * A partial on-media write must fail, poison and RETAIN its mounted
     * owner and exclusive VFS quiescence barrier. */
    if (dsys_unmount(clean_target_v1567) == 0)
        return clean_fail_v1567("FAIL_PARTIAL_ACCEPTED", 8);
    if (clean_step_v1567("WRITE_FAILED") != 0)
        return 9;
    if (dsys_fsinfo(1U, &clean_info_v1567) >= 0 ||
        dsys_chdir(clean_target_v1567) == 0 ||
        dsys_unmount(clean_target_v1567) == 0 ||
        dsys_fsinfo(0U, &clean_info_v1567) != 1 ||
        clean_info_v1567.provider != 7UL)
        return clean_fail_v1567("FAIL_STICKY_OR_ROOT", 10);
    if (clean_step_v1567("POISONED") != 0)
        return 11;
    return clean_step_v1567("PASS") != 0 ? 12 : 0;
}
