/* Real guest MM descriptor exhaustion using independent PIPE owners. */
#include "u.h"
#include "proc.h"

#define V1953_CHILDREN 4U
#define V1953_EXTRA_PIPES 6U
#define V1673_RUN_WORDS (SYS_RUN_V2_FIXED_WORDS + 3U * U_PATH_WORDS + 3U)

extern void v1673_before(void);
extern void v1673_pressure(void);
extern void v1673_reaped(void);

/* Test-only MOUNTALL child reads one word from an inherited pipe.
 * A blocked pipe read is a normal native PROC_SLEEP and has no timer;
 * it is safe to resume after arbitrarily slow host-side MM watchpoints.
 * Never replace the production INIT/MOUNTALL except on disposable media. */
static const char *const v1673_init_name = "/SYSTEM/EXEC/MOUNTALL";

static void
v1673_line(const char *text, kword_t number)
{
        (void)u_puts(1, text);
        (void)u_put_uint(1, number);
        (void)u_crlf(1);
}

static int
v1673_run_child(int readfd)
{
        kword_t words[V1673_RUN_WORDS];
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

        if (u_s6_pack(path, U_PATH_WORDS, v1673_init_name) != 0 ||
            u_s6_pack(child, U_PATH_WORDS, "CHILD") != 0)
                return -1;
        path_words = 1U + (unsigned int)((path[0] + 5UL) / 6UL);
        child_words = 1U + (unsigned int)((child[0] + 5UL) / 6UL);
        arg0 = SYS_RUN_V2_FIXED_WORDS + path_words;
        arg1 = arg0 + path_words;
        maps = arg1 + child_words;
        total = maps + 3U;
        if (total > V1673_RUN_WORDS)
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
        words[maps] = SYS_RUN_FD_MAP(0U, (unsigned int)readfd);
        words[maps + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        words[maps + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        return dsys_run(run);
}

static void
v1673_meminfo(const char *phase)
{
        struct sys_meminfo mem;

        if (dsys_meminfo(&mem) != 0) {
                (void)u_puts(1, "V1673 MEMINFO FAILURE");
                (void)u_crlf(1);
                return;
        }
        (void)u_puts(1, phase);
        (void)u_crlf(1);
        v1673_line("V1673 TOTAL ", mem.total_words);
        v1673_line("V1673 RESIDENT ", mem.resident_words);
        v1673_line("V1673 PROCESS-WORDS ", mem.process_words);
        v1673_line("V1673 PROC-SLOTS ", mem.process_slots_used);
}

/* Guest-only deterministic checkpoint. The host pauses SIMH at the
 * CTY marker and reads the original MM fields. A distinct input token
 * releases each stage; no kernel breakpoint address or resident probe
 * is needed. A missing/closed CTY input is a hard test failure. */
static int
v1673_host_hold(int token)
{
        int c;

        (void)u_puts(1, "V1673 HOLD ");
        (void)u_putc(1, token);
        (void)u_crlf(1);
        for (;;) {
                c = dsys_readchar(0);
                if (c < 0)
                        return -1;
                if (c == token)
                        break;
        }
        (void)u_puts(1, "V1673 RELEASE ");
        (void)u_putc(1, token);
        (void)u_crlf(1);
        return 0;
}

static int
close_pair(kword_t pair)
{
        int rd = (int)((pair >> 18U) & 0777777UL);
        int wr = (int)(pair & 0777777UL);
        if (dsys_close(rd) != 0 || dsys_close(wr) != 0)
                return -1;
        return 0;
}

int
main(int argc, kword_t **argv)
{
        int child[V1953_CHILDREN];
        kword_t coord, extra[V1953_EXTRA_PIPES], token, status;
        unsigned int i, n, spin;
        int rd, wr, pid;
        struct sys_procinfo info;
        struct sys_meminfo mem;

        (void)argv;
        if (argc < 1 || dsys_getpid() != 1 ||
            dsys_meminfo(&mem) != 0 || mem.total_words != 49152UL)
                return 30;
        coord = dsys_pipe();
        if (coord == (kword_t)-1)
                return 31;
        rd = (int)((coord >> 18U) & 0777777UL);
        wr = (int)(coord & 0777777UL);
        v1673_meminfo("V1953 BASELINE");
        v1673_before();
        if (v1673_host_hold('A') != 0)
                return 32;
        for (i = 0U; i < V1953_CHILDREN; ++i) {
                pid = v1673_run_child(rd);
                if (pid <= 1)
                        return 33;
                child[i] = pid;
                /* The assembly child allocates three separate pipe
                 * objects before entering an unbounded pipe wait. */
                for (spin = 0U; spin < 020000U; ++spin) {
                        if (dsys_procinfo((unsigned int)pid, &info) == 0 &&
                            info.state == (kword_t)PROC_SLEEP)
                                break;
                        if (dsys_sleep(1U) != 0)
                                return 34;
                }
                if (spin == 020000U)
                        return 35;
                v1673_line("V1953 CHILD ", (kword_t)pid);
        }
        /* Only FD 0..2 and the coordination writer are live in PID1.
         * A refusal must occur before the six remaining FD pairs are
         * consumed; the physical verifier requires MM count==capacity. */
        if (dsys_close(rd) != 0)
                return 36;
        for (n = 0U; n < V1953_EXTRA_PIPES; ++n) {
                extra[n] = dsys_pipe();
                if (extra[n] == (kword_t)-1)
                        break;
        }
        if (n == 0U || n >= V1953_EXTRA_PIPES)
                return 37;
        v1673_line("V1953 EXTRA PIPES ", n);
        v1673_meminfo("V1953 EXHAUSTED");
        v1673_pressure();
        if (v1673_host_hold('B') != 0)
                return 38;
        if (close_pair(extra[n-1U]) != 0)
                return 39;
        extra[n-1U] = dsys_pipe();
        if (extra[n-1U] == (kword_t)-1)
                return 40;
        if (dsys_pipe() != (kword_t)-1)
                return 41;
        v1673_meminfo("V1953 RETRY");
        if (v1673_host_hold('C') != 0)
                return 42;
        /* Free parent-owned extra descriptors before restoring children.
         * Their three independent pipes are closed by native EXIT. */
        for (i = 0U; i < n; ++i)
                if (close_pair(extra[i]) != 0)
                        return 43;
        token = 01234567UL;
        for (i = 0U; i < V1953_CHILDREN; ++i)
                if (dsys_write_words(wr, &token, 1U) != 1)
                        return 44;
        for (i = 0U; i < V1953_CHILDREN; ++i) {
                if (dsys_wait((unsigned int)child[i], &status, 0U) != child[i] ||
                    SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                    SYS_WAIT_STATUS_VALUE(status) != 0U)
                        return 45;
                v1673_line("V1953 WAIT ", (kword_t)child[i]);
        }
        if (dsys_close(wr) != 0)
                return 46;
        v1673_meminfo("V1953 REAPED");
        v1673_reaped();
        if (v1673_host_hold('D') != 0)
                return 47;
        (void)u_puts(1, "V1673 PASS RUN EXIT WAIT");
        (void)u_crlf(1);
        for (;;)
                (void)dsys_sleep(600U);
}
