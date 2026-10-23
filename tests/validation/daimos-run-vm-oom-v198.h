/*
 * v198: a genuine physical-MM allocation failure via VM break growth.
 * On a 256K PDP-6, 0776000 words would leave less than one APR quantum
 * for the kernel, resident metadata, and three live child processes.
 * Unlike an invalid 36-bit address, this is a valid 18-bit break request.
 *
 * An attempted reclaim may evict a sleeping child, so the resident process
 * word count may decrease. The caller's break, logical VM size and data
 * must remain unchanged after each rejected allocation.
 */
#ifndef DAIMOS_RUN_VM_OOM_V198_H
#define DAIMOS_RUN_VM_OOM_V198_H

#define V198_OOM_REQUEST   0776000UL
#define V198_OOM_ATTEMPTS  4U

static void
check_vm_oom_v198(const struct sys_meminfo *occupied)
{
        struct sys_meminfo info;
        struct sys_procinfo current_proc;
        kword_t saved_break;
        kword_t original_words;
        unsigned int i;

        if (dsys_meminfo(&info) != 0 ||
            info.total_words <= V198_OOM_REQUEST)
                fail('m');
        if (dsys_procinfo(1U, &current_proc) != 0)
                fail('n');
        original_words = current_proc.words;
        saved_break = dsys_brk(0UL);
        if (saved_break == (kword_t)-1L ||
            saved_break >= V198_OOM_REQUEST)
                fail('o');

        for (i = 0U; i < V198_OOM_ATTEMPTS; ++i) {
                if (dsys_brk(V198_OOM_REQUEST) != (kword_t)-1L)
                        fail('p');
                if (dsys_brk(0UL) != saved_break ||
                    vm_pressure[037777] != 01234567UL)
                        fail('q');
                if (dsys_procinfo(1U, &current_proc) != 0 ||
                    current_proc.words != original_words)
                        fail('r');
                if (dsys_meminfo(&info) != 0 ||
                    info.process_slots_used != occupied->process_slots_used ||
                    info.process_words > occupied->process_words)
                        fail('s');
        }
        (void)dsys_writechar(1, 'M');
}

#endif
