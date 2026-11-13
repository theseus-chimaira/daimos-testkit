/*
 * KCORE v1533: physical high-slot FSINFO acceptance on PDP-6.
 * TSFS DTC0..2 root, native independent DTC3..6 on mount IDs 2..5.
 * All calls use the production DTFS provider and real Type-551 tapes.
 * Testkit only. C89, ASCII.
 */
#include "u.h"

static kword_t devices_v1533[4][U_PATH_WORDS];
static kword_t targets_v1533[4][U_PATH_WORDS];
static struct sys_fsinfo info_v1533;
static const char *const device_names_v1533[4] = {
    "/DEV/DTC3", "/DEV/DTC4", "/DEV/DTC5", "/DEV/DTC6"
};
static const char *const target_names_v1533[4] = {
    "/MOUNT/DT0", "/MOUNT/DT1", "/MOUNT/DT2", "/MOUNT/DT3"
};

static int
stage_v1533(const char *stage)
{
    if (u_puts(1, "FSINFOHI V1533 ") != 0 ||
        u_puts(1, stage) != 0 ||
        u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
fail_v1533(const char *stage, int rc)
{
    (void)stage_v1533(stage);
    return rc;
}

int
main(int argc, kword_t **argv)
{
    unsigned int i;
    int rc;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1)
        return fail_v1533("FAIL_PID", 1);
    if (stage_v1533("START") != 0)
        return 2;
    if (dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0) != 7)
        return fail_v1533("FAIL_CAPACITY", 3);
    for (i = 0U; i < 4U; ++i) {
        if (u_s6_pack(devices_v1533[i], U_PATH_WORDS,
                device_names_v1533[i]) != 0 ||
            u_s6_pack(targets_v1533[i], U_PATH_WORDS,
                target_names_v1533[i]) != 0)
            return fail_v1533("FAIL_PATH", 4);
        if (dsys_dtfs_mount(devices_v1533[i], targets_v1533[i],
                SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0)
            return fail_v1533("FAIL_MOUNT", 5);
        if (dsys_fsinfo(1U + i, &info_v1533) != 1 ||
            info_v1533.provider != 5UL ||
            info_v1533.mount_id != (kword_t)(i + 2U) ||
            !u_s6_eq(info_v1533.path, target_names_v1533[i]))
            return fail_v1533("FAIL_SLOT", 6);
    }
    if (stage_v1533("MOUNTED5") != 0)
        return 7;

    /* Scan beyond the old fourth mount; two upper holes remain empty. */
    if (dsys_fsinfo(0U, &info_v1533) != 1 ||
        info_v1533.provider != 7UL)
        return fail_v1533("FAIL_ROOT", 8);
    for (i = 1U; i < 7U; ++i) {
        rc = dsys_fsinfo(i, &info_v1533);
        if ((i < 5U && rc != 1) || (i >= 5U && rc != 0))
            return fail_v1533("FAIL_SCAN", 9);
    }
    if (dsys_fsinfo(7U, 0) >= 0)
        return fail_v1533("FAIL_BOUND", 10);
    if (stage_v1533("SCANNED7") != 0)
        return 11;

    /* Delete a middle mount first: high IDs must remain unchanged. */
    if (dsys_unmount(targets_v1533[1]) != 0 ||
        dsys_fsinfo(2U, &info_v1533) != 0 ||
        dsys_fsinfo(4U, &info_v1533) != 1 ||
        info_v1533.mount_id != 5UL ||
        !u_s6_eq(info_v1533.path, "/MOUNT/DT3"))
        return fail_v1533("FAIL_HOLE", 12);
    if (stage_v1533("HOLE_STABLE") != 0)
        return 13;
    for (i = 4U; i > 0U; --i) {
        if (i == 2U)
            continue;
        if (dsys_unmount(targets_v1533[i - 1U]) != 0)
            return fail_v1533("FAIL_UNMOUNT", 14);
    }
    for (i = 1U; i < 7U; ++i)
        if (dsys_fsinfo(i, &info_v1533) != 0)
            return fail_v1533("FAIL_RETIRE", 15);
    if (dsys_fsinfo(0U, &info_v1533) != 1 ||
        info_v1533.provider != 7UL ||
        dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0) != 7)
        return fail_v1533("FAIL_FINAL", 16);
    if (stage_v1533("RETIRED") != 0)
        return 17;
    return stage_v1533("PASS") != 0 ? 18 : 0;
}
