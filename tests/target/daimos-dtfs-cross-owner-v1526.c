/*
 * Real PDP-6 cross-process mounted DTFS owner-lifetime acceptance, v1526.
 *
 * A booted PID1 mounts DTC3, RUNs a distinct process from the real TSFS
 * root, and synchronizes every ownership phase with actual kernel pipes.
 * The child alone owns DTFS cwd, then only a DTFS FILE. The parent has
 * neither reference when UNMOUNT must refuse. The child remains alive
 * during the successful unmount after it closes its final FILE.
 *
 * No KCORE, provider, VFS, or DTC I/O is simulated or replaced.
 * Test executable only; C89 and ASCII.
 */
#include "u.h"

#ifdef DAIMOS_DTFS_V2_PHYSICAL_V1564
#define CROSS_TEST_PREFIX_V1526 "DTFSV2 V1564 "
#else
#define CROSS_TEST_PREFIX_V1526 "DTFSCROSS V1526 "
#endif

#define CROSS_V1526_RUN_PATH_WORDS 3U
#define CROSS_V1526_ARG_WORDS 2U
#define CROSS_V1526_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define CROSS_V1526_ARG0_OFF \
    (CROSS_V1526_PATH_OFF + CROSS_V1526_RUN_PATH_WORDS)
#define CROSS_V1526_ARG1_OFF \
    (CROSS_V1526_ARG0_OFF + CROSS_V1526_RUN_PATH_WORDS)
#define CROSS_V1526_MAP_OFF \
    (CROSS_V1526_ARG1_OFF + CROSS_V1526_ARG_WORDS)
#define CROSS_V1526_RUN_WORDS (CROSS_V1526_MAP_OFF + 5U)

static kword_t cross_device_v1526[U_PATH_WORDS];
static kword_t cross_target_v1526[U_PATH_WORDS];
static kword_t cross_root_v1526[U_PATH_WORDS];
static kword_t cross_init_v1526[CROSS_V1526_RUN_PATH_WORDS];
static struct sys_fsinfo cross_info_v1526;

static int
cross_log_v1526(const char *message)
{
    if (u_puts(1, CROSS_TEST_PREFIX_V1526) != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
cross_fail_v1526(const char *message, int code)
{
    (void)cross_log_v1526(message);
    return code;
}

static int
cross_pipe_v1526(int *read_fd, int *write_fd)
{
    kword_t pair;

    pair = dsys_pipe();
    if (pair == ~0UL)
        return -1;
    *read_fd = (int)((pair >> 18U) & 0777777UL);
    *write_fd = (int)(pair & 0777777UL);
    if (*read_fd < 0 || *write_fd < 0 ||
        *read_fd >= (int)SYS_RUN_FD_MAX ||
        *write_fd >= (int)SYS_RUN_FD_MAX ||
        *read_fd == *write_fd)
        return -1;
    return 0;
}

static int
cross_send_v1526(int fd, kword_t word)
{
    return dsys_write_words(fd, &word, 1U) == 1 ? 0 : -1;
}

static int
cross_recv_v1526(int fd, kword_t wanted)
{
    kword_t word;

    word = 0UL;
    return dsys_read_words(fd, &word, 1U) == 1 &&
        word == wanted ? 0 : -1;
}

static int
cross_mounted_v1526(int expected)
{
    int rc;

    rc = dsys_fsinfo(1U, &cross_info_v1526);
    if (expected)
        return rc == 1 && cross_info_v1526.provider == 5UL &&
            u_s6_eq(cross_info_v1526.path, "/MOUNT/DT0");
    return rc == 0;
}

static int
cross_spawn_v1526(int control_read_fd, int ready_write_fd)
{
    kword_t words[CROSS_V1526_RUN_WORDS];
    struct sys_run_v2 *run;
    unsigned int i;

    for (i = 0U; i < CROSS_V1526_RUN_WORDS; ++i)
        words[i] = 0UL;
    for (i = 0U; i < CROSS_V1526_RUN_PATH_WORDS; ++i) {
        words[CROSS_V1526_PATH_OFF + i] = cross_init_v1526[i];
        words[CROSS_V1526_ARG0_OFF + i] = cross_init_v1526[i];
    }
    if (u_s6_pack(&words[CROSS_V1526_ARG1_OFF],
        CROSS_V1526_ARG_WORDS, "H") != 0)
        return -1;
    words[CROSS_V1526_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
    words[CROSS_V1526_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
    words[CROSS_V1526_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
    words[CROSS_V1526_MAP_OFF + 3U] =
        SYS_RUN_FD_MAP(3U, (unsigned int)control_read_fd);
    words[CROSS_V1526_MAP_OFF + 4U] =
        SYS_RUN_FD_MAP(4U, (unsigned int)ready_write_fd);
    run = (struct sys_run_v2 *)words;
    run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
        CROSS_V1526_RUN_WORDS);
    run->flags = SYS_RUN_PGRP_INHERIT;
    run->pgrp = 0UL;
    run->fdmap_count = 5UL;
    run->argc = 2UL;
    run->envc = 0UL;
    return dsys_run(run);
}

static int
cross_child_v1526(void)
{
    int fd;

    if (dsys_getpid() <= 1 ||
        cross_log_v1526("CHILD_START") != 0 ||
        dsys_chdir(cross_target_v1526) != 0 ||
        cross_send_v1526(4, 0101UL) != 0 ||
        cross_recv_v1526(3, 0201UL) != 0)
        return cross_fail_v1526("FAIL_CHILD_CWD", 31);

    fd = dsys_open(cross_target_v1526, SYS_O_RDONLY);
    if (fd < 0 || dsys_chdir(cross_root_v1526) != 0 ||
        cross_send_v1526(4, 0102UL) != 0 ||
        cross_recv_v1526(3, 0202UL) != 0)
        return cross_fail_v1526("FAIL_CHILD_FILE", 32);
    if (dsys_close(fd) != 0 ||
        cross_send_v1526(4, 0103UL) != 0 ||
        cross_recv_v1526(3, 0203UL) != 0)
        return cross_fail_v1526("FAIL_CHILD_RELEASE", 33);
    if (dsys_close(3) != 0 || dsys_close(4) != 0)
        return cross_fail_v1526("FAIL_CHILD_PIPE", 34);
    return cross_log_v1526("CHILD_DONE") != 0 ? 35 : 0;
}

int
main(int argc, kword_t **argv)
{
    int control_read;
    int control_write;
    int ready_read;
    int ready_write;
    int pid;
    kword_t status;
    kword_t parent_cwd[U_PATH_WORDS];
    struct sys_procinfo child_info;

    if (u_s6_pack(cross_device_v1526, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(cross_target_v1526, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(cross_root_v1526, U_PATH_WORDS, "/") != 0 ||
        u_s6_pack(cross_init_v1526, CROSS_V1526_RUN_PATH_WORDS,
            "/SYSTEM/INIT") != 0)
        return cross_fail_v1526("FAIL_PATH", 1);

    if (argc == 2 && argv != 0 && argv[1] != 0 &&
        u_s6_eq(argv[1], "H"))
        return cross_child_v1526();
    if (argc != 1 || dsys_getpid() != 1)
        return cross_fail_v1526("FAIL_PID1", 2);

#ifdef DAIMOS_DTFS_V2_PHYSICAL_V1564
    /* Real physical DTVOL2 media must NEVER become writable while the
     * v1555 unconditional read-only veto remains in effect. A refused
     * mount must not publish a VFS slot or poison the CLEAN marker. */
    if (cross_log_v1526("START") != 0 ||
        dsys_dtfs_mount(cross_device_v1526, cross_target_v1526,
            SYS_DTFS_TYPE_NATIVE) == 0 ||
        !cross_mounted_v1526(0))
        return cross_fail_v1526("FAIL_RW_REFUSAL", 36);
    if (cross_log_v1526("RW_REFUSED") != 0)
        return 37;
#endif

#ifndef DAIMOS_DTFS_V2_PHYSICAL_V1564
    if (cross_log_v1526("START") != 0 ||
#else
    if (
#endif
        dsys_getcwd(parent_cwd, U_PATH_WORDS) != 0 ||
        !u_s6_eq(parent_cwd, "/") ||
        dsys_dtfs_mount(cross_device_v1526, cross_target_v1526,
            SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0 ||
        !cross_mounted_v1526(1))
        return cross_fail_v1526("FAIL_MOUNT", 3);
    if (cross_log_v1526("MOUNTED") != 0)
        return 4;
    if (cross_pipe_v1526(&control_read, &control_write) != 0 ||
        cross_pipe_v1526(&ready_read, &ready_write) != 0)
        return cross_fail_v1526("FAIL_PIPE", 5);

    pid = cross_spawn_v1526(control_read, ready_write);
    if (pid < 2)
        return cross_fail_v1526("FAIL_RUN", 6);
    if (dsys_close(control_read) != 0 || dsys_close(ready_write) != 0)
        return cross_fail_v1526("FAIL_PIPE_PARENT", 7);

    /* Parent has no cwd/FILE reference on DTFS. Child owns cwd alone. */
    if (cross_recv_v1526(ready_read, 0101UL) != 0)
        return cross_fail_v1526("FAIL_CWD_ACK", 8);
    if (dsys_unmount(cross_target_v1526) == 0 ||
        !cross_mounted_v1526(1))
        return cross_fail_v1526("FAIL_CROSS_CWD", 9);
    if (cross_log_v1526("CROSS_CWD_REFUSED") != 0 ||
        cross_send_v1526(control_write, 0201UL) != 0)
        return 10;

    /* Child has released cwd, but retains its own mounted FILE. */
    if (cross_recv_v1526(ready_read, 0102UL) != 0)
        return cross_fail_v1526("FAIL_FILE_ACK", 11);
    if (dsys_unmount(cross_target_v1526) == 0 ||
        !cross_mounted_v1526(1))
        return cross_fail_v1526("FAIL_CROSS_FILE", 12);
    if (cross_log_v1526("CROSS_FILE_REFUSED") != 0 ||
        cross_send_v1526(control_write, 0202UL) != 0)
        return 13;

    /* Child remains live (blocked on the release pipe) but no longer
     * has DTFS cwd or FILE references. Now retirement must succeed.
     */
    if (cross_recv_v1526(ready_read, 0103UL) != 0)
        return cross_fail_v1526("FAIL_RELEASE_ACK", 14);
    if (dsys_procinfo((unsigned int)pid, &child_info) != 0 ||
        child_info.pid != (kword_t)pid ||
        child_info.state == 4UL)
        return cross_fail_v1526("FAIL_CHILD_NOT_LIVE", 19);
    if (dsys_unmount(cross_target_v1526) != 0 ||
        !cross_mounted_v1526(0))
        return cross_fail_v1526("FAIL_RETIRE", 15);
    if (cross_log_v1526("CROSS_RETIRED") != 0 ||
        cross_send_v1526(control_write, 0203UL) != 0 ||
        dsys_close(control_write) != 0 || dsys_close(ready_read) != 0)
        return 16;
    status = 0UL;
    if (dsys_wait((unsigned int)pid, &status, 0U) != pid ||
        SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
        SYS_WAIT_STATUS_VALUE(status) != 0U)
        return cross_fail_v1526("FAIL_WAIT", 17);
#ifdef DAIMOS_DTFS_V2_PHYSICAL_V1564
    /* A retired DTVOL2 slot must not preserve a borrowed quiescence or
     * per-mount MM owner. Re-read the SAME physical CLEAN tape, refuse
     * a second writable attempt, then mount and retire RO a second time.
     * The host also independently verifies that RBN0 was not modified. */
    if (dsys_dtfs_mount(cross_device_v1526, cross_target_v1526,
            SYS_DTFS_TYPE_NATIVE) == 0 ||
        !cross_mounted_v1526(0))
        return cross_fail_v1526("FAIL_RW_AFTER_RETIRE", 38);
    if (dsys_dtfs_mount(cross_device_v1526, cross_target_v1526,
            SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0 ||
        !cross_mounted_v1526(1))
        return cross_fail_v1526("FAIL_REMOUNT_RO", 39);
    if (dsys_unmount(cross_target_v1526) != 0 ||
        !cross_mounted_v1526(0))
        return cross_fail_v1526("FAIL_REMOUNT_RETIRE", 40);
    if (cross_log_v1526("REMOUNTED") != 0)
        return 41;
#endif
    if (cross_log_v1526("PASS") != 0)
        return 18;
    return 0;
}
