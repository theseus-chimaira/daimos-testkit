/*
 * v1664 native PDP-6 compressed FULL restore. The runner merges the
 * original v1662 and v1663 fixtures, renaming their main functions.
 * Every allocator/pin/free is the source-linked PDP-6 MM assembler.
 */
#include "proc_pure_bitmap_restore_v1664.h"

#define APR_BASE_V1664 0100000UL

static unsigned int fault_v1664;
static unsigned int loads_v1664;
static unsigned int finish_calls_v1664;
static unsigned int rollback_unpin_calls_v1664;
static unsigned int rollback_free_calls_v1664;

extern int mm_pure_bitmap_finish_v1664(unsigned int, kword_t,
    kword_t, kword_t, kword_t);

int
mm_restore_alloc_v1664(kword_t words, kword_t align,
    unsigned int type, unsigned int owner, unsigned int pref,
    kword_t *out)
{
        int rc;
        if (fault_v1664 == 2U)
                return MM_ERR_NOMEM;
        if (fault_v1664 == 3U)
                return MM_ERR_DESCRIPTORS;
        rc = mm_alloc_aligned_noreclaim(words, align, type, owner,
            pref, out);
        if (rc != MM_OK)
                return rc;
        if (fault_v1664 == 6U) {
                /* Real allocation exists but the returned physical
                 * pointer is forged. No writes or repair allowed.
                 */
                *out = PACKED_BASE_V1661;
        }
        return MM_OK;
}

int
mm_restore_pin_v1664(kword_t base)
{
        if (fault_v1664 == 7U && base != APR_BASE_V1664)
                return MM_ERR_BUSY;
        if (fault_v1664 == 8U && base != APR_BASE_V1664)
                return MM_OK;       /* false source pin success */
        if (fault_v1664 == 4U && base == APR_BASE_V1664)
                return MM_ERR_BUSY;
        if (fault_v1664 == 5U && base == APR_BASE_V1664)
                return MM_OK;       /* false target pin success */
        return mm_pin(base);
}

int
mm_restore_unpin_v1664(kword_t base)
{
        ++rollback_unpin_calls_v1664;
        if (fault_v1664 == 21U && base == APR_BASE_V1664)
                return MM_ERR_BUSY;
        if (fault_v1664 == 22U && base == APR_BASE_V1664)
                return MM_OK;       /* false success, still pinned */
        if (fault_v1664 == 23U && base != APR_BASE_V1664)
                return MM_ERR_BUSY;
        if (fault_v1664 == 24U && base != APR_BASE_V1664)
                return MM_OK;       /* false success, still pinned */
        return mm_unpin(base);
}

int
mm_restore_free_v1664(kword_t base, unsigned int type,
    unsigned int owner)
{
        ++rollback_free_calls_v1664;
        if (fault_v1664 == 25U)
                return MM_ERR_BUSY;
        if (fault_v1664 == 26U)
                return MM_OK;       /* false success, still owned */
        return mm_free(base, type, owner);
}

int
mm_finish_hook_v1664(unsigned int slot, kword_t packed,
    kword_t encoded, kword_t apr, kword_t words)
{
        ++finish_calls_v1664;
        if (pi_depth_v1661 != 1U ||
            ((storage_v1661[0] >> 4U) & 3UL) !=
                PROC_STORAGE_BITMAP_V1661)
                return MM_ERR_INVAL;
        if (fault_v1664 == 20U)
                return MM_ERR_BUSY;
        return mm_pure_bitmap_finish_v1664(slot, packed, encoded,
            apr, words);
}

static int
load_full_v1664(kword_t backing, kword_t base,
    kword_t uarea, kword_t words)
{
        kword_t *data = (kword_t *)(unsigned long)base;
        kword_t i;
        ++loads_v1664;
        if (base != APR_BASE_V1664 || backing != BACKING_V1661 ||
            uarea != UAREA_V1661 || words != FULL_V1661)
                return -1;
        for (i = 0UL; i < words; ++i)
                data[i] = 0500000UL + i; /* overwritten by RAW suffix */
        if (fault_v1664 == 36U)
                storage_v1661[0] =
                    (kword_t)PROC_STORAGE_PACKED << 4U;
        if (fault_v1664 == 37U)
                ((kword_t *)(unsigned long)uarea)[
                    PROC_SWAP_BACKING_OFFSET] ^= 1UL;
        if (fault_v1664 == 38U)
                PROC_CLEAR_TRANSITION(&processes_v1661[SLOT_V1661]);
        if (fault_v1664 == 39U)
                processes_v1661[SLOT_V1661].vm_state |= 02000UL;
        if (fault_v1664 == 1U || fault_v1664 == 21U ||
            fault_v1664 == 22U || fault_v1664 == 23U ||
            fault_v1664 == 24U || fault_v1664 == 25U ||
            fault_v1664 == 26U)
                return -1; /* deliberately fail after partial writes */
        return 0;
}

static int
setup_v1664(unsigned int zero)
{
        kword_t encoded = 0UL, i;
        kword_t *raw;
        int rc;

        setup_v1663();
        raw = (kword_t *)(unsigned long)PACKED_BASE_V1661;
        if (zero)
                for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                        raw[i] = 0UL;
        rc = proc_pure_bitmap_compress_v1663(SLOT_V1661, &encoded);
        if (rc != MM_OK || encoded !=
            (zero ? RAW_WORDS_V1662 / 36UL : ENCODED_V1662) ||
            mm_extent_count != 1 ||
            MM_EXTENT_PINS(&mm_extents[0]) ||
            storage_v1661[0] !=
                ((kword_t)PROC_STORAGE_BITMAP_V1661 << 4U))
                return 1;
        mm_arena_count = 2;
        mm_arenas[1] = (FULL_V1661 << 18U) | APR_BASE_V1664;
        fault_v1664 = 0U;
        loads_v1664 = 0U;
        finish_calls_v1664 = 0U;
        rollback_unpin_calls_v1664 = 0U;
        rollback_free_calls_v1664 = 0U;
        return 0;
}

static int
restore_case_v1664(unsigned int kind)
{
        struct proc *p = &processes_v1661[SLOT_V1661];
        kword_t *u = (kword_t *)(unsigned long)UAREA_V1661;
        kword_t source, length, old_base, old_meta;
        kword_t *packed;
        int rc;

        if (setup_v1664(kind == 35U))
                return 1;
        source = MM_EXTENT_BASE(&mm_extents[0]);
        length = MM_EXTENT_WORDS(&mm_extents[0]);
        packed = (kword_t *)(unsigned long)source;
        switch (kind) {
        case 9U: packed[1] = 0UL; break; /* invalid literal */
        case 10U: packed[0] ^= (kword_t)1UL << 35U; break;
        case 11U: storage_v1661[0] =
                      (kword_t)PROC_STORAGE_PACKED << 4U;
                  break;
        case 12U: u[PROC_SWAP_BACKING_OFFSET] ^= 1UL; break;
        case 13U: vfs_mount_root_base = (vnode_t *)0; break;
        case 14U: p->vm_state |= 02000UL; break;
        case 15U: PROC_CLEAR_TRANSITION(p); break;
        case 16U: mm_extent_count = 2;
                  mm_extents[1].span = (10UL << 18U) | EXTRA_BASE_V1662;
                  mm_extents[1].meta =
                      ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                      SLOT_V1661;
                  break;
        case 17U: mm_extent_count = 2;
                  mm_extents[1].span = (10UL << 18U) | EXTRA_BASE_V1662;
                  mm_extents[1].meta =
                      ((kword_t)MM_TYPE_MODULE << 18U) | SLOT_V1661;
                  break;
        case 18U: p->sched =
                      (kword_t)PROC_SRUN << PROC_STATE_SHIFT;
                  proc_current_slot = SLOT_V1661;
                  break;
        case 19U: p->sched =
                      (kword_t)PROC_SRUN << PROC_STATE_SHIFT;
                  proc_current_slot = 0UL; /* valid slot-0 wake */
                  break;
        case 27U: mm_arena_count = 1; break;
        case 28U: mm_extent_capacity = 1U; break;
        case 29U: mm_extents[0].meta +=
                      (kword_t)1UL << MM_PIN_SHIFT;
                  break;
        case 30U: mm_extents[0].span =
                      (RAW_WORDS_V1662 << 18U) | source;
                  break;
        case 31U: mm_extent_count = 0; break;
        case 32U: mm_extent_count = 2;
                  mm_extents[1].span = (10UL << 18U) | EXTRA_BASE_V1662;
                  mm_extents[1].meta =
                      ((kword_t)MM_TYPE_PROCESS << 18U) | SLOT_V1661;
                  break;
        default: break;
        }
        old_base = mm_extents[0].span;
        old_meta = mm_extents[0].meta;

        fault_v1664 = kind;
        rc = proc_pure_bitmap_restore_v1664(SLOT_V1661,
            load_full_v1664);
        fault_v1664 = 0U;
        if (pi_depth_v1661)
                return 2;
        if (kind == 0U || kind == 17U || kind == 19U ||
            kind == 35U) {
                const kword_t *dest = (const kword_t *)(unsigned long)
                    APR_BASE_V1664;
                unsigned int apr_index = kind == 17U ? 1U : 0U;
                kword_t i;
                if (rc != MM_OK || loads_v1664 != 1U ||
                    finish_calls_v1664 != 1U ||
                    mm_extent_count != (kind == 17U ? 2 : 1) ||
                    MM_EXTENT_TYPE(&mm_extents[apr_index]) !=
                        MM_TYPE_PROCESS ||
                    MM_EXTENT_BASE(&mm_extents[apr_index]) !=
                        APR_BASE_V1664 ||
                    MM_EXTENT_PINS(&mm_extents[apr_index]) ||
                    VM_PDP6_BASE(p) != APR_BASE_V1664 ||
                    PROC_TRANSITION(p) ||
                    storage_v1661[0] ||
                    u[PROC_SWAP_BACKING_OFFSET])
                        return 3;
                for (i = 0UL; i < FULL_V1661; ++i) {
                        kword_t want = i < SKIP_V1661 ?
                            0500000UL + i :
                            (kind == 35U ? 0UL :
                             raw_word_v1662(i - SKIP_V1661));
                        if (dest[i] != want)
                                return 4;
                }
                if (kind == 17U &&
                    (MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_MODULE ||
                     MM_EXTENT_OWNER(&mm_extents[0]) != SLOT_V1661))
                        return 5;
                return 0;
        }
        if (rc == MM_OK || VM_PDP6_BASE(p) !=
            ((kind == 14U || kind == 39U) ? 02000UL : 0UL) ||
            u[PROC_SWAP_BACKING_OFFSET] !=
            ((kind == 12U || kind == 37U) ?
                (BACKING_V1661 ^ 1UL) : BACKING_V1661) ||
            mm_extents[0].span != old_base ||
            mm_extents[0].meta == 0UL)
                return 6;
        if (kind != 11U && kind != 36U && storage_v1661[0] !=
            ((kword_t)PROC_STORAGE_BITMAP_V1661 << 4U))
                return 7;
        if (kind != 15U && kind != 38U && !PROC_TRANSITION(p))
                return 8;
        if (kind != 16U && kind != 32U &&
            kind != 31U && kind != 29U && kind != 30U &&
            kind != 5U && kind != 6U && kind != 8U &&
            kind != 21U && kind != 22U && kind != 23U &&
            kind != 24U && kind != 25U && kind != 26U &&
            kind != 36U && kind != 37U && kind != 38U &&
            kind != 39U &&
            mm_extent_count != 1)
                return 9;
        if (kind != 29U && kind != 5U && kind != 6U &&
            kind != 8U && kind != 21U && kind != 22U &&
            kind != 23U && kind != 24U && kind != 25U &&
            kind != 26U && kind != 36U && kind != 37U &&
            kind != 38U && kind != 39U && mm_extent_count > 0 &&
            MM_EXTENT_PINS(&mm_extents[0]))
                return 10;
        if (kind >= 36U && kind <= 39U &&
            (mm_extent_count != 2 ||
             MM_EXTENT_PINS(&mm_extents[0]) != 1U ||
             MM_EXTENT_PINS(&mm_extents[1]) != 1U ||
             finish_calls_v1664 != 0U))
                return 11;
        return 0;
}

/* Independently test the atomic MM assembler against invalid
 * descriptors, pins, order, full table and physical boundaries.
 */
static int
finish_case_v1664(unsigned int kind)
{
        kword_t source, length, target, old0, meta0, old1, meta1;
        int rc, count;

        if (setup_v1664(0U))
                return 1;
        source = MM_EXTENT_BASE(&mm_extents[0]);
        length = MM_EXTENT_WORDS(&mm_extents[0]);
        target = APR_BASE_V1664;
        rc = mm_pin(source);
        if (rc != MM_OK)
                return 2;
        if (kind == 17U)
                mm_arenas[1] = (FULL_V1661 << 18U) | 020000UL;
        rc = mm_alloc_aligned_noreclaim(FULL_V1661,
            VM_PDP6_ALIGN_WORDS, MM_TYPE_PROCESS,
            SLOT_V1661, MM_ALLOC_HIGH, &target);
        if (rc != MM_OK ||
            target != (kind == 17U ? 020000UL : APR_BASE_V1664) ||
            mm_pin(target) != MM_OK)
                return 3;
        switch (kind) {
        case 1U: mm_extents[0].meta +=
                    (kword_t)1UL << MM_PIN_SHIFT; break;
        case 2U: mm_extents[1].meta +=
                    (kword_t)1UL << MM_PIN_SHIFT; break;
        case 3U: mm_extents[0].meta -=
                    (kword_t)1UL << MM_PIN_SHIFT; break;
        case 4U: mm_extents[1].meta -=
                    (kword_t)1UL << MM_PIN_SHIFT; break;
        case 5U: mm_extents[0].meta =
                    ((kword_t)MM_TYPE_PROCESS << 18U) | SLOT_V1661;
                  break;
        case 6U: mm_extents[1].meta =
                    ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                    SLOT_V1661; break;
        case 7U: mm_extents[0].meta ^= 1UL; break;
        case 8U: mm_extents[1].meta ^= 1UL; break;
        case 9U: target = source + 010UL; break;
        case 10U: length++; break;
        case 11U: mm_extent_count = 3;
                  mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                  mm_extents[2].meta =
                      ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                      SLOT_V1661; break;
        case 12U: mm_extent_count = 3;
                  mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                  mm_extents[2].meta =
                      ((kword_t)MM_TYPE_MODULE << 18U) |
                      SLOT_V1661; break;
        case 13U: mm_extent_capacity = 1U; break;
        case 14U: mm_extent_count = -1; break;
        case 15U: target++; break;
        case 16U: mm_extent_count = 3;
                  mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                  mm_extents[2].meta = (5UL << 18U) | SLOT_V1661;
                  break;
        case 18U: {
                  unsigned int j;
                  mm_extent_count = MM_MAX_EXTENTS;
                  for (j = 2U; j < MM_MAX_EXTENTS; ++j) {
                          mm_extents[j].span =
                              (1UL << 18U) | (0120000UL + j);
                          mm_extents[j].meta =
                              ((kword_t)MM_TYPE_MODULE << 18U) |
                              SLOT_V1661;
                  }
                  break;
        }
        case 19U: mm_extent_count = MM_MAX_EXTENTS + 1; break;
        case 20U: target = APR_BASE_V1664 + 1UL; break;
        case 21U: mm_extents[1].span =
                      ((FULL_V1661 - 1UL) << 18U) | APR_BASE_V1664;
                  break;
        case 22U: mm_extent_count = 3;
                  mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                  mm_extents[2].meta =
                      ((kword_t)MM_TYPE_PROCESS << 18U) | SLOT_V1661;
                  break;
        case 23U: source = 0777700UL; break;
        default: break;
        }
        old0 = mm_extents[0].span;
        meta0 = mm_extents[0].meta;
        old1 = mm_extents[1].span;
        meta1 = mm_extents[1].meta;
        count = mm_extent_count;
        pi_depth_v1661 = 1U;
        rc = mm_pure_bitmap_finish_v1664(SLOT_V1661,
            source, length, target, FULL_V1661);
        pi_depth_v1661 = 0U;
        if (kind == 0U || kind == 12U || kind == 17U || kind == 18U) {
                unsigned int j;
                if (rc != MM_OK ||
                    mm_extent_count != (kind == 18U ?
                        MM_MAX_EXTENTS - 1 :
                        (kind == 12U ? 2 : 1)) ||
                    MM_EXTENT_BASE(&mm_extents[0]) !=
                        (kind == 17U ? 020000UL : APR_BASE_V1664) ||
                    MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
                    MM_EXTENT_PINS(&mm_extents[0]))
                        return 4;
                if (kind == 18U)
                        for (j = 1U; j < MM_MAX_EXTENTS - 1U; ++j)
                                if (mm_extents[j].span !=
                                    ((1UL << 18U) |
                                     (0120000UL + j + 1U)) ||
                                    MM_EXTENT_TYPE(&mm_extents[j]) !=
                                        MM_TYPE_MODULE)
                                        return 6;
        } else if (rc != (kind <= 4U ? MM_ERR_BUSY : MM_ERR_INVAL) ||
            mm_extent_count != count ||
            mm_extents[0].span != old0 ||
            mm_extents[0].meta != meta0 ||
            mm_extents[1].span != old1 ||
            mm_extents[1].meta != meta1)
                return 5;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;
        for (kind = 0U; kind <= 32U; ++kind) {
                rc = restore_case_v1664(kind);
                if (rc != 0)
                        return (int)(05000U + kind * 16U + (unsigned int)rc);
        }
        rc = restore_case_v1664(35U);
        if (rc)
                return 05700 + rc;
        for (kind = 36U; kind <= 39U; ++kind) {
                rc = restore_case_v1664(kind);
                if (rc)
                        return (int)(07000U + (kind - 36U) * 16U +
                            (unsigned int)rc);
        }
        for (kind = 0U; kind <= 23U; ++kind) {
                rc = finish_case_v1664(kind);
                if (rc)
                        return (int)(06000U + kind * 16U + (unsigned int)rc);
        }
        return 0;
}
