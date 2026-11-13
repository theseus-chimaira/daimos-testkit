/*
 * KCORE v1532: real boot-published FSINFO inventory, not a fixed 4 slots.
 * PDP-6 256K, TSFS root DTC0..2: installed DTC controller (8 transports)
 * and MEMFS yield 7 mount slots (root + 5 spare DTC + MEMFS).
 * Test only; the actual FSINFO handler and DTFS mount I/O run unchanged.
 * C89, ASCII.
 */
#include "u.h"

static struct sys_fsinfo cap_info_v1532;
static kword_t cap_dtc3_v1532[U_PATH_WORDS];
static kword_t cap_target_v1532[U_PATH_WORDS];

static int
cap_step_v1532(const char *stage)
{
    if (u_puts(1, "FSINFOCAP V1532 ") != 0 ||
        u_puts(1, stage) != 0 ||
        u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
cap_fail_v1532(const char *stage, int code)
{
    (void)cap_step_v1532(stage);
    return code;
}

int
main(int argc, kword_t **argv)
{
    int capacity;
    unsigned int slot;
    int occupied;
    int rc;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(cap_dtc3_v1532, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(cap_target_v1532, U_PATH_WORDS, "/MOUNT/DT0") != 0)
        return cap_fail_v1532("FAIL_SETUP", 1);
    if (cap_step_v1532("START") != 0)
        return 2;

    /* This call deliberately passes no user-memory record. The kernel
     * must report the live KINIT-published count without mapping AC3. */
    capacity = dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0);
    if (capacity != 7)
        return cap_fail_v1532("FAIL_CAPACITY", 3);
    if (cap_step_v1532("CAPACITY7") != 0)
        return 4;

    /* Empty holes must not be confused with the end of the table. */
    if (dsys_fsinfo(0U, &cap_info_v1532) != 1 ||
        cap_info_v1532.provider != 7UL ||
        cap_info_v1532.mount_id != 1UL)
        return cap_fail_v1532("FAIL_ROOT", 5);
    if (dsys_dtfs_mount(cap_dtc3_v1532, cap_target_v1532,
            SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0)
        return cap_fail_v1532("FAIL_MOUNT", 6);
    if (dsys_fsinfo(1U, &cap_info_v1532) != 1 ||
        cap_info_v1532.provider != 5UL ||
        cap_info_v1532.mount_id != 2UL)
        return cap_fail_v1532("FAIL_DTFS", 7);
    occupied = 0;
    for (slot = 0U; slot < (unsigned int)capacity; ++slot) {
        rc = dsys_fsinfo(slot, &cap_info_v1532);
        if (rc < 0)
            return cap_fail_v1532("FAIL_VALID_SLOT", 8);
        if (rc == 1)
            ++occupied;
        if (slot >= 2U && rc != 0)
            return cap_fail_v1532("FAIL_HOLE", 9);
    }
    if (occupied != 2)
        return cap_fail_v1532("FAIL_ENUM", 10);
    if (dsys_fsinfo((unsigned int)capacity, 0) >= 0 ||
        dsys_fsinfo((unsigned int)capacity + 1U, 0) >= 0)
        return cap_fail_v1532("FAIL_BOUND", 11);
    if (cap_step_v1532("SCANNED7") != 0)
        return 12;

    if (dsys_unmount(cap_target_v1532) != 0 ||
        dsys_fsinfo(1U, &cap_info_v1532) != 0 ||
        dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0) != capacity ||
        dsys_fsinfo(0U, &cap_info_v1532) != 1 ||
        cap_info_v1532.provider != 7UL)
        return cap_fail_v1532("FAIL_RETIRE", 13);
    if (cap_step_v1532("RETIRED") != 0)
        return 14;
    return cap_step_v1532("PASS") != 0 ? 15 : 0;
}
