/*
 * v1545: real PDP-6, independent D6FS root and secondary D6FS.
 * The host supplies a previously checked, read-only, 14-word handoff.
 * After mounting, detach ONLY the secondary Type-270/236 device set.
 * A real failed secondary file read must return without KCORE HALT.
 * This code follows C89 (no C99 declarations, inline, or long long).
 */
#include "u.h"
#include "secondary-handoff-v1545.h"

static kword_t secondary_mount_v1545[U_PATH_WORDS];
static kword_t secondary_dir_v1545[U_PATH_WORDS];
static kword_t secondary_file_v1545[U_PATH_WORDS];
static kword_t root_file_v1545[U_PATH_WORDS];
static kword_t words_v1545[0200];
static struct vfs_stat stat_v1545;
static struct sys_fsinfo info_v1545;

static int
stage_v1545(const char *message)
{
    if (u_puts(1,"SECD6FS V1545 ") != 0 ||
        u_puts(1,message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
acknowledge_v1545(void)
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
    int root_fd;
    int nread;
    int info_result;

    (void)argv;
    if (argc != 1 || dsys_getpid() != 1 ||
        u_s6_pack(secondary_mount_v1545,U_PATH_WORDS,"/MOUNT/DT0") != 0 ||
        u_s6_pack(secondary_dir_v1545,U_PATH_WORDS,
                  "/MOUNT/DT0/SYSTEM") != 0 ||
        u_s6_pack(secondary_file_v1545,U_PATH_WORDS,
                  "/MOUNT/DT0/SYSTEM/INIT") != 0 ||
        u_s6_pack(root_file_v1545,U_PATH_WORDS,"/SYSTEM/INIT") != 0 ||
        stage_v1545("START") != 0 ||
        dsys_stat(root_file_v1545,&stat_v1545) != 0)
        return 1;

    /* The test HOST has validated the complete, clean D6FS four-member
     * media set with d6fsck and derived this handoff from its real DBOOT
     * descriptors and superblock. Use the actual userland mount syscall.
     */
    if (dsys_d6fs_mount(secondary_handoff_v1545,
                        secondary_mount_v1545,1U) != 0) {
        (void)stage_v1545("FAIL_MOUNT");
        return 2;
    }
    info_result = dsys_fsinfo(1U,&info_v1545);
    (void)u_puts(1,"SECD6FS V1545 FSINFO: ");
    (void)u_put_octal(1,(kword_t)info_result,6U);
    (void)u_putc(1,' ');
    (void)u_put_octal(1,info_v1545.mount_id,6U);
    (void)u_putc(1,' ');
    (void)u_put_octal(1,info_v1545.provider,6U);
    (void)u_crlf(1);
    if (info_result != 1 || info_v1545.mount_id != 2UL ||
        info_v1545.provider != 6UL) {
        (void)stage_v1545("FAIL_FSINFO");
        return 3;
    }
    if (dsys_stat(secondary_mount_v1545,&stat_v1545) != 0) {
        (void)stage_v1545("FAIL_MOUNT_ROOT_STAT");
        return 3;
    }
    if (dsys_stat(secondary_dir_v1545,&stat_v1545) != 0) {
        (void)stage_v1545("FAIL_SECONDARY_DIR_STAT");
        return 3;
    }
    if (dsys_stat(secondary_file_v1545,&stat_v1545) != 0) {
        (void)stage_v1545("FAIL_SECONDARY_FILE_STAT");
        return 3;
    }
    if (stat_v1545.size_words < 0200U) {
        (void)stage_v1545("FAIL_SECONDARY_FILE_SIZE");
        return 3;
    }
    fd = dsys_open(secondary_file_v1545,SYS_O_RDONLY);
    if (fd < 0) {
        (void)stage_v1545("FAIL_SECONDARY_OPEN");
        return 4;
    }
    if (stage_v1545("MOUNTED") != 0 ||
        stage_v1545("READY_DETACH") != 0 ||
        acknowledge_v1545() != 0)
        return 5;

    /* Metadata and FD are already valid. The first file DATA read has
     * never occurred; it must force a physical transfer after detach.
     */
    nread = dsys_read_words(fd,words_v1545,0200U);
    if (nread >= 0) {
        (void)stage_v1545("FAIL_SECONDARY_READ_NOT_FAILED");
        return 6;
    }
    if (stage_v1545("SECONDARY_FAILED") != 0)
        return 7;

    /* A surviving independent D6FS root is proof of device isolation;
     * check real root DATA, not only warm metadata or a live console.
     */
    root_fd = dsys_open(root_file_v1545,SYS_O_RDONLY);
    if (root_fd < 0) {
        (void)stage_v1545("FAIL_ROOT_OPEN");
        return 8;
    }
    nread = dsys_read_words(root_fd,words_v1545,0200U);
    if (nread <= 0) {
        (void)stage_v1545("FAIL_ROOT_READ");
        return 9;
    }
    if (stage_v1545("ROOT_ALIVE") != 0 ||
        stage_v1545("PASS") != 0)
        return 10;
    /* Leave the processor running until the host accepts PASS. A normal
     * PID1 exit could otherwise produce a HALT unrelated to media loss.
     */
    for (;;)
        (void)dsys_sleep(60U);
}
