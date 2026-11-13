/*
 * KCORE P1-C v1534: independent provider survival after a genuine
 * physically failed DTC3 metadata WRITE, with separate DTC4 native
 * DTFS, writable MEMFS, and TSFS root.  Real PDP-6/PID1 guest.
 * Only testkit; C89 and ASCII.
 */
#include "u.h"

static kword_t dev3_v1534[U_PATH_WORDS];
static kword_t dev4_v1534[U_PATH_WORDS];
static kword_t dt0_v1534[U_PATH_WORDS];
static kword_t dt1_v1534[U_PATH_WORDS];
static kword_t ram_v1534[U_PATH_WORDS];
static kword_t file3_v1534[U_PATH_WORDS];
static kword_t file4_v1534[U_PATH_WORDS];
static kword_t fileram_v1534[U_PATH_WORDS];
static kword_t word3_v1534[1] = { 01234567UL };
static kword_t words4_v1534[2] = { 06712345UL, 07654321UL };
static kword_t wordsram_v1534[3] = { 02460321UL, 01357246UL, 03412765UL };
static kword_t received_v1534[3];
static struct sys_fsinfo info_v1534;
static struct vfs_stat stat_v1534;

static int
mixed_stage_v1534(const char *name)
{
    if (u_puts(1, "MIXEDIO V1534 ") != 0 ||
        u_puts(1, name) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
mixed_fail_v1534(const char *name, int rc)
{
    (void)mixed_stage_v1534(name);
    return rc;
}

static int
mixed_wait_v1534(void)
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

static int
mixed_check_file_v1534(kword_t *path, kword_t *expected,
    unsigned int count)
{
    unsigned int i;
    int fd;

    if (dsys_stat(path, &stat_v1534) != 0 ||
        stat_v1534.size_words != (kword_t)count)
        return -1;
    fd = dsys_open(path, SYS_O_RDONLY);
    if (fd < 0)
        return -1;
    if (dsys_read_words(fd, received_v1534, count) != (int)count)
        return -1;
    if (dsys_close(fd) != 0)
        return -1;
    for (i = 0U; i < count; ++i)
        if (received_v1534[i] != expected[i])
            return -1;
    return 0;
}

static int
mixed_check_healthy_v1534(void)
{
    if (dsys_fsinfo(0U, &info_v1534) != 1 ||
        info_v1534.provider != 7UL ||
        dsys_fsinfo(2U, &info_v1534) != 1 ||
        info_v1534.provider != 5UL ||
        !u_s6_eq(info_v1534.path, "/MOUNT/DT1") ||
        mixed_check_file_v1534(file4_v1534, words4_v1534, 2U) != 0 ||
        dsys_fsinfo(3U, &info_v1534) != 1 ||
        info_v1534.provider != 4UL ||
        !u_s6_eq(info_v1534.path, "/MOUNT/RAM") ||
        mixed_check_file_v1534(fileram_v1534,
            wordsram_v1534, 3U) != 0 ||
        dsys_fsinfo(SYS_FSINFO_CAPACITY_SLOT, 0) != 7)
        return -1;
    return 0;
}

int
main(int argc, kword_t **argv)
{
    int fd3;
    int fd;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(dev3_v1534, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(dev4_v1534, U_PATH_WORDS, "/DEV/DTC4") != 0 ||
        u_s6_pack(dt0_v1534, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(dt1_v1534, U_PATH_WORDS, "/MOUNT/DT1") != 0 ||
        u_s6_pack(ram_v1534, U_PATH_WORDS, "/MOUNT/RAM") != 0 ||
        u_s6_pack(file3_v1534, U_PATH_WORDS, "/MOUNT/DT0/FAULT") != 0 ||
        u_s6_pack(file4_v1534, U_PATH_WORDS, "/MOUNT/DT1/CHECK") != 0 ||
        u_s6_pack(fileram_v1534, U_PATH_WORDS,
            "/MOUNT/RAM/CHECK") != 0)
        return mixed_fail_v1534("FAIL_SETUP", 1);
    if (mixed_stage_v1534("START") != 0 ||
        dsys_dtfs_mount(dev3_v1534, dt0_v1534,
            SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_dtfs_mount(dev4_v1534, dt1_v1534,
            SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_memfs_mount(ram_v1534, 4096U, SYS_MOUNT_RW) != 0 ||
        dsys_fsinfo(1U, &info_v1534) != 1 ||
        info_v1534.provider != 5UL)
        return mixed_fail_v1534("FAIL_MOUNT", 2);

    fd3 = dsys_open(file3_v1534, SYS_O_CREAT | SYS_O_RDWR);
    if (fd3 < 0 ||
        dsys_write_words(fd3, word3_v1534, 1U) != 1 ||
        dsys_chmod(file3_v1534, 0U) != 0)
        return mixed_fail_v1534("FAIL_SEED_DTC3", 3);

    fd = dsys_open(file4_v1534, SYS_O_CREAT | SYS_O_RDWR);
    if (fd < 0 ||
        dsys_write_words(fd, words4_v1534, 2U) != 2 ||
        dsys_close(fd) != 0)
        return mixed_fail_v1534("FAIL_SEED_DTC4", 4);
    fd = dsys_open(fileram_v1534, SYS_O_CREAT | SYS_O_RDWR);
    if (fd < 0 ||
        dsys_write_words(fd, wordsram_v1534, 3U) != 3 ||
        dsys_close(fd) != 0)
        return mixed_fail_v1534("FAIL_SEED_MEMFS", 5);
    if (mixed_check_healthy_v1534() != 0)
        return mixed_fail_v1534("FAIL_PRECHECK", 6);
    /*
     * DTC4's last data read displaced DTC3's shared directory cache.
     * Warm DTC3 LAST while it is physically attached. Otherwise the
     * subsequent CHMOD first needs a directory READ and its negative
     * result only marks READ_SUSPECT, never WRITE_UNCERTAIN. This test
     * explicitly requires a failed physical metadata WRITE.
     */
    if (dsys_stat(file3_v1534, &stat_v1534) != 0 ||
        stat_v1534.size_words != 1UL)
        return mixed_fail_v1534("FAIL_WARM_WRITER", 6);
    if (mixed_stage_v1534("READY_DETACH") != 0 ||
        mixed_wait_v1534() != 0)
        return mixed_fail_v1534("FAIL_DETACH_ACK", 7);

    /* The ordinary DTFS commit must reach the physically missing tape,
     * not a mocked provider. The failure quarantines only DTC3. */
    if (dsys_chmod(file3_v1534, 0111U) == 0 ||
        dsys_fsinfo(1U, &info_v1534) >= 0 ||
        dsys_close(fd3) == 0 ||
        dsys_unmount(dt0_v1534) == 0)
        return mixed_fail_v1534("FAIL_WRITER_ISOLATION", 8);
    if (mixed_stage_v1534("WRITE_FAILED") != 0 ||
        mixed_check_healthy_v1534() != 0)
        return mixed_fail_v1534("FAIL_HEALTHY_DURING", 9);
    if (mixed_stage_v1534("HEALTHY_DURING") != 0 ||
        mixed_stage_v1534("READY_RETURN") != 0 ||
        mixed_wait_v1534() != 0)
        return mixed_fail_v1534("FAIL_RETURN_ACK", 10);

    /* Matching identity cannot erase a failed write's sticky marker.
     * A later *healthy* DTC4 metadata write must still succeed. */
    if (dsys_fsinfo(1U, &info_v1534) >= 0)
        return mixed_fail_v1534("FAIL_RETURN_POISON_FSINFO", 11);
    if (dsys_stat(file3_v1534, &stat_v1534) == 0)
        return mixed_fail_v1534("FAIL_RETURN_POISON_STAT", 12);
    if (dsys_close(fd3) == 0)
        return mixed_fail_v1534("FAIL_RETURN_POISON_CLOSE", 13);
    if (dsys_chmod(file4_v1534, 0111U) != 0)
        return mixed_fail_v1534("FAIL_RETURN_DTC4_CHMOD", 14);
    if (mixed_check_healthy_v1534() != 0)
        return mixed_fail_v1534("FAIL_RETURN_HEALTHY_READ", 15);
    if (mixed_stage_v1534("HEALTHY_RETURN") != 0 ||
        dsys_unmount(dt1_v1534) != 0 ||
        dsys_unmount(ram_v1534) != 0 ||
        dsys_fsinfo(2U, &info_v1534) != 0 ||
        dsys_fsinfo(3U, &info_v1534) != 0 ||
        dsys_fsinfo(0U, &info_v1534) != 1 ||
        info_v1534.provider != 7UL ||
        dsys_fsinfo(1U, &info_v1534) >= 0)
        return mixed_fail_v1534("FAIL_RETIRED", 16);
    if (mixed_stage_v1534("RETIRED_HEALTHY") != 0)
        return 17;
    return mixed_stage_v1534("PASS") != 0 ? 18 : 0;
}
