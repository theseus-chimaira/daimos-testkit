#include "memfs.h"
#include "mm.h"

static struct memfs fs;
/* MEMFS owner and mtime tables live at fixed offsets after the node area. */
static kword_t metadata[MEMFS_METADATA_WORDS];
static struct memfs_node *node_store = (struct memfs_node *)metadata;
static const kword_t data_word = 012345670123UL;
kword_t daimos_memfs_fifo_pdp6_result;

#define META_DIR_WRITABLE \
    (((kword_t)VFS_TYPE_DIR << 15U) | MEMFS_F_USED | MEMFS_F_WRITABLE)

int
vfs_name_valid(const struct vfs_name *name)
{
        return name != 0 && name->chars != 0U;
}

int
memfs_resize(struct memfs *mfs, unsigned int slot, unsigned int words)
{
        (void)mfs;
        (void)slot;
        (void)words;
        return -1;
}

int
mm_alloc(kword_t words, unsigned int type, unsigned int owner,
    unsigned int preference, kword_t *basep)
{
        (void)words; (void)type; (void)owner; (void)preference; (void)basep;
        return MM_ERR_NOMEM;
}

int
mm_free(kword_t base, unsigned int type, unsigned int owner)
{
        (void)base; (void)type; (void)owner;
        return MM_ERR_INVAL;
}

void memfs_data_init(struct memfs *fs, kword_t limit) { (void)fs; (void)limit; }
int memfs_snapshot_mount(struct memfs *fs, unsigned int flags)
{ (void)fs; return flags == 0U ? 0 : -1; }
int memfs_snapshot_shutdown(void) { return 0; }
void memfs_data_destroy(void) { }
int memfs_data_ensure(struct memfs *fs, unsigned int slot)
{ (void)fs; (void)slot; return 0; }
void memfs_data_dirty(unsigned int slot) { (void)slot; }

int
vfs_mount(vnode_t target, unsigned int provider, unsigned int kind,
    unsigned int index, unsigned int flags, vnode_t *rootp)
{
        (void)target; (void)provider; (void)kind; (void)index;
        (void)flags; (void)rootp;
        return -1;
}

int
daimos_memfs_fifo_pdp6_test(void)
{
        struct vfs_name name;
        struct vfs_name renamed;
        struct vfs_stat st;
        vnode_t root;
        vnode_t node;
        unsigned int i;
        int r;

        fs.nodes = node_store;
        fs.pool_words = 8U;
        fs.used_words = 0U;

        node_store[1].meta = META_DIR_WRITABLE;
        root = VFS_NODE(MEMFS_PROVIDER, MEMFS_KIND_NODE, 1U);

        name.chars = 4U;
        for (i = 0U; i < VFS_NAME_WORDS; ++i)
                name.words[i] = 0;
        name.words[0] = 0302223151700UL; /* PIPE in SIXBIT field. */
        renamed = name;
        renamed.words[0] = 0302223156200UL; /* PIPX in SIXBIT field. */

        r = memfs_mkfifo(&fs, root, &name, 0640U, &node);
        if (r != 0 || fs.used_words != 0U)
                return 1;
        if (((node_store[2].meta >> 15U) & 07UL) != VFS_TYPE_FIFO)
                return 050 + (int)((node_store[2].meta >> 15U) & 07UL);
        r = memfs_stat(&fs, node, &st);
        if (r != 0)
                return 020;
        if (st.type != VFS_TYPE_FIFO)
                return 040 + (int)st.type;
        if (st.mode != 0640U)
                return 022;
        if (st.size_words != 0)
                return 023;

        r = memfs_write_words(&fs, node, 0U, &data_word, 1U);
        if (r >= 0 || fs.used_words != 0U)
                return 3;
        r = memfs_truncate_words(&fs, node, 1U);
        if (r >= 0 || fs.used_words != 0U)
                return 4;

        r = memfs_rename(&fs, root, &name, root, &renamed);
        if (r != 0)
                return 5;
        r = memfs_lookup(&fs, root, &name, &node);
        if (r >= 0)
                return 6;
        r = memfs_lookup(&fs, root, &renamed, &node);
        if (r != 0)
                return 7;

        r = memfs_unlink(&fs, root, &renamed);
        if (r != 0 || fs.used_words != 0U)
                return 8;
        r = memfs_lookup(&fs, root, &renamed, &node);
        if (r >= 0)
                return 9;
        return 0;
}
