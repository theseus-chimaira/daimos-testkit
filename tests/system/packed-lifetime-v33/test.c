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
#include "proc_packed_lifetime_v33.h"
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
int mm_free(kword_t base, unsigned int type, unsigned int owner)
{
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
int main(void)
{
    struct proc_packed_registry_v33 registry = {0};
    struct proc_packed_v1 entries[PROC_MIN_SLOTS] = {{0}};
    struct proc_packed_v1 prepared;
    void *mapped = mmap((void *)0x100000UL, 0x100000UL,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED,
        -1, 0);
    assert(mapped == (void *)0x100000UL);
    setup();
    /* A slot in PACKED mode has no resident VM base. */
    prepared.span = PROC_PACKED_SPAN(SOURCE, ENCODED);
    prepared.layout = (OFFSET << 18U) | ENCODED;
    assert(proc_packed_registry_init_v33(&registry, entries, PROC_MIN_SLOTS) == MM_OK);
    assert(proc_packed_registry_publish_v33(&registry, SLOT, &prepared) == MM_OK);
    assert(proc_packed_registry_get_v33(&registry, SLOT) == &entries[SLOT]);
    assert(proc_packed_registry_publish_v33(&registry, SLOT, &prepared) != MM_OK);
    assert(mm_pin(SOURCE) == MM_OK);
    assert(proc_packed_registry_discard_v33(&registry, SLOT) != MM_OK);
    assert(proc_packed_registry_get_v33(&registry, SLOT)->span == prepared.span);
    assert(proc_storage_get_v28(&proc_storage_runtime_v29, SLOT) == PROC_STORAGE_PACKED);
    assert(mm_unpin(SOURCE) == MM_OK);
    assert(proc_packed_registry_discard_v33(&registry, SLOT) == MM_OK);
    assert(find_extent(SOURCE) < 0);
    assert(entries[SLOT].span == 0UL && entries[SLOT].layout == 0UL);
    assert(proc_storage_get_v28(&proc_storage_runtime_v29, SLOT) == PROC_STORAGE_RESIDENT);
    assert(proc_packed_registry_get_v33(&registry, SLOT) == 0);
    /* Owner change must be rejected even when the base and length match. */
    add_extent(SOURCE, ENCODED, MM_TYPE_PACKED_PROCESS);
    mm_extents[0].meta = (mm_extents[0].meta & ~MM_OWNER_MASK) | 2UL;
    modes[0] = (kword_t)PROC_STORAGE_PACKED << 2U;
    assert(proc_packed_registry_publish_v33(&registry, SLOT, &prepared) == MM_ERR_INVAL);
    assert(entries[SLOT].span == 0UL);
    puts("packed lifetime v33: ownership, pin, release and slot reuse PASS");
    return 0;
}
