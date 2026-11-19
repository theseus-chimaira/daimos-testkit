/*
 * v1614 physical PDP-6 TSFS PURE / BRK / PIPE / WAIT diagnostic.
 *
 * Every child carries a small mutable tail in a private PROCESS VM.
 * The parent starts its sleeping children before growing its own BRK,
 * so the allocation is not confused with a failed new-process RUN.
 * Intended to prove DROP and restoration with preserved mutable tail.
 * The current 48K machine returns !G from BRK after genuine RAW
 * DROP/rebase entry. This is NOT an accepted scheduler regression.
 *
 * No privileged host-only kernel introspection or added process fields.
 * Source is C89 and all code characters are ASCII.
 */
#include "dsys.h"
#include "proc.h"

#define P14_CHILD_MODE       0123U
#define P14_CHILDREN         4U
#define P14_IMAGE_WORDS      04000U
#define P14_BRK_TARGET       022000UL
#define P14_SPINS            020000U
#define P14_PATH_WORDS       3U
#define P14_ARG_WORDS        2U
#define P14_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define P14_ARG0_OFF         (P14_PATH_OFF + P14_PATH_WORDS)
#define P14_ARG1_OFF         (P14_ARG0_OFF + P14_PATH_WORDS)
#define P14_MAP_OFF          (P14_ARG1_OFF + P14_ARG_WORDS)
#define P14_BLOCK_WORDS      (P14_MAP_OFF + 3U)
#define P14_STATUS           057U

#define P14_SIXCHAR(ch) \
    ((unsigned long)(((unsigned int)(ch) - 040U) & 077U))
#define P14_SIX6(a,b,c,d,e,f) \
    ((P14_SIXCHAR(a) << 30) | (P14_SIXCHAR(b) << 24) | \
    (P14_SIXCHAR(c) << 18) | (P14_SIXCHAR(d) << 12) | \
    (P14_SIXCHAR(e) << 6) | P14_SIXCHAR(f))

static volatile kword_t p14_data[P14_IMAGE_WORDS];
static volatile kword_t p14_busy;
static kword_t p14_path[3] = {
    12UL,
    P14_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
    P14_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static int
p14_char(int c)
{
    return dsys_writechar(1, c);
}

static void
p14_fail(int c)
{
    (void)p14_char('!');
    (void)p14_char(c);
    (void)dsys_exit(070);
}

static void
p14_octal(kword_t value)
{
    int shift;
    for (shift = 15; shift >= 0; shift -= 3)
        (void)p14_char('0' + (int)((value >> shift) & 07UL));
}

static void
p14_stat(int mark)
{
    struct sys_meminfo m;
    if (dsys_meminfo(&m) != 0)
        p14_fail('m');
    (void)p14_char('[');
    (void)p14_char(mark);
    p14_octal(m.process_words);
    (void)p14_char('/');
    p14_octal(m.resident_words);
    (void)p14_char(']');
}

static void
p14_spin(void)
{
    unsigned int i;
    for (i = 0U; i < 0400U; ++i)
        p14_busy = (p14_busy + (kword_t)i) & 0777777777777UL;
}

static int
p14_sleeping(unsigned int pid)
{
    unsigned int i;
    struct sys_procinfo p;
    for (i = 0U; i < P14_SPINS; ++i) {
        if (dsys_procinfo(pid, &p) == 0 &&
            p.state == (kword_t)PROC_SLEEP)
            return 1;
        p14_spin();
    }
    return 0;
}

static int
p14_pipe(int *rd, int *wr)
{
    kword_t pair = dsys_pipe();
    if (pair == ~0UL)
        return -1;
    *rd = (int)((pair >> 18U) & 0777777UL);
    *wr = (int)(pair & 0777777UL);
    return (*rd >= 0 && *rd < 16 && *wr >= 0 && *wr < 16 &&
        *rd != *wr) ? 0 : -1;
}

static int
p14_spawn(int fd)
{
    kword_t block[P14_BLOCK_WORDS];
    struct sys_run_v2 *run = (struct sys_run_v2 *)block;
    unsigned int i;
    for (i = 0U; i < P14_BLOCK_WORDS; ++i)
        block[i] = 0UL;
    run->flags = SYS_RUN_PGRP_INHERIT;
    run->pgrp = 0UL;
    run->fdmap_count = 3UL;
    run->argc = 2UL;
    run->envc = 0UL;
    for (i = 0U; i < P14_PATH_WORDS; ++i) {
        block[P14_PATH_OFF + i] = p14_path[i];
        block[P14_ARG0_OFF + i] = p14_path[i];
    }
    block[P14_ARG1_OFF] = 1UL;
    block[P14_ARG1_OFF + 1U] =
        P14_SIX6('C', ' ', ' ', ' ', ' ', ' ');
    block[P14_MAP_OFF] = SYS_RUN_FD_MAP(0U, (unsigned int)fd);
    block[P14_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
    block[P14_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
    run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
        P14_BLOCK_WORDS);
    return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
    int rd, wr, pid[P14_CHILDREN], got;
    unsigned int i;
    kword_t old_brk, target, status, word;
    struct sys_meminfo before, after;
    struct sys_procinfo info;
    kword_t all_words, child_words, brk_words;

    (void)argv;
    p14_data[0] = 012345670123UL;
    p14_data[P14_IMAGE_WORDS - 1U] = 076543210765UL;

    if (argc > 1) {
        if (dsys_read_words(0, &word, 1U) != 0)
            (void)dsys_exit(071);
        if (p14_data[0] != 012345670123UL ||
            p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL)
            (void)dsys_exit(072);
        (void)p14_char('w');
        (void)dsys_exit(P14_STATUS);
        return P14_STATUS;
    }
    if (p14_pipe(&rd, &wr) != 0)
        p14_fail('p');
    for (i = 0U; i < P14_CHILDREN; ++i) {
        pid[i] = p14_spawn(rd);
        if (pid[i] <= 1 || !p14_sleeping((unsigned int)pid[i]))
            p14_fail('c');
        (void)p14_char('a');
    }
    if (dsys_close(rd) != 0)
        p14_fail('d');
    if (dsys_sleep(0200U) != 0)
        p14_fail('t');
    if (dsys_meminfo(&before) != 0)
        p14_fail('n');
    p14_stat('B');

    /* The allocator may reclaim a sleeping process's immutable prefix
     * only when the current BRK delta cannot be placed otherwise.
     * Start with an already fitting set of sleeping owners.
     */
    old_brk = dsys_brk(0UL);
    if (old_brk == (kword_t)-1L)
        p14_fail('q');
    target = P14_BRK_TARGET;
    (void)p14_char('<');
    p14_octal(old_brk);
    (void)p14_char('+');
    p14_octal(target);
    (void)p14_char('>');
    if (target <= old_brk || dsys_brk(target) != target)
        p14_fail('G');
    if (dsys_meminfo(&after) != 0)
        p14_fail('M');
    p14_stat('A');

    /* Logical mapped words exclude a PACKED owner. Compare with the
     * expected BRK APR growth and require at least one complete
     * formerly mapped child to be nonresident.
     */
    all_words = 0UL;
    child_words = 0UL;
    for (i = 0U; i < P14_CHILDREN; ++i) {
        if (dsys_procinfo((unsigned int)pid[i], &info) != 0 ||
            info.state != (kword_t)PROC_SLEEP)
            p14_fail('s');
        all_words += info.words;
        if (!child_words)
            child_words = info.words;
    }
    brk_words = (target + 01777UL) & ~01777UL;
    brk_words -= (old_brk + 01777UL) & ~01777UL;
    (void)p14_char('{');
    p14_octal(before.process_words);
    (void)p14_char('-');
    p14_octal(after.process_words);
    (void)p14_char('}');
    if (!child_words || all_words < child_words ||
        before.process_words + brk_words <
            after.process_words + child_words)
        p14_fail('R');
    (void)p14_char('R');

    if (dsys_close(wr) != 0)
        p14_fail('e');
    for (i = 0U; i < P14_CHILDREN; ++i) {
        status = 0UL;
        got = dsys_wait((unsigned int)pid[i], &status, 0U);
        if (got != pid[i] ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != P14_STATUS)
            p14_fail('W');
    }
    if (p14_data[0] != 012345670123UL ||
        p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL)
        p14_fail('D');
    (void)p14_char('Z');
    (void)dsys_exit(0);
    return 0;
}
