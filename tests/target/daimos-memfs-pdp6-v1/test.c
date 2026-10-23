#include "memfs.h"
#include "mm.h"
#include "bstore.h"

static struct memfs fs;
/* MEMFS owner and mtime tables live at fixed offsets after the node area. */
static kword_t metadata[MEMFS_METADATA_WORDS];
static struct memfs_node *node_store = (struct memfs_node *)metadata;
static kword_t pool[02000];
/* Separate aligned extent for the dedicated XIP reservation test. */
kword_t xip_pool[05000];
static int xip_test_mode;
/* Simulate pressure where enough words exist but no aligned gap fits. */
static int xip_alignment_blocked;
static kword_t allocated_base;
static unsigned int extent_pins;
/* v214: fault-inject MM unpin to test failed VM release rollback. */
static int xip_unpin_injected_failure_v214;
#define backing (metadata + MEMFS_BACKING_OFFSET)
static kword_t swap_image[0200];
static int backstore_live;
kword_t backstore_blocks;
static kword_t put[2];
static kword_t got[2];
kword_t daimos_memfs_pdp6_result;
kword_t daimos_memfs_xip_user_base_v209;
static int pool_live;

extern struct memfs memfs_mres_fs;
extern int test_xip_vm_release_v213(kword_t base);
extern int vm_space_destroy(kword_t *vm_descriptor, unsigned int slot);
static kword_t xip_vm_descriptor_v215[3];
extern kword_t test_xip_instruction_template;
extern kword_t test_xip_execute_word(kword_t address);
#ifdef XIP_USER_APR_TEST_V209
extern kword_t test_xip_user_instruction_store_v209;
extern kword_t test_xip_user_instruction_halt_v209;
#endif
extern int test_memfs_dispatch_stat(vnode_t node, struct vfs_stat *st);
extern int test_memfs_dispatch_readdir(vnode_t dir, unsigned int off,
    struct vfs_dirent *ent);
extern int test_vfs_memfs_stat(vnode_t node, struct vfs_stat *st);

#define META_REG_WRITABLE \
    (((kword_t)VFS_TYPE_REG << 15U) | MEMFS_F_USED | MEMFS_F_WRITABLE)
#define DATA(off, words) (((kword_t)(off) << 18U) | (kword_t)(words))

int
vfs_name_valid(const struct vfs_name *name)
{
        (void)name;
        return 1;
}

int
mm_alloc(kword_t words, unsigned int type, unsigned int owner,
    unsigned int preference, kword_t *basep)
{
        (void)preference;
        if (pool_live || words < 0200U ||
            (words & 0177U) != 0U || type != MM_TYPE_KERNEL_DYNAMIC ||
            owner != 011U || basep == 0)
                return MM_ERR_NOMEM;
        if (xip_test_mode) {
                if (words <= 02000U || words > 04000U)
                        return MM_ERR_NOMEM;
                allocated_base =
                    ((kword_t)(unsigned long)xip_pool + 01777UL) &
                    ~01777UL;
        } else {
                if (words > 02000U)
                        return MM_ERR_NOMEM;
                allocated_base = (kword_t)(unsigned long)pool & 0777777UL;
        }
        pool_live = 1;
        *basep = allocated_base;
        return MM_OK;
}

int
mm_pin(kword_t base)
{
        if (!pool_live || base != allocated_base || extent_pins == 255U)
                return MM_ERR_INVAL;
        ++extent_pins;
        return MM_OK;
}

int
mm_alloc_aligned(kword_t words, kword_t alignment, unsigned int type,
    unsigned int owner, unsigned int preference, kword_t *basep)
{
        int rc;
        if (alignment != 02000U || !xip_test_mode)
                return MM_ERR_INVAL;
        if (xip_alignment_blocked)
                return MM_ERR_FRAGMENTED;
        rc = mm_alloc(words, type, owner, preference, basep);
        if (rc == MM_OK && ((*basep & (alignment - 1U)) != 0U))
                return MM_ERR_INVAL;
        return rc;
}

int
mm_unpin(kword_t base)
{
        if (xip_unpin_injected_failure_v214)
                return MM_ERR_BUSY;
        if (!pool_live || base != allocated_base || extent_pins == 0U)
                return MM_ERR_INVAL;
        --extent_pins;
        return MM_OK;
}

int
mm_is_pinned(kword_t base)
{
        return pool_live && base == allocated_base && extent_pins != 0U;
}

int
backstore_alloc(kword_t blocks, kword_t reserve, kword_t *firstp)
{
        if (backstore_live || blocks != 1U || reserve != 0200U || firstp == 0)
                return -1;
        backstore_live = 1;
        *firstp = 1U;
        return 0;
}

void
backstore_free(kword_t first, kword_t blocks)
{
        if (first == 1U && blocks == 1U)
                backstore_live = 0;
}

int
backstore_read(kword_t first, kword_t blocks, kword_t *buf)
{
        unsigned int i;

        if (!backstore_live || first != 1U || blocks != 1U || buf == 0)
                return -1;
        for (i = 0U; i < 0200U; ++i)
                buf[i] = swap_image[i];
        return 0;
}

int
backstore_write(kword_t first, kword_t blocks, const kword_t *buf)
{
        unsigned int i;

        if (!backstore_live || first != 1U || blocks != 1U || buf == 0)
                return -1;
        for (i = 0U; i < 0200U; ++i)
                swap_image[i] = buf[i];
        return 0;
}

int
mm_free(kword_t base, unsigned int type, unsigned int owner)
{
        if (!pool_live || base != allocated_base || extent_pins ||
            type != MM_TYPE_KERNEL_DYNAMIC || owner != 011U)
                return MM_ERR_INVAL;
        pool_live = 0;
        return MM_OK;
}

int
vfs_mount(vnode_t target, unsigned int provider, unsigned int kind,
    unsigned int index, unsigned int flags, vnode_t *rootp)
{
        (void)target;
        (void)provider;
        (void)kind;
        (void)index;
        (void)flags;
        (void)rootp;
        return -1;
}

int memfs_snapshot_mount(struct memfs *m, unsigned int flags)
{ (void)m; return flags == 0U ? 0 : -1; }
int memfs_snapshot_shutdown(void) { return 0; }

int
daimos_memfs_pdp6_test(void)
{
        struct vfs_name name;
        struct vfs_stat st;
        struct vfs_dirent ent;
        vnode_t node;
        vnode_t root;
        vnode_t child;
        int r;
        kword_t xip_base;
        kword_t xip_entry;
        kword_t xip_header[2];
        struct memfs *xip_fs;

        fs.nodes = node_store;
        fs.pool_words = 0200U;
        fs.used_words = 0U;
        pool_live = 0;
        backstore_live = 0;
        backstore_blocks = 1UL;
        memfs_data_init(&fs, fs.pool_words);

        /* Verify that freeing one sector does not release a chunk which still
         * contains another live allocation.  AC0 is not an index register on
         * PDP-6/PDP-10, so the release-mask shift must use a nonzero AC. */
        fs.pool_words = 02000U;
        memfs_mres_fs = fs;
        node_store[1].meta = META_REG_WRITABLE;
        node_store[1].data = DATA(0U, 0U);
        node_store[2].meta = META_REG_WRITABLE;
        node_store[2].data = DATA(0U, 0U);
        node = VFS_NODE(MEMFS_PROVIDER, MEMFS_KIND_NODE, 1U);
        child = VFS_NODE(MEMFS_PROVIDER, MEMFS_KIND_NODE, 2U);
        r = memfs_truncate_words(&fs, node, 1U);
        if (r != 0) return 0140;
        r = memfs_truncate_words(&fs, child, 1U);
        if (r != 0) return 0141;
        if (!pool_live || fs.used_words != 2U) return 0142;
        r = memfs_truncate_words(&fs, node, 0U);
        if (r != 0 || !pool_live || fs.used_words != 1U) return 0143;
        r = memfs_truncate_words(&fs, child, 0U);
        if (r != 0 || pool_live || fs.used_words != 0U) return 0144;
        node_store[1].meta = 0UL;
        node_store[1].data = 0UL;
        node_store[2].meta = 0UL;
        node_store[2].data = 0UL;

        /* KPARSE writes KIR one word at a time.  Grow through several sector
         * boundaries and prove old contents survive each physical resize. */
        fs.pool_words = 02000U;
        memfs_mres_fs = fs;
        node_store[1].meta = META_REG_WRITABLE;
        node_store[1].data = DATA(0U, 0U);
        node = VFS_NODE(MEMFS_PROVIDER, MEMFS_KIND_NODE, 1U);
        for (r = 0; r < 0600; ++r) {
                put[0] = 012340000000UL | (kword_t)(unsigned int)r;
                if (memfs_write_words(&fs, node, (unsigned int)r, put, 1U) != 1)
                        return 0150;
        }
        if (fs.used_words != 0600U) return 0151;
        got[0] = 0UL;
        if (memfs_read_words(&fs, node, 0U, got, 1U) != 1 ||
            got[0] != 012340000000UL) return 0152;
        got[0] = 0UL;
        if (memfs_read_words(&fs, node, 0177U, got, 1U) != 1 ||
            got[0] != (012340000000UL | 0177UL)) return 0153;
        got[0] = 0UL;
        if (memfs_read_words(&fs, node, 0200U, got, 1U) != 1 ||
            got[0] != (012340000000UL | 0200UL)) return 0154;
        got[0] = 0UL;
        if (memfs_read_words(&fs, node, 0577U, got, 1U) != 1 ||
            got[0] != (012340000000UL | 0577UL)) return 0155;
        if (memfs_truncate_words(&fs, node, 0U) != 0 ||
            fs.used_words != 0U || pool_live) return 0156;
        node_store[1].meta = 0UL;
        node_store[1].data = 0UL;
        fs.pool_words = 0200U;

        node_store[0].meta = ((kword_t)VFS_TYPE_DIR << 15U) |
            ((kword_t)0777U << 3U) | MEMFS_F_USED | MEMFS_F_WRITABLE;
        root = VFS_NODE(MEMFS_PROVIDER,
            VFS_MOUNT_KIND(2U, MEMFS_KIND_NODE), 0U);
        r = memfs_stat(&fs, root, &st);
        if (r != 0 || st.type != VFS_TYPE_DIR || st.mode != 0777U)
                return 0100;

        name.chars = 1U;
        name.words[0] = 013000000000UL; /* SIXBIT X */
        name.words[1] = 0UL;
        name.words[2] = 0UL;
        name.words[3] = 0UL;
        r = memfs_mkdir(&fs, root, &name, 0755U, &child);
        if (r != 0 || VFS_INDEX(child) == 0U)
                return 0101;
        r = memfs_stat(&fs, child, &st);
        if (r != 0)
                return 0106;
        if (st.mode != 0755U)
                return 0116;
        if (st.mtime != 012345670123UL)
                return 0126;
        r = memfs_readdir(&fs, root, 0U, &ent);
        if (r != 1 || ent.type != VFS_TYPE_DIR || ent.name.chars != 1U)
                return 0102;

        memfs_mres_fs = fs;
        st.type = 0U;
        st.mode = 0U;
        st.reserved = 0UL;
        st.size_words = 0UL;
        st.uid = 0U;
        st.gid = 0U;
        st.mtime = 0UL;
        r = test_memfs_dispatch_stat(root, &st);
        if (r != 0)
                return 0103;
        if (st.type != VFS_TYPE_DIR)
                return 0122;
        if (st.mode != 0777U)
                return 0123;
        if (st.mtime != 012345670123UL)
                return 0133;
        r = test_memfs_dispatch_readdir(root, 0U, &ent);
        if (r != 1 || ent.type != VFS_TYPE_DIR || ent.name.chars != 1U)
                return 0104;
        r = test_vfs_memfs_stat(root, &st);
        if (r != 0 || st.type != VFS_TYPE_DIR || st.mode != 0777U)
                return 0105;

        node_store[1].meta = META_REG_WRITABLE;
        node_store[1].data = DATA(0U, 0U);
        /* Live VFS mounts embed a nonzero mount id in the vnode kind field.
         * Provider-local validation must ignore those mount-id bits. */
        node = VFS_NODE(MEMFS_PROVIDER,
            VFS_MOUNT_KIND(2U, MEMFS_KIND_NODE), 1U);

        /* This call exercises the PDP-6 stack epilogue in truncate_words. */
        r = memfs_truncate_words(&fs, node, 1U);
        if (r != 0 || fs.used_words != 1U)
                return 1;

        put[0] = 012345670123UL;
        r = memfs_write_words(&fs, node, 0U, put, 1U);
        if (r != 1)
                return 2;
        if ((node_store[1].data >> 18U) == 0UL)
                return 010;
        if (memfs_data_reclaim(1U) == 0UL)
                return 020;
        if (pool_live) return 021;
        if (backing[1] == 0UL) return 022;
        if ((node_store[1].data >> 18U) != 0UL) return 023;

        got[0] = 0U;
        r = memfs_read_words(&fs, node, 0U, got, 1U);
        if (r != 1)
                return 030;
        if (got[0] != put[0])
                return 031;
        if (!pool_live || backing[1] == 0UL)
                return 032;

        r = memfs_truncate_words(&fs, node, 0U);
        if (r != 0 || fs.used_words != 0U || pool_live || backing[1] != 0UL)
                return 4;
        /* A regular small MEMFS file cannot become an XIP allocation. */
        if (memfs_truncate_words(&fs, node, 1U) != 0) return 0160;
        xip_base = 0123456UL;
        memfs_mres_fs = fs;
        if (memfs_xip_pin(&memfs_mres_fs, node, &xip_base) == 0 ||
            xip_base != 0123456UL || extent_pins != 0U) return 0161;
        if (memfs_truncate_words(&fs, node, 0U) != 0) return 0162;

        /* This is a dedicated, aligned file allocation, not an executable.
         * Exercise the pin and mutation/reclaim guards before any EXEC XIP
         * integration exists. Multiple file references share one MM pin. */
        xip_test_mode = 1;
        fs.pool_words = 04000U;
        memfs_mres_fs = fs;
        xip_fs = &memfs_mres_fs;
        xip_alignment_blocked = 1;
        if (memfs_truncate_words(xip_fs, node, 02001U) == 0 ||
            pool_live || xip_fs->used_words != 0U ||
            node_store[1].data != 0UL || memfs_xip_any_pinned())
                return 0201;
        xip_alignment_blocked = 0;
        if (memfs_truncate_words(xip_fs, node, 02001U) != 0)
                return 0163;
        /* A generic large MEMFS file is not automatically an XIP image. */
        xip_entry = 0777UL;
        xip_base = 0777UL;
        if (memfs_xip_admit(xip_fs, node, &xip_base, &xip_entry) == 0 ||
            xip_base != 0777UL || xip_entry != 0777UL ||
            extent_pins != 0U || memfs_xip_any_pinned())
                return 0202;
        xip_header[0] = 054506000000UL;
        xip_header[1] = 020UL;
        if (memfs_write_words(xip_fs, node, 0U, xip_header, 2U) != 2)
                return 0203;
        if (memfs_write_words(xip_fs, node, 020U,
            &test_xip_instruction_template, 1U) != 1)
                return 0206;
#ifdef XIP_USER_APR_TEST_V209
        if (memfs_write_words(xip_fs, node, 021U,
            &test_xip_user_instruction_store_v209, 1U) != 1 ||
            memfs_write_words(xip_fs, node, 022U,
            &test_xip_user_instruction_halt_v209, 1U) != 1)
                return 0210;
#endif
        xip_base = 0UL;
        xip_entry = 0UL;
        /* A magic header alone is insufficient: no write mode, executable. */
        if (memfs_xip_admit(xip_fs, node, &xip_base, &xip_entry) == 0 ||
            extent_pins != 0U || memfs_xip_any_pinned())
                return 0211;
        if (memfs_chmod(xip_fs, node, 0444U) != 0 ||
            memfs_xip_admit(xip_fs, node, &xip_base, &xip_entry) == 0 ||
            extent_pins != 0U || memfs_xip_any_pinned())
                return 0212;
        if (memfs_chmod(xip_fs, node, 0555U) != 0)
                return 0213;
        if (memfs_xip_admit(xip_fs, node, &xip_base, &xip_entry) != 0 ||
            xip_entry != 020UL || extent_pins != 1U ||
            (xip_base & 01777U))
                return 0204;
        if (!memfs_xip_owns_base(xip_base) ||
            memfs_xip_owns_base(xip_base + 1U))
                return 0215;
#ifdef XIP_USER_APR_TEST_V209
        /* This isolated fixture intentionally demonstrates that PDP-6 user
         * relocation DOES NOT enforce immutability of XIP image backing.
         * It is neither safe process startup nor a production executable. */
        daimos_memfs_xip_user_base_v209 = xip_base;
        return 0;
#endif
        /* Actual PDP-6 XCT fetch at the MEMFS-owned physical location. */
        if (test_xip_execute_word(xip_base + xip_entry) != 01234UL ||
            extent_pins != 1U)
                return 0207;
        if (test_xip_vm_release_v213(xip_base + 1U) != 0 ||
            memfs_xip_unpin_base(xip_base + 1U) == 0 ||
            extent_pins != 1U || !memfs_xip_any_pinned())
                return 0214;
        xip_unpin_injected_failure_v214 = 1;
        xip_vm_descriptor_v215[1] = (02000UL << 18U) | xip_base;
        if (vm_space_destroy(xip_vm_descriptor_v215, 1U) == 0 ||
            xip_vm_descriptor_v215[1] != ((02000UL << 18U) | xip_base) ||
            extent_pins != 1U || !memfs_xip_owns_base(xip_base))
                return 0217;
        xip_unpin_injected_failure_v214 = 0;
        if (vm_space_destroy(xip_vm_descriptor_v215, 1U) != 0 ||
            xip_vm_descriptor_v215[1] != 0777777777777UL ||
            extent_pins != 0U ||
            memfs_xip_owns_base(xip_base))
                return 0205;
        if (test_xip_vm_release_v213(xip_base) != 0)
                return 0216;
        xip_base = 0UL;
        if (memfs_xip_pin(xip_fs, node, &xip_base) != 0) return 0172;
        if (!xip_base) return 0173;
        if (xip_base & 01777U) return 0174;
        if (extent_pins != 1U) return 0175;
        if (!memfs_xip_is_pinned(1U)) return 0176;
        if (!memfs_xip_any_pinned()) return 0177;
        if (memfs_xip_pin(xip_fs, node, &xip_base) != 0 || extent_pins != 1U)
                return 0165;
        put[0] = 07777UL;
        if (memfs_write_words(xip_fs, node, 0U, put, 1U) >= 0 ||
            memfs_truncate_words(xip_fs, node, 0U) == 0 ||
            memfs_data_reclaim(02000U) != 0UL || !pool_live)
                return 0166;
        if (memfs_xip_unpin_base(xip_base) != 0 || extent_pins != 1U ||
            !memfs_xip_is_pinned(1U)) return 0167;
        if (memfs_xip_unpin_base(xip_base) != 0 || extent_pins != 0U ||
            memfs_xip_is_pinned(1U) || memfs_xip_any_pinned()) return 0170;
        if (memfs_xip_unpin_base(xip_base) == 0 ||
            memfs_truncate_words(xip_fs, node, 0U) != 0 || pool_live)
                return 0171;
        return 0;
}
