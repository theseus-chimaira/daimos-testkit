#include "file.h"
#include "../../test_sixbit.h"

extern int file_parent_path(const kword_t *, vnode_t *, struct vfs_name *);

#define N_ROOT VFS_NODE_PACKED(1U, 1U, 1U)
#define N_A    VFS_NODE_PACKED(1U, 1U, 2U)
#define N_B    VFS_NODE_PACKED(1U, 2U, 3U)
#define N_D    VFS_NODE_PACKED(1U, 1U, 4U)
#define N_X    VFS_NODE_PACKED(1U, 2U, 5U)
#define N_Q    VFS_NODE_PACKED(1U, 1U, 6U)
#define N_R    VFS_NODE_PACKED(1U, 1U, 7U)
#define N_Z    VFS_NODE_PACKED(1U, 2U, 8U)
#define N_S    VFS_NODE_PACKED(1U, 3U, 9U)
#define N_L    VFS_NODE_PACKED(1U, 3U, 10U)
#define N_LD   VFS_NODE_PACKED(1U, 3U, 11U)
#define N_ABS  VFS_NODE_PACKED(1U, 3U, 12U)
#define N_UP   VFS_NODE_PACKED(1U, 3U, 13U)
#define N_C1   VFS_NODE_PACKED(1U, 3U, 14U)
#define N_C2   VFS_NODE_PACKED(1U, 3U, 15U)
#define N_LOOP VFS_NODE_PACKED(1U, 3U, 16U)

struct test_uarea {
        vnode_t cwd;
        struct file files[FILE_NFILE];
};

static struct test_uarea uarea;
struct file *file_table;
vnode_t vfs_namespace_root = N_ROOT;
kword_t daimos_file_walk_pdp6_result;

static int
name_is(const struct vfs_name *name, unsigned int chars, kword_t word)
{
        return name != 0 && name->chars == chars && name->words[0] == word;
}

int
vfs_name_is6(const struct vfs_name *name, kword_t word, unsigned int chars)
{
        return name_is(name, chars, word);
}

static int
link_info(vnode_t node, unsigned int *charsp, kword_t *wordp)
{
        if (charsp == 0 || wordp == 0)
                return -1;
        if (node == N_S || node == N_L) {
                *charsp = 1U;
                *wordp = node == N_S ?
                    TEST_SIX6('.',' ',' ',' ',' ',' ') :
                    TEST_SIX6('B',' ',' ',' ',' ',' ');
                return 0;
        }
        if (node == N_LD) {
                *charsp = 1U;
                *wordp = TEST_SIX6('D',' ',' ',' ',' ',' ');
                return 0;
        }
        if (node == N_ABS) {
                *charsp = 4U;
                *wordp = TEST_SIX6('/','Q','/','R',' ',' ');
                return 0;
        }
        if (node == N_UP) {
                *charsp = 4U;
                *wordp = TEST_SIX6('.','.','/','B',' ',' ');
                return 0;
        }
        if (node == N_C1) {
                *charsp = 2U;
                *wordp = TEST_SIX6('C','2',' ',' ',' ',' ');
                return 0;
        }
        if (node == N_C2) {
                *charsp = 1U;
                *wordp = TEST_SIX6('B',' ',' ',' ',' ',' ');
                return 0;
        }
        if (node == N_LOOP) {
                *charsp = 4U;
                *wordp = TEST_SIX6('L','O','O','P',' ',' ');
                return 0;
        }
        return -1;
}

int
vfs_lookup(vnode_t dir, const struct vfs_name *name, vnode_t *nodep)
{
        if (nodep == 0)
                return -1;
        if (dir == N_ROOT) {
                if (name_is(name, 1U, TEST_SIX6('A',' ',' ',' ',' ',' ')))
                        *nodep = N_A;
                else if (name_is(name, 1U,
                    TEST_SIX6('Q',' ',' ',' ',' ',' ')))
                        *nodep = N_Q;
                else if (name_is(name, 1U,
                    TEST_SIX6('S',' ',' ',' ',' ',' ')))
                        *nodep = N_S;
                else
                        return -1;
                return 0;
        }
        if (dir == N_A) {
                if (name_is(name, 1U, TEST_SIX6('B',' ',' ',' ',' ',' ')))
                        *nodep = N_B;
                else if (name_is(name, 1U,
                    TEST_SIX6('D',' ',' ',' ',' ',' ')))
                        *nodep = N_D;
                else if (name_is(name, 1U,
                    TEST_SIX6('L',' ',' ',' ',' ',' ')))
                        *nodep = N_L;
                else if (name_is(name, 2U,
                    TEST_SIX6('L','D',' ',' ',' ',' ')))
                        *nodep = N_LD;
                else if (name_is(name, 3U,
                    TEST_SIX6('A','B','S',' ',' ',' ')))
                        *nodep = N_ABS;
                else if (name_is(name, 2U,
                    TEST_SIX6('C','1',' ',' ',' ',' ')))
                        *nodep = N_C1;
                else if (name_is(name, 2U,
                    TEST_SIX6('C','2',' ',' ',' ',' ')))
                        *nodep = N_C2;
                else if (name_is(name, 4U,
                    TEST_SIX6('L','O','O','P',' ',' ')))
                        *nodep = N_LOOP;
                else
                        return -1;
                return 0;
        }
        if (dir == N_D) {
                if (name_is(name, 1U, TEST_SIX6('X',' ',' ',' ',' ',' ')))
                        *nodep = N_X;
                else if (name_is(name, 2U,
                    TEST_SIX6('U','P',' ',' ',' ',' ')))
                        *nodep = N_UP;
                else
                        return -1;
                return 0;
        }
        if (dir == N_Q &&
            name_is(name, 1U, TEST_SIX6('R',' ',' ',' ',' ',' '))) {
                *nodep = N_R;
                return 0;
        }
        if (dir == N_R &&
            name_is(name, 1U, TEST_SIX6('Z',' ',' ',' ',' ',' '))) {
                *nodep = N_Z;
                return 0;
        }
        return -1;
}

int
vfs_stat(vnode_t node, struct vfs_stat *st)
{
        unsigned int chars;
        kword_t word;

        if (st == 0)
                return -1;
        st->mode = 0777U;
        st->size_words = 0UL;
        if (link_info(node, &chars, &word) == 0) {
                st->type = VFS_TYPE_SYMLINK;
                st->size_words = 2UL;
                return 0;
        }
        if (node == N_ROOT || node == N_A || node == N_D ||
            node == N_Q || node == N_R) {
                st->type = VFS_TYPE_DIR;
                return 0;
        }
        if (node == N_B || node == N_X || node == N_Z) {
                st->type = VFS_TYPE_REG;
                return 0;
        }
        return -1;
}

int
vfs_parent(vnode_t node, vnode_t *parentp)
{
        if (parentp == 0)
                return -1;
        if (node == N_ROOT)
                *parentp = N_ROOT;
        else if (node == N_A || node == N_Q)
                *parentp = N_ROOT;
        else if (node == N_B || node == N_D)
                *parentp = N_A;
        else if (node == N_X)
                *parentp = N_D;
        else if (node == N_R)
                *parentp = N_Q;
        else if (node == N_Z)
                *parentp = N_R;
        else
                return -1;
        return 0;
}

int
vfs_read_words(vnode_t node, unsigned int off, kword_t *buf,
    unsigned int nwords)
{
        unsigned int chars;
        kword_t word;

        if (off != 0U || buf == 0 || nwords != 2U ||
            link_info(node, &chars, &word) != 0)
                return -1;
        buf[0] = (kword_t)chars;
        buf[1] = word;
        return 2;
}

static int
lookup_is(const kword_t *path, vnode_t want)
{
        vnode_t node;

        return file_lookup_path(path, &node) == 0 && node == want;
}

int
vfs_create(vnode_t dir, const struct vfs_name *name,
    unsigned int mode, vnode_t *nodep)
{
        (void)dir;
        (void)name;
        (void)mode;
        (void)nodep;
        return -1;
}

int
vfs_truncate(vnode_t node, unsigned int words)
{
        (void)node;
        (void)words;
        return -1;
}

int vfs_write_words(vnode_t node, unsigned int off, const kword_t *buf,
    unsigned int nwords)
{
        (void)node;
        (void)off;
        (void)buf;
        (void)nwords;
        return -1;
}

int vfs_readchar(vnode_t node, kword_t off, unsigned int *chp)
{ (void)node; (void)off; (void)chp; return -1; }
int vfs_writechar(vnode_t node, kword_t off, unsigned int ch)
{ (void)node; (void)off; (void)ch; return -1; }
int vfs_sync(vnode_t node)
{ (void)node; return 0; }
int vfs_readdir(vnode_t node, unsigned int off, struct vfs_dirent *ent)
{ (void)node; (void)off; (void)ent; return -1; }
int vfs_parent_name(vnode_t node, vnode_t *parentp, struct vfs_name *namep)
{ (void)node; (void)parentp; (void)namep; return -1; }
int vfs_symlink(vnode_t dir, const struct vfs_name *name,
    const kword_t *target, vnode_t *nodep)
{ (void)dir; (void)name; (void)target; (void)nodep; return -1; }
int vfs_rename(vnode_t olddir, const struct vfs_name *oldname,
    vnode_t newdir, const struct vfs_name *newname)
{ (void)olddir; (void)oldname; (void)newdir; (void)newname; return -1; }
int vfs_mkdir(vnode_t dir, const struct vfs_name *name,
    unsigned int mode, vnode_t *nodep)
{ (void)dir; (void)name; (void)mode; (void)nodep; return -1; }
int vfs_unlink(vnode_t dir, const struct vfs_name *name)
{ (void)dir; (void)name; return -1; }

int
daimos_file_walk_pdp6_test(void)
{
        static const kword_t p_a_b[] = {
                4U, TEST_SIX6('/','A','/','B',' ',' ')
        };
        static const kword_t p_a_l[] = {
                4U, TEST_SIX6('/','A','/','L',' ',' ')
        };
        static const kword_t p_a_ld_x[] = {
                7U, TEST_SIX6('/','A','/','L','D','/'),
                TEST_SIX6('X',' ',' ',' ',' ',' ')
        };
        static const kword_t p_a_d_up[] = {
                7U, TEST_SIX6('/','A','/','D','/','U'),
                TEST_SIX6('P',' ',' ',' ',' ',' ')
        };
        static const kword_t p_a_d_dotdot[] = {
                7U, TEST_SIX6('/','A','/','D','/','.'),
                TEST_SIX6('.',' ',' ',' ',' ',' ')
        };
        static const kword_t p_a_abs_z[] = {
                8U, TEST_SIX6('/','A','/','A','B','S'),
                TEST_SIX6('/','Z',' ',' ',' ',' ')
        };
        static const kword_t p_a_c1[] = {
                5U, TEST_SIX6('/','A','/','C','1',' ')
        };
        static const kword_t p_a_loop[] = {
                7U, TEST_SIX6('/','A','/','L','O','O'),
                TEST_SIX6('P',' ',' ',' ',' ',' ')
        };
        static const kword_t p_s8_a[] = {
                18U, TEST_SIX6('/','S','/','S','/','S'),
                TEST_SIX6('/','S','/','S','/','S'),
                TEST_SIX6('/','S','/','S','/','A')
        };
        static const kword_t p_s9_a[] = {
                20U, TEST_SIX6('/','S','/','S','/','S'),
                TEST_SIX6('/','S','/','S','/','S'),
                TEST_SIX6('/','S','/','S','/','S'),
                TEST_SIX6('/','A',' ',' ',' ',' ')
        };
        static const kword_t p_b[] = {
                1U, TEST_SIX6('B',' ',' ',' ',' ',' ')
        };
        static const kword_t p_dotdot[] = {
                2U, TEST_SIX6('.','.',' ',' ',' ',' ')
        };
        vnode_t dir;
        struct vfs_name leaf;

        file_table = 0;
        if (!lookup_is(p_a_b, N_B))
                return 100;
        if (!lookup_is(p_a_l, N_B))
                return 1;
        if (!lookup_is(p_a_ld_x, N_X))
                return 2;
        if (file_parent_path(p_a_ld_x, &dir, &leaf) != 0 || dir != N_D ||
            !name_is(&leaf, 1U, TEST_SIX6('X',' ',' ',' ',' ',' ')))
                return 3;
        if (!lookup_is(p_a_d_up, N_B))
                return 4;
        if (!lookup_is(p_a_d_dotdot, N_A))
                return 11;
        if (!lookup_is(p_a_abs_z, N_Z))
                return 5;
        if (!lookup_is(p_a_c1, N_B))
                return 6;
        if (file_lookup_path(p_a_loop, &dir) == 0)
                return 7;
        if (!lookup_is(p_s8_a, N_A))
                return 8;
        if (file_lookup_path(p_s9_a, &dir) == 0)
                return 9;

        uarea.cwd = N_A;
        file_table = uarea.files;
        if (!lookup_is(p_b, N_B))
                return 10;
        uarea.cwd = N_D;
        if (!lookup_is(p_dotdot, N_A))
                return 12;
        uarea.cwd = N_ROOT;
        if (file_chdir(p_a_d_dotdot) != 0 || uarea.cwd != N_A)
                return 13;
        return 0;
}
