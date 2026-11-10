/*
 * Native PDP-6 tests link the actual v1384 MM claim/release/commit ASM,
 * the actual KCC prefix transaction and existing v1381 zero-copy DROP.
 * MM allocator/PI and immutable-provider payload are controlled fixtures.
 */
#include "mm_pure_rebase_v1381.h"
#define main retired_main_v1379
#define proc_pure_ram_drop_v1379 proc_pure_ram_drop_v1381
#define proc_pure_ram_restore_v1379 proc_pure_ram_restore_v1381
#define proc_pure_ram_discard_v1379 proc_pure_ram_discard_v1381
#define mm_alloc_aligned_noreclaim mm_alloc_fixture_v1381
#define mm_free mm_free_fixture_v1381
#include "test-native-v1379.c"
#undef main
#undef proc_pure_ram_drop_v1379
#undef proc_pure_ram_restore_v1379
#undef proc_pure_ram_discard_v1379
#undef mm_alloc_aligned_noreclaim
#undef mm_free
#define NATIVE_BASE_IN_V1384 1
#define NATIVE_NO_MAIN_V1384 1
#include "test-native-v1381.c"

/* Keep KCC's old 8-level include limit intact in this nested test fixture.
 * The compiled production candidate includes both authoritative headers.
 */
extern int mm_pure_claim_prefix_v1384(kword_t, unsigned int,
    kword_t, kword_t);
extern int mm_pure_release_prefix_v1384(kword_t, unsigned int,
    kword_t, kword_t);
extern int mm_pure_commit_prefix_v1384(kword_t, unsigned int,
    kword_t, kword_t);
extern int proc_pure_restore_v1384(unsigned int,
    int (*)(kword_t, kword_t, kword_t, kword_t));
#define PROC_PURE_PREFIX_FALLBACK_V1384 1

/* The low-level MM test fixture otherwise does not need arena geometry. */
kword_t mm_arenas[MM_MAX_ARENAS];
int mm_arena_count;

static int fail_plain_v1384;
static unsigned int prefix_reads_v1384;
kword_t diag_release_v1384;
kword_t diag_extent_span_v1384;
kword_t diag_extent_meta_v1384;

static int
prefix_plain_v1384(kword_t backing, kword_t base, kword_t uarea,
    kword_t prefix)
{
        kword_t *dest = (kword_t *)(unsigned long)base;
        unsigned int i;
        ++prefix_reads_v1384;
        if (backing != BACKING || uarea != UAREA || prefix != OMIT ||
            pi_depth_v1381)
                return -1;
        if (fail_plain_v1384 == 2)
                return -2;           /* requires full-image codec */
        for (i = 020U; i < prefix; ++i) {
                dest[i] = TEXT_PATTERN;
                if (fail_plain_v1384 == 1 && i == 040U)
                        return -1;   /* partial I/O cannot publish */
        }
        return 0;
}

static void
reset_prefix_v1384(void)
{
        unsigned int i;
        struct proc *p = &process_slots[SLOT];
        kword_t *source = (kword_t *)(unsigned long)SOURCE;
        kword_t *uarea = (kword_t *)(unsigned long)UAREA;
        mm_extent_count = 0;
        add_extent(SOURCE, WORDS, MM_TYPE_PROCESS);
        mm_arena_count = 1;
        mm_arenas[0] = ((kword_t)040000UL << 18U) | 040000UL;
        for (i = 0U; i < WORDS; ++i)
                source[i] = i < OMIT ? TEXT_PATTERN : PATTERN + i;
        for (i = 0U; i < PROC_UAREA_WORDS; ++i)
                uarea[i] = 0UL;
        for (i = 0U; i < PROC_STORAGE_MAP_WORDS_V28(SLOTS); ++i)
                mode_words[i] = 0UL;
        proc_storage_runtime_v29.words = mode_words;
        proc_storage_runtime_v29.slots = SLOTS;
        p->meta = (UAREA << PROC_HALF_SHIFT) |
            ((kword_t)(PROC_F_UAREA | PROC_F_TRANSITION) <<
                PROC_FLAGS_SHIFT);
        p->vm_state = (WORDS << PROC_HALF_SHIFT) | SOURCE;
        p->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        swap_slots[SLOT].state = BACKING;
        refuse_restore_alloc = 0;
        pi_depth_v1381 = 0U;
        pi_disable_count_v1381 = 0U;
        pi_restore_count_v1381 = 0U;
        alloc_count_v1381 = 0U;
        free_count_v1381 = 0U;
        prefix_reads_v1384 = 0U;
        fail_plain_v1384 = 0;
}

static int
check_suffix_v1384(void)
{
        unsigned int i;
        kword_t *s = (kword_t *)(unsigned long)(SOURCE + OMIT);
        for (i = 0U; i < SUFFIX; ++i)
                if (s[i] != PATTERN + OMIT + i)
                        return 0;
        return 1;
}

static int
test_negative_mm_v1384(void)
{
        kword_t old_span, old_meta;
        int rc;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        if (mm_pin(SOURCE + OMIT) != MM_OK)
                return 2;
        old_span = mm_extents[0].span;
        old_meta = mm_extents[0].meta;
        rc = mm_pure_claim_prefix_v1384(SOURCE + OMIT, SLOT + 1U,
            OMIT, WORDS);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 3;
        rc = mm_pure_claim_prefix_v1384(SOURCE + OMIT, SLOT,
            OMIT + 1U, WORDS);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 4;
        rc = mm_pure_claim_prefix_v1384(SOURCE + OMIT, SLOT,
            OMIT, WORDS + 02000UL);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 5;
        if (mm_pin(SOURCE + OMIT) != MM_OK)
                return 6;
        old_meta = mm_extents[0].meta;
        rc = mm_pure_claim_prefix_v1384(SOURCE + OMIT, SLOT,
            OMIT, WORDS);
        if (rc != MM_ERR_BUSY ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 7;
        if (mm_unpin(SOURCE + OMIT) != MM_OK ||
            mm_unpin(SOURCE + OMIT) != MM_OK)
                return 8;
        if (mm_pin(SOURCE + OMIT) != MM_OK)
                return 9;
        mm_arena_count = 0;
        old_meta = mm_extents[0].meta;
        rc = mm_pure_claim_prefix_v1384(SOURCE + OMIT, SLOT,
            OMIT, WORDS);
        if (rc != MM_ERR_FRAGMENTED ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 10;
        mm_arena_count = 1;
        rc = mm_pure_claim_prefix_v1384(SOURCE + OMIT, SLOT,
            OMIT, WORDS);
        diag_release_v1384 = (kword_t)rc;
        diag_extent_span_v1384 = mm_extents[0].span;
        diag_extent_meta_v1384 = mm_extents[0].meta;
        if (rc != MM_OK ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE ||
            MM_EXTENT_WORDS(&mm_extents[0]) != WORDS ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS)
                return 11;
        old_span = mm_extents[0].span;
        old_meta = mm_extents[0].meta;
        rc = mm_pure_commit_prefix_v1384(SOURCE, SLOT + 1U,
            OMIT, WORDS);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 12;
        rc = mm_pure_release_prefix_v1384(SOURCE, SLOT, OMIT, WORDS);
        diag_release_v1384 = (kword_t)rc;
        diag_extent_span_v1384 = mm_extents[0].span;
        diag_extent_meta_v1384 = mm_extents[0].meta;
        if (rc != MM_OK)
                return 13;
        if (MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT)
                return 15;
        if (
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX)
                return 16;
        if (mm_unpin(SOURCE + OMIT) != MM_OK)
                return 14;
        return 0;
}

static int
test_fast_v1384(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *image = (kword_t *)(unsigned long)SOURCE;
        unsigned int i;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        if (proc_pure_restore_v1384(SLOT,
            prefix_plain_v1384) != MM_OK)
                return 2;
        if (VM_PDP6_BASE(p) != SOURCE || mm_extent_count != 1 ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE ||
            MM_EXTENT_WORDS(&mm_extents[0]) != WORDS ||
            PROC_TRANSITION(p) || alloc_count_v1381 ||
            free_count_v1381 || prefix_reads_v1384 != 1U ||
            pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 3;
        for (i = 020U; i < WORDS; ++i)
                if (image[i] !=
                    (i < OMIT ? TEXT_PATTERN : PATTERN + i))
                        return 4;
        return 0;
}

static int
test_rollback_v1384(int unsupported)
{
        struct proc *p = &process_slots[SLOT];
        int expected = unsupported ? PROC_PURE_PREFIX_FALLBACK_V1384 :
            MM_ERR_INVAL;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        fail_plain_v1384 = unsupported ? 2 : 1;
        if (proc_pure_restore_v1384(SLOT,
            prefix_plain_v1384) != expected)
                return 2;
        if (mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            VM_PDP6_BASE(p) || !PROC_TRANSITION(p) ||
            !check_suffix_v1384() || pi_depth_v1381)
                return 3;
        fail_plain_v1384 = 0;
        if (proc_pure_restore_v1384(SLOT,
            prefix_plain_v1384) != MM_OK)
                return 4;
        return 0;
}

static int
test_blocked_gap_v1384(void)
{
        struct proc *p = &process_slots[SLOT];
        struct mm_extent suffix;
        int rc;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        suffix = mm_extents[0];
        mm_extents[1] = suffix;
        mm_extents[0].span = ((kword_t)0200UL << 18U) | SOURCE;
        mm_extents[0].meta = ((kword_t)MM_TYPE_KERNEL_DYNAMIC <<
            MM_TYPE_SHIFT) | 7UL;
        mm_extent_count = 2;
        PROC_SET_TRANSITION(p);
        rc = proc_pure_restore_v1384(SLOT,
            prefix_plain_v1384);
        if (rc != PROC_PURE_PREFIX_FALLBACK_V1384 ||
            prefix_reads_v1384 || mm_extent_count != 2 ||
            MM_EXTENT_BASE(&mm_extents[1]) != SOURCE + OMIT ||
            MM_EXTENT_PINNED(&mm_extents[1]) ||
            !check_suffix_v1384())
                return 2;
        if (proc_pure_ram_restore_v1381(SLOT, reload) != MM_OK ||
            VM_PDP6_BASE(p) != RESTORE || mm_extent_count != 2)
                return 3;
        return 0;
}

#ifdef DAIMOS_TEST_PLAIN_DXR_V1385
/* Exact public exec.h values, without another nested legacy KCC include. */
#define EXEC_DXR_F_PURE 0200000UL
#define EXEC_DXR_F_COMPRESSED 0100000UL
#define EXEC_DXR_TEXT_TAG 0647022UL
/*
 * Link the real proc_swap_unpack_backing and a controlled immutable VFS
 * reader. The C test does not simulate the prefix decoder: it calls the
 * compiled PDP-6 assembler plain DXR2 frontend.
 */
extern int proc_pure_prefix_plain_v1385(kword_t, kword_t, kword_t,
    kword_t);
#ifdef DAIMOS_TEST_SHARED_IMAGE_V1387
extern int exec_image_prefix_backing_v1386(kword_t, kword_t, kword_t,
    kword_t);
#define proc_pure_prefix_plain_v1385 exec_image_prefix_backing_v1386
#endif
static vnode_t roots_v1385[26];
vnode_t *vfs_mount_root_base = roots_v1385;
kword_t vfs_mount_limit = 26UL;
static int read_mode_v1385;
static unsigned int payload_reads_v1385;
static unsigned int header_reads_v1385;
vnode_t expected_vnode_v1385;
vnode_t observed_vnode_v1385;
kword_t observed_mount_ext_v1385;
kword_t observed_plain_rc_v1385;

int
vfs_read_words(vnode_t node, unsigned int off, kword_t *buf,
    unsigned int count)
{
        unsigned int i;
        observed_vnode_v1385 = node;
        if (node != expected_vnode_v1385)
                return -1;
        if (off == 0U &&
            (count == 3U
#ifdef DAIMOS_TEST_SHARED_IMAGE_V1387
             || count == 2U
#endif
             )) {
                ++header_reads_v1385;
                buf[0] = ((kword_t)0447062UL << 18U);
                buf[1] = ((kword_t)TEXT << 18U) |
                    EXEC_DXR_F_PURE |
                    (read_mode_v1385 == 2 ? EXEC_DXR_F_COMPRESSED : 0UL);
                buf[2] = ((kword_t)TEXT << 18U) |
                    (read_mode_v1385 == 3 ? 0UL : EXEC_DXR_TEXT_TAG);
                return (int)count;
        }
#ifdef DAIMOS_TEST_SHARED_IMAGE_V1387
        if (off == 2U && count == 1U) {
                buf[0] = ((kword_t)TEXT << 18U) |
                    (read_mode_v1385 == 3 ? 0UL : EXEC_DXR_TEXT_TAG);
                return 1;
        }
#endif
        if (off == 3U && count == OMIT - 020U) {
                ++payload_reads_v1385;
                if (buf != (kword_t *)(unsigned long)(SOURCE + 020UL))
                        return -1;
                for (i = 0U; i < count; ++i) {
                        buf[i] = TEXT_PATTERN;
                        if (read_mode_v1385 == 1 && i == 010U)
                                return (int)i;
                }
                return (int)count;
        }
        return -1;
}

#ifdef DAIMOS_TEST_SHARED_IMAGE_V1387
/* The real shared inspector uses the provider's actual file size.
 * The test's executable is otherwise identical to the plain v1385 case.
 */
int
vfs_stat(vnode_t node, struct vfs_stat *stat)
{
        if (node != expected_vnode_v1385)
                return -1;
        stat->type = 2U;               /* regular executable */
        stat->mode = 0U;
        stat->reserved = 0UL;
        stat->size_words = 3UL + (read_mode_v1385 == 2 ? 2UL :
            (kword_t)TEXT) + (((kword_t)TEXT + 043UL) / 044UL);
        stat->uid = 0U;
        stat->gid = 0U;
        stat->mtime = 0UL;
        return 0;
}

int
d6lz36_decode_vfs(kword_t vnode, unsigned int off,
    unsigned int words, kword_t packed)
{
        (void)vnode;
        (void)off;
        (void)words;
        (void)packed;
        /* PURE_PREFIX must never invoke an unbounded full-image decoder. */
        return -1;
}
#endif

static int
test_plain_loader_v1385(unsigned int mode, unsigned int mount)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *uarea = (kword_t *)(unsigned long)UAREA;
        unsigned int i;
        kword_t state;
        int rc;
        reset_prefix_v1384();
        for (i = 0U; i < 26U; ++i)
                roots_v1385[i] = 0UL;
        roots_v1385[mount - 1U] = VFS_NODE(6U,
            VFS_MOUNT_KIND(mount, 1U), 1U);
        expected_vnode_v1385 = VFS_NODE(6U,
            VFS_MOUNT_KIND(mount, 1U), 012345U);
        state = ((kword_t)TEXT << PROC_SWAP_TEXT_SHIFT) |
            (((kword_t)(mount - 1U) & PROC_SWAP_MOUNT_MASK) <<
                PROC_SWAP_MOUNT_SHIFT) | 012345UL;
        swap_slots[SLOT].state = state;
        if (mount > 16U)
                uarea[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        read_mode_v1385 = (int)mode;
        observed_vnode_v1385 = 0UL;
        observed_mount_ext_v1385 = uarea[PROC_CRED_OFFSET];
        payload_reads_v1385 = header_reads_v1385 = 0U;
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        rc = proc_pure_restore_v1384(SLOT,
            proc_pure_prefix_plain_v1385);
        observed_plain_rc_v1385 = (kword_t)rc;
        if (mode == 0U) {
                if (rc != MM_OK)
                        return 2;
                if (VM_PDP6_BASE(p) != SOURCE)
                        return 6;
                if (payload_reads_v1385 != 1U)
                        return 7;
                if (header_reads_v1385 != 1U)
                        return 8;
                if (!check_suffix_v1384())
                        return 9;
        } else {
                if (rc != (mode == 2U ?
                    PROC_PURE_PREFIX_FALLBACK_V1384 : MM_ERR_INVAL) ||
                    VM_PDP6_BASE(p) ||
                    MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
                    MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
                    MM_EXTENT_PINNED(&mm_extents[0]) ||
                    !check_suffix_v1384())
                        return 3;
                if (mode == 2U && payload_reads_v1385 != 0U)
                        return 4;
                /* Fallback must remain valid, even after a failed read. */
                if (proc_pure_ram_restore_v1381(SLOT, reload) != MM_OK ||
                    VM_PDP6_BASE(p) != RESTORE)
                        return 5;
        }
        return 0;
}
#endif

int
main(void)
{
        int rc = test_negative_mm_v1384();
        if (rc)
                return 0100 + rc;
        rc = test_fast_v1384();
        if (rc)
                return 0200 + rc;
        rc = test_rollback_v1384(0);
        if (rc)
                return 0300 + rc;
        rc = test_rollback_v1384(1);
        if (rc)
                return 0400 + rc;
        rc = test_blocked_gap_v1384();
        if (rc)
                return 0500 + rc;
#ifdef DAIMOS_TEST_PLAIN_DXR_V1385
        rc = test_plain_loader_v1385(0U, 1U);
        if (rc)
                return 0600 + rc;
        rc = test_plain_loader_v1385(0U, 18U);
        if (rc)
                return 0700 + rc;
        rc = test_plain_loader_v1385(1U, 1U);
        if (rc)
                return 01000 + rc;
        rc = test_plain_loader_v1385(2U, 1U);
        if (rc)
                return 01100 + rc;
        rc = test_plain_loader_v1385(3U, 1U);
        if (rc)
                return 01200 + rc;
#endif
        return 0;
}
