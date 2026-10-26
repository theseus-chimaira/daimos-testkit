#include "vfs.h"

int __test_exit;
extern int file_rename(const kword_t *, const kword_t *);
static int parent_calls, access_calls, rename_calls;
static int fail_parent, fail_access, rename_result;
static vnode_t first_dir, second_dir;
static struct vfs_name *first_name, *second_name;
static const kword_t oldpath[] = {1, 0123};
static const kword_t newpath[] = {1, 0456};

int file_parent_path(const kword_t *path, vnode_t *dir, struct vfs_name *name)
{
        ++parent_calls;
        if (parent_calls == fail_parent) return -1;
        *dir = path == oldpath ? 01234 : 05670;
        name->chars = 1;
        name->words[0] = path[1];
        return 0;
}

int file_parent_write_access_v367(vnode_t dir)
{
        (void)dir;
        ++access_calls;
        return access_calls == fail_access ? -1 : 0;
}

int vfs_rename(vnode_t olddir, const struct vfs_name *oldname,
    vnode_t newdir, const struct vfs_name *newname)
{
        ++rename_calls;
        first_dir = olddir;
        second_dir = newdir;
        first_name = (struct vfs_name *)oldname;
        second_name = (struct vfs_name *)newname;
        if (oldname->words[0] != oldpath[1] || newname->words[0] != newpath[1])
                return -2;
        return rename_result;
}

static void reset(int fp, int fa, int rr)
{
        parent_calls = access_calls = rename_calls = 0;
        fail_parent = fp;
        fail_access = fa;
        rename_result = rr;
}

int main(void)
{
        reset(0, 0, 0);
        if (file_rename(oldpath, newpath) != 0) return 1;
        if (parent_calls != 2 || access_calls != 2 || rename_calls != 1) return 2;
        if (first_dir != 01234 || second_dir != 05670 || first_name == second_name) return 3;
        reset(1, 0, 0);
        if (file_rename(oldpath, newpath) != -1 || parent_calls != 1 || access_calls || rename_calls) return 4;
        reset(2, 0, 0);
        if (file_rename(oldpath, newpath) != -1 || parent_calls != 2 || access_calls != 1 || rename_calls) return 5;
        reset(0, 1, 0);
        if (file_rename(oldpath, newpath) != -1 || parent_calls != 1 || access_calls != 1 || rename_calls) return 6;
        reset(0, 2, 0);
        if (file_rename(oldpath, newpath) != -1 || parent_calls != 2 || access_calls != 2 || rename_calls) return 7;
        reset(0, 0, -1);
        if (file_rename(oldpath, newpath) != -1 || rename_calls != 1) return 8;
        return 0;
}
