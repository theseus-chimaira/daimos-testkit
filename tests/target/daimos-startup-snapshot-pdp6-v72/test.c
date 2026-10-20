/* Native PDP-6 correctness oracle for exact-size, resident startup snapshots.
 * Uses a real 36-bit process/u-area layout, not host byte-address emulation. */
#include "proc.h"
#include "proc_swap.h"
#include "exec.h"
#include "vm_pdp6.h"
#include "mm.h"

#define TEST_SNAP_WORDS 15UL
#define TEST_SNAP_OWNER 02001U

static struct proc test_proc[2];
static kword_t test_uarea[PROC_UAREA_WORDS];
static kword_t test_image[2U * EXEC_DXR_STACK_WORDS];
static kword_t test_copy[0100];
static unsigned int test_pinned = 1U;
static unsigned int test_alloc_fail;
static unsigned int test_alloc_count;
static unsigned int test_free_count;
static unsigned int test_invariant;

struct proc *proc_table = test_proc;
unsigned int proc_slots = 2U;
kword_t daimos_snap_result_v72;

extern kword_t proc_snap_words_v72;
extern int proc_snap_take_v72(unsigned int slot);
extern void proc_snap_drop_v72(unsigned int slot);

int
mm_is_pinned(kword_t base)
{
        return base == (kword_t)(unsigned long)test_image && test_pinned;
}

int
mm_alloc_aligned_noreclaim(kword_t words, kword_t alignment,
    unsigned int type, unsigned int owner, unsigned int preference,
    kword_t *basep)
{
        if (test_alloc_fail || words != TEST_SNAP_WORDS ||
            alignment != 1UL || type != MM_TYPE_KERNEL_DYNAMIC ||
            owner != TEST_SNAP_OWNER || preference != MM_ALLOC_LOW ||
            basep == 0)
                return MM_ERR_NOMEM;
        *basep = (kword_t)(unsigned long)test_copy;
        ++test_alloc_count;
        return MM_OK;
}

int
mm_free(kword_t base, unsigned int type, unsigned int owner)
{
        if (base != (kword_t)(unsigned long)test_copy ||
            type != MM_TYPE_KERNEL_DYNAMIC || owner != TEST_SNAP_OWNER)
                return MM_ERR_INVAL;
        ++test_free_count;
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
proc_swap_storage_invariant_v30(void)
{
        ++test_invariant;
}

int
daimos_snap_target_v72(void)
{
        kword_t *v;
        kword_t original[14];
        unsigned int i;

        test_proc[1].meta =
            ((kword_t)(unsigned long)test_uarea << PROC_HALF_SHIFT) |
            ((kword_t)PROC_F_UAREA << PROC_FLAGS_SHIFT);
        test_proc[1].vm_state =
            ((kword_t)(2U * EXEC_DXR_STACK_WORDS) << PROC_HALF_SHIFT) |
            (kword_t)(unsigned long)test_image;
        v = &test_image[EXEC_DXR_STACK_WORDS];
        v[0] = ((kword_t)1UL << PROC_HALF_SHIFT) | 2UL;
        v[1] = EXEC_DXR_STACK_WORDS + 5UL;  /* argv[0] */
        v[2] = EXEC_DXR_STACK_WORDS + 9UL;  /* env[0] */
        v[3] = EXEC_DXR_STACK_WORDS + 11UL; /* env[1] */
        v[4] = 0UL;                   /* env terminator */
        v[5] = 18UL;
        v[6] = 0123456701234UL;
        v[7] = 0345670123456UL;
        v[8] = 0567012345670UL;
        v[9] = 6UL;
        v[10] = 0123456701234UL;
        v[11] = 12UL;
        v[12] = 0765432107654UL;
        v[13] = 0654321076543UL;
        for (i = 0U; i < 14U; ++i)
                original[i] = v[i];

        if (proc_snap_take_v72(1U) != 0 ||
            test_alloc_count != 1U ||
            PROC_STARTUP_SNAPSHOT_WORD(&test_proc[1]) !=
                (kword_t)(unsigned long)test_copy ||
            test_copy[0] != TEST_SNAP_WORDS ||
            proc_snap_words_v72 != TEST_SNAP_WORDS)
                return 1;
        for (i = 0U; i < 14U; ++i) {
                kword_t want;
                want = original[i];
                if (i >= 1U && i <= 3U)
                        want -= EXEC_DXR_STACK_WORDS;
                if (test_copy[1U + i] != want)
                        return 2;
        }
        /* The original image can disappear without invalidating argv/envp. */
        test_proc[1].vm_state &= ~PROC_HALF_MASK;
        if (test_copy[2] != 5UL || test_copy[3] != 9UL ||
            test_copy[4] != 11UL)
                return 3;
        proc_snap_drop_v72(1U);
        if (PROC_STARTUP_SNAPSHOT_WORD(&test_proc[1]) != 0UL ||
            proc_snap_words_v72 != 0UL || test_free_count != 1U ||
            test_invariant != 0U)
                return 4;

        test_proc[1].vm_state |= (kword_t)(unsigned long)test_image;
        v[2] = 8UL;                   /* reject a nonsequential pointer */
        if (proc_snap_take_v72(1U) == 0 || test_alloc_count != 1U)
                return 5;
        v[2] = 9UL;
        test_alloc_fail = 1U;
        if (proc_snap_take_v72(1U) == 0 || test_alloc_count != 1U)
                return 6;
        test_alloc_fail = 0U;
        test_pinned = 0U;
        if (proc_snap_take_v72(1U) == 0 || test_alloc_count != 1U)
                return 7;
        return 0;
}
