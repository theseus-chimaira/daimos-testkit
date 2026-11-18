/* v1666 source-linked original PDP-6 disk terminal + common KCORE
 * proc_swap_detach. The runner prepends the original v1609 process,
 * actual MM/free/storage fixture with its main renamed. No C copy of
 * the disk MRES implementation is used. This tests the real terminal
 * leaf extracted from proc_swap_pdp6.s.
 */

static void
prepare_disk_v1666(void)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;

        prepare_v1609();
        mm_extent_count = 0;
        modes_v1609[0] = (kword_t)PROC_STORAGE_DISK << (2U * V1609_SLOT);
        records_v1609[V1609_SLOT].state = (0500UL << 18U) | 4UL;
        u[PROC_SWAP_BACKING_OFFSET] = V1609_BACKING;
        proc_swap_blocks_used = 4UL;
        disk_accept_v1666 = 1;
        p->vm_state = V1609_WORDS << PROC_HALF_SHIFT;
}

static int
disk_case_v1666(unsigned int kind)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;
        kword_t before_record, before_u, before_cred, before_mode;
        int result, accepted;

        prepare_disk_v1666();
        switch (kind) {
        case 1U: disk_accept_v1666 = 0; break;
        case 2U: proc_swap_blocks_used = 3UL; break;
        case 3U: records_v1609[V1609_SLOT].state &= ~0777777UL;
                 break;
        case 4U: records_v1609[V1609_SLOT].state = 0UL; break;
        case 5U: modes_v1609[0] =
                     (kword_t)PROC_STORAGE_PACKED << (2U * V1609_SLOT);
                 break;
        case 6U: modes_v1609[0] =
                     (kword_t)3UL <<
                     (2U * V1609_SLOT); break;
        case 7U: p->vm_state |= V1609_BASE; break;
        case 8U: modes_v1609[0] = 0UL; break;
        case 9U: modes_v1609[0] = 0UL;
                 p->vm_state |= V1609_BASE; break;
        case 10U: p->sched =
                      (kword_t)PROC_SIDL << PROC_STATE_SHIFT;
                  p->sched |= PROC_SWAP_STAGE_MOUNT_EXT_BIT;
                  break;
        case 11U: u[PROC_CRED_OFFSET] &= ~PROC_SWAP_MOUNT_EXT_BIT;
                  break;
        default: break;
        }
        before_record = records_v1609[V1609_SLOT].state;
        before_u = u[PROC_SWAP_BACKING_OFFSET];
        before_cred = u[PROC_CRED_OFFSET];
        before_mode = modes_v1609[0];
        result = proc_swap_detach((int)V1609_SLOT);
        accepted = kind == 0U || kind == 8U || kind == 9U ||
            kind == 10U || kind == 11U;
        if ((result == 0) != accepted || failed_invariant_v1609)
                return 1;
        if (accepted) {
                if (records_v1609[V1609_SLOT].state ||
                    u[PROC_SWAP_BACKING_OFFSET] ||
                    (u[PROC_CRED_OFFSET] & PROC_SWAP_MOUNT_EXT_BIT) ||
                    modes_v1609[0] != 0UL)
                        return 2;
                if (kind != 8U && kind != 9U &&
                    proc_swap_blocks_used != 0UL)
                        return 3;
                if ((kind == 8U || kind == 9U) &&
                    (disk_free_count_v1609 != 0 ||
                     proc_swap_blocks_used != 4UL))
                        return 4;
                if (kind == 10U &&
                    (p->sched & PROC_SWAP_STAGE_MOUNT_EXT_BIT))
                        return 5;
                if (proc_swap_detach((int)V1609_SLOT) != 0 ||
                    (kind == 8U || kind == 9U ?
                     disk_free_count_v1609 != 0 :
                     disk_free_count_v1609 != 1))
                        return 6;
        } else {
                if (records_v1609[V1609_SLOT].state != before_record ||
                    u[PROC_SWAP_BACKING_OFFSET] != before_u ||
                    u[PROC_CRED_OFFSET] != before_cred ||
                    modes_v1609[0] != before_mode ||
                    proc_swap_blocks_used != (kind == 2U ? 3UL : 4UL) ||
                    (kind >= 5U && disk_free_count_v1609 != 0))
                        return 7;
        }
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;

#if defined(DAIMOS_TEST_NO_BACKEND_V1666)
        /* The ACTUAL default JRST kret_neg1 must prevent release of
         * disk mode1 without an installed backing service. Valid
         * mode0 still permits the common metadata detach.
         */
        prepare_disk_v1666();
        if (proc_swap_detach((int)V1609_SLOT) == 0 ||
            records_v1609[V1609_SLOT].state !=
                ((0500UL << 18U) | 4UL) ||
            proc_swap_blocks_used != 4UL ||
            disk_free_count_v1609)
                return 04001;
        modes_v1609[0] = 0UL;
        if (proc_swap_detach((int)V1609_SLOT) != 0 ||
            records_v1609[V1609_SLOT].state ||
            proc_swap_blocks_used != 4UL || disk_free_count_v1609)
                return 04002;
        return 0;
#else
        for (kind = 0U; kind <= 11U; ++kind) {
                rc = disk_case_v1666(kind);
                if (rc)
                        return (int)(03000U + 16U * kind +
                            (unsigned int)rc);
        }
        return 0;
#endif
}
