/* v1684: C89 two actual RAW DROP owners during a source-locked FULL.
 * The original MM rebase, v1391 FULL and VFS mount/backing guards run.
 */
#define V1684_SECOND_SLOT (SLOT + 1U)
#define V1684_SECOND_SOURCE 070000UL
#define V1684_SECOND_UAREA 0140000UL
#define V1684_SECOND_BACKING (BACKING + \
    ((kword_t)1UL << PROC_SWAP_MOUNT_SHIFT) + 1UL)

static vnode_t roots_v1684[2];
static kword_t second_span_v1684;
static kword_t second_meta_v1684;
static unsigned int scanned_v1684;

static int
second_owner_v1684(void)
{
        int i;
        unsigned int seen = 0U;
        for (i = 0; i < mm_extent_count; ++i) {
                const struct mm_extent *e = &mm_extents[i];
                if (MM_EXTENT_OWNER(e) != V1684_SECOND_SLOT)
                        continue;
                ++seen;
                if (e->span != second_span_v1684 ||
                    e->meta != second_meta_v1684)
                        return 0;
        }
        if (seen != 1U)
            return 0;
        {
            const kword_t *suffix = (const kword_t *)(unsigned long)
                (V1684_SECOND_SOURCE + OMIT);
            unsigned int j;
            for (j = 0U; j < SUFFIX; ++j)
                if (suffix[j] != PATTERN + OMIT + j)
                    return 0;
        }
        return !VM_PDP6_BASE(&process_slots[V1684_SECOND_SLOT]) &&
            proc_storage_expect_v30(V1684_SECOND_SLOT,
                PROC_STORAGE_PACKED) == 0;
}

static int
loader_v1684(kword_t backing, kword_t base, kword_t stable,
    kword_t capacity)
{
        vnode_t first = VFS_NODE(5U, VFS_MOUNT_KIND(1U, 2U), 012345UL);
        vnode_t second = VFS_NODE(5U, VFS_MOUNT_KIND(2U, 2U), 012346UL);
        vnode_t other = VFS_NODE(5U, VFS_MOUNT_KIND(2U, 2U), 012347UL);
        struct proc *p = &process_slots[SLOT];
        kword_t span1, meta1, span2, meta2;
        int i;

        scanned_v1684 = 0100U;
        if (backing != BACKING || base != RESTORE || stable != UAREA ||
            capacity != WORDS || mm_extent_count != 3 ||
            !PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            !second_owner_v1684() ||
            proc_swap_mount_busy(1U) != 1 ||
            proc_swap_mount_busy(2U) != 1 ||
            proc_swap_mount_busy(3U) != 0 ||
            proc_swap_backing_busy(first) != 1 ||
            proc_swap_backing_busy(second) != 1 ||
            proc_swap_backing_busy(other) != 0)
                return -1;
        scanned_v1684 = 0200U;
        span1 = meta1 = span2 = meta2 = 0UL;
        for (i = 0; i < mm_extent_count; ++i) {
            const struct mm_extent *e = &mm_extents[i];
            if (MM_EXTENT_OWNER(e) != SLOT)
                continue;
            if (MM_EXTENT_TYPE(e) == MM_TYPE_PACKED_PROCESS) {
                if (span1)
                    return -1;
                span1 = e->span;
                meta1 = e->meta;
                if (!MM_EXTENT_PINNED(e))
                    return -1;
            } else if (MM_EXTENT_TYPE(e) == MM_TYPE_PROCESS) {
                if (span2)
                    return -1;
                span2 = e->span;
                meta2 = e->meta;
                if (!MM_EXTENT_PINNED(e))
                    return -1;
            } else
                return -1;
        }
        if (!span1 || !span2)
            return -1;
        /* This is the actual callback boundary: checking mount and
         * vnode owners must not disturb a live pinned FULL transaction. */
        if (proc_swap_mount_busy(1U) != 1 ||
            proc_swap_backing_busy(second) != 1 ||
            !second_owner_v1684())
                return -1;
        for (i = 0; i < mm_extent_count; ++i) {
            const struct mm_extent *e = &mm_extents[i];
            if (e->span == span1 && e->meta != meta1)
                return -1;
            if (e->span == span2 && e->meta != meta2)
                return -1;
        }
        scanned_v1684 = 1U;
        return accept_payload_v1395(backing, base, stable, capacity);
}

static int
case_source_multi_v1684(void)
{
        struct proc *second = &process_slots[V1684_SECOND_SLOT];
        struct proc *first = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1684_SECOND_UAREA;
        kword_t *data = (kword_t *)(unsigned long)V1684_SECOND_SOURCE;
        vnode_t *old_roots = vfs_mount_root_base;
        kword_t old_limit = vfs_mount_limit;
        vnode_t first_node = VFS_NODE(5U, VFS_MOUNT_KIND(1U, 2U), 012345UL);
        vnode_t second_node = VFS_NODE(5U, VFS_MOUNT_KIND(2U, 2U), 012346UL);
        unsigned int i;
        int index = -1;
        int rc = 1;

        fault_kind_v1395 = 0U;
        fault_kind_v1648 = 0U;
        reset_prefix_v1384();
        roots_v1684[0] = VFS_NODE(5U, VFS_MOUNT_KIND(1U, 2U), 0UL);
        roots_v1684[1] = VFS_NODE(5U, VFS_MOUNT_KIND(2U, 2U), 0UL);
        vfs_mount_root_base = roots_v1684;
        vfs_mount_limit = 2UL;
        do {
            if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                {
                    rc = 1;
                    goto cleanup_v1684;
                }
            for (i = 0U; i < WORDS; ++i)
                data[i] = i < OMIT ? TEXT_PATTERN : PATTERN + i;
            for (i = 0U; i < PROC_UAREA_WORDS; ++i)
                u[i] = 0UL;
            second->meta = (V1684_SECOND_UAREA << PROC_HALF_SHIFT) |
                ((kword_t)(PROC_F_UAREA | PROC_F_TRANSITION) <<
                 PROC_FLAGS_SHIFT);
            second->vm_state = (WORDS << PROC_HALF_SHIFT) |
                V1684_SECOND_SOURCE;
            second->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
            swap_slots[V1684_SECOND_SLOT].state = V1684_SECOND_BACKING;
            add_extent(V1684_SECOND_SOURCE, WORDS, MM_TYPE_PROCESS);
            mm_extents[mm_extent_count - 1].meta =
                (mm_extents[mm_extent_count - 1].meta & ~((kword_t)0777UL)) |
                V1684_SECOND_SLOT;
            if (proc_pure_ram_drop_v1381(V1684_SECOND_SLOT) != MM_OK)
                {
                    rc = 2;
                    goto cleanup_v1684;
                }
            for (i = 0U; i < (unsigned int)mm_extent_count; ++i)
                if (MM_EXTENT_OWNER(&mm_extents[i]) == V1684_SECOND_SLOT)
                    index = (int)i;
            if (index < 0)
                {
                    rc = 3;
                    goto cleanup_v1684;
                }
            second_span_v1684 = mm_extents[index].span;
            second_meta_v1684 = mm_extents[index].meta;
            if (!second_owner_v1684() || mm_extent_count != 2 ||
                !proc_swap_mount_busy(1U) || !proc_swap_mount_busy(2U) ||
                !proc_swap_backing_busy(first_node) ||
                !proc_swap_backing_busy(second_node))
                {
                    rc = 4;
                    goto cleanup_v1684;
                }
            PROC_SET_TRANSITION(first);
            scanned_v1684 = 0U;
            {
                int original = proc_pure_ram_restore_v1391(SLOT,
                    loader_v1684);
                if (original != MM_OK)
                    {
                        rc = 0100 + (int)scanned_v1684;
                        goto cleanup_v1684;
                    }
                if (scanned_v1684 != 1U)
                    {
                        rc = 0200;
                        goto cleanup_v1684;
                    }
                if (!second_owner_v1684())
                    {
                        rc = 0201;
                        goto cleanup_v1684;
                    }
                if (mm_extent_count != 2)
                    {
                        rc = 0202;
                        goto cleanup_v1684;
                    }
                /* Resident owners keep the executable source live
                 * because future pressure may make them PACKED again. */
                if (proc_swap_mount_busy(1U) != 1)
                    {
                        rc = 0203;
                        goto cleanup_v1684;
                    }
                if (proc_swap_backing_busy(first_node) != 1)
                    {
                        rc = 0204;
                        goto cleanup_v1684;
                    }
                if (proc_swap_mount_busy(2U) != 1)
                    {
                        rc = 0205;
                        goto cleanup_v1684;
                    }
                if (proc_swap_backing_busy(second_node) != 1)
                    {
                        rc = 0206;
                        goto cleanup_v1684;
                    }
            }
            /* A missing second executable provider must refuse FULL
             * before stealing or unpinning the retained source. */
            roots_v1684[1] = 0UL;
            PROC_SET_TRANSITION(second);
            if (proc_pure_ram_restore_v1391(V1684_SECOND_SLOT,
                    loader_v1684) != MM_ERR_INVAL ||
                !second_owner_v1684() ||
                mm_extent_count != 2 ||
                proc_swap_mount_busy(2U) != 1 ||
                !PROC_TRANSITION(second))
                {
                    rc = 6;
                    goto cleanup_v1684;
                }
            roots_v1684[1] = VFS_NODE(5U,
                VFS_MOUNT_KIND(2U, 2U), 0UL);
            if (!second_owner_v1684() ||
                proc_swap_backing_busy(second_node) != 1)
                {
                    rc = 7;
                    goto cleanup_v1684;
                }
            rc = 0;
        } while (0);
cleanup_v1684:
        vfs_mount_root_base = old_roots;
        vfs_mount_limit = old_limit;
        return rc;
}

int
main(void)
{
        int rc = 0;
#ifndef V1684_ONLY
        rc = baseline_main_v1684();
        if (rc != 0)
            return rc;
#endif
        rc = case_source_multi_v1684();
        if (rc != 0)
            return 04000 + rc;
        return 0;
}
