/* v1570: genuine Type-551 V2 writable failure -> same/different reel.
 * This is an isolated guest test: v1555 remains read-only in production.
 * The production v1531 privileged owner-safe discard, v1551-v1554
 * first-write, and v1570 physical V2 replacement verifier run for real.
 * Tests are C89 and ASCII; no patient data is reconstructed from tape.
 */
#include "u.h"

#define V1570_WORDS 2U

static kword_t device_v1570[U_PATH_WORDS];
static kword_t target_v1570[U_PATH_WORDS];
static kword_t file_v1570[U_PATH_WORDS];
static kword_t root_v1570[U_PATH_WORDS];
static kword_t old_words_v1570[V1570_WORDS];
static kword_t new_words_v1570[V1570_WORDS];
static struct sys_fsinfo info_v1570;
static struct vfs_stat stat_v1570;

static int
step_v1570(const char *message)
{
    if (u_puts(1, "DTFSV2ADM V1570 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
fail_v1570(const char *message, int result)
{
    (void)step_v1570(message);
    return result;
}

static int
ack_v1570(void)
{
    unsigned int tries;
    int ch;

    for (tries = 0U; tries < 4U; ++tries) {
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

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(device_v1570, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(target_v1570, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(file_v1570, U_PATH_WORDS, "/MOUNT/DT0/POISON") != 0 ||
        u_s6_pack(root_v1570, U_PATH_WORDS, "/") != 0)
        return fail_v1570("FAIL_SETUP", 1);

    if (step_v1570("START") != 0 ||
        dsys_dtfs_mount(device_v1570, target_v1570,
            SYS_DTFS_TYPE_NATIVE) == 0 ||
        dsys_dtfs_mount(device_v1570, target_v1570,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) != 0 ||
        dsys_fsinfo(1U, &info_v1570) != 1 ||
        info_v1570.provider != 5UL)
        return fail_v1570("FAIL_MOUNT", 2);

    old_words_v1570[0] = 010000000UL;
    old_words_v1570[1] = 010000001UL;
    new_words_v1570[0] = 020000000UL;
    new_words_v1570[1] = 020000001UL;
    fd = dsys_open(file_v1570, SYS_O_CREAT | SYS_O_RDWR);
    if (fd < 0 ||
        dsys_truncate(file_v1570, V1570_WORDS) != 0 ||
        dsys_write_words(fd, old_words_v1570, V1570_WORDS) !=
            (int)V1570_WORDS ||
        dsys_seek(fd, 0UL, SYS_SEEK_SET) != 0UL ||
        dsys_chdir(target_v1570) != 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_DROP_FD_V1531,
            (unsigned int)fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0)
        return fail_v1570("FAIL_SEED_OR_UNPOISONED_ADMIN", 3);

    if (step_v1570("READY_ARM") != 0 || ack_v1570() != 0)
        return fail_v1570("FAIL_ARM_ACK", 4);
    if (dsys_write_words(fd, new_words_v1570, V1570_WORDS) >= 0)
        return fail_v1570("FAIL_PARTIAL_ACCEPTED", 5);
    if (step_v1570("WRITE_FAILED") != 0 ||
        step_v1570("READY_VERIFY") != 0 || ack_v1570() != 0)
        return fail_v1570("FAIL_VERIFY_ACK", 6);

    /* A same reel cannot replace its own poisoned open FILE/cwd.
     * Releasing the FD is explicit: ordinary close must fail. */
    if (dsys_fsinfo(1U, &info_v1570) >= 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0 ||
        dsys_close(fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_DROP_FD_V1531,
            (unsigned int)fd) != 0 ||
        dsys_close(fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_DROP_FD_V1531,
            (unsigned int)fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0 ||
        dsys_chdir(root_v1570) != 0)
        return fail_v1570("FAIL_OWNER_RELEASE", 7);

    /* All old owners gone, but the physical RBN0 still names the
     * SAME original poisoned 72-bit ID and is still DIRTY. Neither
     * operator reinsertion nor an independent raw re-read repairs it. */
    if (dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0 ||
        dsys_fsinfo(1U, &info_v1570) >= 0)
        return fail_v1570("FAIL_SAME_ID_RETIRED", 8);
    if (step_v1570("SAME_REJECTED") != 0 ||
        step_v1570("READY_REPLACE") != 0 || ack_v1570() != 0)
        return fail_v1570("FAIL_REPLACE_ACK", 9);

    /* The host has detached the physically damaged DTVOL2/DIRTY tape
     * and attached a separately formatted, different-ID DTVOL2/CLEAN.
     * This privileged operation discards the *old owner*, not its data.
     * The new volume must be freshly mounted READ-ONLY. */
    if (dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 0U) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) != 0 ||
        dsys_fsinfo(1U, &info_v1570) != 0)
        return fail_v1570("FAIL_REPLACE_RETIRE", 10);
    if (step_v1570("RETIRED") != 0 ||
        dsys_dtfs_mount(device_v1570, target_v1570,
            SYS_DTFS_TYPE_NATIVE) == 0 ||
        dsys_dtfs_mount(device_v1570, target_v1570,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) != 0 ||
        dsys_fsinfo(1U, &info_v1570) != 1 ||
        info_v1570.provider != 5UL ||
        dsys_stat(file_v1570, &stat_v1570) == 0 ||
        /* No second test-only policy exception on the replacement:
         * CREATE must fail under its genuine read-only VFS mount. */
        dsys_open(file_v1570, SYS_O_CREAT | SYS_O_RDWR) >= 0 ||
        dsys_unmount(target_v1570) != 0 ||
        dsys_fsinfo(1U, &info_v1570) != 0 ||
        dsys_fsinfo(0U, &info_v1570) != 1 ||
        info_v1570.provider != 7UL)
        return fail_v1570("FAIL_NEW_CLEAN_MOUNT", 11);
    return step_v1570("PASS") != 0 ? 12 : 0;
}
