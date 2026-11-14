/*
 * v1565: actual PDP-6 PID1/PID2 DTFS unmount admission race.
 *
 * The disposable test image extends the interval AFTER the production
 * v1562 barrier is armed and BEFORE production VFS SYNC. The second
 * process observes actual provider SPACE refusal through FSINFO,
 * attempts two real owner-producing syscalls, then waits for retirement.
 * No syscall, VFS gate, provider, or scheduler implementation is stubbed.
 * This file is testkit-only and uses C89 and ASCII exclusively.
 */
#include "u.h"

#define RACE_PATH_WORDS_V1565 3U
#define RACE_ARG_WORDS_V1565 2U
#define RACE_PATH_OFF_V1565 SYS_RUN_V2_FIXED_WORDS
#define RACE_ARG0_OFF_V1565 (RACE_PATH_OFF_V1565 + RACE_PATH_WORDS_V1565)
#define RACE_ARG1_OFF_V1565 (RACE_ARG0_OFF_V1565 + RACE_PATH_WORDS_V1565)
#define RACE_MAP_OFF_V1565 (RACE_ARG1_OFF_V1565 + RACE_ARG_WORDS_V1565)
#define RACE_RUN_WORDS_V1565 (RACE_MAP_OFF_V1565 + 5U)

static kword_t race_device_v1565[U_PATH_WORDS];
static kword_t race_target_v1565[U_PATH_WORDS];
static kword_t race_root_v1565[U_PATH_WORDS];
static kword_t race_program_v1565[RACE_PATH_WORDS_V1565];
static struct sys_fsinfo race_info_v1565;
static kword_t race_cwd_v1565[U_PATH_WORDS];

static int
race_log_v1565(const char *message)
{
    if (u_puts(1, "DTFSRACE V1565 ") != 0 ||
        u_puts(1, message) != 0 || u_crlf(1) != 0)
        return -1;
    return 0;
}

static int
race_fail_v1565(const char *message, int code)
{
    (void)race_log_v1565(message);
    return code;
}

static int
race_pipe_v1565(int *reader, int *writer)
{
    kword_t pair;

    pair = dsys_pipe();
    if (pair == ~0UL)
        return -1;
    *reader = (int)((pair >> 18U) & 0777777UL);
    *writer = (int)(pair & 0777777UL);
    if (*reader < 0 || *writer < 0 ||
        *reader >= (int)SYS_RUN_FD_MAX ||
        *writer >= (int)SYS_RUN_FD_MAX ||
        *reader == *writer)
        return -1;
    return 0;
}

static int
race_send_v1565(int fd, kword_t value)
{
    return dsys_write_words(fd, &value, 1U) == 1 ? 0 : -1;
}

static int
race_recv_v1565(int fd, kword_t wanted)
{
    kword_t value;

    value = 0UL;
    return dsys_read_words(fd, &value, 1U) == 1 && value == wanted ? 0 : -1;
}

static int
race_spawn_v1565(int control_read, int report_write)
{
    kword_t words[RACE_RUN_WORDS_V1565];
    struct sys_run_v2 *run;
    unsigned int i;

    for (i = 0U; i < RACE_RUN_WORDS_V1565; ++i)
        words[i] = 0UL;
    for (i = 0U; i < RACE_PATH_WORDS_V1565; ++i) {
        words[RACE_PATH_OFF_V1565 + i] = race_program_v1565[i];
        words[RACE_ARG0_OFF_V1565 + i] = race_program_v1565[i];
    }
    if (u_s6_pack(&words[RACE_ARG1_OFF_V1565],
        RACE_ARG_WORDS_V1565, "R") != 0)
        return -1;
    words[RACE_MAP_OFF_V1565] = SYS_RUN_FD_MAP(0U, 0U);
    words[RACE_MAP_OFF_V1565 + 1U] = SYS_RUN_FD_MAP(1U, 1U);
    words[RACE_MAP_OFF_V1565 + 2U] = SYS_RUN_FD_MAP(2U, 2U);
    words[RACE_MAP_OFF_V1565 + 3U] =
        SYS_RUN_FD_MAP(3U, (unsigned int)control_read);
    words[RACE_MAP_OFF_V1565 + 4U] =
        SYS_RUN_FD_MAP(4U, (unsigned int)report_write);
    run = (struct sys_run_v2 *)words;
    run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
        RACE_RUN_WORDS_V1565);
    run->flags = SYS_RUN_PGRP_INHERIT;
    run->pgrp = 0UL;
    run->fdmap_count = 5UL;
    run->argc = 2UL;
    run->envc = 0UL;
    return dsys_run(run);
}

static int
race_child_v1565(void)
{
    unsigned int attempt;
    int rc;
    int fd;

    if (dsys_getpid() <= 1 || race_log_v1565("CHILD_START") != 0 ||
        race_recv_v1565(3, 0201UL) != 0)
        return race_fail_v1565("FAIL_CHILD_START", 21);

    /* When the exact live DTFS slot is quiescing, FSINFO's real
     * provider SPACE dispatch refuses with -1. Before sealing it
     * succeeds (+1), and after retirement the slot is empty (0).
     * This is the guest's witness for the actual acquired barrier. */
    for (attempt = 0U; attempt < 03000U; ++attempt) {
        rc = dsys_fsinfo(1U, &race_info_v1565);
        if (rc < 0)
            break;
        if (rc == 0)
            return race_fail_v1565("FAIL_RETIRED_BEFORE_SEAL", 22);
        if (dsys_sleep(1U) != 0)
            return race_fail_v1565("FAIL_CHILD_SLEEP", 23);
    }
    if (attempt == 03000U || race_log_v1565("SEAL_OBSERVED") != 0)
        return race_fail_v1565("FAIL_NO_SEAL_WITNESS", 24);

    /* During quiescence, both operations MUST refuse without creating
     * a hidden FILE or cwd reference. Do not attempt to close a wrongly
     * successful descriptor: that is a hard test failure. */
    fd = dsys_open(race_target_v1565, SYS_O_RDONLY);
    if (fd >= 0)
        return race_fail_v1565("FAIL_OPEN_ADMITTED", 25);
    if (dsys_chdir(race_target_v1565) == 0)
        return race_fail_v1565("FAIL_CHDIR_ADMITTED", 26);
    if (dsys_getcwd(race_cwd_v1565, U_PATH_WORDS) != 0 ||
        !u_s6_eq(race_cwd_v1565, "/"))
        return race_fail_v1565("FAIL_CWD_CHANGED", 27);
    if (race_log_v1565("OWNERS_REFUSED") != 0 ||
        race_send_v1565(4, 0101UL) != 0 ||
        race_recv_v1565(3, 0202UL) != 0)
        return race_fail_v1565("FAIL_CHILD_RELEASE", 28);

    /* The original /MOUNT/DT0 directory belongs to the underlying
     * TSFS root, not the now-retired DTFS. Fresh path access MUST be
     * allowed to reach that directory once the transient V2 seal is
     * retired; rejecting all access here would be an incorrect oracle.
     * Check that the public DTFS slot stays absent before and after
     * normal TSFS access, with no stale DTFS-owned descriptor. */
    if (dsys_fsinfo(1U, &race_info_v1565) != 0)
        return race_fail_v1565("FAIL_RETIRED_SLOT", 29);
    fd = dsys_open(race_target_v1565, SYS_O_RDONLY);
    if (fd < 0 || dsys_close(fd) != 0 ||
        dsys_chdir(race_target_v1565) != 0 ||
        dsys_getcwd(race_cwd_v1565, U_PATH_WORDS) != 0 ||
        !u_s6_eq(race_cwd_v1565, "/MOUNT/DT0") ||
        dsys_chdir(race_root_v1565) != 0 ||
        dsys_fsinfo(1U, &race_info_v1565) != 0)
        return race_fail_v1565("FAIL_RETIRED_TSFS", 31);
    if (race_log_v1565("RETIRED_TSFS") != 0 ||
        race_send_v1565(4, 0102UL) != 0 ||
        dsys_close(3) != 0 || dsys_close(4) != 0)
        return race_fail_v1565("FAIL_CHILD_PIPE", 30);
    return 0;
}

int
main(int argc, kword_t **argv)
{
    int control_read;
    int control_write;
    int report_read;
    int report_write;
    int child;
    kword_t status;

    if (u_s6_pack(race_device_v1565, U_PATH_WORDS, "/DEV/DTC3") != 0 ||
        u_s6_pack(race_target_v1565, U_PATH_WORDS, "/MOUNT/DT0") != 0 ||
        u_s6_pack(race_root_v1565, U_PATH_WORDS, "/") != 0 ||
        u_s6_pack(race_program_v1565, RACE_PATH_WORDS_V1565,
            "/SYSTEM/INIT") != 0)
        return race_fail_v1565("FAIL_PATH", 1);
    if (argc == 2 && argv != 0 && argv[1] != 0 &&
        u_s6_eq(argv[1], "R"))
        return race_child_v1565();
    if (argc != 1 || dsys_getpid() != 1 ||
        race_log_v1565("START") != 0)
        return race_fail_v1565("FAIL_PID1", 2);

    if (dsys_dtfs_mount(race_device_v1565, race_target_v1565,
            SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE) != 0 ||
        dsys_fsinfo(1U, &race_info_v1565) != 1)
        return race_fail_v1565("FAIL_MOUNT", 3);
    if (race_log_v1565("MOUNTED") != 0)
        return 4;
    if (race_pipe_v1565(&control_read, &control_write) != 0 ||
        race_pipe_v1565(&report_read, &report_write) != 0)
        return race_fail_v1565("FAIL_PIPE", 5);

    child = race_spawn_v1565(control_read, report_write);
    if (child < 2 || dsys_close(control_read) != 0 ||
        dsys_close(report_write) != 0)
        return race_fail_v1565("FAIL_RUN", 6);

    /* Wake the real independently scheduled child, then enter UNMOUNT.
     * The disposable test-only KCORE source extends the time between
     * v1562 quiesce_begin and SYNC with an actual scheduler sleep. */
    if (race_send_v1565(control_write, 0201UL) != 0 ||
        dsys_unmount(race_target_v1565) != 0 ||
        dsys_fsinfo(1U, &race_info_v1565) != 0)
        return race_fail_v1565("FAIL_UNMOUNT", 7);
    if (race_log_v1565("RETIRED") != 0 ||
        race_recv_v1565(report_read, 0101UL) != 0)
        return race_fail_v1565("FAIL_NO_RACE_WITNESS", 8);
    if (race_log_v1565("RACE_PROVEN") != 0 ||
        race_send_v1565(control_write, 0202UL) != 0 ||
        race_recv_v1565(report_read, 0102UL) != 0)
        return race_fail_v1565("FAIL_RETIRED_RESPONSE", 9);
    if (dsys_close(control_write) != 0 ||
        dsys_close(report_read) != 0)
        return race_fail_v1565("FAIL_PARENT_PIPE", 10);
    status = 0UL;
    if (dsys_wait((unsigned int)child, &status, 0U) != child ||
        SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
        SYS_WAIT_STATUS_VALUE(status) != 0U)
        return race_fail_v1565("FAIL_WAIT", 11);
    if (race_log_v1565("PASS") != 0)
        return 12;
    return 0;
}
