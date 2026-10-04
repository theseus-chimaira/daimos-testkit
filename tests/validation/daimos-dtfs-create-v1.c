#include "dtfs.h"

int __test_exit;
kword_t *dtfs_dir;
kword_t fs_block_workspace[0200];

static kword_t dirbuf[0200];
static struct vfs_name name;
static unsigned int personality;
static unsigned int free_slot;
static unsigned int free_block;
static int write_result;
static int commit_result;
static int foreign_calls;
static int foreign_its;
static int set_name_calls;
static int last_words_calls;
static unsigned int seen_last_words;
static int set_exec_calls;
static int seen_exec;
static int clear_calls;
static int zero_calls;
static int owner_calls;
static unsigned int owner_block[2];
static unsigned int owner_value[2];
static unsigned int seen_write_unit;
static unsigned int seen_write_block;

int dtfs_is_root(vnode_t node) { (void)node; return 1; }
int dtfs_load(vnode_t node) { (void)node; return 0; }

int
dtfs_scan_slot(vnode_t dir, const struct vfs_name *n, unsigned int *slotp)
{
        (void)dir;
        if (n != 0)
                return -1;             /* requested name is absent */
        if (slotp != 0)
                *slotp = free_slot;
        return 0;
}

unsigned int dtfs_personality(vnode_t node) { (void)node; return personality; }

int
dtfs_find_free_block(unsigned int first, unsigned int mapoff, unsigned int *bp)
{
        (void)first;
        if (mapoff != 1U)
                return -1;
        *bp = free_block;
        return 0;
}

int
dtfs_foreign_set_name(unsigned int slot, const struct vfs_name *n, int its)
{
        if (slot != free_slot || n != &name)
                return -1;
        ++foreign_calls;
        foreign_its = its;
        if (its) {
                dtfs_dir[slot * 2U] = 0111UL;
                dtfs_dir[slot * 2U + 1U] = 0222UL;
        } else {
                dtfs_dir[0123U + slot] = 0333UL;
                dtfs_dir[0151U + slot] = 0444UL;
        }
        return 0;
}

void fs_zero_block_workspace(void)
{
        unsigned int i;
        ++zero_calls;
        for (i = 0U; i != 0200U; ++i)
                fs_block_workspace[i] = 0UL;
}

unsigned int dtfs_unit(vnode_t node) { (void)node; return 3U; }

int
dtfs_dtc_write(unsigned int unit, unsigned int block, kword_t *buf)
{
        seen_write_unit = unit;
        seen_write_block = block;
        if (buf != fs_block_workspace)
                return -1;
        return write_result;
}

void
dtfs_set_owner(unsigned int mapword, unsigned int block, unsigned int owner)
{
        (void)mapword;
        if (owner_calls < 2) {
                owner_block[owner_calls] = block;
                owner_value[owner_calls] = owner;
        }
        ++owner_calls;
}

int dtfs_commit(vnode_t node) { (void)node; return commit_result; }

void
dtfs_set_name(unsigned int slot, const struct vfs_name *n)
{
        if (slot == free_slot && n == &name)
                ++set_name_calls;
}

void
dtfs_set_last_words(unsigned int slot, unsigned int words)
{
        if (slot == free_slot) {
                ++last_words_calls;
                seen_last_words = words;
        }
}

void
dtfs_set_exec(unsigned int slot, int executable)
{
        if (slot == free_slot) {
                ++set_exec_calls;
                seen_exec = executable;
        }
}

void dtfs_clear_slot(unsigned int slot) { if (slot == free_slot) ++clear_calls; }

static void
reset(unsigned int media)
{
        unsigned int i;
        personality = media;
        free_slot = 5U;
        free_block = 0200U;
        write_result = 0;
        commit_result = 0;
        foreign_calls = foreign_its = 0;
        set_name_calls = last_words_calls = set_exec_calls = clear_calls = 0;
        seen_last_words = 0777U;
        seen_exec = -1;
        zero_calls = owner_calls = 0;
        seen_write_unit = seen_write_block = 0U;
        for (i = 0U; i != 0200U; ++i)
                dirbuf[i] = 0UL;
        dtfs_dir = dirbuf;
}

static int
run_create(unsigned int mode, vnode_t *nodep)
{
        vnode_t dir;
        dir = VFS_NODE_PACKED(DTFS_PROVIDER,
            (1U << VFS_MOUNT_SHIFT) | DTFS_KIND_ROOT, 0U);
        return dtfs_create(dir, &name, mode, nodep);
}

int
main(void)
{
        vnode_t node;
        vnode_t want;

        want = VFS_NODE_PACKED(DTFS_PROVIDER, DTFS_KIND_FILE, 5U);

        reset(0U);
        node = 0UL;
        if (run_create(0755U, &node) != 0 || node != want ||
            set_name_calls != 1 || last_words_calls != 1 ||
            seen_last_words != 0U || set_exec_calls != 1 || seen_exec != 1 ||
            clear_calls != 0)
                return 1;

        reset(0U);
        commit_result = -1;
        if (run_create(0644U, &node) != -1 || clear_calls != 1)
                return 2;

        reset(010U);                    /* TENEX */
        node = 0UL;
        if (run_create(0666U, &node) != 0 || node != want ||
            foreign_calls != 1 || foreign_its != 0 || zero_calls != 1 ||
            seen_write_unit != 3U || seen_write_block != free_block ||
            fs_block_workspace[0] != ((kword_t)free_block << 8U) ||
            owner_calls != 1 || owner_block[0] != free_block - 1U ||
            owner_value[0] != free_slot + 1U)
                return 3;

        reset(010U);
        write_result = -1;
        if (run_create(0666U, &node) != -1 || owner_calls != 0 ||
            dirbuf[0123U + free_slot] != 0UL ||
            dirbuf[0151U + free_slot] != 0UL)
                return 4;

        reset(010U);
        commit_result = -1;
        if (run_create(0666U, &node) != -1 || owner_calls != 2 ||
            owner_value[0] != free_slot + 1U || owner_value[1] != 0U ||
            dirbuf[0123U + free_slot] != 0UL ||
            dirbuf[0151U + free_slot] != 0UL)
                return 5;

        reset(020U);                    /* ITS */
        node = 0UL;
        if (run_create(0666U, &node) != 0 || node != want ||
            foreign_calls != 1 || foreign_its != 1)
                return 6;

        reset(020U);
        commit_result = -1;
        if (run_create(0666U, &node) != -1 ||
            dirbuf[free_slot * 2U] != 0UL ||
            dirbuf[free_slot * 2U + 1U] != 0UL)
                return 7;
        return 0;
}
