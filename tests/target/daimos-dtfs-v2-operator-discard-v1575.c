/* v1575: operator-trust V2 poisoned-slot discard and independent mount.
 * Real production PDP-6 Type-551 partial write, explicit FILE/cwd release,
 * provider-lease drain without any replacement RBN0 preflight, then a new
 * native mount after the operator supplies a different CLEAN reel.
 * The original DIRTY reel is rejected at the normal mount boundary.
 * C89, ASCII. No failed write is reconstructed or silently repaired.
 */
#include "u.h"

#define V1575_WORDS 2U

static kword_t device_v1575[U_PATH_WORDS];
static kword_t target_v1575[U_PATH_WORDS];
static kword_t file_v1575[U_PATH_WORDS];
static kword_t root_v1575[U_PATH_WORDS];
static kword_t old_words_v1575[V1575_WORDS];
static kword_t new_words_v1575[V1575_WORDS];
static struct sys_fsinfo info_v1575;
static struct vfs_stat stat_v1575;

static int
step_v1575(const char *message)
{
    if (u_puts(1, "DTFSV2ADM V1575 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
fail_v1575(const char *message, int result)
{
    (void)step_v1575(message);
    return result;
}

static int
ack_v1575(void)
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
        u_s6_pack(device_v1575, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(target_v1575, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(file_v1575, U_PATH_WORDS, "/MOUNT/DT0/POISON") != 0 ||
        u_s6_pack(root_v1575, U_PATH_WORDS, "/") != 0)
        return fail_v1575("FAIL_SETUP", 1);

    if (step_v1575("START") != 0 ||
        dsys_dtfs_mount(device_v1575, target_v1575,
            SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_fsinfo(1U, &info_v1575) != 1 ||
        info_v1575.provider != 5UL)
        return fail_v1575("FAIL_MOUNT", 2);

    old_words_v1575[0] = 010000000UL;
    old_words_v1575[1] = 010000001UL;
    new_words_v1575[0] = 020000000UL;
    new_words_v1575[1] = 020000001UL;
    fd = dsys_open(file_v1575, SYS_O_CREAT | SYS_O_RDWR);
    if (fd < 0 ||
        dsys_truncate(file_v1575, V1575_WORDS) != 0 ||
        dsys_write_words(fd, old_words_v1575, V1575_WORDS) !=
            (int)V1575_WORDS ||
        dsys_seek(fd, 0UL, SYS_SEEK_SET) != 0UL ||
        dsys_chdir(target_v1575) != 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_DROP_FD_V1531,
            (unsigned int)fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0)
        return fail_v1575("FAIL_SEED_OR_UNPOISONED_ADMIN", 3);

    if (step_v1575("READY_ARM") != 0 || ack_v1575() != 0)
        return fail_v1575("FAIL_ARM_ACK", 4);
    if (dsys_write_words(fd, new_words_v1575, V1575_WORDS) >= 0)
        return fail_v1575("FAIL_PARTIAL_ACCEPTED", 5);
    if (step_v1575("WRITE_FAILED") != 0 ||
        step_v1575("READY_VERIFY") != 0 || ack_v1575() != 0)
        return fail_v1575("FAIL_VERIFY_ACK", 6);

    /* A same reel cannot replace its own poisoned open FILE/cwd.
     * Releasing the FD is explicit: ordinary close must fail. */
    if (dsys_fsinfo(1U, &info_v1575) >= 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0 ||
        dsys_close(fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_DROP_FD_V1531,
            (unsigned int)fd) != 0 ||
        dsys_close(fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_DROP_FD_V1531,
            (unsigned int)fd) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0 ||
        dsys_chdir(root_v1575) != 0)
        return fail_v1575("FAIL_OWNER_RELEASE", 7);

    /* Discard is allowed with the original DIRTY reel still present:
     * the operator explicitly abandoned this damaged mounted owner.
     * No replacement-media reads occur in the private provider drain.
     * Normal MOUNT must nevertheless reject this same physical DIRTY reel.
     */
    if (dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) != 0 ||
        dsys_fsinfo(1U, &info_v1575) != 0 ||
        dsys_dtfs_mount(device_v1575, target_v1575,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) == 0 ||
        dsys_dtfs_mount(device_v1575, target_v1575,
            SYS_DTFS_TYPE_NATIVE) == 0)
        return fail_v1575("FAIL_DIRTY_REMOUNT", 8);
    if (step_v1575("DISCARDED_DIRTY") != 0 ||
        step_v1575("READY_REPLACE") != 0 || ack_v1575() != 0)
        return fail_v1575("FAIL_REPLACE_ACK", 9);

    /* The operator has now independently installed a CLEAN reel.
     * Retired slots cannot be discarded twice; normal MOUNT validates.
     */
    if (dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 0U) == 0 ||
        dsys_dtfs_recover_v1531(SYS_DTFS_REPLACE_SLOT_V1531, 1U) == 0 ||
        dsys_fsinfo(1U, &info_v1575) != 0)
        return fail_v1575("FAIL_DISCARD_TWICE", 10);
    if (step_v1575("RETIRED") != 0 ||
        dsys_dtfs_mount(device_v1575, target_v1575,
            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) != 0 ||
        dsys_fsinfo(1U, &info_v1575) != 1 ||
        info_v1575.provider != 5UL ||
        dsys_stat(file_v1575, &stat_v1575) == 0 ||
        /* CREATE must fail under the genuine read-only VFS mount. */
        dsys_open(file_v1575, SYS_O_CREAT | SYS_O_RDWR) >= 0 ||
        dsys_unmount(target_v1575) != 0 ||
        dsys_fsinfo(1U, &info_v1575) != 0 ||
        dsys_fsinfo(0U, &info_v1575) != 1 ||
        info_v1575.provider != 7UL)
        return fail_v1575("FAIL_NEW_CLEAN_MOUNT", 11);
    return step_v1575("PASS") != 0 ? 12 : 0;
}
