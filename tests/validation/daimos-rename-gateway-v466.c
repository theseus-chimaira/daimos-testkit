#include "vfs.h"

int __test_exit;
extern int file_rename(const kword_t *, const kword_t *);
extern kword_t vfs_mount_root_base, vfs_mount_target_base;
extern kword_t rename_test_calls, rename_test_op, rename_test_result;
extern int rename_full_probe(const kword_t *, const kword_t *);
extern kword_t mapping_holds, mapping_releases, mapping_calls;
extern kword_t mapping_fail_call, rename_provider_without_hold;
extern kword_t rename_wait_calls;
extern kword_t fs_provider_ready, rename_wake_calls;
extern kword_t fs_dtfs_service_jump;
extern void rename_gateway_bind_v466(void);
static kword_t roots[4], targets[4];
static int parents, checks, fail_parent, fail_access;
static const kword_t oldpath[2] = {1, 0123};
static const kword_t newpath[2] = {1, 0456};

#define NODE(m) ((((kword_t)5U) << 30) | (((kword_t)(m)) << 24) | (((kword_t)1U) << 18) | 2U)

int file_parent_path(const kword_t *path, vnode_t *dir, struct vfs_name *name)
{
        ++parents;
        if (parents == fail_parent) return -1;
        *dir = NODE(0);
        name->chars = 1;
        name->words[0] = path == oldpath ? 0123 : 0456;
        return 0;
}

int file_parent_write_access_v367(vnode_t dir)
{
        (void)dir;
        ++checks;
        return checks == fail_access ? -1 : 0;
}

static void reset(int parent_failure, int access_failure, int provider_failure)
{
        parents = checks = 0;
        fail_parent = parent_failure;
        fail_access = access_failure;
        rename_test_calls = 0;
        rename_test_result = provider_failure ? (kword_t)-1 : 0;
        mapping_holds = mapping_releases = mapping_calls = 0;
        mapping_fail_call = rename_provider_without_hold = 0;
        rename_wait_calls = 0;
        rename_wake_calls = 0;
        fs_provider_ready = 0;
}

/* Each syscall invocation owns exactly one VM mapping lease, even when a
 * pointer, parent resolution, permission or provider operation fails. */
static int invoke(const kword_t *oldp, const kword_t *newp)
{
        int result = rename_full_probe(oldp, newp);
        if (mapping_holds != 1 || mapping_releases != 1 || mapping_calls != 2 ||
            rename_provider_without_hold != 0)
                return -99;
        return result;
}

int main(void)
{
        rename_gateway_bind_v466();
        vfs_mount_root_base = (kword_t)(unsigned long)roots;
        vfs_mount_target_base = (kword_t)(unsigned long)targets;
        reset(0, 0, 0);
        {
                int rc = invoke(oldpath, newpath);
                if (rc == -99) return 21;
                if (rc != 0) return 22;
        }
        if (parents != 2 || checks != 2 || rename_test_calls != 1 || rename_test_op != 012U || rename_wait_calls != 1 || rename_wake_calls != 1 || !fs_provider_ready) return 2;
        reset(1, 0, 0);
        if (invoke(oldpath, newpath) != -1 || parents != 1 || checks || rename_test_calls) return 3;
        reset(2, 0, 0);
        if (invoke(oldpath, newpath) != -1 || parents != 2 || checks != 1 || rename_test_calls) return 4;
        reset(0, 1, 0);
        if (invoke(oldpath, newpath) != -1 || parents != 1 || checks != 1 || rename_test_calls) return 5;
        reset(0, 2, 0);
        if (invoke(oldpath, newpath) != -1 || parents != 2 || checks != 2 || rename_test_calls) return 6;
        reset(0, 0, 1);
        if (invoke(oldpath, newpath) != -1 || rename_test_calls != 1) return 7;
        reset(0, 0, 0);
        mapping_fail_call = 1;
        if (invoke(oldpath, newpath) != -1 || parents || rename_test_calls) return 8;
        reset(0, 0, 0);
        mapping_fail_call = 2;
        if (invoke(oldpath, newpath) != -1 || parents || rename_test_calls || rename_wait_calls) return 9;
        if (mapping_holds != mapping_releases || rename_provider_without_hold) return 10;
        return 0;
}
