#include "memfs.h"
#include "mm.h"
#include "bstore.h"

static struct memfs fs;
/* MEMFS owner and mtime tables live at fixed offsets after the node area. */
static kword_t metadata[MEMFS_METADATA_WORDS];
static struct memfs_node *node_store = (struct memfs_node *)metadata;
static kword_t pool[02000];
static kword_t backing[0100];
static kword_t swap_image[0200];
static int backstore_live;
kword_t backstore_blocks;
static kword_t put[2];
static kword_t got[2];
kword_t daimos_memfs_pdp6_result;
static int pool_live;

extern struct memfs memfs_mres_fs;
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
        if (pool_live || words < 0200U || words > 02000U ||
            (words & 0177U) != 0U || type != MM_TYPE_KERNEL_DYNAMIC ||
            owner != 011U || basep == 0)
                return MM_ERR_NOMEM;
        pool_live = 1;
        *basep = (kword_t)(unsigned long)pool & 0777777UL;
        return MM_OK;
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
        if (!pool_live || base != ((kword_t)(unsigned long)pool & 0777777UL) ||
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

        fs.nodes = node_store;
        fs.pool = backing;
        fs.pool_words = 0200U;
        fs.used_words = 0U;
        pool_live = 0;
        backstore_live = 0;
        backstore_blocks = 1UL;
        memfs_data_init(&fs, fs.pool_words);

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
        return 0;
}
