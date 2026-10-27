#include "vfs.h"

int __test_exit;
extern int rename_mapping_probe(const kword_t *, const kword_t *);
extern kword_t mapping_holds, mapping_releases, mapping_calls;
extern kword_t mapping_fail_call, mapping_old, mapping_new;

static kword_t old_path[2] = {1, 0123};
static kword_t new_path[2] = {1, 0456};

static int check(unsigned int failing, int expected)
{
        int result;
        mapping_holds = mapping_releases = mapping_calls = 0;
        mapping_fail_call = failing;
        mapping_old = mapping_new = 0;
        result = rename_mapping_probe(old_path, new_path);
        if (result != expected || mapping_holds != 1 || mapping_releases != 1)
                return 1;
        if (mapping_calls != 2)
                return 2;
        if (failing == 0 && (mapping_old != (kword_t)(unsigned long)old_path ||
            mapping_new != (kword_t)(unsigned long)new_path))
                return 3;
        return 0;
}

int main(void)
{
        if (check(0, 0)) return 1;
        if (check(1, -1)) return 2;
        if (check(2, -1)) return 3;
        return 0;
}
