/*
 * Unlinked PDP-6 PURE-only RAM transaction test. The actual production
 * C algorithms and MM ownership interfaces are compiled into this host
 * fixture; only MM, physical memory, VFS reload and scheduler are mocked.
 */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

#include "proc_pure_ram_v1377.h"
#include "proc_swap.h"
#include "proc_packed_owner_v37.h"
#include "vm_pdp6.h"
#include "mm_internal.h"

#define OWNER 1U
#define SLOTS PROC_MIN_SLOTS
#define UAREA 0x23000UL
#define PHYS_A 0x24000UL
#define PHYS_B 0x28000UL
#define RAM_BASE 0x30000UL
#define FULL_WORDS 02000UL
#define TEXT_WORDS 0500UL
#define OMIT_WORDS 0400UL
#define RETAINED (FULL_WORDS - OMIT_WORDS)
#define BACKING ((TEXT_WORDS << PROC_SWAP_TEXT_SHIFT) | 012345UL)
#define PURE_PATTERN 012345670123UL
#define MUTABLE_PATTERN 067012345670UL

static struct proc processes[SLOTS];
static struct proc_swap_record swap_records[SLOTS];
static kword_t modes[PROC_STORAGE_MAP_WORDS_V28(SLOTS)];
static kword_t layouts[SLOTS];
static int fail_alloc_type;
static int fail_pin_type;
static int fail_unpin_type;
static int fail_free_type;
static int fail_reload;
static unsigned int reload_calls;
static unsigned int alloc_calls;
static unsigned int free_calls;
static int use_next_base_b;

struct proc *proc_table = processes;
unsigned int proc_slots = SLOTS;
unsigned int proc_high_slot = SLOTS;
struct proc_swap_record *proc_swap_records = swap_records;
struct proc_storage_map_v28 proc_storage_runtime_v29;
struct proc_packed_layout_v36 proc_packed_runtime_v38;
kword_t *backstore_bitmap;
kword_t backstore_blocks;
kword_t backstore_blocks_used;
unsigned int backstore_enabled;
struct mm_extent mm_extents[MM_MAX_EXTENTS];
int mm_extent_count;
unsigned int mm_extent_capacity = MM_MAX_EXTENTS;
kword_t mm_arenas[MM_MAX_ARENAS];
kword_t mm_core_words;
int mm_arena_count;

static kword_t *
ptr(kword_t word_address)
{
        return (kword_t *)(unsigned long)
            (word_address * (kword_t)sizeof(kword_t));
}

static int
find_extent(kword_t base)
{
        int i;
        for (i = 0; i < mm_extent_count; ++i)
                if (MM_EXTENT_BASE(&mm_extents[i]) == base)
                        return i;
        return -1;
}

/* A real MM allocator checks half-open PHYSICAL intervals, not only
 * descriptor base equality. In particular an inactive PURE suffix may
 * start INSIDE the old process span; a resumed full APR image must not
 * overlap that still-authoritative suffix or a failed reload destroys it.
 */
static int
overlap_extent(kword_t base, kword_t words)
{
        int i;
        for (i = 0; i < mm_extent_count; ++i) {
                kword_t other = MM_EXTENT_BASE(&mm_extents[i]);
                kword_t length = MM_EXTENT_WORDS(&mm_extents[i]);
                if (base < other + length && other < base + words)
                        return 1;
        }
        return 0;
}

static void
add_extent(kword_t base, kword_t words, unsigned int type)
{
        struct mm_extent *e;
        assert(mm_extent_count < MM_MAX_EXTENTS);
        assert(find_extent(base) == -1);
        e = &mm_extents[mm_extent_count++];
        e->span = (words << 18U) | base;
        e->meta = ((kword_t)type << MM_TYPE_SHIFT) | OWNER;
}

int
mm_alloc_aligned_noreclaim(kword_t words, kword_t align,
    unsigned int type, unsigned int owner, unsigned int preference,
    kword_t *basep)
{
        kword_t base;
        ++alloc_calls;
        if (!basep || owner != OWNER || preference != MM_ALLOC_HIGH ||
            (int)type == fail_alloc_type)
                return MM_ERR_NOMEM;
        if (type == MM_TYPE_PACKED_PROCESS && words == RETAINED)
                base = RAM_BASE;
        else if (type == MM_TYPE_PROCESS && words == FULL_WORDS) {
                base = use_next_base_b ? PHYS_B : PHYS_A;
                use_next_base_b = !use_next_base_b;
                if (overlap_extent(base, words))
                        base = base == PHYS_A ? PHYS_B : PHYS_A;
        } else
                return MM_ERR_INVAL;
        if ((base & (align - 1UL)) || overlap_extent(base, words))
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
        if ((int)MM_EXTENT_TYPE(&mm_extents[i]) == fail_pin_type)
                return MM_ERR_BUSY;
        mm_extents[i].meta += (kword_t)1UL << MM_PIN_SHIFT;
        return MM_OK;
}

int
mm_unpin(kword_t base)
{
        int i = find_extent(base);
        if (i < 0 || !MM_EXTENT_PINNED(&mm_extents[i]))
                return MM_ERR_INVAL;
        if ((int)MM_EXTENT_TYPE(&mm_extents[i]) == fail_unpin_type)
                return MM_ERR_BUSY;
        mm_extents[i].meta -= (kword_t)1UL << MM_PIN_SHIFT;
        return MM_OK;
}

int
mm_free(kword_t base, unsigned int type, unsigned int owner)
{
        int i = find_extent(base);
        ++free_calls;
        if (i < 0 || MM_EXTENT_PINNED(&mm_extents[i]) ||
            MM_EXTENT_TYPE(&mm_extents[i]) != type ||
            MM_EXTENT_OWNER(&mm_extents[i]) != owner)
                return MM_ERR_INVAL;
        if ((int)type == fail_free_type)
                return MM_ERR_BUSY;
        memmove(&mm_extents[i], &mm_extents[i + 1],
            (size_t)(mm_extent_count - i - 1) * sizeof(mm_extents[0]));
        --mm_extent_count;
        return MM_OK;
}

void
fs_copy_words(const kword_t *src, kword_t *dst, unsigned int count)
{
        memmove(dst, src, (size_t)count * sizeof(*src));
}

void
fs_zero_words(kword_t *dst, unsigned int count)
{
        memset(dst, 0, (size_t)count * sizeof(*dst));
}

static int
reload(kword_t backing, kword_t base, kword_t uarea)
{
        kword_t *memory = ptr(base);
        unsigned int i;
        assert(backing == BACKING && uarea == UAREA);
        ++reload_calls;
        if (fail_reload)
                return -1;
        /* Simulate compressed DXR: all initialized memory is rebuilt,
         * so the retained mutable suffix MUST overlay these new words.
         */
        for (i = 020U; i < FULL_WORDS; ++i)
                memory[i] = i < OMIT_WORDS ? PURE_PATTERN : 07777UL;
        return 0;
}

static void
setup(unsigned int format)
{
        unsigned int i;
        kword_t *image = ptr(PHYS_A);
        kword_t *uarea = ptr(UAREA);
        memset(mm_extents, 0, sizeof(mm_extents));
        memset(processes, 0, sizeof(processes));
        memset(swap_records, 0, sizeof(swap_records));
        memset(modes, 0, sizeof(modes));
        memset(layouts, 0, sizeof(layouts));
        memset(&proc_packed_runtime_v38, 0,
            sizeof(proc_packed_runtime_v38));
        memset(uarea, 0, PROC_UAREA_WORDS * sizeof(*uarea));
        mm_extent_count = 0;
        add_extent(PHYS_A, FULL_WORDS, MM_TYPE_PROCESS);
        proc_storage_runtime_v29.words = modes;
        proc_storage_runtime_v29.slots = SLOTS;
        assert(proc_packed_layout_init_v36(&proc_packed_runtime_v38,
            layouts, SLOTS, 2U, format) == MM_OK);
        processes[OWNER].meta = (UAREA << PROC_HALF_SHIFT) |
            ((kword_t)(PROC_F_TRANSITION | PROC_F_UAREA)
                << PROC_FLAGS_SHIFT);
        processes[OWNER].vm_state = (FULL_WORDS << 18U) | PHYS_A;
        processes[OWNER].sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        swap_records[OWNER].state = BACKING;
        fail_alloc_type = -1;
        fail_pin_type = -1;
        fail_unpin_type = -1;
        fail_free_type = -1;
        fail_reload = 0;
        reload_calls = 0U;
        alloc_calls = free_calls = 0U;
        use_next_base_b = 1;
        for (i = 0U; i < FULL_WORDS; ++i)
                image[i] = i < OMIT_WORDS ? PURE_PATTERN :
                    (MUTABLE_PATTERN + (kword_t)i);
}

static void
verify_inactive(void)
{
        struct proc_packed_v1 descriptor;
        int i;
        kword_t *uarea = ptr(UAREA);
        assert(proc_storage_get_v28(&proc_storage_runtime_v29, OWNER) ==
            PROC_STORAGE_PACKED);
        assert(VM_PDP6_BASE(&processes[OWNER]) == 0UL);
        assert(!PROC_TRANSITION(&processes[OWNER]));
        assert(mm_extent_count == 1);
        assert(proc_packed_owner_lookup_v37(&proc_packed_runtime_v38,
            OWNER, &descriptor) == MM_OK);
        assert(PROC_PACKED_BASE(&descriptor) == RAM_BASE);
        assert(PROC_PACKED_WORDS(&descriptor) == RETAINED);
        assert(PROC_PACKED_DECODED(&descriptor) == RETAINED);
        assert(PROC_PACKED_OFFSET(&descriptor) == OMIT_WORDS);
        assert(uarea[PROC_SWAP_BACKING_OFFSET] == BACKING);
        assert(swap_records[OWNER].state == BACKING);
        assert(!(ptr(UAREA)[PROC_FDCTL_OFFSET] & PROC_USER_MAP_BIT));
        for (i = 0; i < (int)RETAINED; ++i)
                assert(ptr(RAM_BASE)[i] == MUTABLE_PATTERN +
                    (kword_t)(i + OMIT_WORDS));
}

static void
verify_resident(void)
{
        unsigned int i;
        kword_t *image = ptr(VM_PDP6_BASE(&processes[OWNER]));
        assert(proc_storage_get_v28(&proc_storage_runtime_v29, OWNER) ==
            PROC_STORAGE_RESIDENT);
        assert(!PROC_TRANSITION(&processes[OWNER]));
        assert(mm_extent_count == 1);
        assert(VM_PDP6_BASE(&processes[OWNER]) != 0UL);
        assert(find_extent(RAM_BASE) == -1);
        assert(ptr(UAREA)[PROC_SWAP_BACKING_OFFSET] == 0UL);
        for (i = 020U; i < OMIT_WORDS; ++i)
                assert(image[i] == PURE_PATTERN);
        for (i = OMIT_WORDS; i < FULL_WORDS; ++i)
                assert(image[i] == MUTABLE_PATTERN + (kword_t)i);
}

static void
test_cycle(unsigned int format)
{
        unsigned int i;
        setup(format);
        for (i = 0U; i < 3U; ++i) {
                assert(proc_pure_ram_drop_v1377(OWNER) == MM_OK);
                verify_inactive();
                PROC_SET_TRANSITION(&processes[OWNER]);
                assert(proc_pure_ram_restore_v1377(OWNER, reload) ==
                    MM_OK);
                verify_resident();
                assert(reload_calls == i + 1U);
                PROC_SET_TRANSITION(&processes[OWNER]);
        }
}

static void
test_rejections(unsigned int format)
{
        setup(format);
        swap_records[OWNER].state = 0UL;
        assert(proc_pure_ram_drop_v1377(OWNER) == MM_ERR_INVAL);
        swap_records[OWNER].state = BACKING;
        PROC_SET_STATE(&processes[OWNER], PROC_SRUN);
        assert(proc_pure_ram_drop_v1377(OWNER) == MM_ERR_INVAL);
        PROC_SET_STATE(&processes[OWNER], PROC_SLEEP);
        ptr(UAREA)[PROC_FDCTL_OFFSET] = PROC_USER_MAP_BIT;
        assert(proc_pure_ram_drop_v1377(OWNER) == MM_ERR_BUSY);
        ptr(UAREA)[PROC_FDCTL_OFFSET] = 0UL;
        fail_alloc_type = MM_TYPE_PACKED_PROCESS;
        assert(proc_pure_ram_drop_v1377(OWNER) == MM_ERR_NOMEM);
        assert(mm_extent_count == 1);
        assert(VM_PDP6_BASE(&processes[OWNER]) == PHYS_A);
        assert(proc_storage_get_v28(&proc_storage_runtime_v29, OWNER) ==
            PROC_STORAGE_RESIDENT);
        fail_alloc_type = -1;
        fail_free_type = MM_TYPE_PROCESS;
        assert(proc_pure_ram_drop_v1377(OWNER) == MM_ERR_BUSY);
        assert(mm_extent_count == 1);
        assert(VM_PDP6_BASE(&processes[OWNER]) == PHYS_A);
        assert(!ptr(UAREA)[PROC_SWAP_BACKING_OFFSET]);
        assert(!layouts[OWNER]);
        fail_free_type = -1;
        assert(proc_pure_ram_drop_v1377(OWNER) == MM_OK);
        verify_inactive();
        /* A failed RAW restore allocation must leave the saved payload
         * and executable backing untouched for later retry.
         */
        PROC_SET_TRANSITION(&processes[OWNER]);
        fail_alloc_type = MM_TYPE_PROCESS;
        assert(proc_pure_ram_restore_v1377(OWNER, reload) ==
            MM_ERR_NOMEM);
        assert(mm_extent_count == 1);
        assert(VM_PDP6_BASE(&processes[OWNER]) == 0UL);
        assert(proc_storage_get_v28(&proc_storage_runtime_v29, OWNER) ==
            PROC_STORAGE_PACKED);
        fail_alloc_type = -1;
        fail_reload = 1;
        assert(proc_pure_ram_restore_v1377(OWNER, reload) ==
            MM_ERR_INVAL);
        assert(find_extent(RAM_BASE) >= 0);
        assert(mm_extent_count == 1);
        fail_reload = 0;
        fail_free_type = MM_TYPE_PACKED_PROCESS;
        assert(proc_pure_ram_restore_v1377(OWNER, reload) ==
            MM_ERR_BUSY);
        assert(mm_extent_count == 1);
        assert(find_extent(RAM_BASE) >= 0);
        fail_free_type = -1;
        assert(proc_pure_ram_restore_v1377(OWNER, reload) == MM_OK);
        verify_resident();
}

static void
test_discard(unsigned int format)
{
        setup(format);
        ptr(UAREA)[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        assert(proc_pure_ram_drop_v1377(OWNER) == MM_OK);
        /* Terminal teardown can run after the process becomes ZOMB:
         * it must release owned inactive RAM without restoring an APR.
         */
        PROC_SET_STATE(&processes[OWNER], PROC_ZOMB);
        PROC_SET_TRANSITION(&processes[OWNER]);
        fail_free_type = MM_TYPE_PACKED_PROCESS;
        assert(proc_pure_ram_discard_v1377(OWNER) == MM_ERR_BUSY);
        assert(proc_storage_get_v28(&proc_storage_runtime_v29, OWNER) ==
            PROC_STORAGE_PACKED);
        assert(swap_records[OWNER].state == BACKING);
        fail_free_type = -1;
        assert(proc_pure_ram_discard_v1377(OWNER) == MM_OK);
        assert(mm_extent_count == 0);
        assert(swap_records[OWNER].state == 0UL);
        assert(ptr(UAREA)[PROC_SWAP_BACKING_OFFSET] == 0UL);
        assert(!(ptr(UAREA)[PROC_CRED_OFFSET] &
            PROC_SWAP_MOUNT_EXT_BIT));
        assert(proc_storage_get_v28(&proc_storage_runtime_v29, OWNER) ==
            PROC_STORAGE_RESIDENT);
        assert(!proc_packed_layout_find_v36(&proc_packed_runtime_v38,
            OWNER));
}

int
main(void)
{
        unsigned int format;
        void *mapped;

        mapped = mmap((void *)0x100000UL, 0x300000UL, PROT_READ |
            PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
        assert(mapped == (void *)0x100000UL);
        for (format = PROC_PACKED_LAYOUT_DENSE_V36;
             format <= PROC_PACKED_LAYOUT_SPARSE_V36; ++format) {
                test_cycle(format);
                test_rejections(format);
                test_discard(format);
        }
        puts("PURE RAM lifecycle v1377: 2 layouts, 3 cycles, failures PASS");
        return 0;
}
