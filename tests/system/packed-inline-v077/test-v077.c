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
#include "proc_packed_boot_v38.h"
#include "proc_packed_release_v43.h"
#include "proc_storage_map_v28.h"
#include "mm_internal.h"
#include "d6codec-codec-v068.h"
#include "proc_packed_evict_v077.h"

#define SLOT 1U
#define SOURCE 0x24000UL
#define DEST 0x28000UL
#define WORDS 256UL
#define ENCODED 128UL
#define OFFSET 128UL
#define BACKING 012345UL
static unsigned int pattern;
static unsigned int measured_words;
static kword_t source_word(unsigned int i)
{
    return pattern && i < 8U ? (kword_t)(02000U + i) : 0UL;
}

struct mm_extent mm_extents[MM_MAX_EXTENTS];
kword_t mm_arenas[MM_MAX_ARENAS];
kword_t mm_core_words;
int mm_extent_count;
int mm_arena_count;
static struct proc processes[PROC_MIN_SLOTS];
struct proc *proc_table = processes;
unsigned int proc_slots = PROC_MIN_SLOTS;
struct proc_packed_layout_v36 proc_packed_runtime_v38;
static kword_t registry_words[PROC_MIN_SLOTS];
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
    if (type == MM_TYPE_PACKED_PROCESS && words > 0UL && words < 128UL && find_extent(SOURCE) < 0) {
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
static int inline_size(const kword_t *src, unsigned int n)
{
    uint64_t *out = NULL;
    size_t count = 0U;
    int result = -1;
    if (d6codec_encode_v068((const uint64_t *)src, n, &out, &count) == 0 &&
        count <= 0777777U)
        result = (int)count;
    free(out);
    return result;
}
static int inline_encode(const kword_t *src, unsigned int n, kword_t *dst,
    unsigned int capacity)
{
    uint64_t *out = NULL;
    size_t written = 0U;
    int result = -1;
    if (d6codec_encode_v068((const uint64_t *)src, n, &out, &written) == 0 &&
        written <= capacity) {
        memcpy(dst, out, written * sizeof(*dst));
        result = (int)written;
    }
    free(out);
    return result;
}
static int inline_decode(const kword_t *src, unsigned int words,
    kword_t *dst, unsigned int expected)
{
    return d6codec_decode_v068((const uint64_t *)src, words,
        (uint64_t *)dst, expected) == 0 ? (int)expected : -1;
}
static int reload_pure(kword_t backing, kword_t base)
{
    kword_t *dst = (kword_t *)(unsigned long)(base * sizeof(kword_t));
    unsigned int i;
    if (backing != BACKING) return -1;
    for (i = 0; i < OFFSET; ++i) dst[i] = 0777UL;
    return 0;
}
static int bad_size(const kword_t *src, unsigned int n)
{
    (void)src; (void)n;
    return -1;
}
static int bad_encode(const kword_t *src, unsigned int n, kword_t *dst,
    unsigned int capacity)
{
    (void)src; (void)n; (void)dst; (void)capacity;
    return -1;
}
static void resident_setup(void)
{
    unsigned int i;
    kword_t *ptr = (kword_t *)(unsigned long)(DEST * sizeof(kword_t));
    setup();
    mm_extent_count = 0;
    add_extent(DEST, WORDS, MM_TYPE_PROCESS);
    processes[SLOT].vm_state = (WORDS << PROC_HALF_SHIFT) | DEST;
    modes[0] = 0UL;
    for (i = 0; i < OFFSET; ++i) ptr[i] = 0777UL;
    for (i = 0; i < 128U; ++i)
        ptr[OFFSET + i] = source_word(i);
}
static void run_mode(unsigned int format, unsigned int input_pattern)
{
    kword_t *entry;
    kword_t *source;
    pattern = input_pattern;
    resident_setup();
    source = (kword_t *)(unsigned long)(DEST * sizeof(kword_t));
    measured_words = (unsigned int)inline_size(source + OFFSET, 128U);
    assert(measured_words > 0U && measured_words < 128U);
    if (pattern == 0U) assert(measured_words == 3U);
    else assert(measured_words > 3U);

    memset(registry_words, 0, sizeof(registry_words));
    memset(&proc_packed_runtime_v38, 0, sizeof(proc_packed_runtime_v38));
    assert(proc_packed_layout_init_v36(&proc_packed_runtime_v38,
        registry_words, PROC_MIN_SLOTS, 2U, format) == MM_OK);
    /* A full sparse registry must fail before even allocating the encoded
     * extent; no source is released, and TRANSITION is retained. */
    if (format == PROC_PACKED_LAYOUT_SPARSE_V36) {
        registry_words[0] = 2UL;
        registry_words[1] = 1UL;
        registry_words[2] = 3UL;
        registry_words[3] = 1UL;
        assert(proc_packed_evict_transaction_v077(SLOT, OFFSET, inline_size,
            inline_encode) == MM_ERR_INVAL);
        assert(find_extent(DEST) >= 0 && find_extent(SOURCE) < 0);
        assert(VM_PDP6_BASE(&processes[SLOT]) == DEST);
        assert(PROC_TRANSITION(&processes[SLOT]));
        memset(registry_words, 0, sizeof(registry_words));
    }
    /* A failing encoder cannot alter process MM ownership or storage mode. */
    assert(proc_packed_evict_transaction_v077(SLOT, OFFSET, inline_size,
        bad_encode) != MM_OK);
    assert(VM_PDP6_BASE(&processes[SLOT]) == DEST);
    assert(mm_extent_count == 1 && find_extent(SOURCE) < 0);
    assert(proc_storage_get_v28(&proc_storage_runtime_v29, SLOT) ==
        PROC_STORAGE_RESIDENT);
    assert(PROC_TRANSITION(&processes[SLOT]));
    assert(MM_EXTENT_PINS(&mm_extents[find_extent(DEST)]) == 0U);
    assert(proc_packed_evict_transaction_v077(SLOT, OFFSET, bad_size,
        inline_encode) == MM_ERR_INVAL);
    /* Registry publication must finish before TRANSITION can clear. */
    assert(proc_packed_evict_transaction_v077(SLOT, OFFSET, inline_size,
        inline_encode) == MM_OK);
    assert(!PROC_TRANSITION(&processes[SLOT]));
    assert(VM_PDP6_BASE(&processes[SLOT]) == 0UL);
    assert(find_extent(DEST) < 0 && find_extent(SOURCE) >= 0);
    assert(MM_EXTENT_WORDS(&mm_extents[find_extent(SOURCE)]) == measured_words);
    {
        uint64_t restored[128];
        const kword_t *encoded = (const kword_t *)(unsigned long)(SOURCE * sizeof(kword_t));
        unsigned int j;
        assert(d6codec_decode_v068((const uint64_t *)encoded, measured_words,
            restored, 128U) == 0);
        for (j = 0; j < 128U; ++j)
            assert(restored[j] == source_word(j));
    }
    assert(proc_storage_get_v28(&proc_storage_runtime_v29, SLOT) ==
        PROC_STORAGE_PACKED);
    entry = proc_packed_layout_find_v36(&proc_packed_runtime_v38, SLOT);
    assert(entry != 0 && *entry == ((OFFSET << 18U) | 128UL));
    /* Complete the same transaction through the real inline decoder.
     * Registry publication and retirement must match MM ownership. */
    PROC_SET_TRANSITION(&processes[SLOT]);
    assert(proc_packed_restore_transaction_v46(SLOT, BACKING,
        inline_decode, reload_pure) == MM_OK);
    assert(VM_PDP6_BASE(&processes[SLOT]) == DEST);
    assert(find_extent(SOURCE) < 0 && find_extent(DEST) >= 0);
    assert(proc_storage_get_v28(&proc_storage_runtime_v29, SLOT) ==
        PROC_STORAGE_RESIDENT);
    assert(proc_packed_layout_find_v36(&proc_packed_runtime_v38, SLOT) == 0);
    assert(!PROC_TRANSITION(&processes[SLOT]));
    {
        const kword_t *words = (const kword_t *)(unsigned long)(DEST * sizeof(kword_t));
        unsigned int j;
        for (j = 0U; j < OFFSET; ++j) assert(words[j] == 0777UL);
        for (j = OFFSET; j < WORDS; ++j)
            assert(words[j] == source_word(j - OFFSET));
    }
}
int main(void)
{
    void *mapped = mmap((void *)0x100000UL, 0x100000UL,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED,
        -1, 0);
    assert(mapped == (void *)0x100000UL);
    run_mode(PROC_PACKED_LAYOUT_DENSE_V36, 0U);
    run_mode(PROC_PACKED_LAYOUT_DENSE_V36, 1U);
    run_mode(PROC_PACKED_LAYOUT_SPARSE_V36, 0U);
    run_mode(PROC_PACKED_LAYOUT_SPARSE_V36, 1U);
    puts("packed eviction v45: both registries, failure rollback and commit PASS");
    return 0;
}
