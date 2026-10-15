#include <assert.h>
#include "vfs_mount_slab_v4.h"
#include "mm.h"

static kword_t arena[128];
static unsigned int allocations;
static int fail_alloc;

int mm_alloc(kword_t words, unsigned int type, unsigned int owner,
    unsigned int preference, kword_t *basep)
{
        assert(type == MM_TYPE_KERNEL_DYNAMIC);
        assert(owner == 020U);
        assert(preference == MM_ALLOC_LOW);
        assert(words <= 96UL);
        ++allocations;
        if (fail_alloc)
                return MM_ERR_NOMEM;
        *basep = (kword_t)(unsigned long)arena;
        return MM_OK;
}

int main(void)
{
        struct vfs_mount_slab_v4 slab;
        unsigned int i;

        allocations = 0U;
        assert(vfs_mount_slab_v4_prepare(0U, &slab) == -1);
        assert(vfs_mount_slab_v4_prepare(18U, &slab) == -1);
        assert(allocations == 0U);
        fail_alloc = 1;
        assert(vfs_mount_slab_v4_prepare(16U, &slab) == -1);
        assert(allocations == 1U);
        fail_alloc = 0;
        for (i = 0; i < 128; ++i)
                arena[i] = ~0UL;
        assert(vfs_mount_slab_v4_prepare(16U, &slab) == 0);
        assert(slab.capacity == 16U && slab.words == 96U);
        assert(slab.target == slab.base);
        assert(slab.root == slab.base + 16UL);
        assert(slab.reader == slab.base + 32UL);
        assert(slab.media == slab.base + 48UL);
        assert(slab.shape == slab.base + 64UL);
        assert(slab.extent == slab.base + 80UL);
        for (i = 0; i < 96; ++i)
                assert(arena[i] == 0UL);
        assert(arena[96] == ~0UL);
        return 0;
}
