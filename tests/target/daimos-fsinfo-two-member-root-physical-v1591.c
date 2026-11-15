/*
 * Physical PDP-6 alternate KINIT mount inventory v1591.
 * Two-member TSFS DTC0/DTC1 root with eight DTC transports and MEMFS
 * publishes 1 root + 6 spare tape transports + 1 MEMFS = 8 slots.
 * Four independent DTC3..6 real media test mount IDs 2..5 and holes.
 * Testkit only; production FSINFO and provider code are unchanged.
 * C89, ASCII.
 */
#include "u.h"

static kword_t devices_v1591[4][U_PATH_WORDS];
static kword_t targets_v1591[4][U_PATH_WORDS];
static struct sys_fsinfo info_v1591;
static const char *const device_names_v1591[4] = {
    "/DEV/DTC3", "/DEV/DTC4", "/DEV/DTC5", "/DEV/DTC6"
};
static const char *const target_names_v1591[4] = {
    "/MOUNT/DT0", "/MOUNT/DT1", "/MOUNT/DT2", "/MOUNT/DT3"
};

static int
step_v1591(const char *name)
{
    return u_puts(1, "FSINFOINV V1591 ") != 0 ||
        u_puts(1, name) != 0 || u_crlf(1) != 0 ? -1 : 0;
}

static int
fail_v1591(const char *name, int error)
{
    (void)step_v1591(name);
    return error;
}

int
main(int argc, kword_t **argv)
{
    unsigned int i;
    int capacity;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1)
        return fail_v1591("FAIL_PID", 1);
    if (step_v1591("START") != 0)
        return 2;
    capacity = dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0);
    if (capacity != 8)
        return fail_v1591("FAIL_CAPACITY", 3);
    if (dsys_fsinfo(0U, &info_v1591) != 1 ||
        info_v1591.provider != 7UL || info_v1591.mount_id != 1UL)
        return fail_v1591("FAIL_ROOT", 4);
    if (step_v1591("CAPACITY8") != 0)
        return 5;

    for (i = 0U; i < 4U; ++i) {
        if (u_s6_pack(devices_v1591[i], U_PATH_WORDS,
                device_names_v1591[i]) != 0 ||
            u_s6_pack(targets_v1591[i], U_PATH_WORDS,
                target_names_v1591[i]) != 0)
            return fail_v1591("FAIL_PATH", 6);
        if (dsys_dtfs_mount(devices_v1591[i], targets_v1591[i],
                SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0)
            return fail_v1591("FAIL_MOUNT", 7);
        if (dsys_fsinfo(1U + i, &info_v1591) != 1 ||
            info_v1591.provider != 5UL ||
            info_v1591.mount_id != (kword_t)(i + 2U) ||
            !u_s6_eq(info_v1591.path, target_names_v1591[i]))
            return fail_v1591("FAIL_SLOT", 8);
    }
    if (step_v1591("MOUNTED5") != 0)
        return 9;

    for (i = 5U; i < 8U; ++i)
        if (dsys_fsinfo(i, &info_v1591) != 0)
            return fail_v1591("FAIL_EMPTY", 10);
    if (dsys_fsinfo(8U, &info_v1591) >= 0 ||
        dsys_fsinfo(9U, &info_v1591) >= 0 ||
        dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0) != 8)
        return fail_v1591("FAIL_BOUND", 11);

    if (dsys_unmount(targets_v1591[1]) != 0 ||
        dsys_fsinfo(2U, &info_v1591) != 0 ||
        dsys_fsinfo(4U, &info_v1591) != 1 ||
        info_v1591.mount_id != 5UL ||
        !u_s6_eq(info_v1591.path, "/MOUNT/DT3"))
        return fail_v1591("FAIL_HOLE", 12);
    if (step_v1591("HOLE_STABLE") != 0)
        return 13;

    for (i = 4U; i > 0U; --i) {
        if (i == 2U)
            continue;
        if (dsys_unmount(targets_v1591[i - 1U]) != 0)
            return fail_v1591("FAIL_UNMOUNT", 14);
    }
    for (i = 1U; i < 8U; ++i)
        if (dsys_fsinfo(i, &info_v1591) != 0)
            return fail_v1591("FAIL_FINAL_EMPTY", 15);
    if (dsys_fsinfo(0U, &info_v1591) != 1 ||
        info_v1591.provider != 7UL ||
        dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0) != 8)
        return fail_v1591("FAIL_FINAL_ROOT", 16);
    if (step_v1591("RETIRED") != 0)
        return 17;
    return step_v1591("PASS") != 0 ? 18 : 0;
}
