/*
 * KCORE v1529: real physical partial block-write failure and poison.
 *
 * The host uses a dedicated PDP-6 Type-551 simulator diagnostic to
 * interrupt a real DTC3 data-block write after the first changed word.
 * The physical before/after tape verification belongs to the testkit
 * runner; this real PID1 checks KCORE's existing WRITE_UNCERTAIN policy.
 *
 * Testkit C89, ASCII; neither KCORE nor filesystem is mocked.
 */
#include "u.h"

#define PARTIAL_WORDS_V1529 2U

static kword_t partial_device_v1529[U_PATH_WORDS];
static kword_t partial_target_v1529[U_PATH_WORDS];
static kword_t partial_file_v1529[U_PATH_WORDS];
static kword_t partial_before_v1529[PARTIAL_WORDS_V1529];
static kword_t partial_after_v1529[PARTIAL_WORDS_V1529];
static struct sys_fsinfo partial_info_v1529;
static struct vfs_stat partial_stat_v1529;

static int
partial_step_v1529(const char *message)
{
    if (u_puts(1, "DTFSPART V1529 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
partial_fail_v1529(const char *message, int code)
{
    (void)partial_step_v1529(message);
    return code;
}

static int
partial_ack_v1529(void)
{
    unsigned int i;
    int ch;

    for (i = 0U; i != 4U; ++i) {
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
    unsigned int i;
    int fd;
    int written;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(partial_device_v1529, U_PATH_WORDS,
            "/DEV/DTC3") != 0 ||
        u_s6_pack(partial_target_v1529, U_PATH_WORDS,
            "/MOUNT/DT0") != 0 ||
        u_s6_pack(partial_file_v1529, U_PATH_WORDS,
            "/MOUNT/DT0/PARTIAL") != 0)
        return partial_fail_v1529("FAIL_SETUP", 1);

    if (partial_step_v1529("START") != 0 ||
        dsys_dtfs_mount(partial_device_v1529, partial_target_v1529,
            SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_fsinfo(1U, &partial_info_v1529) != 1 ||
        partial_info_v1529.provider != 5UL)
        return partial_fail_v1529("FAIL_MOUNT", 2);

    for (i = 0U; i != PARTIAL_WORDS_V1529; ++i) {
        partial_before_v1529[i] = 010000000UL + (kword_t)i;
        partial_after_v1529[i] = 020000000UL + (kword_t)i;
    }

    fd = dsys_open(partial_file_v1529, SYS_O_CREAT | SYS_O_RDWR);
    if (fd < 0)
        return partial_fail_v1529("FAIL_CREATE", 3);
    if (dsys_truncate(partial_file_v1529, PARTIAL_WORDS_V1529) != 0)
        return partial_fail_v1529("FAIL_SEED_TRUNCATE", 4);
    if (partial_step_v1529("SEED_TRUNCATE_OK") != 0)
        return 4;
    written = dsys_write_words(fd, partial_before_v1529,
        PARTIAL_WORDS_V1529);
    if (written != (int)PARTIAL_WORDS_V1529) {
        (void)partial_step_v1529("SEED_WRITE_RETURN_OCTAL");
        (void)u_put_octal(1, (kword_t)(unsigned int)written, 12U);
        (void)u_crlf(1);
        return partial_fail_v1529("FAIL_SEED_WRITE", 4);
    }
    if (dsys_stat(partial_file_v1529, &partial_stat_v1529) != 0)
        return partial_fail_v1529("FAIL_SEED_STAT", 4);
    if (partial_stat_v1529.size_words != PARTIAL_WORDS_V1529)
        return partial_fail_v1529("FAIL_SEED_SIZE", 4);
    if (dsys_seek(fd, 0UL, SYS_SEEK_SET) != 0UL)
        return partial_fail_v1529("FAIL_SEED_SEEK", 4);

    /* The host flushes the seeded tape image by detaching DTC3 while
     * the CPU is stopped, copies the genuine 128-word RBN0145 preimage,
     * reattaches it, and arms the Type-551 changed-word fault. */
    if (partial_step_v1529("READY_ARM") != 0 ||
        partial_ack_v1529() != 0)
        return partial_fail_v1529("FAIL_ARM_ACK", 5);

    if (dsys_write_words(fd, partial_after_v1529,
            PARTIAL_WORDS_V1529) >= 0)
        return partial_fail_v1529("FAIL_PARTIAL_ACCEPTED", 6);
    if (partial_step_v1529("WRITE_FAILED") != 0 ||
        partial_step_v1529("READY_VERIFY") != 0 ||
        partial_ack_v1529() != 0)
        return partial_fail_v1529("FAIL_VERIFY_ACK", 7);

    /* The host just detached/reattached the *damaged* tape after
     * checking a nonempty proper subset of its physical data words
     * changed to the attempted new values. Same ID is not repair. */
    if (dsys_fsinfo(1U, &partial_info_v1529) >= 0)
        return partial_fail_v1529("FAIL_STICKY_FSINFO", 8);
    if (dsys_stat(partial_file_v1529, &partial_stat_v1529) == 0)
        return partial_fail_v1529("FAIL_STICKY_STAT", 9);
    if (dsys_close(fd) == 0 || dsys_close(fd) == 0)
        return partial_fail_v1529("FAIL_STICKY_CLOSE", 10);
    if (dsys_unmount(partial_target_v1529) == 0)
        return partial_fail_v1529("FAIL_STICKY_UNMOUNT", 11);
    if (dsys_fsinfo(0U, &partial_info_v1529) != 1 ||
        partial_info_v1529.provider != 7UL)
        return partial_fail_v1529("FAIL_ROOT_BYSTANDER", 12);

    if (partial_step_v1529("STICKY_CONFIRMED") != 0)
        return 13;
    return partial_step_v1529("PASS") != 0 ? 14 : 0;
}
