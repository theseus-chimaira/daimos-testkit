/* v1663 native source-linked real MM end-to-end bitmap preparation.
 * The runner prepends v1662's original native test fixture with only
 * its main renamed, because KCC preprocessor forbids nested main
 * macro redefinitions. Original v1662 tests remain untouched.
 */
#include "proc_pure_bitmap_compress_v1663.h"

static int check_raw_v1663(void);

extern int mm_alloc_aligned_noreclaim(kword_t, kword_t,
    unsigned int, unsigned int, unsigned int, kword_t *);

static unsigned int fault_v1663;
static unsigned int calls_alloc_v1663;
static unsigned int calls_pin_v1663;
static unsigned int calls_unpin_v1663;
static unsigned int calls_free_v1663;
static unsigned int calls_encode_v1663;

int
mm_front_alloc_v1663(kword_t words, kword_t align, unsigned int type,
    unsigned int owner, unsigned int preference, kword_t *basep)
{
        int rc;
        ++calls_alloc_v1663;
        if (fault_v1663 == 2U || fault_v1663 == 7U ||
            fault_v1663 == 36U)
                return MM_ERR_NOMEM;
        if (fault_v1663 == 3U)
                return MM_ERR_DESCRIPTORS;
        rc = mm_alloc_aligned_noreclaim(words, align, type, owner,
            preference, basep);
        if (rc != MM_OK)
                return rc;
        if (fault_v1663 == 32U)
                return MM_ERR_NOMEM; /* false refusal after MM insert */
        if (fault_v1663 == 40U) {
                *basep = 01000000UL; /* invalid 18-bit returned base */
                return MM_OK;
        }
        if (fault_v1663 == 9U || fault_v1663 == 25U) {
                /* Original allocator ran. Corrupt its witness to
                 * overlapping geometry, without touching RAW data.
                 */
                *basep = PACKED_BASE_V1661 + 010UL;
                mm_extents[1].span = (words << 18U) | *basep;
        }
        if (fault_v1663 == 26U) {
                mm_extent_count = 3;
                mm_extents[2].span = (10UL << 18U) | EXTRA_BASE_V1662;
                mm_extents[2].meta =
                    ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                    SLOT_V1661;
        }
        return MM_OK;
}

int
mm_front_pin_v1663(kword_t base)
{
        ++calls_pin_v1663;
        if ((base == PACKED_BASE_V1661 && fault_v1663 == 23U) ||
            (base != PACKED_BASE_V1661 &&
             (fault_v1663 == 4U || fault_v1663 == 6U ||
              fault_v1663 == 22U || fault_v1663 == 35U)))
                return MM_ERR_BUSY;
        if (base != PACKED_BASE_V1661 && fault_v1663 == 33U) {
                if (mm_pin(base) != MM_OK)
                        return MM_ERR_INVAL;
                return MM_ERR_BUSY; /* false refusal after actual pin */
        }
        if ((base == PACKED_BASE_V1661 && fault_v1663 == 29U) ||
            (base != PACKED_BASE_V1661 && fault_v1663 == 27U))
                return MM_OK;  /* invalid witness: did not really pin */
        return mm_pin(base);
}

int
mm_front_unpin_v1663(kword_t base)
{
        ++calls_unpin_v1663;
        if (base == PACKED_BASE_V1661 &&
            (fault_v1663 == 7U || fault_v1663 == 21U ||
             fault_v1663 == 24U))
                return MM_ERR_BUSY;
        if (base == PACKED_BASE_V1661 &&
            (fault_v1663 == 34U || fault_v1663 == 36U ||
             fault_v1663 == 37U))
                return MM_OK; /* false success: RAW pin remains */
        if (base != PACKED_BASE_V1661 && fault_v1663 == 5U)
                return MM_ERR_BUSY;
        if (base != PACKED_BASE_V1661 && fault_v1663 == 38U) {
                if (mm_unpin(base) != MM_OK)
                        return MM_ERR_INVAL;
                return MM_ERR_BUSY; /* false refusal after unpin */
        }
        if (base != PACKED_BASE_V1661 && fault_v1663 == 28U)
                return MM_OK; /* invalid witness: still pinned */
        return mm_unpin(base);
}

int
mm_front_free_v1663(kword_t base, unsigned int type,
    unsigned int owner)
{
        ++calls_free_v1663;
        if (fault_v1663 == 20U || fault_v1663 == 22U)
                return MM_ERR_BUSY;
        if (fault_v1663 == 31U || fault_v1663 == 35U)
                return MM_OK; /* false success: candidate still owned */
        return mm_free(base, type, owner);
}

void
bitmap_front_encode_v1663(kword_t source, kword_t words,
    kword_t target)
{
        kword_t *out = (kword_t *)(unsigned long)target;
        ++calls_encode_v1663;
        bitmap_encode_v1451(source, words, target);
        if (fault_v1663 == 8U || fault_v1663 == 20U ||
            fault_v1663 == 21U || fault_v1663 == 31U ||
            fault_v1663 == 37U)
                out[1] ^= 1UL;
        if (fault_v1663 == 19U)
                out[1] = 0UL;
        if (fault_v1663 == 39U)
                storage_v1661[0] =
                    (kword_t)PROC_STORAGE_BITMAP_V1661 << 4U;
}

static void
setup_v1663(void)
{
        struct proc *p;
        kword_t i;
        kword_t *raw;

        prepare_v1662();
        p = &processes_v1661[SLOT_V1661];
        raw = (kword_t *)(unsigned long)PACKED_BASE_V1661;
        p->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        mm_extent_count = 1;
        mm_extents[0].span = (RAW_WORDS_V1662 << 18U) |
            PACKED_BASE_V1661;
        mm_extents[0].meta =
            ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) | SLOT_V1661;
        mm_extents[1].span = 0UL;
        mm_extents[1].meta = 0UL;
        mm_extents[2].span = 0UL;
        mm_extents[2].meta = 0UL;
        mm_arena_count = 1;
        mm_arenas[0] = (010363UL << 18U) | PACKED_BASE_V1661;
        for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                raw[i] = raw_word_v1662(i);
        fault_v1663 = 0U;
        calls_alloc_v1663 = 0U;
        calls_pin_v1663 = 0U;
        calls_unpin_v1663 = 0U;
        calls_free_v1663 = 0U;
        calls_encode_v1663 = 0U;
}

static int
front_case_v1663(unsigned int kind)
{
        struct proc *p = &processes_v1661[SLOT_V1661];
        kword_t *raw = (kword_t *)(unsigned long)PACKED_BASE_V1661;
        kword_t *u = (kword_t *)(unsigned long)UAREA_V1661;
        kword_t encoded = 0UL;
        unsigned int pins, count;
        int rc;

        setup_v1663();
        switch (kind) {
        case 1U: /* no gain: bitmap greater than dense RAW */
        case 24U:
        case 34U:
                {
                        kword_t i;
                        for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                                raw[i] = 0770000UL + i;
                }
                break;
        case 10U: /* duplicate PROCESS/PACKED owner */
                mm_extent_count = 2;
                mm_extents[1].span = (10UL << 18U) | EXTRA_BASE_V1662;
                mm_extents[1].meta =
                    ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                    SLOT_V1661;
                break;
        case 11U: u[PROC_SWAP_BACKING_OFFSET] ^= 1UL; break;
        case 12U: p->sched = (kword_t)PROC_SRUN << PROC_STATE_SHIFT;
                  break;
        case 13U: mm_extents[0].meta += (kword_t)1UL << MM_PIN_SHIFT;
                  break;
        case 14U: storage_v1661[0] =
                    (kword_t)PROC_STORAGE_BITMAP_V1661 << 4U;
                  break;
        case 15U: vfs_mount_root_base = (vnode_t *)0; break;
        case 16U: mm_extent_count = 0; break;
        case 17U: encoded = 1UL; break;
        case 18U: refuse_retire_v1662 = 1U; break;
        case 41U: /* a completely zero RAW image: only 96 masks */
                  {
                          kword_t i;
                          for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                                  raw[i] = 0UL;
                  }
                  break;
        case 42U: mm_extent_capacity = 1U; break;
        case 43U: /* no free physical word after original RAW owner */
                  mm_arenas[0] =
                      (RAW_WORDS_V1662 << 18U) | PACKED_BASE_V1661;
                  break;
        case 30U: mm_extent_count = 2;
                  mm_extents[1].span = (10UL << 18U) |
                      EXTRA_BASE_V1662;
                  mm_extents[1].meta =
                      ((kword_t)MM_TYPE_MODULE << 18U) | SLOT_V1661;
                  break;
        default: break;
        }
        fault_v1663 = kind;
        rc = proc_pure_bitmap_compress_v1663(SLOT_V1661, &encoded);
        if (pi_depth_v1661 || pi_bad_v1662 ||
            !PROC_TRANSITION(p) || !check_raw_v1663() ||
            u[PROC_SWAP_BACKING_OFFSET] !=
                (kind == 11U ? (BACKING_V1661 ^ 1UL) : BACKING_V1661) ||
            swap_v1661[SLOT_V1661].state != BACKING_V1661)
                return 1;
        fault_v1663 = 0U;

        if (kind == 0U || kind == 30U || kind == 41U) {
                kword_t i;
                kword_t *decoded = (kword_t *)(unsigned long)
                    DECODE_BASE_V1662;
                kword_t size = kind == 41U ?
                    RAW_WORDS_V1662 / 36UL : ENCODED_V1662;
                kword_t base = kind == 41U ? 050223UL : 050122UL;
                if (rc != MM_OK || encoded != size ||
                    calls_alloc_v1663 != 1U ||
                    calls_encode_v1663 != 1U ||
                    mm_extent_count != (kind == 30U ? 2 : 1) ||
                    storage_v1661[0] !=
                      ((kword_t)PROC_STORAGE_BITMAP_V1661 << 4U) ||
                    MM_EXTENT_BASE(&mm_extents[0]) != base ||
                    MM_EXTENT_WORDS(&mm_extents[0]) != size ||
                    MM_EXTENT_PINS(&mm_extents[0]))
                        return 2;
                if (kind == 30U &&
                    (MM_EXTENT_TYPE(&mm_extents[1]) != MM_TYPE_MODULE ||
                     MM_EXTENT_OWNER(&mm_extents[1]) != SLOT_V1661))
                        return 3;
                if (proc_pure_bitmap_decode_v1660(base,
                    size, DECODE_BASE_V1662,
                    RAW_WORDS_V1662) != MM_OK)
                        return 4;
                for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                        if (decoded[i] != (kind == 41U ?
                            0UL : raw_word_v1662(i)))
                                return 5;
                if (kind == 0U || kind == 41U) {
                        kword_t reused = 0UL;
                        if (mm_alloc_aligned_noreclaim(02000UL, 1UL,
                            MM_TYPE_KERNEL_DYNAMIC, 0421U,
                            MM_ALLOC_LOW, &reused) != MM_OK ||
                            reused != PACKED_BASE_V1661)
                                return 6;
                        if (mm_free(reused, MM_TYPE_KERNEL_DYNAMIC,
                            0421U) != MM_OK)
                                return 7;
                        p->sched =
                            (kword_t)PROC_ZOMB << PROC_STATE_SHIFT;
                        if (proc_pure_bitmap_terminal_v1661(SLOT_V1661)
                            != MM_OK || mm_extent_count != 0 ||
                            storage_v1661[0] || !PROC_TRANSITION(p))
                                return 8;
                }
                return 0;
        }

        count = 1U;
        pins = 0U;
        switch (kind) {
        case 1U: return rc == PURE_BITMAP_NO_GAIN_V1663 &&
                !encoded && mm_extent_count == 1 &&
                MM_EXTENT_PINS(&mm_extents[0]) == 0U &&
                calls_alloc_v1663 == 0U &&
                storage_v1661[0] == (PROC_STORAGE_PACKED << 4U) ?
                0 : 9;
        case 2U: case 3U: case 4U: case 6U:
        case 8U: case 19U: case 18U: case 23U:
        case 42U: case 43U:
                break;
        case 5U: case 9U: case 20U: case 22U:
        case 26U: case 27U: case 28U:
        case 31U: case 32U: case 33U: case 35U: case 38U:
        case 39U: case 40U:
                count = kind == 26U ? 3U : 2U;
                pins = 1U;
                break;
        case 7U: case 21U: case 24U: case 13U:
        case 34U: case 36U: case 37U:
                pins = 1U;
                break;
        case 10U: count = 2U; break;
        case 30U: count = 2U; break;
        default: break;
        }
        if (kind == 25U) {
                count = 2U;
                pins = 1U;
        }
        if (kind == 16U)
                count = 0U;
        if (kind == 17U && encoded != 1UL)
                return 10;
        if (kind != 17U && encoded)
                return 11;
        if (mm_extent_count != (int)count ||
            (count && MM_EXTENT_PINS(&mm_extents[0]) != pins) ||
            storage_v1661[0] !=
                ((kind == 14U || kind == 39U) ?
                                (PROC_STORAGE_BITMAP_V1661 << 4U) :
                                (PROC_STORAGE_PACKED << 4U)))
                return 12;
        if (count && (MM_EXTENT_BASE(&mm_extents[0]) !=
            PACKED_BASE_V1661 ||
            MM_EXTENT_WORDS(&mm_extents[0]) != RAW_WORDS_V1662))
                return 13;
        if (count >= 2U && kind != 10U && kind != 30U &&
            (MM_EXTENT_TYPE(&mm_extents[1]) !=
                MM_TYPE_PACKED_PROCESS ||
             MM_EXTENT_OWNER(&mm_extents[1]) != SLOT_V1661))
                return 14;
        if (count >= 2U && kind != 10U && kind != 30U &&
            MM_EXTENT_PINS(&mm_extents[1]) !=
                ((kind == 5U || kind == 28U || kind == 33U) ? 1U : 0U))
                return 16;
        {
                int expected = MM_ERR_INVAL;
                if (kind == 2U)
                        expected = MM_ERR_NOMEM;
                else if (kind == 3U || kind == 42U)
                        expected = MM_ERR_DESCRIPTORS;
                else if (kind == 43U)
                        expected = MM_ERR_NOMEM;
                else if (kind == 1U)
                        expected = PURE_BITMAP_NO_GAIN_V1663;
                else if (kind == 4U || kind == 5U || kind == 6U ||
                    kind == 7U || kind == 9U || kind == 18U ||
                    kind == 20U || kind == 21U || kind == 22U ||
                    kind == 23U || kind == 24U || kind == 25U ||
                    kind == 26U || kind == 27U || kind == 28U ||
                    kind == 29U || kind == 31U || kind == 32U ||
                    kind == 33U || kind == 34U || kind == 35U ||
                    kind == 36U || kind == 37U || kind == 38U ||
                    kind == 39U || kind == 40U)
                        expected = MM_ERR_BUSY;
                if (rc != expected)
                        return 15;
        }
        return 0;
}

static int
check_raw_v1663(void)
{
        /* Check every RAW word regardless of MM ownership failures;
         * faults should never modify the authoritative physical RAW.
         */
        kword_t *raw = (kword_t *)(unsigned long)PACKED_BASE_V1661;
        kword_t i;
        for (i = 0UL; i < RAW_WORDS_V1662; ++i)
                if (raw[i] != ((fault_v1663 == 41U) ? 0UL :
                    ((fault_v1663 == 1U ||
                    fault_v1663 == 24U || fault_v1663 == 34U) ?
                    0770000UL + i :
                    raw_word_v1662(i))))
                        return 0;
        return 1;
}

int
main(void)
{
        unsigned int i;
        int rc;
        for (i = 0U; i <= 43U; ++i) {
                rc = front_case_v1663(i);
                if (rc)
                        return (int)(04000U + i * 16U + (unsigned int)rc);
        }
        return 0;
}
