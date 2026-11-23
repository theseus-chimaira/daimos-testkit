/* v1900: real PDP-6 RAW PURE terminal must reclaim exact rollback
 * source+target without losing another owner or an ambiguous MM reply.
 * Original terminal ASM, VM-destroy ASM, KCORE detach C are linked;
 * only the allocator's response is a test fixture.
 */
#define V1900_TARGET 060000UL
#define V1900_PEER 070000UL
#define V1900_PEER_SLOT (V1609_SLOT + 1U)

static int
v1900_peer_ok(void)
{
        int i;
        int found = 0;
        for (i = 0; i < mm_extent_count; ++i) {
                const struct mm_extent *e = &mm_extents[i];
                if (MM_EXTENT_OWNER(e) != V1900_PEER_SLOT)
                        continue;
                if (++found != 1 ||
                    MM_EXTENT_TYPE(e) != MM_TYPE_PACKED_PROCESS ||
                    MM_EXTENT_BASE(e) != V1900_PEER ||
                    MM_EXTENT_WORDS(e) != V1609_RAW ||
                    MM_EXTENT_PINS(e))
                        return 0;
        }
        return found == 1;
}

static int
v1900_owner(unsigned int type, kword_t base, kword_t words,
    unsigned int pins)
{
        int i;
        int found = 0;
        for (i = 0; i < mm_extent_count; ++i) {
                const struct mm_extent *e = &mm_extents[i];
                if (MM_EXTENT_OWNER(e) != V1609_SLOT)
                        continue;
                if (MM_EXTENT_TYPE(e) != type ||
                    MM_EXTENT_BASE(e) != base ||
                    MM_EXTENT_WORDS(e) != words ||
                    MM_EXTENT_PINS(e) != pins)
                        continue;
                ++found;
        }
        return found == 1;
}

static void
v1900_prepare(void)
{
        false_reply_v1900 = 0;
        refuse_type_v1900 = 0;
        prepare_v1609();
        add_extent_v1609(V1900_TARGET, V1609_WORDS,
            MM_TYPE_PROCESS, V1609_SLOT, 0U);
        add_extent_v1609(V1900_PEER, V1609_RAW,
            MM_TYPE_PACKED_PROCESS, V1900_PEER_SLOT, 0U);
}

static int
v1900_retired(void)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;
        return mm_extent_count == 1 && v1900_peer_ok() &&
            p->vm_state == ~(kword_t)0 &&
            proc_storage_expect_v30(V1609_SLOT,
                PROC_STORAGE_RESIDENT) == 0 &&
            records_v1609[V1609_SLOT].state == 0UL &&
            u[PROC_SWAP_BACKING_OFFSET] == 0UL &&
            !(u[PROC_CRED_OFFSET] & PROC_SWAP_MOUNT_EXT_BIT) &&
            !disk_free_count_v1609 && !failed_invariant_v1609;
}

static int
v1900_double_owner_release(void)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        int rc;

        v1900_prepare();
        rc = vm_space_destroy(p, (int)V1609_SLOT);
        if (rc || free_count_v1609 != 2 || !v1900_retired())
                return 1;
        if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
            free_count_v1609 != 2 || !v1900_retired())
                return 2;
        return 0;
}

static int
v1900_pinned_refusal(unsigned int source_pin)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        int result;
        int tries;

        v1900_prepare();
        if (source_pin)
                mm_extents[0].meta |= (kword_t)1UL << MM_PIN_SHIFT;
        else
                mm_extents[1].meta |= (kword_t)1UL << MM_PIN_SHIFT;
        for (tries = 0; tries < 3; ++tries) {
                result = vm_space_destroy(p, (int)V1609_SLOT);
                if (result == 0 || mm_extent_count != 3 ||
                    free_count_v1609 || !v1900_peer_ok() ||
                    !v1900_owner(MM_TYPE_PACKED_PROCESS, V1609_BASE,
                        V1609_RAW, source_pin ? 1U : 0U) ||
                    !v1900_owner(MM_TYPE_PROCESS, V1900_TARGET,
                        V1609_WORDS, source_pin ? 0U : 1U) ||
                    !unchanged_v1609())
                        return 3;
        }
        if (source_pin)
                mm_extents[0].meta &= ~((kword_t)1UL << MM_PIN_SHIFT);
        else
                mm_extents[1].meta &= ~((kword_t)1UL << MM_PIN_SHIFT);
        if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
            free_count_v1609 != 2 || !v1900_retired())
                return 4;
        return 0;
}

static int
v1900_foreign_and_invalid(void)
{
        struct proc *p = &process_v1609[V1609_SLOT];

        v1900_prepare();
        mm_extents[1].span += (kword_t)1UL << 18U;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            free_count_v1609 || mm_extent_count != 3 ||
            !v1900_peer_ok() || !unchanged_v1609())
                return 5;

        v1900_prepare();
        add_extent_v1609(0100000UL, V1609_WORDS,
            MM_TYPE_PROCESS, V1609_SLOT, 0U);
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            free_count_v1609 || mm_extent_count != 4 ||
            !v1900_peer_ok() || !unchanged_v1609())
                return 6;

        v1900_prepare();
        mm_extents[1].meta &= ~((kword_t)MM_OWNER_MASK);
        mm_extents[1].meta |= V1900_PEER_SLOT;
        /* Foreign owner at the historical scratch address must NOT
         * be treated as this slot's temporary PROCESS. Terminal may
         * release its own sole RAW source and leave foreign intact.
         */
        if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
            free_count_v1609 != 1 || mm_extent_count != 2 ||
            v1900_owner(MM_TYPE_PACKED_PROCESS, V1609_BASE,
                V1609_RAW, 0U) ||
            MM_EXTENT_OWNER(&mm_extents[0]) != V1900_PEER_SLOT ||
            MM_EXTENT_BASE(&mm_extents[0]) != V1900_TARGET ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[1]) != V1900_PEER_SLOT ||
            MM_EXTENT_BASE(&mm_extents[1]) != V1900_PEER ||
            proc_storage_expect_v30(V1609_SLOT,
                PROC_STORAGE_RESIDENT) != 0)
                return 7;

        v1900_prepare();
        mm_extents[1].meta &= ~((kword_t)MM_TYPE_MASK << MM_TYPE_SHIFT);
        mm_extents[1].meta |= (kword_t)5UL << MM_TYPE_SHIFT;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            free_count_v1609 || mm_extent_count != 3 ||
            !v1900_peer_ok() || !unchanged_v1609())
                return 8;

        v1900_prepare();
        mm_extent_count = MM_MAX_EXTENTS + 1;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            free_count_v1609)
                return 9;
        mm_extent_count = 3;

        v1900_prepare();
        mm_extent_capacity = 2;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            free_count_v1609 || mm_extent_count != 3 ||
            !unchanged_v1609())
                return 14;
        mm_extent_capacity = MM_MAX_EXTENTS;
        return 0;
}

static int
v1900_real_free_refusal(unsigned int type)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        int rc;

        v1900_prepare();
        refuse_type_v1900 = (int)type;
        rc = vm_space_destroy(p, (int)V1609_SLOT);
        if (type == MM_TYPE_PROCESS) {
                if (rc == 0 || mm_extent_count != 3 ||
                    free_count_v1609 != 1 || !v1900_peer_ok() ||
                    !v1900_owner(MM_TYPE_PACKED_PROCESS, V1609_BASE,
                        V1609_RAW, 0U) ||
                    !v1900_owner(MM_TYPE_PROCESS, V1900_TARGET,
                        V1609_WORDS, 0U) || !unchanged_v1609())
                        return 10;
                refuse_type_v1900 = 0;
                if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
                    free_count_v1609 != 3 || !v1900_retired())
                        return 11;
        } else {
                /* Target may be committed even though final RAW free
                 * refuses; the sole RAW owner remains retryable.
                 */
                if (rc == 0 || mm_extent_count != 2 ||
                    free_count_v1609 != 2 || !v1900_peer_ok() ||
                    !v1900_owner(MM_TYPE_PACKED_PROCESS, V1609_BASE,
                        V1609_RAW, 0U) || !unchanged_v1609())
                        return 12;
                refuse_type_v1900 = 0;
                if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
                    free_count_v1609 != 3 || !v1900_retired())
                        return 13;
        }
        return 0;
}

static int
v1900_lost_reply(unsigned int type)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        int rc;

        v1900_prepare();
        false_reply_v1900 = (int)type;
        rc = vm_space_destroy(p, (int)V1609_SLOT);
        if (type == MM_TYPE_PROCESS) {
                /* Target is really GONE, RAW still exact/authoritative.
                 * The next PREVM retry may release only the RAW owner.
                 */
                if (rc == 0 || mm_extent_count != 2 ||
                    free_count_v1609 != 1 || !v1900_peer_ok() ||
                    !v1900_owner(MM_TYPE_PACKED_PROCESS, V1609_BASE,
                        V1609_RAW, 0U) || !unchanged_v1609())
                        return 8;
                if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
                    free_count_v1609 != 2 || !v1900_retired())
                        return 9;
        } else {
                /* Both original frees physically COMMITTED, but the
                 * final RAW reply was lost. MM evidence is sufficient
                 * only while original PI exclusion is still held.
                 */
                if (rc != 0 || free_count_v1609 != 2 ||
                    !v1900_retired())
                        return 10;
        }
        return 0;
}

int
main(void)
{
        int rc;

        /* Native single-owner acceptance from v1609/v1680 must
         * remain unchanged and is run by the parent runner. */
        rc = v1900_double_owner_release();
        if (rc)
                return 01000 + rc;
        rc = v1900_pinned_refusal(1U);
        if (rc)
                return 01100 + rc;
        rc = v1900_pinned_refusal(0U);
        if (rc)
                return 01200 + rc;
        rc = v1900_foreign_and_invalid();
        if (rc)
                return 01300 + rc;
        rc = v1900_lost_reply(MM_TYPE_PROCESS);
        if (rc)
                return 01400 + rc;
        rc = v1900_lost_reply(MM_TYPE_PACKED_PROCESS);
        if (rc)
                return 01500 + rc;
        rc = v1900_real_free_refusal(MM_TYPE_PROCESS);
        if (rc)
                return 01600 + rc;
        rc = v1900_real_free_refusal(MM_TYPE_PACKED_PROCESS);
        if (rc)
                return 01700 + rc;
        return 0;
}
