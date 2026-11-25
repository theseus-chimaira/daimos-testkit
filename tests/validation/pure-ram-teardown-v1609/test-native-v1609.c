/*
 * v1609: native PDP-6 terminal RAW PACKED cleanup.
 *
 * Compile the actual vm_pdp6_swap.c (proc_swap_detach), actual
 * vm_pdp6.s vm_space_destroy leaf, actual packed detach ASM and
 * storage mode machine code. Only MM/backstore/provider behavior
 * is controlled by the test fixture.
 */
#include "proc.h"
#include "proc_swap.h"
#include "proc_storage_map_v28.h"
#include "vm_pdp6.h"
#include "vm.h"
#include "mm.h"
#include "vfs.h"

#define V1609_SLOT 1U
#define V1609_SLOTS 8U
#define V1609_UAREA 040000UL
#define V1609_BASE 050400UL
#define V1609_WORDS 02000UL
#define V1609_TEXT 0500UL
#define V1609_PREFIX 0400UL
#define V1609_RAW (V1609_WORDS - V1609_PREFIX)
#define V1609_BACKING \
    ((V1609_TEXT << PROC_SWAP_TEXT_SHIFT) | 012345UL)

kword_t __test_exit;
static struct proc process_v1609[V1609_SLOTS];
static struct proc_swap_record records_v1609[V1609_SLOTS];
static kword_t modes_v1609[PROC_STORAGE_MAP_WORDS_V28(V1609_SLOTS)];
struct proc *proc_table = process_v1609;
struct mm_extent mm_extents[MM_MAX_EXTENTS];
int mm_extent_count;
unsigned int mm_extent_capacity = MM_MAX_EXTENTS;
kword_t mm_core_words = 0100000UL;
kword_t mm_arenas[MM_MAX_ARENAS] = { (040000UL << 18U) | 040000UL };
int mm_arena_count = 1;
static int free_count_v1609;
static int refuse_free_v1609;
static int disk_free_count_v1609;
/* v1666 source-linked disk MRES tests may accept exact verified disk
 * release; the historical RAW tests still refuse disk by default.
 */
static int disk_accept_v1666;
static int failed_invariant_v1609;
kword_t *backstore_bitmap;
kword_t backstore_blocks;
kword_t backstore_blocks_used;
unsigned int backstore_enabled;
vnode_t *vfs_mount_root_base;
kword_t vfs_mount_limit;

extern int proc_storage_expect_v30(unsigned int, unsigned int);
extern int proc_storage_publish_v30(unsigned int, unsigned int,
    unsigned int);

int
fs_provider_reg_call(void)
{
        return 0;
}

int
vfs_dtfs_owner_admit_v1562(vnode_t node)
{
        (void)node;
        return -1;
}

int
backstore_free(kword_t first, kword_t blocks)
{
        ++disk_free_count_v1609;
        if (disk_accept_v1666 && first == 0500UL && blocks == 4UL)
                return 0;
        return -1;
}

void
proc_swap_storage_invariant_v30(void)
{
        ++failed_invariant_v1609;
        __test_exit = 077UL;
}

int
mm_free(kword_t base, unsigned int type, unsigned int owner)
{
        int i;
        ++free_count_v1609;
        if (refuse_free_v1609)
                return MM_ERR_BUSY;
        for (i = 0; i < mm_extent_count; ++i) {
                if (MM_EXTENT_BASE(&mm_extents[i]) != base)
                        continue;
                if (type != MM_TYPE_PACKED_PROCESS ||
                    owner != V1609_SLOT ||
                    MM_EXTENT_TYPE(&mm_extents[i]) != type ||
                    MM_EXTENT_OWNER(&mm_extents[i]) != owner ||
                    MM_EXTENT_PINNED(&mm_extents[i]))
                        return MM_ERR_INVAL;
                for (; i + 1 < mm_extent_count; ++i)
                        mm_extents[i] = mm_extents[i + 1];
                --mm_extent_count;
                return MM_OK;
        }
        return MM_ERR_INVAL;
}

static void
add_extent_v1609(kword_t base, kword_t words, unsigned int type,
    unsigned int owner, unsigned int pins)
{
        struct mm_extent *e = &mm_extents[mm_extent_count++];
        e->span = (words << 18U) | base;
        e->meta = ((kword_t)type << MM_TYPE_SHIFT) |
            ((kword_t)pins << MM_PIN_SHIFT) | owner;
}

static void
prepare_v1609(void)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;
        unsigned int i;

        for (i = 0U; i < PROC_UAREA_WORDS; ++i)
                u[i] = 0UL;
        for (i = 0U; i < V1609_SLOTS; ++i) {
                process_v1609[i].meta = 0UL;
                process_v1609[i].vm_state = 0UL;
                process_v1609[i].sched = 0UL;
                records_v1609[i].state = 0UL;
        }
        for (i = 0U; i < PROC_STORAGE_MAP_WORDS_V28(V1609_SLOTS); ++i)
                modes_v1609[i] = 0UL;
        proc_swap_records = records_v1609;
        proc_storage_runtime_v29.words = modes_v1609;
        proc_storage_runtime_v29.slots = V1609_SLOTS;
        p->meta = (V1609_UAREA << PROC_HALF_SHIFT) |
            ((kword_t)(PROC_F_UAREA | PROC_F_TRANSITION) <<
                PROC_FLAGS_SHIFT);
        p->vm_state = V1609_WORDS << PROC_HALF_SHIFT;
        p->sched = (kword_t)PROC_ZOMB << PROC_STATE_SHIFT;
        records_v1609[V1609_SLOT].state = V1609_BACKING;
        u[PROC_SWAP_BACKING_OFFSET] = V1609_BACKING;
        u[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        mm_extent_count = 0;
        mm_extent_capacity = MM_MAX_EXTENTS;
        mm_core_words = 0100000UL;
        mm_arena_count = 1;
        mm_arenas[0] = (040000UL << 18U) | 040000UL;
        add_extent_v1609(V1609_BASE, V1609_RAW,
            MM_TYPE_PACKED_PROCESS, V1609_SLOT, 0U);
        free_count_v1609 = 0;
        disk_free_count_v1609 = 0;
        disk_accept_v1666 = 0;
        refuse_free_v1609 = 0;
        failed_invariant_v1609 = 0;
        /* VFS is intentionally absent: terminal release may not wait
         * for a vanished immutable source or a backing device. */
        vfs_mount_root_base = (vnode_t *)0;
        vfs_mount_limit = 0UL;
        backstore_bitmap = (kword_t *)0;
        backstore_blocks = 0UL;
        backstore_blocks_used = 0UL;
        backstore_enabled = 0U;
        proc_swap_blocks_used = 0UL;
        if (proc_storage_publish_v30(V1609_SLOT,
            PROC_STORAGE_RESIDENT, PROC_STORAGE_PACKED) != 0)
                __test_exit = 076UL;
}

static int
unchanged_v1609(void)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;
        return p->vm_state == (V1609_WORDS << PROC_HALF_SHIFT) &&
            mm_extent_count >= 1 &&
            MM_EXTENT_TYPE(&mm_extents[0]) == MM_TYPE_PACKED_PROCESS &&
            MM_EXTENT_BASE(&mm_extents[0]) == V1609_BASE &&
            records_v1609[V1609_SLOT].state == V1609_BACKING &&
            u[PROC_SWAP_BACKING_OFFSET] == V1609_BACKING &&
            proc_storage_expect_v30(V1609_SLOT,
                PROC_STORAGE_PACKED) == 0 &&
            PROC_TRANSITION(p) &&
            disk_free_count_v1609 == 0 && !failed_invariant_v1609;
}

static int
negative_v1609(void)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;
        int rc;

        prepare_v1609();
        p->meta &= ~((kword_t)PROC_F_TRANSITION << PROC_FLAGS_SHIFT);
        rc = vm_space_destroy(p, (int)V1609_SLOT);
        if (rc == 0 || mm_extent_count != 1 || free_count_v1609)
                return 1;

        prepare_v1609();
        u[PROC_SWAP_BACKING_OFFSET] = V1609_BACKING + 1UL;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            mm_extent_count != 1 || free_count_v1609)
                return 2;

        prepare_v1609();
        mm_extents[0].span = ((V1609_RAW + 1UL) << 18U) | V1609_BASE;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            mm_extent_count != 1 || free_count_v1609)
                return 3;

        prepare_v1609();
        mm_extents[0].meta |= (kword_t)1UL << MM_PIN_SHIFT;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            mm_extent_count != 1 || free_count_v1609)
                return 4;

        prepare_v1609();
        mm_extents[0].meta &= ~((kword_t)MM_TYPE_MASK << MM_TYPE_SHIFT);
        mm_extents[0].meta |=
            (kword_t)MM_TYPE_PROCESS << MM_TYPE_SHIFT;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            mm_extent_count != 1 || free_count_v1609)
                return 5;

        prepare_v1609();
        add_extent_v1609(V1609_BASE + 02000UL, V1609_RAW,
            MM_TYPE_PACKED_PROCESS, V1609_SLOT, 0U);
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            mm_extent_count != 2 || free_count_v1609)
                return 6;

        prepare_v1609();
        refuse_free_v1609 = 1;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            !unchanged_v1609() || free_count_v1609 != 1)
                return 7;

        prepare_v1609();
        records_v1609[V1609_SLOT].state = 0UL;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            mm_extent_count != 1 || free_count_v1609)
                return 8;

        prepare_v1609();
        p->vm_state |= 050000UL;
        if (vm_space_destroy(p, (int)V1609_SLOT) == 0 ||
            mm_extent_count != 1 || free_count_v1609)
                return 9;

        prepare_v1609();
        /* A still-resident VM image cannot have PACKED mode, even
         * if its backing record and MM slot are superficially valid. */
        p->vm_state |= V1609_BASE;
        if (proc_swap_detach((int)V1609_SLOT) == 0 ||
            mm_extent_count != 1 || free_count_v1609)
                return 10;
        return 0;
}

int
main(void)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;
        int rc = negative_v1609();

        if (rc)
                return 0100 + rc;
        prepare_v1609();
        if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
            p->vm_state != ~(kword_t)0 || mm_extent_count ||
            records_v1609[V1609_SLOT].state ||
            u[PROC_SWAP_BACKING_OFFSET] ||
            (u[PROC_CRED_OFFSET] & PROC_SWAP_MOUNT_EXT_BIT) ||
            proc_storage_expect_v30(V1609_SLOT,
                PROC_STORAGE_RESIDENT) != 0 ||
            free_count_v1609 != 1 || disk_free_count_v1609 ||
            failed_invariant_v1609)
                return 0200;
        if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
            free_count_v1609 != 1 || disk_free_count_v1609 ||
            failed_invariant_v1609)
                return 0201;
        return 0;
}
