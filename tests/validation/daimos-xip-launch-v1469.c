/* Native ROOT-only MEMFS XIP RUN/EXEC guest regression, v1469.
 * The image executes exactly MOVEI AC2,012 and monitor UUO EXIT. It has
 * no user stores, no stack operations and no writable shared variables.
 * The EXIT UUO's unindexed effective address is zero: the DAIMOS ABI
 * does not take the exit status from AC2. Therefore exit status is zero.
 * This fixture uses only C89-compatible declarations and ASCII text. */
#include "u.h"
#include "../test_sixbit.h"

#define XIP_PATH_COUNT_V1469       13U
#define XIP_RECORD_WORDS_V1469     4U
#define XIP_RUN_WORDS_V1469        (SYS_RUN_V2_FIXED_WORDS + XIP_RECORD_WORDS_V1469)
#define XIP_RUN_ARG_WORDS_V1469    (XIP_RUN_WORDS_V1469 + 2U)
#define XIP_EXEC_WORDS_V1469      (SYS_EXEC_V1_FIXED_WORDS + XIP_RECORD_WORDS_V1469)
#define XIP_EXEC_ARG_WORDS_V1469  (XIP_EXEC_WORDS_V1469 + 2U)

static const kword_t xip_self_name_v1469[5] = {
        20UL,
        TEST_SIX6('/', 'C', 'O', 'N', 'F', 'I'),
        TEST_SIX6('G', '/', 'X', 'I', 'P', '1'),
        TEST_SIX6('4', '6', '9', '.', 'T', 'E'),
        TEST_SIX6('S', 'T', ' ', ' ', ' ', ' ')
};

static kword_t xip_path_v1469[U_PATH_WORDS];
static const kword_t xip_name_record_v1469[XIP_RECORD_WORDS_V1469] = {
        XIP_PATH_COUNT_V1469,
        TEST_SIX6('/', 'T', 'E', 'M', 'P', '/'),
        TEST_SIX6('X', 'I', 'P', 'S', 'A', 'F'),
        TEST_SIX6('E', ' ', ' ', ' ', ' ', ' ')
};
static const kword_t xip_header_v1469[2] = {
        054506000000UL,
        (0200000UL << 18U) | 020UL
};
static const kword_t xip_instructions_v1469[2] = {
        (0201UL << 27U) | (2UL << 23U) | 012UL,
        040000000000UL
};

static int
xip_fail_v1469(const char *stage, int result)
{
        (void)u_puts(1, "XIP-FAIL-");
        (void)u_puts(1, stage);
        (void)u_puts(1, "-");
        (void)u_put_octal(1, (kword_t)result, 12U);
        (void)u_crlf(1);
        return 1;
}

static void
xip_copy_record_v1469(kword_t *dst)
{
        unsigned int i;
        for (i = 0U; i < XIP_RECORD_WORDS_V1469; ++i)
                dst[i] = xip_name_record_v1469[i];
}

static int
xip_create_v1469(void)
{
        int fd;
        int rc;

        if (u_s6_pack(xip_path_v1469, U_PATH_WORDS, "/TEMP/XIPSAFE") != 0)
                return xip_fail_v1469("PATH", -1);
        fd = dsys_open(xip_path_v1469,
            SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return xip_fail_v1469("CREATE", fd);
        rc = dsys_truncate(xip_path_v1469, 04000U);
        if (rc != 0)
                return xip_fail_v1469("TRUNCATE", rc);
        if (dsys_write_words(fd, (kword_t *)xip_header_v1469, 2U) != 2)
                return xip_fail_v1469("HEADER", -1);
        if (dsys_seek(fd, 020UL, SYS_SEEK_SET) != 020UL ||
            dsys_write_words(fd, (kword_t *)xip_instructions_v1469, 2U) != 2)
                return xip_fail_v1469("INSTRUCTIONS", -1);
        if (dsys_close(fd) != 0 ||
            dsys_chmod(xip_path_v1469, 0555U) != 0)
                return xip_fail_v1469("CLOSE-CHMOD", -1);
        return 0;
}

/* Read the kernel-visible metadata and bytes back through ordinary VFS,
 * rather than assuming that a successful write created an admissible image. */
static int
xip_check_file_v1469(void)
{
        struct vfs_stat st;
        kword_t words[2];
        int fd;

        if (dsys_stat(xip_path_v1469, &st) != 0)
                return xip_fail_v1469("STAT", -1);
        if (st.type != VFS_TYPE_REG || st.mode != 0555U ||
            st.size_words != 04000UL || st.uid != 0U)
                return xip_fail_v1469("STAT-SHAPE", (int)st.mode);
        fd = dsys_open(xip_path_v1469, SYS_O_RDONLY);
        if (fd < 0)
                return xip_fail_v1469("OPEN-READ", fd);
        if (dsys_read_words(fd, words, 2U) != 2 ||
            words[0] != xip_header_v1469[0] ||
            words[1] != xip_header_v1469[1])
                return xip_fail_v1469("READ-HEADER", -1);
        if (dsys_seek(fd, 020UL, SYS_SEEK_SET) != 020UL ||
            dsys_read_words(fd, words, 2U) != 2 ||
            words[0] != xip_instructions_v1469[0] ||
            words[1] != xip_instructions_v1469[1])
                return xip_fail_v1469("READ-CODE", -1);
        if (dsys_close(fd) != 0)
                return xip_fail_v1469("READ-CLOSE", -1);
        return 0;
}

static int
xip_run_v1469(unsigned int argc)
{
        kword_t words[XIP_RUN_ARG_WORDS_V1469];
        struct sys_run_v2 *block;
        unsigned int i;
        unsigned int count;

        count = argc ? XIP_RUN_ARG_WORDS_V1469 : XIP_RUN_WORDS_V1469;
        for (i = 0U; i < XIP_RUN_ARG_WORDS_V1469; ++i)
                words[i] = 0UL;
        block = (struct sys_run_v2 *)words;
        block->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, count);
        block->flags = SYS_RUN_PGRP_INHERIT;
        block->pgrp = 0UL;
        block->fdmap_count = 0UL;
        block->argc = (kword_t)argc;
        block->envc = 0UL;
        xip_copy_record_v1469(words + SYS_RUN_V2_FIXED_WORDS);
        if (argc) {
                words[XIP_RUN_WORDS_V1469] = 1UL;
                words[XIP_RUN_WORDS_V1469 + 1U] =
                    TEST_SIX6('A', ' ', ' ', ' ', ' ', ' ');
        }
        return dsys_run(block);
}

#ifdef XIP_SNAPSHOT_V1477
/* Snapshot test runs the same executable on two independent cold boots.
 * It never destroys or overwrites the first boot's persistent image
 * during the second boot's verification. All strings and data are ASCII
 * or 36-bit words and remain compatible with KCC/C89. */
static const kword_t xip_snapshot_payload_v1477[3] = {
        012345670123UL, 076543210765UL, 055225522552UL
};
static int
xip_snapshot_v1477(void)
{
        kword_t path[U_PATH_WORDS];
        kword_t contents[3];
        kword_t status;
        struct sys_meminfo mem;
        struct vfs_stat st;
        int fd;
        int pid;
        unsigned int i;

        if (u_s6_pack(xip_path_v1469, U_PATH_WORDS,
                "/TEMP/XIPSAFE") != 0 ||
            u_s6_pack(path, U_PATH_WORDS, "/TEMP/SNAPDATA") != 0)
                return xip_fail_v1469("SNAP-PATH", -1);
        /* /TEMP exists on the D6FS root even when MOUNTALL fails. Do not
         * mistake a file persisted there for a MEMFS snapshot. */
        if (dsys_meminfo(&mem) != 0)
                return xip_fail_v1469("SNAP-NO-MEMFS", -1);
#ifdef XIP_SNAPSHOT_CORRUPT_V1485
        {
                /* Probe the mount itself, not MEMINFO's stale capacity:
                 * the pre-fix snapshot failure left the singleton record
                 * allocated despite no published MEMFS mount. Duplicate
                 * mount is refused on boot one; the repaired cleanup
                 * allows a new volatile mount after boot-two rejection. */
                kword_t mount_path[U_PATH_WORDS];
                if (u_s6_pack(mount_path, U_PATH_WORDS, "/TEMP") != 0)
                        return xip_fail_v1469("SNAP-CORRUPT-PATH", -1);
                if (dsys_memfs_mount(mount_path, 4096U, SYS_MOUNT_RW) == 0) {
                        kword_t recovered_status;
                        int recovered_pid;
                        if (dsys_meminfo(&mem) != 0 ||
                            mem.memfs_capacity_words == 0UL ||
                            xip_create_v1469() != 0 ||
                            xip_check_file_v1469() != 0)
                                return xip_fail_v1469("SNAP-CORRUPT-RECOVERY", -1);
                        recovered_pid = xip_run_v1469(0U);
                        recovered_status = 0UL;
                        if (recovered_pid <= 1 ||
                            dsys_wait((unsigned int)recovered_pid,
                                &recovered_status, 0U) != recovered_pid ||
                            SYS_WAIT_STATUS_KIND(recovered_status) != SYS_WAIT_EXITED ||
                            SYS_WAIT_STATUS_VALUE(recovered_status) != 0U)
                                return xip_fail_v1469("SNAP-CORRUPT-RUN", recovered_pid);
                        (void)u_puts(1, "XIP-SNAPSHOT-CORRUPT-RECOVERED");
                        (void)u_crlf(1);
                        return 0;
                }
        }
#endif
        if (mem.memfs_capacity_words == 0UL)
                return xip_fail_v1469("SNAP-NO-MEMFS", -1);
        if (dsys_stat(path, &st) == 0) {
                if (st.type != VFS_TYPE_REG ||
                    st.size_words != 3UL ||
                    xip_check_file_v1469() != 0)
                        return xip_fail_v1469("SNAP-RESTORE-STAT", -1);
                fd = dsys_open(path, SYS_O_RDONLY);
                if (fd < 0)
                        return xip_fail_v1469("SNAP-RESTORE-OPEN", fd);
                if (dsys_read_words(fd, contents, 3U) != 3 ||
                    dsys_close(fd) != 0)
                        return xip_fail_v1469("SNAP-RESTORE-READ", -1);
                for (i = 0U; i < 3U; ++i)
                        if (contents[i] != xip_snapshot_payload_v1477[i])
                                return xip_fail_v1469("SNAP-RESTORE-DATA",
                                    (int)i);
                pid = xip_run_v1469(0U);
                if (pid <= 1)
                        return xip_fail_v1469("SNAP-RESTORE-RUN", pid);
                status = 0UL;
                if (dsys_wait((unsigned int)pid, &status, 0U) != pid ||
                    SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                    SYS_WAIT_STATUS_VALUE(status) != 0U)
                        return xip_fail_v1469("SNAP-RESTORE-WAIT", pid);
#ifdef XIP_SNAPSHOT_FAULT_V1478
                /* The isolated one-shot write hook is reset by each cold
                 * boot. Consume and verify that boot's refused HALT here
                 * so the shell can safely retry the real publication. */
                if (dsys_halt() != -1)
                        return xip_fail_v1469("SNAP-RESTORE-HALT", -1);
                (void)u_puts(1, "XIP-SNAPSHOT-HALT-REFUSED");
                (void)u_crlf(1);
#endif
                (void)u_puts(1, "XIP-SNAPSHOT-RESTORED");
                (void)u_crlf(1);
                return 0;
        }
        if (xip_create_v1469() != 0 ||
            xip_check_file_v1469() != 0)
                return xip_fail_v1469("SNAP-CREATE-XIP", -1);
        fd = dsys_open(path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return xip_fail_v1469("SNAP-CREATE-OPEN", fd);
        if (dsys_write_words(fd,
                (kword_t *)xip_snapshot_payload_v1477, 3U) != 3 ||
            dsys_close(fd) != 0)
                return xip_fail_v1469("SNAP-CREATE-WRITE", -1);
        if (xip_check_file_v1469() != 0 ||
            dsys_meminfo(&mem) != 0 ||
            mem.memfs_used_words < 04000UL)
                return xip_fail_v1469("SNAP-NO-OWNER", -1);
        pid = xip_run_v1469(0U);
        status = 0UL;
        if (pid <= 1 ||
            dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 0U)
                return xip_fail_v1469("SNAP-FIRST-RUN", pid);
        (void)u_puts(1, "XIP-SNAPSHOT-WRITTEN");
        (void)u_crlf(1);
#ifdef XIP_SNAPSHOT_FAULT_V1478
        /* A test-only storage refusal must prevent HALT. The enclosing
         * shell issues a second HALT after the one-shot fault clears. */
        if (dsys_halt() != -1)
                return xip_fail_v1469("SNAP-HALT-ACCEPTED", -1);
        (void)u_puts(1, "XIP-SNAPSHOT-HALT-REFUSED");
        (void)u_crlf(1);
#endif
        return 0;
}
#endif

#ifdef XIP_REMOUNT_V1474
/* Repeated real VFS/MEMFS lifetime through the public root-only syscalls.
 * No stale vnode from the retired mount may be accepted on the new one.
 * The original driver continues with the final newly created XIP file. */
#define XIP_REMOUNT_ROUNDS_V1474 3U
static int
xip_remount_v1474(void)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        struct sys_meminfo absent;
        struct vfs_stat st;
        kword_t temp_path[U_PATH_WORDS];
        kword_t status;
        unsigned int round;
        int pid;

        if (u_s6_pack(temp_path, U_PATH_WORDS, "/TEMP") != 0 ||
            dsys_meminfo(&before) != 0)
                return xip_fail_v1469("REMOUNT-SETUP", -1);
        for (round = 0U; round < XIP_REMOUNT_ROUNDS_V1474; ++round) {
                pid = xip_run_v1469(0U);
                if (pid <= 1)
                        return xip_fail_v1469("REMOUNT-RUN", pid);
                status = 0UL;
                if (dsys_wait((unsigned int)pid, &status, 0U) != pid ||
                    SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                    SYS_WAIT_STATUS_VALUE(status) != 0U)
                        return xip_fail_v1469("REMOUNT-WAIT", (int)round);
                /* Verify that the singleton does not permit duplicate
                 * mounts before any of its resources are released. */
                if (dsys_memfs_mount(temp_path, 4096U, SYS_MOUNT_RW) == 0)
                        return xip_fail_v1469("REMOUNT-DUP", (int)round);
#ifdef XIP_UNMOUNT_FAULT_V1475
                if (round == 0U) {
                        /* A test-only data-destroy preflight refusal must
                         * leave the old MEMFS mount and XIP image intact. */
                        if (dsys_unmount(temp_path) != -1 ||
                            dsys_meminfo(&after) != 0 ||
                            after.memfs_used_words != before.memfs_used_words ||
                            after.memfs_capacity_words != before.memfs_capacity_words ||
                            after.resident_words != before.resident_words ||
                            xip_check_file_v1469() != 0)
                                return xip_fail_v1469("REMOUNT-REFUSAL", (int)round);
                        pid = xip_run_v1469(0U);
                        status = 0UL;
                        if (pid <= 1 ||
                            dsys_wait((unsigned int)pid, &status, 0U) != pid ||
                            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                            SYS_WAIT_STATUS_VALUE(status) != 0U)
                                return xip_fail_v1469("REMOUNT-RETRY-RUN", (int)round);
                        (void)u_puts(1, "XIP-REMOUNT-REFUSAL-PASS");
                        (void)u_crlf(1);
                }
#endif
                if (dsys_unmount(temp_path) != 0)
                        return xip_fail_v1469("REMOUNT-UNMOUNT", (int)round);
                if (dsys_stat(xip_path_v1469, &st) == 0 ||
                    dsys_meminfo(&absent) != 0 ||
                    absent.memfs_used_words != 0UL ||
                    absent.memfs_capacity_words != 0UL)
                        return xip_fail_v1469("REMOUNT-STALE", (int)round);
                if (dsys_memfs_mount(temp_path, 4096U, SYS_MOUNT_RW) != 0)
                        return xip_fail_v1469("REMOUNT-MOUNT", (int)round);
                if (dsys_stat(xip_path_v1469, &st) == 0)
                        return xip_fail_v1469("REMOUNT-OLD-NODE", (int)round);
                if (xip_create_v1469() != 0 ||
                    xip_check_file_v1469() != 0)
                        return xip_fail_v1469("REMOUNT-RECREATE", (int)round);
                if (dsys_meminfo(&after) != 0 ||
                    after.process_slots_used != before.process_slots_used ||
                    after.process_words != before.process_words ||
                    after.memfs_used_words != before.memfs_used_words ||
                    after.memfs_capacity_words != before.memfs_capacity_words ||
                    after.resident_words != before.resident_words)
                        return xip_fail_v1469("REMOUNT-MM-LEAK", (int)round);
        }
        (void)u_puts(1, "XIP-REMOUNT-PASS");
        (void)u_crlf(1);
        return 0;
}
#endif

#ifdef XIP_PRESSURE_V1473
/* A full-profile 128K PDP-6 has 32 process slots, while 192K/256K
 * machines have 48/64. Exercise almost the complete available table,
 * with distinct u-areas and a common pinned MEMFS executable. No user
 * memory is written by the certified two-instruction image itself. */
#define XIP_PRESSURE_LIMIT_V1473  56U
#define XIP_PRESSURE_ROUNDS_V1473 3U

static int
xip_pressure_v1473(void)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        struct sys_meminfo occupied;
        kword_t status;
        int children[XIP_PRESSURE_LIMIT_V1473];
        unsigned int count;
        unsigned int round;
        unsigned int i;
        int pid;

        if (dsys_meminfo(&before) != 0 ||
            before.process_slots_total <= before.process_slots_used + 3U)
                return xip_fail_v1469("PRESSURE-MEMINFO", -1);
        count = (unsigned int)(before.process_slots_total -
            before.process_slots_used - 2U);
        if (count > XIP_PRESSURE_LIMIT_V1473)
                count = XIP_PRESSURE_LIMIT_V1473;
        if (count < 12U)
                return xip_fail_v1469("PRESSURE-SLOTS", (int)count);

        for (round = 0U; round < XIP_PRESSURE_ROUNDS_V1473; ++round) {
                for (i = 0U; i < count; ++i) {
                        pid = xip_run_v1469(0U);
                        if (pid <= 1)
                                return xip_fail_v1469("PRESSURE-RUN", pid);
                        children[i] = pid;
                }
                if (dsys_meminfo(&occupied) != 0 ||
                    occupied.process_slots_used !=
                        before.process_slots_used + count)
                        return xip_fail_v1469("PRESSURE-COUNT", (int)round);
                /* These short XIP programs may already have exited and
                 * become zombies, retaining process slots but NOT pins.
                 * Do not infer live MEMFS pins from occupied slots.
                 * The proven-pinned unmount test is in v1472 below. */

                for (i = 0U; i < count; ++i) {
                        status = 0UL;
                        if (dsys_wait((unsigned int)children[i],
                            &status, 0U) != children[i] ||
                            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                            SYS_WAIT_STATUS_VALUE(status) != 0U)
                                return xip_fail_v1469("PRESSURE-WAIT", (int)i);
                }
                if (dsys_meminfo(&after) != 0 ||
                    after.process_slots_used != before.process_slots_used ||
                    after.process_words != before.process_words ||
                    after.memfs_used_words != before.memfs_used_words)
                        return xip_fail_v1469("PRESSURE-LEAK", (int)round);
                if (dsys_chmod(xip_path_v1469, 0644U) != 0 ||
                    dsys_chmod(xip_path_v1469, 0555U) != 0 ||
                    xip_check_file_v1469() != 0)
                        return xip_fail_v1469("PRESSURE-RELEASE", (int)round);
        }
        (void)u_puts(1, "XIP-PRESSURE-PASS");
        (void)u_crlf(1);
        return 0;
}
#endif

static int
xip_exec_v1469(unsigned int argc)
{
        kword_t words[XIP_EXEC_ARG_WORDS_V1469];
        struct sys_exec_v1 *block;
        unsigned int i;

        for (i = 0U; i < XIP_EXEC_ARG_WORDS_V1469; ++i)
                words[i] = 0UL;
        block = (struct sys_exec_v1 *)words;
        block->version_words = SYS_RUN_HEADER(SYS_EXEC_VERSION_1,
            argc ? XIP_EXEC_ARG_WORDS_V1469 : XIP_EXEC_WORDS_V1469);
        block->argc = argc;
        block->envc = 0UL;
        xip_copy_record_v1469(words + SYS_EXEC_V1_FIXED_WORDS);
        if (argc) {
                words[XIP_EXEC_WORDS_V1469] = 1UL;
                words[XIP_EXEC_WORDS_V1469 + 1U] =
                    TEST_SIX6('A', ' ', ' ', ' ', ' ', ' ');
        }
        return dsys_exec(block);
}

static int
xip_mutation_refusal_v1469(void)
{
        int fd;
        kword_t word;

        if (dsys_chmod(xip_path_v1469, 0644U) != 0)
                return xip_fail_v1469("BAD-CHMOD-1", -1);
        fd = dsys_open(xip_path_v1469, SYS_O_WRONLY);
        if (fd < 0 || dsys_seek(fd, 022UL, SYS_SEEK_SET) != 022UL)
                return xip_fail_v1469("BAD-OPEN", fd);
        word = 1UL;
        if (dsys_write_words(fd, &word, 1U) != 1 ||
            dsys_close(fd) != 0 ||
            dsys_chmod(xip_path_v1469, 0555U) != 0)
                return xip_fail_v1469("BAD-WRITE", -1);
        if (xip_run_v1469(0U) != -1)
                return xip_fail_v1469("BAD-ADMITTED", -1);
        if (dsys_chmod(xip_path_v1469, 0644U) != 0)
                return xip_fail_v1469("BAD-CHMOD-2", -1);
        fd = dsys_open(xip_path_v1469, SYS_O_WRONLY);
        if (fd < 0 || dsys_seek(fd, 022UL, SYS_SEEK_SET) != 022UL)
                return xip_fail_v1469("RESTORE-OPEN", fd);
        word = 0UL;
        if (dsys_write_words(fd, &word, 1U) != 1 ||
            dsys_close(fd) != 0 ||
            dsys_chmod(xip_path_v1469, 0555U) != 0)
                return xip_fail_v1469("RESTORE-WRITE", -1);
        return 0;
}

static int
xip_unprivileged_v1469(void)
{
        int rc;

        if (dsys_procctl(SYS_PROCCTL_SETUID, 1U) != 1)
                return 031;
        rc = xip_run_v1469(0U);
        if (rc != -1)
                return 032;
        return 0;
}

static int
xip_run_unprivileged_v1469(void)
{
        kword_t words[SYS_RUN_V2_FIXED_WORDS + 7U];
        struct sys_run_v2 *block;
        int pid;
        kword_t status;
        unsigned int i;

        for (i = 0U; i < SYS_RUN_V2_FIXED_WORDS + 7U; ++i)
                words[i] = 0UL;
        block = (struct sys_run_v2 *)words;
        block->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            SYS_RUN_V2_FIXED_WORDS + 7U);
        block->flags = SYS_RUN_PGRP_INHERIT;
        block->argc = 1UL;
        for (i = 0U; i < 5U; ++i)
                words[SYS_RUN_V2_FIXED_WORDS + i] =
                    xip_self_name_v1469[i];
        words[SYS_RUN_V2_FIXED_WORDS + 5U] = 1UL;
        words[SYS_RUN_V2_FIXED_WORDS + 6U] =
            TEST_SIX6('N', ' ', ' ', ' ', ' ', ' ');
        pid = dsys_run(block);
        if (pid <= 1)
                return xip_fail_v1469("USER-CHILD", pid);
        status = 0UL;
        if (dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 0U)
                return xip_fail_v1469("USER-WAIT", (int)status);
        return 0;
}

#ifdef XIP_UAREA_FAULT_V1472
/* Full kernel image, with the allocator/u-area failure injected only in
 * its isolated test copy. Real MEMFS certifies and pins the image first.
 * The first rollback retains its pin while two test-only unpin attempts
 * fail; slot zero then finishes the original unpublished child. */
static int
xip_uarea_fault_v1472(void)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        unsigned int slot;
        unsigned int i;
        int pending;
        int detail;
        int pid;
        int wait_result;
        kword_t status;
        kword_t temp_path[U_PATH_WORDS];

        if (dsys_meminfo(&before) != 0)
                return xip_fail_v1469("UAREA-INFO-BEFORE", -1);
        if (xip_run_v1469(0U) != -1)
                return xip_fail_v1469("UAREA-NOT-REFUSED", -1);

        pending = -1;
        for (slot = 1U; slot <= 32U; ++slot) {
                detail = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    slot | SYS_TEARDOWN_DETAIL_FLAG);
                if (detail >= 0 &&
                    SYS_TEARDOWN_STAGE(detail) == SYS_TEARDOWN_RUN_VM &&
                    SYS_TEARDOWN_RETRY_TICKS(detail) != 0U) {
                        pending = (int)slot;
                        break;
                }
        }
        if (pending < 2)
                return xip_fail_v1469("UAREA-NO-DEFERRED-VM", pending);
        if (dsys_chmod(xip_path_v1469, 0644U) == 0)
                return xip_fail_v1469("UAREA-PIN-DROPPED", pending);
        /* The failed CHMOD proves that the owner still has a MEMFS pin.
         * Unlike ordinary queued XIP children, this injected SIDL owner
         * cannot exit and lose its pin before the unmount request. */
        if (u_s6_pack(temp_path, U_PATH_WORDS, "/TEMP") != 0 ||
            dsys_unmount(temp_path) == 0)
                return xip_fail_v1469("UAREA-PINNED-UNMOUNT", pending);
        status = 0UL;
        wait_result = dsys_wait((unsigned int)pending, &status,
            SYS_WAIT_NOHANG);
        if (wait_result > 0)
                return xip_fail_v1469("UAREA-ZOMBIE", pending);

        for (i = 0U; i < 220U; ++i) {
                detail = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    (unsigned int)pending);
                if (detail == -1)
                        break;
                if (SYS_TEARDOWN_STAGE(detail) != SYS_TEARDOWN_RUN_VM ||
                    dsys_sleep(1U) != 0)
                        return xip_fail_v1469("UAREA-RETRY", detail);
        }
        if (i == 220U)
                return xip_fail_v1469("UAREA-TIMEOUT", pending);
        if (dsys_wait((unsigned int)pending, &status,
            SYS_WAIT_NOHANG) != -1)
                return xip_fail_v1469("UAREA-LATE-ZOMBIE", pending);
        if (dsys_chmod(xip_path_v1469, 0644U) != 0 ||
            dsys_chmod(xip_path_v1469, 0555U) != 0)
                return xip_fail_v1469("UAREA-LEAK", pending);
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words)
                return xip_fail_v1469("UAREA-ACCOUNTING", pending);

        pid = xip_run_v1469(0U);
        if (pid <= 1)
                return xip_fail_v1469("UAREA-RECOVERY-RUN", pid);
        status = 0UL;
        if (dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 0U)
                return xip_fail_v1469("UAREA-RECOVERY-WAIT", pid);
        if (xip_check_file_v1469() != 0)
                return 1;
        (void)u_puts(1, "XIP-UAREA-FAULT-PASS");
        (void)u_crlf(1);
        return 0;
}
#endif

int
main(int argc, kword_t **argv)
{
        int pid;
        int i;
        int shared_pids[3];
        kword_t status;

#ifdef XIP_SNAPSHOT_V1477
        (void)argc;
        (void)argv;
        return xip_snapshot_v1477();
#endif
        if (argc == 1 && argv != 0 && argv[0] != 0 &&
            argv[0][1] == TEST_SIX6('N', ' ', ' ', ' ', ' ', ' ')) {
                i = xip_unprivileged_v1469();
                (void)dsys_exit(i);
                return i;
        }
        if (argc > 1)
                return xip_fail_v1469("UNEXPECTED-ARGV", argc);
        if (xip_create_v1469() != 0)
                return 1;
        if (xip_check_file_v1469() != 0)
                return 1;
#ifdef XIP_REMOUNT_V1474
        if (xip_remount_v1474() != 0)
                return 1;
#endif
#ifdef XIP_PRESSURE_V1473
        if (xip_pressure_v1473() != 0)
                return 1;
#endif
#ifdef XIP_UAREA_FAULT_V1472
        if (xip_uarea_fault_v1472() != 0)
                return 1;
#endif
        for (i = 0; i < 3; ++i) {
                pid = xip_run_v1469(0U);
                if (pid <= 1)
                        return xip_fail_v1469("RUN", pid);
                status = 0UL;
                if (dsys_wait((unsigned int)pid, &status, 0U) != pid ||
                    SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                    SYS_WAIT_STATUS_VALUE(status) != 0U)
                        return xip_fail_v1469("WAIT", (int)status);
        }
        /* Queue three instances before WAIT. They can share one pinned
         * MEMFS extent, but each needs an independent VM/u-area lifetime. */
        for (i = 0; i < 3; ++i) {
                shared_pids[i] = xip_run_v1469(0U);
                if (shared_pids[i] <= 1)
                        return xip_fail_v1469("SHARED-RUN", shared_pids[i]);
        }
        for (i = 0; i < 3; ++i) {
                status = 0UL;
                if (dsys_wait((unsigned int)shared_pids[i],
                    &status, 0U) != shared_pids[i] ||
                    SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                    SYS_WAIT_STATUS_VALUE(status) != 0U)
                        return xip_fail_v1469("SHARED-WAIT", (int)status);
        }
        if (xip_run_v1469(1U) != -1)
                return xip_fail_v1469("ARGV-ACCEPTED", -1);
        if (xip_mutation_refusal_v1469() != 0 ||
            xip_run_unprivileged_v1469() != 0)
                return 1;
        if (xip_exec_v1469(1U) != -1)
                return xip_fail_v1469("EXEC-ARGV-ACCEPTED", -1);
        if (dsys_chmod(xip_path_v1469, 0644U) != 0 ||
            dsys_chmod(xip_path_v1469, 0555U) != 0)
                return xip_fail_v1469("PIN-LEAK", -1);
        (void)u_puts(1, "XIP-RUN-PASS");
        (void)u_crlf(1);
        /* On success the process is replaced and exits with status zero.
         * Returning here proves a failed transactional EXEC selection. */
        return xip_fail_v1469("EXEC-RETURNED", xip_exec_v1469(0U));
}
