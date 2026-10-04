#include "dtfs.h"

int __test_exit;
kword_t *dtfs_dir;
kword_t fs_block_workspace[0200];
kword_t dtfs_cache_mount;

static kword_t dirbuf[0200];
static struct vfs_name name;
static unsigned int personality;
static unsigned int found_slot;
static unsigned int blocks;
static unsigned int first_block;
static int wrong_owner;
static int read_fail;
static int resize_fail;
static int commit_fail;
static int clear_calls;
static int resize_calls;
static vnode_t seen_resize_node;
static int read_calls;
static int free_calls;
static unsigned int freed_block[4];
static int commit_calls;

int dtfs_is_root(vnode_t node) { (void)node; return 1; }
int dtfs_load(vnode_t node) { (void)node; return 0; }

int
dtfs_scan_slot(vnode_t dir, const struct vfs_name *n, unsigned int *slotp)
{
        (void)dir;
        if (n != &name || slotp == 0)
                return -1;
        *slotp = found_slot;
        return 0;
}

unsigned int dtfs_personality(vnode_t node) { (void)node; return personality; }

unsigned int
dtfs_block_info(vnode_t node, unsigned int slot, unsigned int *blockp)
{
        vnode_t want;
        want = VFS_NODE_PACKED(DTFS_PROVIDER,
            (1U << VFS_MOUNT_SHIFT) | DTFS_KIND_FILE, found_slot);
        if (node != want || slot != found_slot)
                return 0U;
        *blockp = first_block;
        return blocks;
}

unsigned int
dtfs_owner(unsigned int mapword, unsigned int index)
{
        (void)mapword;
        (void)index;
        return wrong_owner ? 077U : found_slot + 1U;
}

unsigned int dtfs_unit(vnode_t node) { (void)node; return 3U; }

int
dtfs_dtc_read(unsigned int unit, unsigned int block, kword_t *buf)
{
        ++read_calls;
        if (unit != 3U || buf != fs_block_workspace || read_fail)
                return -1;
        if (block == first_block)
                buf[0] = (kword_t)(first_block + 1U) << 18U;
        else if (block == first_block + 1U)
                buf[0] = 0UL;
        else
                return -1;
        return 0;
}

void
dtfs_set_owner(unsigned int mapword, unsigned int index, unsigned int owner)
{
        (void)mapword;
        if (owner == 0U && free_calls < 4)
                freed_block[free_calls] = index;
        if (owner == 0U)
                ++free_calls;
}

int
dtfs_resize(vnode_t node, unsigned int words)
{
        ++resize_calls;
        seen_resize_node = node;
        if (words != 0U)
                return -1;
        return resize_fail ? -1 : 0;
}

void dtfs_clear_slot(unsigned int slot) { if (slot == found_slot) ++clear_calls; }

int
dtfs_commit(vnode_t node)
{
        (void)node;
        ++commit_calls;
        return commit_fail ? -1 : 0;
}

static vnode_t
root_node(void)
{
        return VFS_NODE_PACKED(DTFS_PROVIDER,
            (1U << VFS_MOUNT_SHIFT) | DTFS_KIND_ROOT, 0U);
}

static vnode_t
file_node(void)
{
        return VFS_NODE_PACKED(DTFS_PROVIDER,
            (1U << VFS_MOUNT_SHIFT) | DTFS_KIND_FILE, found_slot);
}

static void
reset(unsigned int media)
{
        unsigned int i;
        personality = media;
        found_slot = 5U;
        blocks = 2U;
        first_block = 0200U;
        wrong_owner = read_fail = resize_fail = commit_fail = 0;
        clear_calls = resize_calls = read_calls = free_calls = commit_calls = 0;
        seen_resize_node = 0UL;
        dtfs_cache_mount = 7UL;
        for (i = 0U; i != 0200U; ++i)
                dirbuf[i] = 0UL;
        dtfs_dir = dirbuf;
        dirbuf[0123U + found_slot] = 0111UL;
        dirbuf[0151U + found_slot] = 0222UL;
        dirbuf[found_slot * 2U] = 0333UL;
        dirbuf[found_slot * 2U + 1U] = 0444UL;
}

int
main(void)
{
        vnode_t root;

        root = root_node();

        reset(0U);
        if (dtfs_unlink(root, &name) != 0 || resize_calls != 1 ||
            seen_resize_node != file_node() || clear_calls != 1 || commit_calls != 1)
                return 1;

        reset(020U);                    /* ITS */
        if (dtfs_unlink(root, &name) != 0 || resize_calls != 1 ||
            dirbuf[found_slot * 2U] != 0UL ||
            dirbuf[found_slot * 2U + 1U] != 0UL || commit_calls != 1)
                return 2;

        reset(010U);                    /* TENEX two-block chain */
        if (dtfs_unlink(root, &name) != 0 || read_calls != 2 || free_calls != 2 ||
            freed_block[0] != first_block - 1U ||
            freed_block[1] != first_block ||
            dirbuf[0123U + found_slot] != 0UL ||
            dirbuf[0151U + found_slot] != 0UL || commit_calls != 1)
                return 3;

        reset(010U);
        wrong_owner = 1;
        if (dtfs_unlink(root, &name) != -1 || dtfs_cache_mount != 0UL ||
            free_calls != 0)
                return 4;

        reset(010U);
        commit_fail = 1;
        if (dtfs_unlink(root, &name) != -1 || dtfs_cache_mount != 0UL ||
            free_calls != 2)
                return 5;

        reset(0U);
        resize_fail = 1;
        if (dtfs_unlink(root, &name) != -1 || clear_calls != 0 || commit_calls != 0)
                return 6;
        return 0;
}
