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
static int media_fsinfo_v1527(unsigned int slot, unsigned int provider,
    const char *path);
#ifdef DAIMOS_P1C_MEMFS_HILOSS_V1596
/* Writable unrelated memory provider remains alive through real physical
 * DTC6 high-slot detachment. This fixture contains no fake device calls. */
static kword_t media_ram_mount_v1596[U_PATH_WORDS];
static kword_t media_ram_file_v1596[U_PATH_WORDS];
static kword_t media_ram_data_v1596[3] = {
    0157600101UL, 0157600202UL, 0157600303UL
};
static kword_t media_ram_read_v1596[3];

static int
media_ram_check_v1596(void)
{
    unsigned int i;
    int fd;

    fd = dsys_open(media_ram_file_v1596, SYS_O_RDONLY);
    if (fd < 0)
        return -1;
    if (dsys_read_words(fd, media_ram_read_v1596, 3U) != 3 ||
        dsys_close(fd) != 0)
        return -2;
    for (i = 0U; i < 3U; ++i)
        if (media_ram_read_v1596[i] != media_ram_data_v1596[i])
            return -3;
    return 0;
}
#endif
#ifdef DAIMOS_P1D_HI_MEDIA_V1595
/* Distinct live DTC5/DTC6 high-slot volumes; never assign an unused slot
 * to the temporarily unavailable DTC3 owner. This remains a C89 test. */
static kword_t media_hi_devices_v1595[2][U_PATH_WORDS];
static kword_t media_hi_targets_v1595[2][U_PATH_WORDS];
static const char *const media_hi_devs_v1595[2] = {
    "/DEV/DTC5", "/DEV/DTC6"
};
static const char *const media_hi_paths_v1595[2] = {
    "/MOUNT/DT2", "/MOUNT/DT3"
};

static int
media_hi_validate_v1595(int expected_dtc3)
{
    unsigned int i;
    int rc;

    if (dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0) != 8 ||
        dsys_fsinfo(0U, &media_info_v1527) != 1 ||
        media_info_v1527.provider != 7UL ||
        media_info_v1527.mount_id != 1UL)
        return -1;
    rc = dsys_fsinfo(1U, &media_info_v1527);
    if (rc != expected_dtc3)
        return -2;
    if (rc == 1 && (media_info_v1527.provider != 5UL ||
        media_info_v1527.mount_id != 2UL ||
        !u_s6_eq(media_info_v1527.path, "/MOUNT/DT0")))
        return -3;
    if (!media_fsinfo_v1527(2U, 5U, "/MOUNT/DT1") ||
        media_info_v1527.mount_id != 3UL)
        return -4;
    for (i = 0U; i < 2U; ++i) {
        rc = dsys_fsinfo(3U + i, &media_info_v1527);
        if (rc != 1)
            return -5 - (int)i; /* identify actual failed high slot */
        if (media_info_v1527.provider != 5UL ||
            media_info_v1527.mount_id != (kword_t)(4U + i) ||
            !u_s6_eq(media_info_v1527.path, media_hi_paths_v1595[i]))
            return -10 - (int)i; /* distinct false/misbound owner */
    }
#ifdef DAIMOS_P1C_MEMFS_HILOSS_V1596
    if (!media_fsinfo_v1527(5U, 4U, "/MOUNT/RAM") ||
        media_info_v1527.mount_id != 6UL ||
        media_ram_check_v1596() != 0)
        return -8;
    for (i = 6U; i < 8U; ++i)
#else
    for (i = 5U; i < 8U; ++i)
#endif
        if (dsys_fsinfo(i, &media_info_v1527) != 0)
            return -6;
    if (dsys_fsinfo(8U, &media_info_v1527) >= 0 ||
        dsys_fsinfo(9U, &media_info_v1527) >= 0 ||
        dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0) != 8)
        return -7;
    return 0;
}
#endif
#ifdef DAIMOS_DTFS_V2_OPERATOR_V1572
static kword_t media_file_v1572[U_PATH_WORDS];
static kword_t media_data_v1572[2];
#endif

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
        u_s6_pack(media_dt1_v1527, U_PATH_WORDS, "/MOUNT/DT1") != 0
#ifdef DAIMOS_P1C_MEMFS_HILOSS_V1596
        || u_s6_pack(media_ram_mount_v1596, U_PATH_WORDS,
            "/MOUNT/RAM") != 0 ||
        u_s6_pack(media_ram_file_v1596, U_PATH_WORDS,
            "/MOUNT/RAM/KEEP") != 0
#endif
#ifdef DAIMOS_DTFS_V2_OPERATOR_V1572
        || u_s6_pack(media_file_v1572, U_PATH_WORDS,
            "/MOUNT/DT0/TRUST") != 0
#endif
        )
        return media_fail_v1527("FAIL_SETUP", 1);

    if (media_step_v1527("START") != 0 ||
        dsys_dtfs_mount(media_dtc3_v1527, media_dt0_v1527,
#ifdef DAIMOS_DTFS_V2_OPERATOR_V1572
            SYS_DTFS_TYPE_NATIVE) != 0 ||
#else
            SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0 ||
#endif
        !media_fsinfo_v1527(1U, 5U, "/MOUNT/DT0"))
        return media_fail_v1527("FAIL_MOUNT3", 2);

#ifdef DAIMOS_DTFS_V2_OPERATOR_V1572
    /* Real production V2 RW must already be physically ARMED/DIRTY.
     * Test-only DETACH follows and is a deliberately prohibited
     * operator action, used solely to exercise observed-read rollback. */
    media_data_v1572[0] = 010000000UL;
    media_data_v1572[1] = 010000001UL;
    fd = dsys_open(media_file_v1572, SYS_O_CREAT | SYS_O_RDWR);
    if (fd < 0 || dsys_truncate(media_file_v1572, 2U) != 0 ||
        dsys_write_words(fd, media_data_v1572, 2U) != 2 ||
        dsys_close(fd) != 0 ||
        media_step_v1527("RW_ARMED") != 0)
        return media_fail_v1527("FAIL_RW_ARM", 3);
#endif

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
#ifdef DAIMOS_P1D_HI_MEDIA_V1595
    {
        unsigned int i;

        for (i = 0U; i < 2U; ++i) {
            if (u_s6_pack(media_hi_devices_v1595[i], U_PATH_WORDS,
                    media_hi_devs_v1595[i]) != 0 ||
                u_s6_pack(media_hi_targets_v1595[i], U_PATH_WORDS,
                    media_hi_paths_v1595[i]) != 0 ||
                dsys_dtfs_mount(media_hi_devices_v1595[i],
                    media_hi_targets_v1595[i],
                    SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0)
                return media_fail_v1527("FAIL_HI_MOUNT_V1595", 26);
        }
#ifdef DAIMOS_P1C_MEMFS_HILOSS_V1596
        if (dsys_memfs_mount(media_ram_mount_v1596, 4096U,
                SYS_MOUNT_RW) != 0)
            return media_fail_v1527("FAIL_RAM_MOUNT_V1596", 34);
        {
            int ramfd;

            ramfd = dsys_open(media_ram_file_v1596,
                SYS_O_CREAT | SYS_O_RDWR);
            if (ramfd < 0 ||
                dsys_write_words(ramfd, media_ram_data_v1596, 3U) != 3 ||
                dsys_close(ramfd) != 0 ||
                media_ram_check_v1596() != 0 ||
                media_step_v1527("RAM_SEEDED_V1596") != 0)
                return media_fail_v1527("FAIL_RAM_SEED_V1596", 35);
        }
#endif
        if (media_hi_validate_v1595(1) != 0 ||
            media_step_v1527("MOUNTED5_V1595") != 0)
            return media_fail_v1527("FAIL_HI_INITIAL_V1595", 27);
    }
#endif
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
#ifdef DAIMOS_P1D_HI_MEDIA_V1595
    /* v1527 proves slot1 error. v1595 additionally proves that its
     * published owner remains IN slot1 (not silently retired) by
     * successful later original-identity revalidation on return. */
    if (media_hi_validate_v1595(-1) != 0 ||
        media_step_v1527("OFFLINE_HIGH_STABLE_V1595") != 0)
        return media_fail_v1527("FAIL_OFFLINE_HIGH_V1595", 28);
#endif
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
#ifdef DAIMOS_P1D_HI_MEDIA_V1595
    if (media_hi_validate_v1595(-1) != 0 ||
        media_step_v1527("REPLACEMENT_HIGH_STABLE_V1595") != 0)
        return media_fail_v1527("FAIL_REPLACEMENT_HIGH_V1595", 29);
#endif
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
#ifdef DAIMOS_P1D_HI_MEDIA_V1595
    if (media_hi_validate_v1595(1) != 0 ||
        media_step_v1527("RETURN_ALL_STABLE_V1595") != 0)
        return media_fail_v1527("FAIL_RETURN_HIGH_V1595", 30);
#endif
    if (media_step_v1527("RETURN_VERIFIED") != 0)
        return media_fail_v1527("FAIL_RETURN_STAGE", 11);
#ifdef DAIMOS_P1C_MEMFS_HILOSS_V1596
    if (media_step_v1527("READY_HI_DETACH_V1596") != 0 ||
        media_wait_v1527() != 0)
        return media_fail_v1527("FAIL_HI_DETACH_ACK_V1596", 36);
    /* The DTC5 physical read evicts DTC6's loaded directory. DTC6's
     * FSINFO must now physically revalidate and fail, never return
     * an old successful data/space record or mark slot4 empty. */
    if (!media_fsinfo_v1527(3U, 5U, "/MOUNT/DT2") ||
        dsys_fsinfo(4U, &media_info_v1527) >= 0 ||
        !media_fsinfo_v1527(1U, 5U, "/MOUNT/DT0") ||
        !media_fsinfo_v1527(2U, 5U, "/MOUNT/DT1") ||
        !media_fsinfo_v1527(3U, 5U, "/MOUNT/DT2") ||
        dsys_fsinfo(5U, &media_info_v1527) != 1 ||
        media_info_v1527.provider != 4UL ||
        media_info_v1527.mount_id != 6UL ||
        media_ram_check_v1596() != 0)
        return media_fail_v1527("FAIL_HIGH_OFFLINE_V1596", 37);
    {
        int ramfd;

        /* Make real forward progress on unrelated writable MEMFS during
         * the absent physical DTC6 mount, then reread original bytes. */
        ramfd = dsys_open(media_ram_file_v1596, SYS_O_RDWR);
        media_ram_data_v1596[0] = 0157600404UL;
        if (ramfd < 0 ||
            dsys_seek(ramfd, 0UL, SYS_SEEK_SET) != 0 ||
            dsys_write_words(ramfd, media_ram_data_v1596, 1U) != 1 ||
            dsys_close(ramfd) != 0 ||
            media_ram_check_v1596() != 0 ||
            media_step_v1527("HIGH_OFFLINE_RAM_WRITE_V1596") != 0)
            return media_fail_v1527("FAIL_RAM_LIVE_V1596", 38);
    }
    if (media_step_v1527("READY_HI_RETURN_V1596") != 0 ||
        media_wait_v1527() != 0)
        return media_fail_v1527("FAIL_HIGH_RETURN_ACK_V1596", 39);
    {
        int hi_rc;

        hi_rc = media_hi_validate_v1595(1);
        if (hi_rc != 0) {
            /* Keep the precise failing original FSINFO/BCACHE/MEMFS
             * boundary visible. Never mask it with a fallback mount. */
            (void)media_step_v1527("HIGH_RETURN_DIAG_V1596");
            (void)u_put_uint(1, (kword_t)(-hi_rc));
            (void)u_crlf(1);
            return media_fail_v1527("FAIL_HIGH_RETURN_V1596", 40);
        }
        if (media_step_v1527("HIGH_RETURNED_V1596") != 0)
            return media_fail_v1527("FAIL_HIGH_RETURN_STAGE_V1596", 42);
    }
#endif
    if (
        dsys_close(fd) != 0 ||
        dsys_unmount(media_dt0_v1527) != 0 ||
        dsys_unmount(media_dt1_v1527) != 0 ||
        dsys_fsinfo(1U, &media_info_v1527) != 0 ||
        dsys_fsinfo(2U, &media_info_v1527) != 0)
        return media_fail_v1527("FAIL_RETIRE", 12);

#ifdef DAIMOS_P1D_HI_MEDIA_V1595
    {
        unsigned int i;

        for (i = 0U; i < 2U; ++i)
            if (dsys_unmount(media_hi_targets_v1595[i]) != 0)
                return media_fail_v1527("FAIL_HI_UNMOUNT_V1595", 31);
#ifdef DAIMOS_P1C_MEMFS_HILOSS_V1596
        if (dsys_unmount(media_ram_mount_v1596) != 0)
            return media_fail_v1527("FAIL_RAM_UNMOUNT_V1596", 41);
#endif
        for (i = 1U; i < 8U; ++i)
            if (dsys_fsinfo(i, &media_info_v1527) != 0)
                return media_fail_v1527("FAIL_HI_EMPTY_V1595", 32);
        if (dsys_fsinfo(0U, &media_info_v1527) != 1 ||
            media_info_v1527.provider != 7UL ||
            dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0) != 8 ||
            media_step_v1527("RETIRED_ALL_V1595") != 0)
            return media_fail_v1527("FAIL_HI_FINAL_V1595", 33);
    }
#endif

    return media_step_v1527("PASS") != 0 ? 13 : 0;
}
