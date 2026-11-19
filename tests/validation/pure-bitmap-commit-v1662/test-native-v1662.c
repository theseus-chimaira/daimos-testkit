/*
 * v1662 native PDP-6 exact bitmap commit. Reuse the established v1661
 * process and REAL assembler MM-free fixture, not a second MM model.
 */
#define main retired_terminal_main_v1661
#include "../pure-bitmap-terminal-v1661/test-native-v1661.c"
#undef main
#include "proc_pure_bitmap_commit_v1662.h"
#include "proc_pure_bitmap_decode_v1660.h"
#include "bstore.h"
#include "memfs.h"

#define RAW_BASE_V1662 050000UL
#define DECODE_BASE_V1662 060000UL
#define EXTRA_BASE_V1662 070000UL
#define RAW_WORDS_V1662 RAW_V1661
#define ENCODED_V1662 PACKED_V1661
#define NONZERO_V1662 65U

unsigned int backstore_enabled;
kword_t backstore_blocks;
kword_t backstore_blocks_used;
kword_t *backstore_bitmap;
kword_t proc_swap_blocks_used;
static vnode_t roots_v1662[1] = {
        VFS_NODE(MEMFS_PROVIDER, VFS_MOUNT_KIND(1U, MEMFS_KIND_NODE), 1UL)
};
vnode_t *vfs_mount_root_base = roots_v1662;
kword_t vfs_mount_limit = 1UL;

extern void bitmap_encode_v1451(kword_t, kword_t, kword_t);
extern int mm_pure_bitmap_retire_v1662(unsigned int, kword_t,
    kword_t, kword_t, kword_t);

static unsigned int retire_calls_v1662;
static unsigned int refuse_retire_v1662;
static unsigned int pi_bad_v1662;

int
mm_bitmap_retire_hook_v1662(unsigned int slot, kword_t source,
    kword_t raw, kword_t target, kword_t encoded)
{
        ++retire_calls_v1662;
        if (pi_depth_v1661 != 1U ||
            ((storage_v1661[0] >> 4U) & 3UL) != PROC_STORAGE_PACKED) {
                ++pi_bad_v1662;
                return MM_ERR_BUSY;
        }
        if (refuse_retire_v1662)
                return MM_ERR_BUSY;
        return mm_pure_bitmap_retire_v1662(slot, source, raw, target,
            encoded);
}

static kword_t
raw_word_v1662(kword_t i)
{
        if (!(i % 050UL) && i / 050UL < NONZERO_V1662)
                return 0770000UL + i;
        return 0UL;
}

static void
prepare_v1662(void)
{
        struct proc *p = &processes_v1661[SLOT_V1661];
        kword_t *raw = (kword_t *)(unsigned long)RAW_BASE_V1662;
        kword_t *u = (kword_t *)(unsigned long)UAREA_V1661;
        kword_t i;

        reset_v1661();
        p->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        storage_v1661[0] = (kword_t)PROC_STORAGE_PACKED << 4U;
        mm_extent_count = 2;
        mm_extents[0].span = (ENCODED_V1662 << 18U) |
            PACKED_BASE_V1661;
        mm_extents[0].meta = ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
            SLOT_V1661;
        mm_extents[1].span = (RAW_WORDS_V1662 << 18U) |
            RAW_BASE_V1662;
        mm_extents[1].meta = ((kword_t)1UL << MM_PIN_SHIFT) |
            ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) | SLOT_V1661;
        mm_extents[2].span = 0UL;
        mm_extents[2].meta = 0UL;
        mm_extent_capacity = MM_MAX_EXTENTS;
        retire_calls_v1662 = 0U;
        refuse_retire_v1662 = 0U;
        pi_bad_v1662 = 0U;
        backstore_enabled = 0U;
        backstore_blocks = 0UL;
        backstore_blocks_used = 0UL;
        backstore_bitmap = (kword_t *)0;
        proc_swap_blocks_used = 0UL;
        vfs_mount_root_base = roots_v1662;
        vfs_mount_limit = 1UL;
        roots_v1662[0] = VFS_NODE(MEMFS_PROVIDER,
            VFS_MOUNT_KIND(1U, MEMFS_KIND_NODE), 1UL);
        u[PROC_CRED_OFFSET] = 0UL;
        u[PROC_FDCTL_OFFSET] = 0UL;
        for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                raw[i] = raw_word_v1662(i);
        bitmap_encode_v1451(RAW_BASE_V1662, RAW_WORDS_V1662,
            PACKED_BASE_V1661);
}

static int
check_raw_v1662(void)
{
        const kword_t *raw = (const kword_t *)(unsigned long)
            RAW_BASE_V1662;
        kword_t i;

        for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                if (raw[i] != raw_word_v1662(i))
                        return 0;
        return 1;
}

static int
case_v1662(unsigned int kind)
{
        struct proc *p = &processes_v1661[SLOT_V1661];
        kword_t *packed = (kword_t *)(unsigned long)PACKED_BASE_V1661;
        kword_t *u = (kword_t *)(unsigned long)UAREA_V1661;
        kword_t old_mode, span0, meta0, span1, meta1, span2, meta2;
        kword_t source = RAW_BASE_V1662, target = PACKED_BASE_V1661;
        kword_t encoded = ENCODED_V1662;
        unsigned int slot = SLOT_V1661;
        int old_count, rc;

        prepare_v1662();
        switch (kind) {
        case 1U: packed[1] ^= 1UL; break; /* literal mismatch */
        case 2U: packed[1] = 0UL; break; /* absent nonzero literal */
        case 3U: packed[0] |= 1UL; break; /* illegal mask presence */
        case 4U: encoded = ENCODED_V1662 + 1UL; break;
        case 5U: encoded = ENCODED_V1662 - 1UL; break;
        case 6U: mm_extents[0].meta |= (kword_t)1UL << MM_PIN_SHIFT;
                 break;
        case 7U: mm_extents[1].meta += (kword_t)1UL << MM_PIN_SHIFT;
                 break;
        case 8U: mm_extent_count = 3;
                 mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                 mm_extents[2].meta =
                     ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                     SLOT_V1661;
                 break;
        case 9U: mm_extents[1].span =
                     ((RAW_WORDS_V1662 - 1UL) << 18U) | RAW_BASE_V1662;
                 break;
        case 10U: mm_extents[0].span =
                      ((ENCODED_V1662 + 1UL) << 18U) | PACKED_BASE_V1661;
                  break;
        case 11U: mm_extents[1].meta =
                      ((kword_t)MM_TYPE_PROCESS << 18U) | SLOT_V1661;
                  break;
        case 12U: mm_extents[0].meta =
                      ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                      (SLOT_V1661 + 1U);
                  break;
        case 13U: target = RAW_BASE_V1662 + 010UL; break;
        case 14U: storage_v1661[0] =
                      (kword_t)PROC_STORAGE_BITMAP_V1661 << 4U;
                  break;
        case 15U: vfs_mount_root_base = (vnode_t *)0; break;
        case 16U: u[PROC_SWAP_BACKING_OFFSET] ^= 1UL; break;
        case 17U: PROC_CLEAR_TRANSITION(p); break;
        case 18U: p->sched = (kword_t)PROC_SRUN << PROC_STATE_SHIFT;
                  break;
        case 19U: refuse_retire_v1662 = 1U; break;
        case 20U: slot = SLOT_V1661 + 1U; break;
        case 21U: roots_v1662[0] = VFS_NODE(1U,
                      VFS_MOUNT_KIND(1U, MEMFS_KIND_NODE), 1UL);
                  break;
        case 22U: mm_extent_count = 3;
                  mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                  mm_extents[2].meta = (5UL << 18U) | SLOT_V1661;
                  break;
        case 23U: mm_extent_count = 3;
                  mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                  mm_extents[2].meta =
                      ((kword_t)MM_TYPE_MODULE << 18U) | SLOT_V1661;
                  break;
        case 24U: mm_extent_capacity = 1U; break;
        case 25U: mm_extent_count = -1; break;
        default: break;
        }
        old_mode = storage_v1661[0];
        span0 = mm_extents[0].span;
        meta0 = mm_extents[0].meta;
        span1 = mm_extents[1].span;
        meta1 = mm_extents[1].meta;
        span2 = mm_extents[2].span;
        meta2 = mm_extents[2].meta;
        old_count = mm_extent_count;

        rc = proc_pure_bitmap_commit_v1662(slot, source, target, encoded);
        if (pi_depth_v1661 || pi_bad_v1662)
                return 1;
        if (kind == 0U || kind == 23U) {
                kword_t i;
                kword_t *decoded = (kword_t *)(unsigned long)
                    DECODE_BASE_V1662;
                if (rc != MM_OK || retire_calls_v1662 != 1U ||
                    mm_extent_count != (kind == 23U ? 2 : 1) ||
                    mm_extents[0].span != span0 ||
                    mm_extents[0].meta != meta0 ||
                    storage_v1661[0] !=
                      ((kword_t)PROC_STORAGE_BITMAP_V1661 << 4U) ||
                    !PROC_TRANSITION(p) ||
                    !check_raw_v1662() ||
                    swap_v1661[SLOT_V1661].state != BACKING_V1661 ||
                    u[PROC_SWAP_BACKING_OFFSET] != BACKING_V1661)
                        return 2;
                if (kind == 23U &&
                    (mm_extents[1].span != span2 ||
                     mm_extents[1].meta != meta2))
                        return 3;
                if (proc_pure_bitmap_decode_v1660(PACKED_BASE_V1661,
                    ENCODED_V1662, DECODE_BASE_V1662,
                    RAW_WORDS_V1662) != MM_OK)
                        return 4;
                for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                        if (decoded[i] != raw_word_v1662(i))
                                return 5;
                if (kind == 0U) {
                        p->sched = (kword_t)PROC_ZOMB << PROC_STATE_SHIFT;
                        if (proc_pure_bitmap_terminal_v1661(SLOT_V1661)
                            != MM_OK || mm_extent_count != 0 ||
                            storage_v1661[0] != 0UL ||
                            !PROC_TRANSITION(p))
                                return 6;
                }
        } else if (rc != (kind == 19U ? MM_ERR_BUSY : MM_ERR_INVAL) ||
            retire_calls_v1662 != (kind == 19U ? 1U : 0U) ||
            mm_extent_count != old_count ||
            mm_extents[0].span != span0 ||
            mm_extents[0].meta != meta0 ||
            mm_extents[1].span != span1 ||
            mm_extents[1].meta != meta1 ||
            mm_extents[2].span != span2 ||
            mm_extents[2].meta != meta2 ||
            storage_v1661[0] != old_mode) {
                return 7;
        }
        return 0;
}

/* Test the new atomic assembly leaf DIRECTLY as well. C preflight
 * cannot substitute for independent lower-level pin/owner validation.
 */
static int
mm_leaf_case_v1662(unsigned int kind)
{
        kword_t span0, meta0, span1, meta1, span2, meta2;
        kword_t source = RAW_BASE_V1662;
        kword_t target = PACKED_BASE_V1661;
        kword_t raw = RAW_WORDS_V1662;
        kword_t enc = ENCODED_V1662;
        int count, rc;

        prepare_v1662();
        switch (kind) {
        case 1U: mm_extents[1].meta += (kword_t)1UL << MM_PIN_SHIFT;
                 break;
        case 2U: mm_extents[0].meta |= (kword_t)1UL << MM_PIN_SHIFT;
                 break;
        case 3U: mm_extents[1].meta =
                     ((kword_t)MM_TYPE_PROCESS << 18U) | SLOT_V1661;
                 break;
        case 4U: mm_extents[0].meta =
                     ((kword_t)MM_TYPE_PROCESS << 18U) | SLOT_V1661;
                 break;
        case 5U: mm_extents[1].meta ^= 1UL; break;
        case 6U: mm_extents[0].meta ^= 1UL; break;
        case 7U: mm_extent_count = 3;
                 mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                 mm_extents[2].meta =
                     ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                     SLOT_V1661;
                 break;
        case 8U: mm_extent_count = 3;
                 mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                 mm_extents[2].meta = (5UL << 18U) | SLOT_V1661;
                 break;
        case 9U: raw++; break;
        case 10U: enc++; break;
        case 11U: source = target + 010UL; break;
        case 12U: target = source + 010UL; break;
        case 13U: mm_extent_count = -1; break;
        case 14U: mm_extent_capacity = 1U; break;
        case 15U: mm_extent_count = 1; break;
        case 16U: mm_extents[1].span = (raw << 18U) | 0777700UL;
                  source = 0777700UL; break;
        case 17U: mm_extents[0].span = (enc << 18U) | 0777700UL;
                  target = 0777700UL; break;
        case 18U: /* RAW first: deletion must shift candidate left */
                  source = PACKED_BASE_V1661;
                  target = 050122UL;
                  mm_extents[0].span = (raw << 18U) | source;
                  mm_extents[0].meta =
                      ((kword_t)1UL << MM_PIN_SHIFT) |
                      ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                      SLOT_V1661;
                  mm_extents[1].span = (enc << 18U) | target;
                  mm_extents[1].meta =
                      ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                      SLOT_V1661;
                  break;
        case 19U: /* exact maximum 136 descriptors; final count 135 */
                  {
                          unsigned int j;
                          mm_extent_count = MM_MAX_EXTENTS;
                          for (j = 2U; j < MM_MAX_EXTENTS; ++j) {
                                  mm_extents[j].span = (1UL << 18U) |
                                      (070000UL + (kword_t)j);
                                  mm_extents[j].meta =
                                      ((kword_t)MM_TYPE_MODULE << 18U) |
                                      SLOT_V1661;
                          }
                  }
                  break;
        case 20U: mm_extent_count = MM_MAX_EXTENTS + 1; break;
        case 21U: source = 01000000UL; break;
        case 22U: enc |= 01000000UL; break;
        case 23U: mm_extents[1].meta =
                      ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                      SLOT_V1661;
                  break;
        default: break;
        }
        span0 = mm_extents[0].span;
        meta0 = mm_extents[0].meta;
        span1 = mm_extents[1].span;
        meta1 = mm_extents[1].meta;
        span2 = mm_extents[2].span;
        meta2 = mm_extents[2].meta;
        count = mm_extent_count;
        pi_depth_v1661 = 1U;
        rc = mm_pure_bitmap_retire_v1662(SLOT_V1661, source, raw,
            target, enc);
        pi_depth_v1661 = 0U;
        if (kind == 0U || kind == 18U || kind == 19U) {
                if (rc != MM_OK ||
                    mm_extent_count != (kind == 19U ?
                        MM_MAX_EXTENTS - 1 : 1) ||
                    mm_extents[0].span !=
                        (kind == 18U ? span1 : span0) ||
                    mm_extents[0].meta !=
                        (kind == 18U ? meta1 : meta0))
                        return 1;
                if (kind == 19U) {
                        unsigned int j;
                        for (j = 1U; j < MM_MAX_EXTENTS - 1U; ++j)
                                if (mm_extents[j].span !=
                                    ((1UL << 18U) |
                                      (070000UL + (kword_t)(j + 1U))) ||
                                    mm_extents[j].meta !=
                                    (((kword_t)MM_TYPE_MODULE << 18U) |
                                     SLOT_V1661))
                                        return 3;
                }
        } else if (rc != ((kind <= 2U || kind == 23U) ?
                        MM_ERR_BUSY : MM_ERR_INVAL) ||
            mm_extent_count != count ||
            mm_extents[0].span != span0 ||
            mm_extents[0].meta != meta0 ||
            mm_extents[1].span != span1 ||
            mm_extents[1].meta != meta1 ||
            mm_extents[2].span != span2 ||
            mm_extents[2].meta != meta2)
                return 2;
        return 0;
}

/* Genuine original PDP-6 allocator + 883-word gap from v1657, not a
 * manually installed compressed MM extent. After commit, allocate a
 * new independent MM owner in the formerly pinned RAW physical area.
 */
static int
allocator_commit_case_v1662(void)
{
        struct proc *p = &processes_v1661[SLOT_V1661];
        kword_t *source = (kword_t *)(unsigned long)PACKED_BASE_V1661;
        kword_t *decoded = (kword_t *)(unsigned long)DECODE_BASE_V1662;
        kword_t packed_base = 0UL, reused_base = 0UL, i;
        int rc;

        prepare_v1662();
        for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                source[i] = raw_word_v1662(i);
        mm_extent_count = 1;
        mm_extents[0].span = (RAW_WORDS_V1662 << 18U) |
            PACKED_BASE_V1661;
        mm_extents[0].meta = ((kword_t)1UL << MM_PIN_SHIFT) |
            ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) | SLOT_V1661;
        mm_arena_count = 1;
        mm_arenas[0] = (010363UL << 18U) | PACKED_BASE_V1661;

        rc = mm_alloc_aligned_noreclaim(ENCODED_V1662, 1UL,
            MM_TYPE_PACKED_PROCESS, SLOT_V1661, MM_ALLOC_HIGH,
            &packed_base);
        if (rc != MM_OK || packed_base != 050122UL ||
            mm_extent_count != 2 ||
            MM_EXTENT_BASE(&mm_extents[1]) != packed_base ||
            MM_EXTENT_WORDS(&mm_extents[1]) != ENCODED_V1662 ||
            MM_EXTENT_PINS(&mm_extents[1]))
                return 1;

        bitmap_encode_v1451(PACKED_BASE_V1661, RAW_WORDS_V1662,
            packed_base);
        rc = proc_pure_bitmap_commit_v1662(SLOT_V1661,
            PACKED_BASE_V1661, packed_base, ENCODED_V1662);
        if (rc != MM_OK || retire_calls_v1662 != 1U ||
            mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != packed_base ||
            MM_EXTENT_WORDS(&mm_extents[0]) != ENCODED_V1662 ||
            MM_EXTENT_PINS(&mm_extents[0]) ||
            storage_v1661[0] !=
                ((kword_t)PROC_STORAGE_BITMAP_V1661 << 4U) ||
            !PROC_TRANSITION(p) || pi_depth_v1661)
                return 2;

        /* Original allocator must actually reuse previously pinned RAW
         * core, while the compressed source remains independently held.
         */
        rc = mm_alloc_aligned_noreclaim(02000UL, 1UL,
            MM_TYPE_KERNEL_DYNAMIC, 0421U, MM_ALLOC_LOW,
            &reused_base);
        if (rc != MM_OK || reused_base != PACKED_BASE_V1661 ||
            mm_extent_count != 2 ||
            MM_EXTENT_BASE(&mm_extents[1]) != packed_base ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_KERNEL_DYNAMIC)
                return 3;
        if (mm_free(reused_base, MM_TYPE_KERNEL_DYNAMIC, 0421U) != MM_OK ||
            mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != packed_base)
                return 4;

        if (proc_pure_bitmap_decode_v1660(packed_base,
            ENCODED_V1662, DECODE_BASE_V1662, RAW_WORDS_V1662) != MM_OK)
                return 5;
        for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                if (decoded[i] != raw_word_v1662(i))
                        return 6;
        p->sched = (kword_t)PROC_ZOMB << PROC_STATE_SHIFT;
        if (proc_pure_bitmap_terminal_v1661(SLOT_V1661) != MM_OK ||
            mm_extent_count != 0 || storage_v1661[0] ||
            !PROC_TRANSITION(p))
                return 7;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;

        for (kind = 0U; kind <= 25U; ++kind) {
                rc = case_v1662(kind);
                if (rc != 0)
                        return (int)(01000U + kind * 8U + (unsigned int)rc);
        }
        for (kind = 0U; kind <= 23U; ++kind) {
                rc = mm_leaf_case_v1662(kind);
                if (rc != 0)
                        return (int)(02000U + kind * 8U + (unsigned int)rc);
        }
        rc = allocator_commit_case_v1662();
        if (rc != 0)
                return 03000 + rc;
        return 0;
}
