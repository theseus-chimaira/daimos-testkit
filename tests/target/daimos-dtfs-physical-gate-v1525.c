/*
 * Booted PDP-6 KCORE DTFS mount and owner-lifetime oracle, v1525.
 *
 * This is a disposable testkit user process, not production DAIMOS
 * userland. Running all checks within one executable avoids repeated
 * root DECtape seeks while keeping the actual resident KCORE, physical
 * Type-551/Type-136 driver, DTFS MRES, VFS and syscall entry points.
 * No fake mount/FSINFO handlers are supplied by this program.
 *
 * C89, ASCII, and one short process-wide test state only.
 */
#include "u.h"

#define GATE_MAX_SLOTS 26U
#define GATE_DTFS_PROVIDER 5UL

static kword_t gate_device[U_PATH_WORDS];
static kword_t gate_target[U_PATH_WORDS];
static kword_t gate_root[U_PATH_WORDS];
static kword_t gate_cwd[U_PATH_WORDS];
static struct sys_fsinfo gate_info;
static struct vfs_stat gate_stat;

static int
gate_fail(const char *reason, int code)
{
    (void)u_puts(1, "DTFSGATE V1525 FAIL ");
    (void)u_puts(1, reason);
    (void)u_crlf(1);
    return code;
}

static int
gate_step(const char *step)
{
    if (u_puts(1, "DTFSGATE V1525 ") != 0 ||
        u_puts(1, step) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

/*
 * Return 1 only for the real DTFS provider at our target.
 * A pre-existing TSFS directory called /MOUNT/DT0 does not count.
 * Use the genuine FSINFO publication and path, not STAT alone.
 * Scan all slots: a provider error in one populated mount can return
 * -1 for FSINFO without implying that later slots are absent.
 * Treat that error as a separate, recorded P1-D issue, not permission
 * to skip the still-valid physical DTFS mount in a later slot.
 */
static int
gate_published(void)
{
    unsigned int slot;
    unsigned int found;
    int rc;

    found = 0U;
    for (slot = 0U; slot != GATE_MAX_SLOTS; ++slot) {
        rc = dsys_fsinfo(slot, &gate_info);
        (void)u_puts(1, "DTFSGATE V1525 SLOT ");
        (void)u_put_uint(1, (kword_t)slot);
        (void)u_puts(1, " RC ");
        if (rc < 0)
            (void)u_puts(1, "NEG");
        else
            (void)u_put_uint(1, (kword_t)rc);
        if (rc > 0) {
            (void)u_puts(1, " PROVIDER ");
            (void)u_put_uint(1, gate_info.provider);
            (void)u_puts(1, " PATH ");
            (void)u_put_s6(1, gate_info.path);
        }
        (void)u_crlf(1);
        if (rc < 0)
            continue;
        if (rc == 0)
            continue;
        if (gate_info.provider == GATE_DTFS_PROVIDER &&
            u_s6_eq(gate_info.path, "/MOUNT/DT0"))
            ++found;
    }
    return found == 1U ? 1 : (found == 0U ? 0 : -1);
}

int
main(int argc, kword_t **argv)
{
    int rc;
    int fsinfo_ok;
    int fd;

    (void)argc;
    (void)argv;
    if (u_s6_pack(gate_device, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(gate_target, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(gate_root, U_PATH_WORDS, "/") != 0)
        return gate_fail("PATH", 1);
    if (gate_step("START") != 0)
        return 2;

    /* Intentionally call the kernel entry without a userland probe.
     * The actual KCORE v1519/v1520 mount path must validate native
     * directory RBN0144 and identity RBN0 from the physical DTC3.
     */
    rc = dsys_dtfs_mount(gate_device, gate_target,
        SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE);
    if (rc != 0)
        return gate_fail("MOUNT", 3);
    if (gate_step("MOUNTED") != 0)
        return 4;

    fsinfo_ok = gate_published() == 1;
    if (!fsinfo_ok && gate_step("FSINFO_BROKEN") != 0)
        return 5;
    if (gate_step("FSINFO") != 0)
        return 6;

    if (dsys_stat(gate_target, &gate_stat) != 0 ||
        gate_stat.type != VFS_TYPE_DIR)
        return gate_fail("STAT", 7);
    if (dsys_chdir(gate_target) != 0)
        return gate_fail("CHDIR", 8);
    if (dsys_getcwd(gate_cwd, U_PATH_WORDS) != 0 ||
        !u_s6_eq(gate_cwd, "/MOUNT/DT0"))
        return gate_fail("CWD", 9);

    /* Current process owns cwd on the live DTFS mount.
     * The real v1523 all-process lifetime scan must refuse unmount.
     */
    if (dsys_unmount(gate_target) == 0)
        return gate_fail("ACCEPTED_BUSY_UNMOUNT", 10);
    if (gate_published() != 1)
        return gate_fail("LOST_BUSY_MOUNT", 11);
    if (gate_step("BUSY_REFUSED") != 0)
        return 12;

    /* With cwd still inside DTFS, open a real FILE on its directory.
     * Then leave the directory: only the open FILE owns it.  This
     * isolates the v1523 descriptor lifetime guard from the cwd guard.
     */
    fd = dsys_open(gate_target, SYS_O_RDONLY);
    if (fd < 0)
        return gate_fail("OPEN_FILE", 17);
    if (dsys_chdir(gate_root) != 0)
        return gate_fail("CHDIR_ROOT", 13);
    if (dsys_unmount(gate_target) == 0)
        return gate_fail("ACCEPTED_OPEN_FILE_UNMOUNT", 18);
    if (gate_published() != 1)
        return gate_fail("LOST_FILE_MOUNT", 19);
    if (gate_step("FD_REFUSED") != 0)
        return 20;
    if (dsys_close(fd) != 0)
        return gate_fail("CLOSE_FILE", 21);
    if (dsys_unmount(gate_target) != 0)
        return gate_fail("FINAL_UNMOUNT", 14);
    if (gate_published() != 0)
        return gate_fail("STALE_MOUNT", 15);

    if (!fsinfo_ok)
        return gate_fail("FSINFO_NOT_DTFS", 5);
    if (gate_step("PASS") != 0)
        return 16;
    return 0;
}
