#include "dsys.h"
#include "proc.h"

#define WRITER_MODE          0131U
#define JOB_MODE             0132U
#define PRESSURE_MODE        0133U
#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 4U)
#define WAIT_SPINS           020000U
#define PIPE_WORDS           8U
#define WRITER_STATUS        050U
#define JOB_STATUS           051U
#define PRESSURE_STATUS      052U
#define TEST_SIXCHAR(ch) \
        ((unsigned long)(((unsigned int)(ch) - 040U) & 077U))
#define TEST_SIX6(a,b,c,d,e,f) \
        ((TEST_SIXCHAR(a) << 30) | (TEST_SIXCHAR(b) << 24) | \
        (TEST_SIXCHAR(c) << 18) | (TEST_SIXCHAR(d) << 12) | \
        (TEST_SIXCHAR(e) << 6) | TEST_SIXCHAR(f))

/* Every invocation of /SYSTEM/INIT carries this array.  Parent, target and
 * v271: 24K-word data array deliberately stays below the 077777-octal
 * BSS cap; it tests loader admission before later 256K stress calibration. */
static volatile kword_t pressure_area[020000];
static volatile kword_t burn_word;

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static int
mark(int ch)
{
        return dsys_writechar(1, ch);
}

static void
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

static void
touch_image(unsigned int mode)
{
        pressure_area[0] = (kword_t)mode;
    pressure_area[017777] = (kword_t)mode ^ 0123456701234UL;
}

static void
burn(void)
{
        unsigned int i;

        for (i = 0U; i < 0400U; ++i)
                burn_word = (burn_word + (kword_t)i + 1UL) & 0777777777777UL;
}

static int
new_pipe(int *read_fd, int *write_fd)
{
        kword_t pair;

        pair = dsys_pipe();
        if (pair == ~0UL)
                return -1;
        *read_fd = (int)((pair >> 18U) & 0777777UL);
        *write_fd = (int)(pair & 0777777UL);
        return *read_fd >= 0 && *read_fd < 16 && *write_fd >= 0 &&
            *write_fd < 16 && *read_fd != *write_fd ? 0 : -1;
}

static int
spawn_child(unsigned int mode, unsigned int pgrp_mode, unsigned int pgrp,
    int input_fd, int data_fd)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int n;
        unsigned int i;
        int mode_ch;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = (kword_t)pgrp_mode;
        run->pgrp = (kword_t)pgrp;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        mode_ch = mode == WRITER_MODE ? 'W' :
            (mode == JOB_MODE ? 'J' : 'P');
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
        n = 0U;
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(0U,
            (unsigned int)input_fd);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(2U, 2U);
        if (data_fd >= 0)
                block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(3U,
                    (unsigned int)data_fd);
        run->fdmap_count = (kword_t)n;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_MAP_OFF + n);
        return dsys_run(run);
}

/* v550: explicitly release alternating resident child images. */
static volatile kword_t keeper;
static int
wait_state(unsigned int pid, unsigned int state)
{
    struct sys_procinfo info;
    unsigned int tries;
    for (tries = 0U; tries < WAIT_SPINS; ++tries) {
        if (dsys_procinfo(pid, &info) == 0 && info.state == state)
            return 0;
        burn();
    }
    return -1;
}
/* Serial octal diagnostic: 18-bit logical addresses, no printf/heap. */
static void oct6(kword_t x)
{
    int shift;
    for (shift = 15; shift >= 0; shift -= 3)
        (void)mark('0' + (int)((x >> shift) & 7UL));
}

int main(int argc, kword_t **argv)
{
    int gate_r, gate_w, child[16];
    unsigned int i;
    kword_t w, status;
    (void)argv;
    keeper = 012345670123UL;
    touch_image(argc > 1 ? PRESSURE_MODE : 1U);
    if (argc > 1) {
        /* Child holds its resident image until the parent closes its gate. */
        if (dsys_read_words(0, &w, 1U) != 0)
            (void)dsys_exit(071);
        if (pressure_area[0] != (kword_t)PRESSURE_MODE ||
            pressure_area[017777] != ((kword_t)PRESSURE_MODE ^ 0123456701234UL))
            (void)dsys_exit(072);
        (void)dsys_exit(PRESSURE_STATUS);
        return PRESSURE_STATUS;
    }
    (void)dsys_storagectl(SYS_STORAGECTL_SWAP | SYS_STORAGECTL_LOGSTORE);
    if (mark('<') != 0) fail('M', 1);
    if (new_pipe(&gate_r, &gate_w) != 0) fail('P', 2);
    for (i = 0U; i < 16U; ++i) {
        child[i] = spawn_child(PRESSURE_MODE, SYS_RUN_PGRP_INHERIT,
            0U, gate_r, -1);
        if (child[i] <= 1 ||
            wait_state((unsigned int)child[i], PROC_SLEEP) != 0)
            fail('S', 3);
    }
    (void)mark('A');
    for (i = 1U; i < 16U; i += 2U) {
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG((unsigned int)child[i], SYS_EVENT_TERM)) < 0 ||
            dsys_wait((unsigned int)child[i], &status, 0U) != child[i])
            fail('E', 4);
    }
    (void)mark('B');
    /* Request a large contiguous parent image while alternating holes
       remain separated by live, asleep child processes. */
    {
        kword_t old_break = dsys_brk(0UL);
        kword_t new_break = 0300000UL;
        (void)mark('['); oct6(old_break);
        (void)mark('+'); oct6(new_break);
        (void)mark('=');
        {
            kword_t got = dsys_brk(new_break);
            oct6(got);
            (void)mark(']');
            if (got != new_break) fail('G', 5);
        }
    }
    (void)mark('C');
    if (dsys_close(gate_w) != 0 || dsys_close(gate_r) != 0) fail('W', 7);
    for (i = 0U; i < 16U; i += 2U) {
        if (dsys_wait((unsigned int)child[i], &status, 0U) != child[i] ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != PRESSURE_STATUS)
            fail('W', 7);
    }
    if (keeper != 012345670123UL) fail('D', 8);
    (void)mark('Q');
    (void)dsys_exit(0);
    return 0;
}
