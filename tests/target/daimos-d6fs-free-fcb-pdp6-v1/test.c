/* Native PDP-6 FCB allocator bound and first-free search regression. */
#include "d6fs.h"

extern int d6fs_provider_free_fcb(unsigned int *indexp);

static struct d6fs_reader reader;
struct d6fs_reader *d6fs_active_reader = &reader;
static unsigned int free_index;
static unsigned int calls;
kword_t daimos_d6fs_free_fcb_bound_v1_result;

/* Mock only the decoded FCB reader. The allocator is original assembly. */
int
d6fs_reader_fcb(struct d6fs_reader *source, unsigned int index,
    kword_t *fcb, struct d6fs_fcb_info *info)
{
    (void)fcb;
    if (source != &reader || index == 0U || index >= reader.fcb_count)
        return -1;
    ++calls;
    info->type = index == free_index ? D6FS_TYPE_FREE : D6FS_TYPE_REG;
    return 0;
}

int
daimos_d6fs_free_fcb_bound_v1_test(void)
{
    unsigned int index;

    reader.fcb_count = 8U;
    reader.super_block[0] = 0UL;
    free_index = 7U;
    calls = 0U;
    index = 0U;
    if (d6fs_provider_free_fcb(&index) != 0 || index != 7U ||
        calls != 7U)
        return 1;

    /* A large superblock LBN must not permit scanning past fcb_count. */
    reader.fcb_count = 7U;
    reader.super_block[0] = 01000UL;
    free_index = 7U;
    calls = 0U;
    index = 0U;
    if (d6fs_provider_free_fcb(&index) != -1 || calls != 6U)
        return 2;

    reader.fcb_count = 8U;
    reader.super_block[0] = 1UL;
    free_index = 2U;
    calls = 0U;
    index = 0U;
    if (d6fs_provider_free_fcb(&index) != 0 || index != 2U ||
        calls != 2U)
        return 3;

    reader.fcb_count = 0U;
    calls = 0U;
    index = 0U;
    if (d6fs_provider_free_fcb(&index) != -1 || calls != 0U)
        return 4;
    return 0;
}
