/* Test of actual KCC-compiled opt-in PURE slot-0 reconciliation.
 * The historical v1612 PDP6 service/MM fixture is concatenated above.
 * MM refuses and lost replies are explicitly controlled by this kit;
 * production owner matching and TRANSITION publication are unmodified.
 */
#define V1902_RECOVER (0400000UL | SLOT)
#define V1902_PC 0340000016664UL
#define V1902_FDCTL 04010UL

static void
v1902_prepare(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;

        reset_service_v1611();
        refuse_target_free_v1902 = 0;
        false_target_reply_v1902 = 0;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U))
                __test_exit = 071UL;
        PROC_SET_STATE(p, PROC_SRUN);
        PROC_SET_TRANSITION(p);
        add_extent(RESTORE, WORDS, MM_TYPE_PROCESS);
        u[PROC_FINALIZE_OFFSET] = PROC_SWAP_RETRY_TAG_V1507;
        u[020] = V1902_PC;
        u[PROC_FDCTL_OFFSET] = V1902_FDCTL;
        free_count_v1381 = 0U;
        pi_disable_count_v1381 = 0U;
        pi_restore_count_v1381 = 0U;
}

static int
v1902_retained(unsigned int source_pins, unsigned int target_pins)
{
        const struct proc *p = &process_slots[SLOT];
        const kword_t *u = (const kword_t *)(unsigned long)UAREA;

        return mm_extent_count == 2 &&
            MM_EXTENT_BASE(&mm_extents[0]) == SOURCE + OMIT &&
            MM_EXTENT_WORDS(&mm_extents[0]) == SUFFIX &&
            MM_EXTENT_OWNER(&mm_extents[0]) == SLOT &&
            MM_EXTENT_TYPE(&mm_extents[0]) == MM_TYPE_PACKED_PROCESS &&
            MM_EXTENT_PINS(&mm_extents[0]) == source_pins &&
            MM_EXTENT_BASE(&mm_extents[1]) == RESTORE &&
            MM_EXTENT_WORDS(&mm_extents[1]) == WORDS &&
            MM_EXTENT_OWNER(&mm_extents[1]) == SLOT &&
            MM_EXTENT_TYPE(&mm_extents[1]) == MM_TYPE_PROCESS &&
            MM_EXTENT_PINS(&mm_extents[1]) == target_pins &&
            PROC_TRANSITION(p) && !VM_PDP6_BASE(p) &&
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) == 0 &&
            swap_slots[SLOT].state == BACKING &&
            u[PROC_SWAP_BACKING_OFFSET] == BACKING &&
            u[020] == V1902_PC && u[PROC_FDCTL_OFFSET] == V1902_FDCTL &&
            u[PROC_FINALIZE_OFFSET] == PROC_SWAP_RETRY_TAG_V1507 &&
            pi_depth_v1381 == 0U &&
            pi_disable_count_v1381 == pi_restore_count_v1381 &&
            check_suffix_v1384();
}

static int
v1902_unlocked(void)
{
        const struct proc *p = &process_slots[SLOT];
        const kword_t *u = (const kword_t *)(unsigned long)UAREA;

        return mm_extent_count == 1 &&
            MM_EXTENT_BASE(&mm_extents[0]) == SOURCE + OMIT &&
            MM_EXTENT_WORDS(&mm_extents[0]) == SUFFIX &&
            MM_EXTENT_TYPE(&mm_extents[0]) == MM_TYPE_PACKED_PROCESS &&
            MM_EXTENT_OWNER(&mm_extents[0]) == SLOT &&
            !MM_EXTENT_PINNED(&mm_extents[0]) &&
            !PROC_TRANSITION(p) && !VM_PDP6_BASE(p) &&
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) == 0 &&
            swap_slots[SLOT].state == BACKING &&
            u[PROC_SWAP_BACKING_OFFSET] == BACKING &&
            u[020] == V1902_PC && u[PROC_FDCTL_OFFSET] == V1902_FDCTL &&
            u[PROC_FINALIZE_OFFSET] == 0UL &&
            pi_depth_v1381 == 0U &&
            pi_disable_count_v1381 == pi_restore_count_v1381 &&
            check_suffix_v1384();
}

static int
v1902_pin_then_release(void)
{
        int i;

        v1902_prepare();
        if (mm_pin(SOURCE + OMIT) != MM_OK ||
            !v1902_retained(1U, 0U))
                return 1;
        for (i = 0; i < 4; ++i)
                if (proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
                    !v1902_retained(1U, 0U) || free_count_v1381)
                        return 2;
        if (mm_unpin(SOURCE + OMIT) != MM_OK ||
            !v1902_retained(0U, 0U) ||
            proc_pure_mres_service_v1611(V1902_RECOVER) != 0 ||
            !v1902_unlocked() || free_count_v1381 != 1U)
                return 3;
        /* Retired scratch target cannot be double-freed by the
         * recovery command after TRANSITION has cleared. */
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
            !v1902_unlocked() || free_count_v1381 != 1U)
                return 4;
        return 0;
}

static int
v1902_pinned_target(void)
{
        v1902_prepare();
        if (mm_pin(RESTORE) != MM_OK ||
            proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
            !v1902_retained(0U, 1U) || free_count_v1381)
                return 5;
        if (mm_unpin(RESTORE) != MM_OK ||
            proc_pure_mres_service_v1611(V1902_RECOVER) != 0 ||
            !v1902_unlocked() || free_count_v1381 != 1U)
                return 6;
        return 0;
}

static int
v1902_actual_free_reply(void)
{
        v1902_prepare();
        refuse_target_free_v1902 = 1;
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
            !v1902_retained(0U, 0U) || free_count_v1381 != 1U)
                return 7;
        refuse_target_free_v1902 = 0;
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != 0 ||
            !v1902_unlocked() || free_count_v1381 != 2U)
                return 8;

        v1902_prepare();
        false_target_reply_v1902 = 1;
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != 0 ||
            !v1902_unlocked() || free_count_v1381 != 1U ||
            false_target_reply_v1902)
                return 9;
        return 0;
}

static int
v1902_invalid_owner(void)
{
        v1902_prepare();
        mm_extents[1].span += (kword_t)1UL << 18U;
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
            mm_extent_count != 2 || free_count_v1381 ||
            !PROC_TRANSITION(&process_slots[SLOT]))
                return 10;
        v1902_prepare();
        add_extent(0100000UL, WORDS, MM_TYPE_PROCESS);
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
            mm_extent_count != 3 || free_count_v1381 ||
            !PROC_TRANSITION(&process_slots[SLOT]))
                return 11;
        v1902_prepare();
        mm_extents[1].meta &= ~((kword_t)MM_OWNER_MASK);
        mm_extents[1].meta |= SLOT + 1U;
        /* An unrelated owner at a scratch-like address is NEVER
         * released; a sole correct PACKED source may be unlocked. */
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != 0 ||
            mm_extent_count != 2 ||
            MM_EXTENT_OWNER(&mm_extents[1]) != SLOT + 1U ||
            PROC_TRANSITION(&process_slots[SLOT]) ||
            free_count_v1381)
                return 12;
        v1902_prepare();
        mm_extent_capacity = 1U;
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
            mm_extent_count != 2 || free_count_v1381 ||
            !PROC_TRANSITION(&process_slots[SLOT]))
                return 13;
        mm_extent_capacity = MM_MAX_EXTENTS;
        v1902_prepare();
        ((kword_t *)(unsigned long)UAREA)[PROC_FINALIZE_OFFSET] |=
            PROC_FINALIZE_MARK;
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
            mm_extent_count != 2 || free_count_v1381 ||
            !PROC_TRANSITION(&process_slots[SLOT]))
                return 14;
        v1902_prepare();
        ((kword_t *)(unsigned long)UAREA)[PROC_SWAP_BACKING_OFFSET] ^= 1UL;
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
            mm_extent_count != 2 || free_count_v1381 ||
            !PROC_TRANSITION(&process_slots[SLOT]))
                return 15;
        v1902_prepare();
        ((kword_t *)(unsigned long)UAREA)[PROC_FINALIZE_OFFSET] = 0UL;
        if (proc_pure_mres_service_v1611(V1902_RECOVER) != -1 ||
            mm_extent_count != 2 || free_count_v1381 ||
            !PROC_TRANSITION(&process_slots[SLOT]))
                return 16;
        return 0;
}

int
main(void)
{
        int rc;

        rc = v1902_pin_then_release();
        if (rc)
                return 01000 + rc;
        rc = v1902_pinned_target();
        if (rc)
                return 01100 + rc;
        rc = v1902_actual_free_reply();
        if (rc)
                return 01200 + rc;
        rc = v1902_invalid_owner();
        if (rc)
                return 01300 + rc;
        return 0;
}
