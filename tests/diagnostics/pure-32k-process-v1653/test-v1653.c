/*
 * v1653: minimal genuine PDP-6 32K no-AUX PURE MRES boot/RUN/WAIT.
 *
 * The production kernel, loader, scheduler and MM allocator are
 * unchanged. The child is loaded as a separate DXR2 process.
 * This guest is NOT proof of actual RAW PACKED memory savings.
 *
 * C89 and ASCII only.
 */
#include "dsys.h"
#include "proc.h"

#define V1653_PATH_WORDS 3U
#define V1653_ARG_WORDS 2U
#define V1653_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define V1653_ARG0_OFF (V1653_PATH_OFF + V1653_PATH_WORDS)
#define V1653_ARG1_OFF (V1653_ARG0_OFF + V1653_PATH_WORDS)
#define V1653_MAP_OFF (V1653_ARG1_OFF + V1653_ARG_WORDS)
#define V1653_BLOCK_WORDS (V1653_MAP_OFF + 3U)
#define V1653_STATUS 057U

#define V1653_SIXCHAR(c) (((unsigned long)(c) - 040UL) & 077UL)
#define V1653_SIX6(a,b,c,d,e,f) \
    ((V1653_SIXCHAR(a) << 30) | (V1653_SIXCHAR(b) << 24) | \
     (V1653_SIXCHAR(c) << 18) | (V1653_SIXCHAR(d) << 12) | \
     (V1653_SIXCHAR(e) << 6) | V1653_SIXCHAR(f))

static volatile kword_t v1653_mutable = 054321UL;
static kword_t v1653_path[3] = {
    12UL,
    V1653_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
    V1653_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static void
v1653_fail(int marker)
{
    (void)dsys_writechar(1, '!');
    (void)dsys_writechar(1, marker);
    (void)dsys_exit(070U);
}

static int
v1653_run_child(void)
{
    kword_t block[V1653_BLOCK_WORDS];
    struct sys_run_v2 *run = (struct sys_run_v2 *)block;
    unsigned int i;

    for (i = 0U; i < V1653_BLOCK_WORDS; ++i)
        block[i] = 0UL;
    run->flags = SYS_RUN_PGRP_INHERIT;
    run->pgrp = 0UL;
    run->fdmap_count = 3UL;
    run->argc = 2UL;
    run->envc = 0UL;
    for (i = 0U; i < V1653_PATH_WORDS; ++i) {
        block[V1653_PATH_OFF + i] = v1653_path[i];
        block[V1653_ARG0_OFF + i] = v1653_path[i];
    }
    block[V1653_ARG1_OFF] = 1UL;
    block[V1653_ARG1_OFF + 1U] =
        V1653_SIX6('C', ' ', ' ', ' ', ' ', ' ');
    block[V1653_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
    block[V1653_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
    block[V1653_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
    run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
        V1653_BLOCK_WORDS);
    return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
    struct sys_meminfo mem;
    kword_t status;
    int child;

    (void)argv;
    if (argc > 1) {
        if (v1653_mutable != 054321UL)
            v1653_fail('d');
        (void)dsys_writechar(1, 'c');
        (void)dsys_exit(V1653_STATUS);
        return V1653_STATUS;
    }
    if (dsys_meminfo(&mem) != 0)
        v1653_fail('m');
    if (dsys_brk(0UL) == (kword_t)-1L)
        v1653_fail('b');
    v1653_mutable = 012345UL;
    (void)dsys_writechar(1, 'B');
    child = v1653_run_child();
    if (child <= 1)
        v1653_fail('r');
    status = 0UL;
    if (dsys_wait((unsigned int)child, &status, 0U) != child ||
        SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
        SYS_WAIT_STATUS_VALUE(status) != V1653_STATUS)
        v1653_fail('w');
    if (v1653_mutable != 012345UL)
        v1653_fail('D');
    (void)dsys_writechar(1, 'Z');
    (void)dsys_exit(0U);
    return 0;
}
