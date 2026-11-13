/*
 * v1527: physically detached/replaced/returned DTC3, real KCORE and
 * optional DTFS MRES, with an open DTFS FILE held across all failures.
 *
 * The host interrupts SIMH only after READY_* checkpoints; real PID1
 * blocks on its controlling CTY READCHAR until host detach/attach has
 * finished. A separate physically mounted DTC4 displaces the shared
 * directory cache and proves that only the failing DTC3 was marked.
 *
 * Testkit only, C89, ASCII. No fake VFS, physical I/O or MRES handler.
 */
#include "u.h"

static kword_t media_dtc3_v1527[U_PATH_WORDS];
static kword_t media_dtc4_v1527[U_PATH_WORDS];
static kword_t media_dt0_v1527[U_PATH_WORDS];
static kword_t media_dt1_v1527[U_PATH_WORDS];
static struct sys_fsinfo media_info_v1527;
static struct vfs_dirent media_entry_v1527;

static int
media_step_v1527(const char *message)
{
    if (u_puts(1, "DTFSMEDIA V1527 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
media_fail_v1527(const char *reason, int code)
{
    (void)media_step_v1527(reason);
    return code;
}

static int
media_fsinfo_v1527(unsigned int slot, unsigned int provider,
    const char *path)
{
    return dsys_fsinfo(slot, &media_info_v1527) == 1 &&
        media_info_v1527.provider == (kword_t)provider &&
        u_s6_eq(media_info_v1527.path, path);
}

/*
 * READCHAR is intentionally a real CTY input operation. Host sends
 * 'A' only after SIMH has completed the requested media change and
 * resumed the processor. Ignore a bounded number of canonical CR/LF
 * characters from the preceding acknowledgment.
 */
static int
media_wait_v1527(void)
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
    int replaced_info;
    int replaced_file;
    int other_result;
    struct vfs_stat other_stat;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(media_dtc3_v1527, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(media_dtc4_v1527, U_PATH_WORDS, "/DEV/DTC4") != 0 ||
        u_s6_pack(media_dt0_v1527, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(media_dt1_v1527, U_PATH_WORDS, "/MOUNT/DT1") != 0)
        return media_fail_v1527("FAIL_SETUP", 1);

    if (media_step_v1527("START") != 0 ||
        dsys_dtfs_mount(media_dtc3_v1527, media_dt0_v1527,
            SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0 ||
        !media_fsinfo_v1527(1U, 5U, "/MOUNT/DT0"))
        return media_fail_v1527("FAIL_MOUNT3", 2);

    /* Keep a real descriptor and vnode owner from the original DTC3.
     * Mounting DTC4 physically validates its own stamped directory and
     * invalidates all older BCACHE tags; DTC3's directory MUST be read
     * from physical DTC3 after this point, never a cached old success.
     */
    fd = dsys_open(media_dt0_v1527, SYS_O_RDONLY);
    if (fd < 0)
        return media_fail_v1527("FAIL_OPEN3", 3);
    if (dsys_dtfs_mount(media_dtc4_v1527, media_dt1_v1527,
            SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0 ||
        !media_fsinfo_v1527(2U, 5U, "/MOUNT/DT1"))
        return media_fail_v1527("FAIL_MOUNT4", 4);
    if (media_step_v1527("READY_DETACH") != 0 ||
        media_wait_v1527() != 0)
        return media_fail_v1527("FAIL_DETACH_ACK", 5);

    /* The original live mount remains published, but an actual DTC3
     * physical read must now fail. The v1522 READ_SUSPECT marker and
     * clean-cache invalidation must block both FSINFO and old FILE I/O.
     */
    if (dsys_fsinfo(1U, &media_info_v1527) >= 0 ||
        dsys_dirread(fd, &media_entry_v1527) >= 0)
        return media_fail_v1527("FAIL_OFFLINE_CACHED", 6);
    if (!media_fsinfo_v1527(2U, 5U, "/MOUNT/DT1"))
        return media_fail_v1527("FAIL_OTHER_MOUNT", 7);
    if (media_step_v1527("OFFLINE_REFUSED") != 0 ||
        media_step_v1527("READY_SWAP") != 0 ||
        media_wait_v1527() != 0)
        return media_fail_v1527("FAIL_SWAP_ACK", 8);
    /* v1535 witness: distinguish a lost CTY ACK from an actual in-flight
     * DTC4 FSINFO/provider fault. The host queues the ACK using SIMH
     * SEND only after allowing remaining READY_* output to complete.
     * Preserve every following physical media correctness assertion. */
    if (media_step_v1527("SWAP_ACK_RECEIVED_V1535") != 0)
        return media_fail_v1527("FAIL_SWAP_ACK_TRACE_V1535", 25);

    /* A different independently stamped native DTFS volume can satisfy
     * both the full directory validator and RBN0 checksum. It may never
     * satisfy the old open vnode's stored 72-bit equality token.
     */
    other_result = dsys_fsinfo(2U, &media_info_v1527);
    if (other_result < 0)
        return media_fail_v1527("FAIL_DTC4_BEFORE_REPLACEMENT_PROBE_NEG", 19);
    if (other_result != 1 || media_info_v1527.provider != 5UL ||
        !u_s6_eq(media_info_v1527.path, "/MOUNT/DT1"))
        return media_fail_v1527("FAIL_DTC4_BEFORE_REPLACEMENT_PROBE", 20);
    if (media_step_v1527("DTC4_PREPROBE_OK") != 0)
        return 21;
    replaced_info = dsys_fsinfo(1U, &media_info_v1527);
    if (replaced_info >= 0)
        return media_fail_v1527("FAIL_REPLACEMENT_FSINFO", 9);
    other_result = dsys_fsinfo(2U, &media_info_v1527);
    if (other_result < 0) {
        (void)media_step_v1527("DTC4_FSINFO_NEG_CODE");
        (void)u_put_uint(1, (kword_t)(-other_result));
        (void)u_crlf(1);
        other_result = dsys_stat(media_dt1_v1527, &other_stat);
        (void)media_step_v1527(other_result == 0 ?
            "DTC4_STAT_OK_AFTER_NEG_FSINFO" :
            "DTC4_STAT_FAIL_AFTER_NEG_FSINFO");
        return media_fail_v1527("FAIL_DTC4_AFTER_REPLACEMENT_INFO_NEG", 22);
    }
    if (other_result != 1 || media_info_v1527.provider != 5UL ||
        !u_s6_eq(media_info_v1527.path, "/MOUNT/DT1"))
        return media_fail_v1527("FAIL_DTC4_AFTER_REPLACEMENT_INFO", 23);
    if (media_step_v1527("DTC4_AFTER_INFO_OK") != 0)
        return 24;
    replaced_file = dsys_dirread(fd, &media_entry_v1527);
    if (replaced_file >= 0)
        return media_fail_v1527("FAIL_REPLACEMENT_OLD_FILE", 14);
    other_result = dsys_fsinfo(2U, &media_info_v1527);
    if (other_result < 0)
        return media_fail_v1527("FAIL_DTC4_AFTER_OLD_FILE_NEG", 15);
    if (other_result == 0)
        return media_fail_v1527("FAIL_REPLACEMENT_DTC4_EMPTY", 16);
    if (media_info_v1527.provider != 5UL)
        return media_fail_v1527("FAIL_REPLACEMENT_DTC4_PROVIDER", 17);
    if (!u_s6_eq(media_info_v1527.path, "/MOUNT/DT1"))
        return media_fail_v1527("FAIL_REPLACEMENT_DTC4_PATH", 18);
    if (media_step_v1527("REPLACEMENT_REFUSED") != 0 ||
        media_step_v1527("READY_RESTORE") != 0 ||
        media_wait_v1527() != 0)
        return media_fail_v1527("FAIL_RETURN_ACK", 10);

    /* The original IDENTICAL physical tape is back. The full 128-word
     * RBN0 record, checksum, both saved 36-bit ID halves and directory
     * must now be physically reread before re-enabling old FILE use.
     */
    if (!media_fsinfo_v1527(1U, 5U, "/MOUNT/DT0") ||
        dsys_dirread(fd, &media_entry_v1527) < 0 ||
        !media_fsinfo_v1527(2U, 5U, "/MOUNT/DT1"))
        return media_fail_v1527("FAIL_SAME_RETURN", 11);
    if (media_step_v1527("RETURN_VERIFIED") != 0 ||
        dsys_close(fd) != 0 ||
        dsys_unmount(media_dt0_v1527) != 0 ||
        dsys_unmount(media_dt1_v1527) != 0 ||
        dsys_fsinfo(1U, &media_info_v1527) != 0 ||
        dsys_fsinfo(2U, &media_info_v1527) != 0)
        return media_fail_v1527("FAIL_RETIRE", 12);

    return media_step_v1527("PASS") != 0 ? 13 : 0;
}
