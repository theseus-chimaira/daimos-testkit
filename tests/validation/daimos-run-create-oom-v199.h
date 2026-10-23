/*
 * v199: exercise failure of vm_space_create during a *valid* RUN.
 *
 * Fill most of the 256K physical address space with the active process's
 * own VM.  Its live APR mapping cannot be swapped out. Since the separately
 * linked v199 child needs at least 0100000 physical words after rounding
 * its BSS, text and startup to the APR quantum. RUN must fail before
 * child u-area/startup/descriptor construction. Shrink back to the original
 * break and prove that the very same valid RUN can start and be reaped.
 *
 * This variant is intentionally separate from v198's valid-but-unallocatable
 * large BRK request. No kernel fault-injection switch or changed limit.
 */
#ifndef DAIMOS_RUN_CREATE_OOM_V199_H
#define DAIMOS_RUN_CREATE_OOM_V199_H

#define V199_VM_LIMIT      0776000UL
#define V199_VM_QUANTUM    02000UL
#define V199_FAILED_RUNS   4U

static int
run_large_child_v199(void)
{
        static kword_t large_path[] = {
                22UL,
                TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
                TEST_SIX6('M', '/', 'E', 'X', 'E', 'C'),
                TEST_SIX6('/', 'T', 'S', 'F', 'S', 'P'),
                TEST_SIX6('R', 'O', 'B', 'E', ' ', ' ')
        };
        kword_t block[SYS_RUN_V2_FIXED_WORDS + 5U + 3U];
        struct sys_run_v2 *req;
        unsigned int i;

        for (i = 0U; i < sizeof(block) / sizeof(block[0]); ++i)
                block[i] = 0UL;
        req = (struct sys_run_v2 *)block;
        req->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            sizeof(block) / sizeof(block[0]));
        req->flags = SYS_RUN_PGRP_INHERIT;
        req->fdmap_count = 3UL;
        req->argc = 0UL;
        req->envc = 0UL;
        for (i = 0U; i < 5U; ++i)
                block[SYS_RUN_V2_FIXED_WORDS + i] = large_path[i];
        block[SYS_RUN_V2_FIXED_WORDS + 5U] = SYS_RUN_FD_MAP(0U, 0U);
        block[SYS_RUN_V2_FIXED_WORDS + 6U] = SYS_RUN_FD_MAP(1U, 1U);
        block[SYS_RUN_V2_FIXED_WORDS + 7U] = SYS_RUN_FD_MAP(2U, 2U);
        return dsys_run(req);
}

static void
check_run_create_oom_v199(void)
{
        struct sys_meminfo before;
        struct sys_meminfo constrained;
        struct sys_meminfo after;
        struct sys_procinfo self_info;
        kword_t original_break;
        kword_t low;
        kword_t high;
        kword_t candidate;
        kword_t constrained_words;
        unsigned int i;
        unsigned int grew;
        unsigned int exhausted;
        int pid;

        if (dsys_meminfo(&before) != 0 ||
            dsys_procinfo(1U, &self_info) != 0)
                fail('a');
        original_break = dsys_brk(0UL);
        if (original_break == (kword_t)-1L ||
            original_break >= V199_VM_LIMIT)
                fail('b');

        /* Establish that the identical child/path really works before
         * memory pressure; a malformed DXR must not masquerade as ENOMEM. */
        pid = run_large_child_v199();
        if (pid <= 1 || wait_exit((unsigned int)pid) != 0)
                fail('w');

        /* Find the largest feasible 02000-aligned break via a bounded
         * search. Each unsuccessful request must preserve its previous VM. */
        low = original_break;
        high = V199_VM_LIMIT;
        grew = 0U;
        exhausted = 0U;
        for (i = 0U; i < 11U && high > low + V199_VM_QUANTUM; ++i) {
                candidate = ((low + high) / 2UL) & ~01777UL;
                if (candidate <= low)
                        break;
                if (dsys_brk(candidate) == candidate) {
                        low = candidate;
                        ++grew;
                } else {
                        ++exhausted;
                        high = candidate;
                        if (dsys_brk(0UL) != low)
                                fail('c');
                }
        }
        if (grew == 0U || exhausted == 0U ||
            low < 0600000UL ||
            vm_pressure[037777] != 01234567UL)
                fail('d');

        if (dsys_meminfo(&constrained) != 0 ||
            dsys_procinfo(1U, &self_info) != 0)
                fail('e');
        constrained_words = self_info.words;
        /* This is a strict physical impossibility, not just fragmentation:
         * caller extent + minimum child extent exceed all installed core. */
        if (constrained_words + 0100000UL <= before.total_words)
                fail('f');

        for (i = 0U; i < V199_FAILED_RUNS; ++i) {
                pid = run_large_child_v199();
                if (pid > 1) {
                        (void)wait_exit((unsigned int)pid);
                        fail('g');
                }
                if (pid != -1 || dsys_brk(0UL) != low ||
                    vm_pressure[037777] != 01234567UL)
                        fail('h');
                if (dsys_meminfo(&after) != 0 ||
                    after.process_slots_used != constrained.process_slots_used ||
                    after.process_words != constrained.process_words)
                        fail('i');
        }

        /* Free physical memory again and demonstrate that only the VM
         * allocation constraint caused the failed RUN requests. */
        if (dsys_brk(original_break) != original_break ||
            dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words)
                fail('j');
        pid = run_large_child_v199();
        if (pid <= 1)
                fail('k');
        if (wait_exit((unsigned int)pid) != 0)
                fail('v');
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words)
                fail('l');
        (void)dsys_writechar(1, 'V');
}

#endif
