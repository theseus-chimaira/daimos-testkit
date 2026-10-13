/* Host-side transactional packed restore contract, no simulator required.
 * Isolated MM mock uses fixed low addresses to model PDP-6 physical pointers.
 */
#define _GNU_SOURCE
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include "proc.h"
#include "vm_pdp6.h"
#include "proc_swap.h"
#include "proc_packed_v1.h"
#include "proc_packed_teardown_v39.h"
#include "proc_packed_boot_v38.h"
#include "proc_packed_release_v43.h"
#include "proc_packed_publish_v44.h"
#include "proc_storage_map_v28.h"
#include "mm_internal.h"

#define SLOT 1U
#define SOURCE 0x24000UL
#define DEST 0x28000UL
#define WORDS 256UL
#define ENCODED 128UL
#define OFFSET 128UL
#define BACKING 012345UL

struct mm_extent mm_extents[MM_MAX_EXTENTS];
kword_t mm_arenas[MM_MAX_ARENAS];
kword_t mm_core_words;
int mm_extent_count;
int mm_arena_count;
static struct proc processes[PROC_MIN_SLOTS];
struct proc *proc_table = processes;
unsigned int proc_slots = PROC_MIN_SLOTS;
static kword_t *boot_block;
static int fail_boot_alloc;
static int fail_boot_free;
static struct proc_swap_record swap_records[PROC_MIN_SLOTS];
struct proc_swap_record *proc_swap_records = swap_records;
static kword_t modes[PROC_STORAGE_MAP_WORDS_V28(PROC_MIN_SLOTS)];
struct proc_storage_map_v28 proc_storage_runtime_v29;
static int fail_decoder;
static int reload_count;

static void add_extent(kword_t base, kword_t words, unsigned int type)
{
    struct mm_extent *e = &mm_extents[mm_extent_count++];
    e->span = (words << 18U) | base;
    e->meta = (kword_t)SLOT | ((kword_t)type << MM_TYPE_SHIFT);
}
static int find_extent(kword_t base)
{
    int i;
    for (i = 0; i < mm_extent_count; ++i)
        if (MM_EXTENT_BASE(&mm_extents[i]) == base) return i;
    return -1;
}
int mm_alloc_aligned_noreclaim(kword_t words, kword_t align,
    unsigned int type, unsigned int owner, unsigned int preference,
    kword_t *basep)
{
    (void)preference;
    if (owner != SLOT) return MM_ERR_INVAL;
    if (type == MM_TYPE_PACKED_PROCESS && words == 64UL && find_extent(SOURCE) < 0) {
        add_extent(SOURCE, words, type); *basep = SOURCE;
    } else if (type == MM_TYPE_PROCESS && words == WORDS &&
               (DEST % align) == 0UL && find_extent(DEST) < 0) {
        add_extent(DEST, words, type); *basep = DEST;
    } else return MM_ERR_NOMEM;
    return MM_OK;
}
int mm_pin(kword_t base)
{
    int i = find_extent(base);
    if (i < 0) return MM_ERR_INVAL;
    mm_extents[i].meta += 1UL << MM_PIN_SHIFT;
    return MM_OK;
}
int mm_unpin(kword_t base)
{
    int i = find_extent(base);
    if (i < 0 || !MM_EXTENT_PINNED(&mm_extents[i])) return MM_ERR_INVAL;
    mm_extents[i].meta -= 1UL << MM_PIN_SHIFT;
    return MM_OK;
}
int mm_alloc(kword_t n, unsigned int type, unsigned int owner,
    unsigned int preference, kword_t *base)
{
    assert(type == MM_TYPE_KERNEL_DYNAMIC && owner == 5U &&
        preference == MM_ALLOC_LOW && n);
    if (fail_boot_alloc || boot_block) return MM_ERR_NOMEM;
    boot_block = calloc((size_t)n, sizeof(*boot_block));
    if (!boot_block) return MM_ERR_NOMEM;
    *base = (kword_t)(unsigned long)boot_block;
    return MM_OK;
}
void fs_zero_words(kword_t *p, unsigned int n)
{
    memset(p, 0, (size_t)n * sizeof(*p));
}
int mm_free(kword_t base, unsigned int type, unsigned int owner)
{
    if (type == MM_TYPE_KERNEL_DYNAMIC) {
        assert(owner == 5U && (kword_t)(unsigned long)boot_block == base);
        if (fail_boot_free) return MM_ERR_BUSY;
        free(boot_block);
        boot_block = 0;
        return MM_OK;
    }
    int i = find_extent(base);
    if (i < 0 || MM_EXTENT_PINNED(&mm_extents[i]) ||
        MM_EXTENT_TYPE(&mm_extents[i]) != type ||
        MM_EXTENT_OWNER(&mm_extents[i]) != owner) return MM_ERR_INVAL;
    memmove(&mm_extents[i], &mm_extents[i + 1],
        (size_t)(mm_extent_count - i - 1) * sizeof(mm_extents[0]));
    --mm_extent_count;
    return MM_OK;
}
int proc_storage_get_v28(const struct proc_storage_map_v28 *map,
    unsigned int slot)
{
    if (!map || !map->words || slot >= map->slots) return -1;
    return (int)((map->words[slot / 18U] >> (slot % 18U) * 2U) & 3UL);
}
static void setup(void)
{
    unsigned int i;
    kword_t *ptr = (kword_t *)(unsigned long)(SOURCE * sizeof(kword_t));
    memset(processes, 0, sizeof(processes));
    memset(mm_extents, 0, sizeof(mm_extents));
    memset(modes, 0, sizeof(modes));
    memset(swap_records, 0, sizeof(swap_records));
    mm_extent_count = 0;
    add_extent(SOURCE, ENCODED, MM_TYPE_PACKED_PROCESS);
    proc_storage_runtime_v29.words = modes;
    proc_storage_runtime_v29.slots = PROC_MIN_SLOTS;
    modes[0] = (kword_t)PROC_STORAGE_PACKED << 2U;
    processes[SLOT].vm_state = WORDS << PROC_HALF_SHIFT;
    processes[SLOT].meta = ((kword_t)(PROC_F_TRANSITION | PROC_F_UAREA) << PROC_FLAGS_SHIFT);
    swap_records[SLOT].state = BACKING;
    for (i = 0; i < ENCODED; ++i) ptr[i] = 02000UL + i;
    fail_decoder = 0;
    reload_count = 0;
}
int proc_storage_change_v28(struct proc_storage_map_v28 *map,
    unsigned int slot, unsigned int old_state, unsigned int new_state)
{
    unsigned int shift = (slot % 18U) * 2U;
    kword_t mask = (kword_t)3UL << shift;
    if (slot >= map->slots || new_state > 2U ||
        proc_storage_get_v28(map, slot) != (int)old_state)
        return -1;
    map->words[slot / 18U] = (map->words[slot / 18U] & ~mask) |
        ((kword_t)new_state << shift);
    return 0;
}
static void exercise(unsigned int concurrency, unsigned int budget,
    unsigned int expected_format)
{
    struct proc_packed_layout_v36 *layout = &proc_packed_runtime_v38;
    struct proc_packed_v1 prepared;
    struct proc_packed_v1 found = {0};
    setup();
    prepared.span = PROC_PACKED_SPAN(SOURCE, ENCODED);
    prepared.layout = (OFFSET << 18U) | ENCODED;
    assert(proc_packed_boot_prepare_v38(proc_slots, concurrency, budget) == MM_OK);
    assert(layout->format == expected_format);
    assert(proc_packed_boot_abort_v38() == MM_OK);
    /* Reinitialize to exercise a clean registry after startup rollback. */
    assert(proc_packed_boot_prepare_v38(proc_slots, concurrency, budget) == MM_OK);
    /* Publication requires the transition and exact ownership. */
    PROC_CLEAR_TRANSITION(&processes[SLOT]);
    assert(proc_packed_publish_v44(SLOT, &prepared) != MM_OK);
    PROC_SET_TRANSITION(&processes[SLOT]);
    mm_extents[0].meta = (mm_extents[0].meta & ~MM_OWNER_MASK) | 2UL;
    assert(proc_packed_publish_v44(SLOT, &prepared) != MM_OK);
    mm_extents[0].meta = (mm_extents[0].meta & ~MM_OWNER_MASK) | SLOT;
    assert(proc_packed_release_v43(SLOT) == MM_ERR_INVAL);
    assert(proc_packed_publish_v44(SLOT, &prepared) == MM_OK);
    assert(proc_packed_owner_lookup_v37(layout, SLOT, &found) == MM_OK);
    assert(found.span == prepared.span && found.layout == prepared.layout);
    assert(proc_packed_publish_v44(SLOT, &prepared) != MM_OK);
    /* A duplicate sparse slot must be rejected without releasing MM. */
    if (expected_format == PROC_PACKED_LAYOUT_SPARSE_V36) {
        layout->words[2] = SLOT;
        layout->words[3] = prepared.layout;
        assert(proc_packed_release_v43(SLOT) == MM_ERR_INVAL);
        assert(find_extent(SOURCE) >= 0);
        layout->words[2] = 0UL;
        layout->words[3] = 0UL;
    }
    PROC_CLEAR_TRANSITION(&processes[SLOT]);
    assert(proc_packed_release_v43(SLOT) == MM_ERR_INVAL);
    assert(find_extent(SOURCE) >= 0);
    PROC_SET_TRANSITION(&processes[SLOT]);
    processes[SLOT].vm_state |= 010000UL;
    assert(proc_packed_release_v43(SLOT) == MM_ERR_INVAL);
    processes[SLOT].vm_state &= ~MM_HALF_MASK;
    assert(find_extent(SOURCE) >= 0);
    assert(mm_pin(SOURCE) == MM_OK);
    assert(proc_packed_release_v43(SLOT) != MM_OK);
    assert(proc_packed_owner_lookup_v37(layout, SLOT, &found) == MM_OK);
    assert(proc_storage_get_v28(&proc_storage_runtime_v29, SLOT) == PROC_STORAGE_PACKED);
    assert(mm_unpin(SOURCE) == MM_OK);
    add_extent(SOURCE + 0400UL, 8UL, MM_TYPE_PACKED_PROCESS);
    assert(proc_packed_owner_lookup_v37(layout, SLOT, &found) == MM_ERR_INVAL);
    assert(proc_packed_release_v43(SLOT) == MM_ERR_INVAL);
    --mm_extent_count;
    assert(proc_packed_release_v43(SLOT) == MM_OK);
    assert(find_extent(SOURCE) < 0);
    assert(proc_packed_owner_lookup_v37(layout, SLOT, &found) == MM_ERR_INVAL);
    assert(proc_storage_get_v28(&proc_storage_runtime_v29, SLOT) == PROC_STORAGE_RESIDENT);
    assert(proc_packed_release_v43(SLOT) == MM_ERR_INVAL);
    modes[0] = (kword_t)PROC_STORAGE_DISK << 2U;
    assert(proc_packed_release_v43(SLOT) == MM_ERR_INVAL);
    modes[0] = (kword_t)3UL << 2U;
    assert(proc_packed_release_v43(SLOT) == MM_ERR_INVAL);
    modes[0] = 0UL;
    assert(proc_packed_layout_find_v36(layout, SLOT) == 0);
    /* Reusing the slot cannot inherit a stale layout. */
    add_extent(SOURCE, ENCODED, MM_TYPE_PACKED_PROCESS);
    modes[0] = (kword_t)PROC_STORAGE_PACKED << 2U;
    assert(proc_packed_publish_v44(SLOT, &prepared) == MM_OK);
    assert(proc_packed_boot_abort_v38() == MM_ERR_BUSY);
    assert(proc_packed_release_v43(SLOT) == MM_OK);
    fail_boot_free = 1;
    assert(proc_packed_boot_abort_v38() == MM_ERR_BUSY);
    assert(layout->words == boot_block);
    fail_boot_free = 0;
    assert(proc_packed_boot_abort_v38() == MM_OK);
    assert(!boot_block && !layout->words);
}
int main(void)
{
    void *mapped = mmap((void *)0x100000UL, 0x100000UL,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED,
        -1, 0);
    assert(mapped == (void *)0x100000UL);
    setup();
    fail_boot_alloc = 1;
    assert(proc_packed_boot_prepare_v38(proc_slots, 4U, 8U) == MM_ERR_NOMEM);
    assert(!proc_packed_runtime_v38.words);
    fail_boot_alloc = 0;
    exercise(12U, 24U, PROC_PACKED_LAYOUT_DENSE_V36);
    exercise(4U, 8U, PROC_PACKED_LAYOUT_SPARSE_V36);
    puts("packed publish v44: dense/sparse publication, release, rollback PASS");
    return 0;
}
