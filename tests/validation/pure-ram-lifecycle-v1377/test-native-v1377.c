/*
 * Real PDP-6 execution of the staged, compiled PURE-only RAM transaction.
 * MM/provider/scheduler integration is intentionally mocked; the process
 * owner, layout, restore order and physical word copies are real target C.
 */
#include "proc_pure_ram_v1377.h"
#include "proc_swap.h"
#include "proc_packed_owner_v37.h"
#include "vm_pdp6.h"
#include "mm_internal.h"

#define SLOT 1U
#define SLOTS PROC_MIN_SLOTS
#define UAREA 040000UL
#define SOURCE 050000UL
#define RESTORE 060000UL
#define PACKED 070000UL
#define WORDS 02000UL
#define TEXT 0500UL
#define OMIT 0400UL
#define SUFFIX (WORDS - OMIT)
#define BACKING ((TEXT << PROC_SWAP_TEXT_SHIFT) | 012345UL)
#define PATTERN 071234567UL
#define TEXT_PATTERN 054321UL

kword_t __test_exit;
static struct proc process_slots[SLOTS];
static struct proc_swap_record swap_slots[SLOTS];
static kword_t mode_words[PROC_STORAGE_MAP_WORDS_V28(SLOTS)];
static kword_t layout_words[SLOTS];

struct proc *proc_table = process_slots;
unsigned int proc_slots = SLOTS;
struct proc_swap_record *proc_swap_records = swap_slots;
struct proc_storage_map_v28 proc_storage_runtime_v29;
struct proc_packed_layout_v36 proc_packed_runtime_v38;
struct mm_extent mm_extents[MM_MAX_EXTENTS];
int mm_extent_count;
kword_t backstore_blocks;
unsigned int backstore_enabled;
static int refuse_restore_alloc;

static int
find_extent(kword_t base)
{
        int i;
        for (i = 0; i < mm_extent_count; ++i)
                if (MM_EXTENT_BASE(&mm_extents[i]) == base)
                        return i;
        return -1;
}

static void
add_extent(kword_t base, kword_t words, unsigned int type)
{
        struct mm_extent *e = &mm_extents[mm_extent_count++];
        e->span = (words << 18U) | base;
        e->meta = ((kword_t)type << MM_TYPE_SHIFT) | SLOT;
}

int
mm_alloc_aligned_noreclaim(kword_t words, kword_t align,
    unsigned int type, unsigned int owner, unsigned int preference,
    kword_t *basep)
{
        kword_t base;
        if (owner != SLOT || preference != MM_ALLOC_HIGH || !basep)
                return MM_ERR_INVAL;
        if (type == MM_TYPE_PACKED_PROCESS && words == SUFFIX)
                base = PACKED;
        else if (type == MM_TYPE_PROCESS && words == WORDS) {
                if (refuse_restore_alloc)
                        return MM_ERR_NOMEM;
                base = RESTORE;
        } else
                return MM_ERR_NOMEM;
        if (find_extent(base) >= 0 || (base & (align - 1UL)) != 0UL)
                return MM_ERR_NOMEM;
        add_extent(base, words, type);
        *basep = base;
        return MM_OK;
}

int
mm_pin(kword_t base)
{
        int i = find_extent(base);
        if (i < 0)
                return MM_ERR_INVAL;
        mm_extents[i].meta += (kword_t)1UL << MM_PIN_SHIFT;
        return MM_OK;
}

int
mm_unpin(kword_t base)
{
        int i = find_extent(base);
        if (i < 0 || !MM_EXTENT_PINNED(&mm_extents[i]))
                return MM_ERR_INVAL;
        mm_extents[i].meta -= (kword_t)1UL << MM_PIN_SHIFT;
        return MM_OK;
}

int
mm_free(kword_t base, unsigned int type, unsigned int owner)
{
        int i = find_extent(base);
        int j;
        if (i < 0 || MM_EXTENT_PINNED(&mm_extents[i]) ||
            MM_EXTENT_TYPE(&mm_extents[i]) != type ||
            MM_EXTENT_OWNER(&mm_extents[i]) != owner)
                return MM_ERR_BUSY;
        for (j = i; j + 1 < mm_extent_count; ++j)
                mm_extents[j] = mm_extents[j + 1];
        --mm_extent_count;
        return MM_OK;
}

void
fs_copy_words(const kword_t *src, kword_t *dst, unsigned int n)
{
        unsigned int i;
        for (i = 0U; i < n; ++i)
                dst[i] = src[i];
}

void
fs_zero_words(kword_t *dst, unsigned int n)
{
        unsigned int i;
        for (i = 0U; i < n; ++i)
                dst[i] = 0UL;
}

static int
reload(kword_t backing, kword_t base, kword_t uarea)
{
        unsigned int i;
        kword_t *dest = (kword_t *)(unsigned long)base;
        if (backing != BACKING || uarea != UAREA || base != RESTORE)
                return -1;
        for (i = 020U; i < WORDS; ++i)
                dest[i] = i < OMIT ? TEXT_PATTERN : 07777UL;
        return 0;
}

#ifndef DAIMOS_TEST_FIXTURE_NO_MAIN
int
main(void)
{
        struct proc *p = &process_slots[SLOT];
        struct proc_packed_v1 d;
        kword_t *source = (kword_t *)(unsigned long)SOURCE;
        kword_t *suffix = (kword_t *)(unsigned long)PACKED;
        kword_t *dest = (kword_t *)(unsigned long)RESTORE;
        kword_t *uarea = (kword_t *)(unsigned long)UAREA;
        unsigned int i;

        mm_extent_count = 0;
        add_extent(SOURCE, WORDS, MM_TYPE_PROCESS);
        for (i = 0U; i < PROC_UAREA_WORDS; ++i)
                uarea[i] = 0UL;
        for (i = 0U; i < WORDS; ++i)
                source[i] = i < OMIT ? TEXT_PATTERN : PATTERN + i;
        proc_storage_runtime_v29.words = mode_words;
        proc_storage_runtime_v29.slots = SLOTS;
        if (proc_packed_layout_init_v36(&proc_packed_runtime_v38,
            layout_words, SLOTS, 2U, PROC_PACKED_LAYOUT_DENSE_V36) !=
            MM_OK)
                return 1;
        p->meta = (UAREA << PROC_HALF_SHIFT) |
            ((kword_t)(PROC_F_UAREA | PROC_F_TRANSITION) <<
                PROC_FLAGS_SHIFT);
        p->vm_state = (WORDS << PROC_HALF_SHIFT) | SOURCE;
        p->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        swap_slots[SLOT].state = BACKING;
        if (proc_pure_ram_drop_v1377(SLOT) != MM_OK)
                return 2;
        if (VM_PDP6_BASE(p) || mm_extent_count != 1 ||
            proc_packed_owner_lookup_v37(&proc_packed_runtime_v38,
                SLOT, &d) != MM_OK || PROC_PACKED_BASE(&d) != PACKED ||
            PROC_PACKED_WORDS(&d) != SUFFIX ||
            PROC_PACKED_OFFSET(&d) != OMIT ||
            uarea[PROC_SWAP_BACKING_OFFSET] != BACKING)
                return 3;
        for (i = 0U; i < SUFFIX; ++i)
                if (suffix[i] != PATTERN + OMIT + i)
                        return 4;
        PROC_SET_TRANSITION(p);
        refuse_restore_alloc = 1;
        if (proc_pure_ram_restore_v1377(SLOT, reload) != MM_ERR_NOMEM ||
            mm_extent_count != 1 ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            VM_PDP6_BASE(p) || uarea[PROC_SWAP_BACKING_OFFSET] != BACKING)
                return 9;
        refuse_restore_alloc = 0;
        if (proc_pure_ram_restore_v1377(SLOT, reload) != MM_OK)
                return 5;
        if (VM_PDP6_BASE(p) != RESTORE || mm_extent_count != 1 ||
            find_extent(PACKED) >= 0 ||
            proc_storage_get_v28(&proc_storage_runtime_v29, SLOT) !=
                PROC_STORAGE_RESIDENT ||
            uarea[PROC_SWAP_BACKING_OFFSET] != 0UL ||
            PROC_TRANSITION(p))
                return 6;
        for (i = 020U; i < WORDS; ++i)
                if (dest[i] != (i < OMIT ? TEXT_PATTERN : PATTERN + i))
                        return 7;
        PROC_SET_TRANSITION(p);
        if (proc_pure_ram_drop_v1377(SLOT) != MM_OK)
                return 10;
        PROC_SET_STATE(p, PROC_ZOMB);
        PROC_SET_TRANSITION(p);
        uarea[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        if (proc_pure_ram_discard_v1377(SLOT) != MM_OK ||
            mm_extent_count != 0 || swap_slots[SLOT].state != 0UL ||
            uarea[PROC_SWAP_BACKING_OFFSET] != 0UL ||
            (uarea[PROC_CRED_OFFSET] & PROC_SWAP_MOUNT_EXT_BIT))
                return 11;
        return 0;
}
#endif
