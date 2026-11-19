/* Physical PDP-6 post-boot RUN/EXIT/WAIT memory pressure, test-only PID1.
 * The production KCORE and original INIT executable are NOT modified.
 * This C89 fixture replaces /SYSTEM/INIT only in a disposable TSFS image.
 */
#include "u.h"

#define V1672_MAX_CHILDREN 7U
#define V1672_RUN_WORDS (SYS_RUN_V2_FIXED_WORDS + 3U * U_PATH_WORDS + 3U)

extern void v1672_before(void);
extern void v1672_pressure(void);
extern void v1672_reaped(void);

/* A disposable TSFS manifest substitutes the tiny v1672 sleep-and-exit
 * assembly test under MOUNTALL. Never alter the production MOUNTALL. */
static const char *const v1672_init_name = "/SYSTEM/EXEC/MOUNTALL";

static void
v1672_line(const char *text, kword_t number)
{
        (void)u_puts(1, text);
        (void)u_put_uint(1, number);
        (void)u_crlf(1);
}

static int
v1672_run_child(void)
{
        kword_t words[V1672_RUN_WORDS];
        kword_t path[U_PATH_WORDS];
        kword_t child[U_PATH_WORDS];
        struct sys_run_v2 *run;
        unsigned int path_words;
        unsigned int child_words;
        unsigned int arg0;
        unsigned int arg1;
        unsigned int maps;
        unsigned int total;
        unsigned int i;

        if (u_s6_pack(path, U_PATH_WORDS, v1672_init_name) != 0 ||
            u_s6_pack(child, U_PATH_WORDS, "CHILD") != 0)
                return -1;
        path_words = 1U + (unsigned int)((path[0] + 5UL) / 6UL);
        child_words = 1U + (unsigned int)((child[0] + 5UL) / 6UL);
        arg0 = SYS_RUN_V2_FIXED_WORDS + path_words;
        arg1 = arg0 + path_words;
        maps = arg1 + child_words;
        total = maps + 3U;
        if (total > V1672_RUN_WORDS)
                return -1;
        for (i = 0U; i < total; ++i)
                words[i] = 0UL;
        run = (struct sys_run_v2 *)words;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, total);
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->pgrp = 0UL;
        run->fdmap_count = 3UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < path_words; ++i) {
                words[SYS_RUN_V2_FIXED_WORDS + i] = path[i];
                words[arg0 + i] = path[i];
        }
        for (i = 0U; i < child_words; ++i)
                words[arg1 + i] = child[i];
        words[maps] = SYS_RUN_FD_MAP(0U, 0U);
        words[maps + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        words[maps + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        return dsys_run(run);
}

static void
v1672_meminfo(const char *phase)
{
        struct sys_meminfo mem;

        if (dsys_meminfo(&mem) != 0) {
                (void)u_puts(1, "V1672 MEMINFO FAILURE");
                (void)u_crlf(1);
                return;
        }
        (void)u_puts(1, phase);
        (void)u_crlf(1);
        v1672_line("V1672 TOTAL ", mem.total_words);
        v1672_line("V1672 RESIDENT ", mem.resident_words);
        v1672_line("V1672 PROCESS-WORDS ", mem.process_words);
    v1672_line("V1672 PROC-SLOTS ", mem.process_slots_used);
}

/* Guest-only deterministic checkpoint. The host pauses SIMH at the
 * CTY marker and reads the original MM fields. A distinct input token
 * releases each stage; no kernel breakpoint address or resident probe
 * is needed. A missing/closed CTY input is a hard test failure. */
static int
v1672_host_hold(int token)
{
        int c;

        (void)u_puts(1, "V1672 HOLD ");
        (void)u_putc(1, token);
        (void)u_crlf(1);
        for (;;) {
                c = dsys_readchar(0);
                if (c < 0)
                        return -1;
                if (c == token)
                        break;
        }
        (void)u_puts(1, "V1672 RELEASE ");
        (void)u_putc(1, token);
        (void)u_crlf(1);
        return 0;
}

int
main(int argc, kword_t **argv)
{
        unsigned int count;
        unsigned int i;
        unsigned int actual;
        int children[V1672_MAX_CHILDREN];
        int pid;
        kword_t status;
        struct sys_meminfo mem;

        if (argc == 2 && u_s6_eq(argv[1], "CHILD")) {
                /* Long enough for parent to launch all siblings and for
                 * the physical simulator to sample their REAL MM owners.
                 * No child touches a shared kernel test latch. */
                (void)dsys_sleep(1800U);
                return 0;
        }
        if (dsys_getpid() != 1 || argc < 1 ||
            dsys_meminfo(&mem) != 0) {
                (void)u_puts(1, "V1672 BAD INITIAL PROCESS");
                (void)u_crlf(1);
                return 31;
        }
        count = (mem.total_words <= 49152UL) ? 4U : 7U;
        v1672_line("V1672 START CHILDREN ", count);
        v1672_meminfo("V1672 BASELINE");
        v1672_before();
        if (v1672_host_hold('A') != 0)
                return 34;

        actual = 0U;
        for (i = 0U; i < count; ++i) {
                v1672_line("V1672 LAUNCH ", i);
                pid = v1672_run_child();
                if (pid <= 0) {
                        (void)u_puts(1, "V1672 RUN FAILURE");
                        (void)u_crlf(1);
                        return 32;
                }
                children[actual++] = pid;
                v1672_line("V1672 CHILD PID ", (kword_t)pid);
        }
        v1672_meminfo("V1672 PRESSURE");
        v1672_pressure();
        if (v1672_host_hold('B') != 0)
                return 35;
        for (i = 0U; i < actual; ++i) {
                if (dsys_wait((unsigned int)children[i], &status, 0U) !=
                        children[i] ||
                    SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                    SYS_WAIT_STATUS_VALUE(status) != 0U) {
                        (void)u_puts(1, "V1672 WAIT FAILURE");
                        (void)u_crlf(1);
                        return 33;
                }
        }
        v1672_meminfo("V1672 REAPED");
        v1672_reaped();
        if (v1672_host_hold('C') != 0)
                return 36;
        (void)u_puts(1, "V1672 PASS RUN EXIT WAIT");
        (void)u_crlf(1);
        /* Deliberately retain PID1 until the host terminates SIMH.
         * The reaped snapshot is taken before this extra sleep. */
        for (;;)
                (void)dsys_sleep(600U);
}
