/* Isolated KINIT allocator contract: no production codec or scheduler. */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "proc_packed_boot_v38.h"
#include "proc.h"

unsigned int proc_slots = 24U;
struct proc_storage_map_v28 proc_storage_runtime_v29;
static kword_t mode_words[2];
static kword_t *allocated;
static int deny_alloc;
static int deny_free;

int mm_alloc(kword_t n, unsigned int type, unsigned int owner,
    unsigned int preference, kword_t *base)
{
    assert(type == MM_TYPE_KERNEL_DYNAMIC && owner == 5U);
    assert(preference == MM_ALLOC_LOW && n != 0UL);
    if (deny_alloc || allocated) return MM_ERR_NOMEM;
    allocated = calloc((size_t)n, sizeof(*allocated));
    if (!allocated) return MM_ERR_NOMEM;
    *base = (kword_t)(unsigned long)allocated;
    return MM_OK;
}
int mm_free(kword_t base, unsigned int type, unsigned int owner)
{
    assert(type == MM_TYPE_KERNEL_DYNAMIC && owner == 5U);
    if (deny_free) return MM_ERR_BUSY;
    if ((kword_t)(unsigned long)allocated != base || !allocated)
        return MM_ERR_INVAL;
    free(allocated);
    allocated = 0;
    return MM_OK;
}
void fs_zero_words(kword_t *p, unsigned int n)
{
    memset(p, 0, (size_t)n * sizeof(*p));
}
int main(void)
{
    unsigned int i;
    kword_t *p;
    proc_storage_runtime_v29.words = mode_words;
    proc_storage_runtime_v29.slots = proc_slots;
    deny_alloc = 1;
    assert(proc_packed_boot_prepare_v38(24U, 4U, 8U) == MM_ERR_NOMEM);
    assert(!proc_packed_runtime_v38.words && !allocated);
    deny_alloc = 0;
    assert(proc_packed_boot_prepare_v38(24U, 4U, 7U) == MM_ERR_NOMEM);
    assert(proc_packed_boot_prepare_v38(40U, 4U, 8U) == MM_ERR_INVAL);
    assert(proc_packed_boot_prepare_v38(24U, 4U, 8U) == MM_OK);
    assert(proc_packed_runtime_v38.format == PROC_PACKED_LAYOUT_SPARSE_V36);
    assert(proc_packed_runtime_v38.capacity == 4U);
    assert(proc_packed_runtime_v38.words == allocated);
    assert(proc_packed_boot_prepare_v38(24U, 4U, 8U) == MM_ERR_INVAL);
    p = proc_packed_layout_reserve_v36(&proc_packed_runtime_v38, 1U);
    assert(p != 0);
    *p = 0123UL;
    assert(proc_packed_boot_abort_v38() == MM_ERR_BUSY);
    assert(allocated != 0);
    assert(proc_packed_layout_clear_v36(&proc_packed_runtime_v38, 1U) == MM_OK);
    deny_free = 1;
    assert(proc_packed_boot_abort_v38() == MM_ERR_BUSY);
    assert(proc_packed_runtime_v38.words == allocated);
    deny_free = 0;
    assert(proc_packed_boot_abort_v38() == MM_OK);
    assert(!allocated && !proc_packed_runtime_v38.words);
    assert(proc_packed_boot_prepare_v38(24U, 12U, 24U) == MM_OK);
    assert(proc_packed_runtime_v38.format == PROC_PACKED_LAYOUT_DENSE_V36);
    for (i = 0; i < 24U; ++i)
        assert(proc_packed_runtime_v38.words[i] == 0UL);
    assert(proc_packed_boot_abort_v38() == MM_OK);
    puts("packed boot v38: policy, allocation, failure, occupied abort, reuse PASS");
    return 0;
}
