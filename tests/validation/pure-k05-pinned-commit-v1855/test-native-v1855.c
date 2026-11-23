/* K05 v1855: original KCC FULL restore must never publish an APR whose
 * target has an unexpected second pin. The extra original MM pin is
 * acquired by the callback while the same two-extent transaction is
 * active, BEFORE final PI-disabled commit. No production test hook.
 *
 * Also exercise repeated allocator refusal, intact saved source and
 * eventual exact reconstruction after pressure is released.
 * ANSI C89 only; appended after the complete v1839 baseline fixture.
 */

static unsigned int refuse_alloc_v1855;
static unsigned int alloc_hits_v1855;
static unsigned int pin_kind_v1855;
static unsigned int pin_hits_v1855;
static unsigned int bystander_hits_v1855;
static unsigned int create_bystander_v1855;
#define BYSTANDER_BASE_V1855 0100000UL
#define BYSTANDER_WORDS_V1855 0200UL
#define BYSTANDER_OWNER_V1855 (SLOT + 1U)
/* Outside the real eight-bit pin field: no temporary APR is expected. */
#define NO_TARGET_V1855 0777U

int
mm_alloc_fault_v1855(kword_t words, kword_t align, unsigned int type,
    unsigned int owner, unsigned int pref, kword_t *basep)
{
        ++alloc_hits_v1855;
        if (refuse_alloc_v1855) {
                --refuse_alloc_v1855;
                return MM_ERR_NOMEM;
        }
        return mm_alloc_aligned_noreclaim(words, align, type, owner,
            pref, basep);
}

static int
inject_second_pin_v1855(kword_t backing, kword_t base, kword_t uarea,
    kword_t capacity)
{
        struct mm_extent *other;
        kword_t pinned;
        int rc;

        rc = accept_payload_v1395(backing, base, uarea, capacity);
        if (rc != 0)
                return rc;
        if (!pin_kind_v1855 && !create_bystander_v1855)
                return 0;
        if (pin_kind_v1855) {
                pinned = pin_kind_v1855 == 1U ? base : SOURCE + OMIT;
                rc = mm_pin(pinned);
                if (rc == MM_OK)
                        ++pin_hits_v1855;
                if (rc != MM_OK)
                        return rc;
        }
        if (!create_bystander_v1855)
                return 0;
        if (mm_extent_count != 2)
                return MM_ERR_INVAL;
        /* An independent live owner has its own permanent descriptor.
         * Its physical pin and ownership must never change due to the
         * transitional FULL owner's rejected commit or retry.
         */
        other = &mm_extents[mm_extent_count++];
        other->span = (BYSTANDER_WORDS_V1855 << 18U) |
            BYSTANDER_BASE_V1855;
        other->meta = ((kword_t)1UL << MM_PIN_SHIFT) |
            ((kword_t)MM_TYPE_PROCESS << MM_TYPE_SHIFT) |
            BYSTANDER_OWNER_V1855;
        ++bystander_hits_v1855;
        return 0;
}

static int
owner_state_v1855(unsigned int rawpins, unsigned int targetpins)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;

        if (mm_extent_count != (targetpins == NO_TARGET_V1855 ? 1 : 3) ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINS(&mm_extents[0]) != rawpins ||
            !PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
            proc_swap_records[SLOT].state != BACKING ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) != 0 ||
            !check_suffix_v1384())
                return 0;
        if (targetpins == NO_TARGET_V1855)
                return 1;
        return MM_EXTENT_BASE(&mm_extents[2]) == BYSTANDER_BASE_V1855 &&
            MM_EXTENT_WORDS(&mm_extents[2]) == BYSTANDER_WORDS_V1855 &&
            MM_EXTENT_TYPE(&mm_extents[2]) == MM_TYPE_PROCESS &&
            MM_EXTENT_OWNER(&mm_extents[2]) == BYSTANDER_OWNER_V1855 &&
            MM_EXTENT_PINS(&mm_extents[2]) == 1U &&
            MM_EXTENT_BASE(&mm_extents[1]) == RESTORE &&
            MM_EXTENT_WORDS(&mm_extents[1]) == WORDS &&
            MM_EXTENT_TYPE(&mm_extents[1]) == MM_TYPE_PROCESS &&
            MM_EXTENT_OWNER(&mm_extents[1]) == SLOT &&
            MM_EXTENT_PINS(&mm_extents[1]) == targetpins;
}

static int
allocator_refusal_v1855(void)
{
        struct proc *p = &process_slots[SLOT];
        unsigned int i;
        int rc;

        reset_prefix_v1384();
        fault_kind_v1395 = 0U;
        refuse_alloc_v1855 = 2U;
        alloc_hits_v1855 = 0U;
        pin_kind_v1855 = 0U;
        pin_hits_v1855 = 0U;
        bystander_hits_v1855 = 0U;
        create_bystander_v1855 = 0U;
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        for (i = 0U; i < 2U; ++i) {
                rc = proc_pure_ram_restore_v1391(SLOT,
                    inject_second_pin_v1855);
                if (rc != MM_ERR_NOMEM ||
                    alloc_hits_v1855 != i + 1U ||
                    !owner_state_v1855(0U, NO_TARGET_V1855) ||
                    pi_depth_v1381 ||
                    pi_disable_count_v1381 != pi_restore_count_v1381)
                        return 2;
        }
        rc = proc_pure_ram_restore_v1391(SLOT,
            inject_second_pin_v1855);
        if (rc != MM_OK || refuse_alloc_v1855 ||
            alloc_hits_v1855 != 3U || mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != RESTORE ||
            MM_EXTENT_WORDS(&mm_extents[0]) != WORDS ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_PINS(&mm_extents[0]) ||
            VM_PDP6_BASE(p) != RESTORE || PROC_TRANSITION(p) ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            !check_suffix_v1384() || pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 3;
        return 0;
}

static int
extra_pin_v1855(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        kword_t before_source, before_target;
        int rc;

        reset_prefix_v1384();
        fault_kind_v1395 = 0U;
        refuse_alloc_v1855 = 0U;
        alloc_hits_v1855 = 0U;
        pin_kind_v1855 = kind;
        pin_hits_v1855 = 0U;
        bystander_hits_v1855 = 0U;
        create_bystander_v1855 = 1U;
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        rc = proc_pure_ram_restore_v1391(SLOT,
            inject_second_pin_v1855);
        if (rc != MM_ERR_BUSY || pin_hits_v1855 != 1U ||
            bystander_hits_v1855 != 1U ||
            alloc_hits_v1855 != 1U ||
            !owner_state_v1855(kind == 2U ? 2U : 1U,
                              kind == 1U ? 2U : 1U) ||
            pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 2;
        before_source = mm_extents[0].meta;
        before_target = mm_extents[1].meta;
        /* Existing TRANSITION and two owners reject a fabricated retry.
         * The service must not turn these into a runnable APR.
         */
        pin_kind_v1855 = 0U;
        rc = proc_pure_ram_restore_v1391(SLOT,
            inject_second_pin_v1855);
        if (rc != MM_ERR_INVAL || bystander_hits_v1855 != 1U ||
            mm_extents[0].meta != before_source ||
            mm_extents[1].meta != before_target ||
            !owner_state_v1855(kind == 2U ? 2U : 1U,
                              kind == 1U ? 2U : 1U))
                return 3;
        return 0;
}

static int
bystander_success_v1855(void)
{
        struct proc *p = &process_slots[SLOT];
        struct mm_extent *other;
        int rc;

        reset_prefix_v1384();
        fault_kind_v1395 = 0U;
        refuse_alloc_v1855 = 0U;
        pin_kind_v1855 = 0U;
        pin_hits_v1855 = 0U;
        bystander_hits_v1855 = 0U;
        create_bystander_v1855 = 1U;
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        rc = proc_pure_ram_restore_v1391(SLOT,
            inject_second_pin_v1855);
        if (rc != MM_OK || !bystander_hits_v1855 ||
            pin_hits_v1855 || mm_extent_count != 2 ||
            VM_PDP6_BASE(p) != RESTORE || PROC_TRANSITION(p) ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            MM_EXTENT_BASE(&mm_extents[0]) != RESTORE ||
            MM_EXTENT_WORDS(&mm_extents[0]) != WORDS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_PINS(&mm_extents[0]) || !check_suffix_v1384() ||
            pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 2;
        other = &mm_extents[1];
        if (MM_EXTENT_BASE(other) != BYSTANDER_BASE_V1855 ||
            MM_EXTENT_WORDS(other) != BYSTANDER_WORDS_V1855 ||
            MM_EXTENT_OWNER(other) != BYSTANDER_OWNER_V1855 ||
            MM_EXTENT_TYPE(other) != MM_TYPE_PROCESS ||
            MM_EXTENT_PINS(other) != 1U)
                return 3;
        return 0;
}

int
main(void)
{
        int rc;

        rc = baseline_main_v1855();
        if (rc)
                return rc;
        rc = allocator_refusal_v1855();
        if (rc)
                return 01000 + rc;
        rc = bystander_success_v1855();
        if (rc)
                return 01400 + rc;
        rc = extra_pin_v1855(1U);
        if (rc)
                return 02000 + rc;
        rc = extra_pin_v1855(2U);
        if (rc)
                return 03000 + rc;
        return 0;
}
