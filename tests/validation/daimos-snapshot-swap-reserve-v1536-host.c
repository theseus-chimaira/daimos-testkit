/*
 * v1536: KINIT's actual proc_swap_boot_init source-linked on the host.
 * The environment stubs ONLY MM allocation and the physical BACKSTORE
 * read/publication; the production reservation function is not copied.
 * Each case starts from independent freshly initialized kernel state.
 * C89, ASCII. No production kernel source modification.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "proc_swap.h"
#include "proc_storage_map_v28.h"
#include "fs_mres.h"
#include "bstore.h"
#include "bcache.h"
#include "mm.h"

#define V1536_BLOCKS 145UL
#define V1536_SNAPSHOT_FIRST 107UL
#define V1536_SNAPSHOT_SPAN 38UL
#define V1536_MAGIC 055464663UL
#define V1536_V1 1UL
#define V1536_V2 2UL
#define V1536_WORD_MASK 0777777777777UL

struct proc_swap_record *proc_swap_records;
kword_t proc_swap_blocks_used;
struct proc_storage_map_v28 proc_storage_runtime_v29;
kword_t *backstore_bitmap;
kword_t backstore_blocks;
kword_t backstore_blocks_used;
unsigned int backstore_enabled;
kword_t fs_block_workspace[128];

static kword_t v1536_mm[4096];
static kword_t v1536_header[6];
static int v1536_fail_read;
static unsigned int v1536_reads;
static unsigned int v1536_invalidates;
static unsigned int v1536_mm_allocs;

static void
v1536_require(int condition, const char *what)
{
    if (!condition) {
        fprintf(stderr, "FAIL v1536: %s\n", what);
        exit(1);
    }
}

int
mm_alloc(kword_t words, unsigned int type, unsigned int owner,
    unsigned int preference, kword_t *basep)
{
    if (type != MM_TYPE_KERNEL_DYNAMIC || owner != 4U ||
        preference != MM_ALLOC_LOW ||
        words > sizeof(v1536_mm) / sizeof(v1536_mm[0]))
        return MM_ERR_INVAL;
    ++v1536_mm_allocs;
    *basep = (kword_t)(unsigned long)v1536_mm;
    return MM_OK;
}

void
fs_zero_words(kword_t *dest, unsigned int count)
{
    unsigned int i;
    for (i = 0U; i < count; ++i)
        dest[i] = 0UL;
}

unsigned int
backstore_bitmap_words(kword_t count)
{
    return (unsigned int)((count + 35UL) / 36UL);
}

void
backstore_init(kword_t *bitmap, kword_t count)
{
    backstore_bitmap = bitmap;
    backstore_blocks = count;
    backstore_blocks_used = 0UL;
    backstore_enabled = 0U;
}

void
bcache_workspace_invalidate(void)
{
    ++v1536_invalidates;
}

int
backstore_read(kword_t start, kword_t count, kword_t *dest)
{
    unsigned int i;
    ++v1536_reads;
    if (v1536_fail_read || start != V1536_BLOCKS - 1UL ||
        count != 1UL || dest != fs_block_workspace)
        return -1;
    for (i = 0U; i < 6U; ++i)
        dest[i] = v1536_header[i];
    return 0;
}

kword_t
backing_region_blocks(void)
{
    return 0UL;
}

static unsigned int
v1536_count_bits(kword_t *bitmap, kword_t blocks)
{
    kword_t block;
    unsigned int n;
    unsigned int word;
    unsigned int bit;
    n = 0U;
    for (block = 0UL; block < blocks; ++block) {
        word = (unsigned int)(block / 36UL);
        bit = (unsigned int)(block % 36UL);
        if ((bitmap[word] & ((kword_t)1UL << bit)) != 0UL)
            ++n;
    }
    return n;
}

static void
v1536_reset(kword_t version)
{
    memset(v1536_mm, 0xcc, sizeof(v1536_mm));
    memset(fs_block_workspace, 0xcc, sizeof(fs_block_workspace));
    memset(v1536_header, 0, sizeof(v1536_header));
    proc_swap_records = 0;
    proc_swap_blocks_used = 999UL;
    proc_storage_runtime_v29.words = 0;
    proc_storage_runtime_v29.slots = 0U;
    backstore_bitmap = 0;
    backstore_blocks = V1536_BLOCKS;
    backstore_blocks_used = 777UL;
    backstore_enabled = 0U;
    v1536_fail_read = 0;
    v1536_reads = 0U;
    v1536_invalidates = 0U;
    v1536_mm_allocs = 0U;
    v1536_header[0] = V1536_MAGIC;
    v1536_header[1] = version;
    v1536_header[2] = V1536_SNAPSHOT_FIRST;
    v1536_header[3] = V1536_SNAPSHOT_SPAN;
}

static void
v1536_check(int expect_reserved, const char *description)
{
    kword_t block;
    unsigned int i;

    v1536_require(proc_swap_boot_init(16U) == 0, description);
    v1536_require(v1536_mm_allocs == 1U, "single MM table allocation");
    v1536_require(v1536_reads == 1U, "exact header read");
    v1536_require(v1536_invalidates == 1U, "cache invalidation");
    v1536_require(proc_swap_records != 0, "swap table installed");
    v1536_require(proc_storage_runtime_v29.words != 0 &&
        proc_storage_runtime_v29.slots == 16U, "slot map installed");
    v1536_require(proc_swap_blocks_used == 0UL, "zero swap usage");
    v1536_require(backstore_blocks == V1536_BLOCKS, "backing capacity");
    v1536_require(backstore_blocks_used ==
        (expect_reserved ? V1536_SNAPSHOT_SPAN : 0UL),
        "snapshot usage account");
    v1536_require(v1536_count_bits(backstore_bitmap,
        V1536_BLOCKS) ==
        (expect_reserved ? (unsigned int)V1536_SNAPSHOT_SPAN : 0U),
        "bitmap exact number of reserved sectors");
    for (block = 0UL; block < V1536_BLOCKS; ++block) {
        i = (unsigned int)(block / 36UL);
        v1536_require(((backstore_bitmap[i] >>
            (unsigned int)(block % 36UL)) & 1UL) ==
            (kword_t)((expect_reserved &&
            block >= V1536_SNAPSHOT_FIRST) ? 1U : 0U),
            "no overlap, gap or false reserved sector");
    }
    v1536_require(proc_swap_boot_init(16U) != 0,
        "repeat bootstrap must refuse");
    printf("PASS v1536: %s\n", description);
}

int
main(void)
{
    v1536_reset(V1536_V2);
    v1536_check(1, "committed v2 snapshot reserved before swap");
    v1536_reset(V1536_V1);
    v1536_check(1, "legacy v1 reservation remains compatible");
    v1536_reset(3UL);
    v1536_check(0, "unsupported header version not reserved");
    v1536_reset(V1536_V2);
    v1536_header[0] = 0UL;
    v1536_check(0, "invalid magic not reserved");
    v1536_reset(V1536_V2);
    v1536_header[3] = 0UL;
    v1536_check(0, "zero-length range not reserved");
    v1536_reset(V1536_V2);
    v1536_header[2] = V1536_BLOCKS;
    v1536_check(0, "out-of-range first block not reserved");
    v1536_reset(V1536_V2);
    v1536_header[3] = V1536_SNAPSHOT_SPAN + 1UL;
    v1536_check(0, "run reaching beyond backing refused");
    v1536_reset(V1536_V2);
    v1536_header[2]--;
    v1536_check(0, "range not ending at commit block refused");
    v1536_reset(V1536_V2);
    v1536_fail_read = 1;
    v1536_check(0, "failed header read does not reserve guesses");
    printf("PASS v1536: source-linked KINIT snapshot reservation matrix\n");
    return 0;
}
