/* v1571: prove an externally exchanged CLEAN reel is invisible to an
 * already mounted V2/RO slot if no Type-551 error has occurred.
 * This is a NEGATIVE safety witness, not acceptable media retention.
 * Real production KCORE/DTFS MRES, real PDP-6 PID1, C89 and ASCII.
 */
#include "u.h"

static kword_t device_v1571[U_PATH_WORDS];
static kword_t target_v1571[U_PATH_WORDS];
static kword_t root_v1571[U_PATH_WORDS];
static struct sys_fsinfo info_v1571;
static struct vfs_stat stat_v1571;

static int
step_v1571(const char *message)
{
    if (u_puts(1, "V2EXCHANGE V1571 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
fail_v1571(const char *message, int result)
{
    (void)step_v1571(message);
    return result;
}

static int
ack_v1571(void)
{
    unsigned int i;
    int c;

    for (i = 0U; i < 4U; ++i) {
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
    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(device_v1571, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(target_v1571, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(root_v1571, U_PATH_WORDS, "/") != 0)
        return fail_v1571("FAIL_SETUP", 1);

    /* First mount is a real production DTVOL2/CLEAN read-only mount.
     * The host will later exchange the attached physical image while
     * the process blocks in CTY READCHAR and performs NO DTC3 I/O. */
    if (step_v1571("START") != 0 ||
        dsys_dtfs_mount(device_v1571, target_v1571,
            SYS_DTFS_TYPE_NATIVE) == 0 ||
        dsys_dtfs_mount(device_v1571, target_v1571,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) != 0 ||
        dsys_fsinfo(1U, &info_v1571) != 1 ||
        info_v1571.provider != 5UL ||
        dsys_stat(target_v1571, &stat_v1571) != 0)
        return fail_v1571("FAIL_INITIAL_MOUNT", 2);
    if (step_v1571("READY_SWAP") != 0 || ack_v1571() != 0)
        return fail_v1571("FAIL_SWAP_ACK", 3);

    /* NO controller fault was reported during host-only swap.
     * Revalidation is driven by READ_SUSPECT, not by a persistent
     * physical media-generation signal. Observe old mounted owner
     * still accepted while a DIFFERENT valid CLEAN 72-bit ID is
     * physically present on the DTC3 transport. */
    if (dsys_fsinfo(1U, &info_v1571) != 1 ||
        info_v1571.provider != 5UL ||
        dsys_stat(target_v1571, &stat_v1571) != 0 ||
        dsys_chdir(target_v1571) != 0)
        return fail_v1571("FAIL_EXPECTED_BLIND_SPOT", 4);
    if (step_v1571("BLIND_SPOT_CONFIRMED") != 0 ||
        dsys_chdir(root_v1571) != 0 ||
        dsys_unmount(target_v1571) != 0 ||
        dsys_fsinfo(1U, &info_v1571) != 0 ||
        dsys_fsinfo(0U, &info_v1571) != 1 ||
        info_v1571.provider != 7UL)
        return fail_v1571("FAIL_OWNER_RETIRE", 5);

    /* This successful unmount is a NEGATIVE witness: no I/O failure
     * forced the kernel to compare the physical RBN0 with the old ID.
     * Do not interpret it as safe runtime reel exchange. */
    return step_v1571("PASS_NEGATIVE") != 0 ? 6 : 0;
}
