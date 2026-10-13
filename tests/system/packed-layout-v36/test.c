/* V36 tests deliberately use only the layout API: MM authority belongs to
 * the common lifecycle caller, never to this representation layer. */
#include <assert.h>
#include <stdio.h>
#include "proc_packed_layout_v36.h"

static void exercise(unsigned int format, unsigned int capacity)
{
    struct proc_packed_layout_v36 layout = {0};
    kword_t memory[24] = {0};
    kword_t *a, *b;
    assert(proc_packed_layout_init_v36(&layout, memory, 24U,
        capacity, format) == MM_OK);
    assert(proc_packed_layout_find_v36(&layout, 1U) == 0);
    a = proc_packed_layout_reserve_v36(&layout, 1U);
    assert(a != 0);
    *a = 0112233UL;
    assert(proc_packed_layout_find_v36(&layout, 1U) == a);
    assert(proc_packed_layout_reserve_v36(&layout, 1U) == 0);
    b = proc_packed_layout_reserve_v36(&layout, 2U);
    assert(b != 0 && b != a);
    *b = 0445566UL;
    assert(proc_packed_layout_find_v36(&layout, 2U) == b);
    if (format == PROC_PACKED_LAYOUT_SPARSE_V36 && capacity == 2U)
        assert(proc_packed_layout_reserve_v36(&layout, 3U) == 0);
    assert(proc_packed_layout_clear_v36(&layout, 1U) == MM_OK);
    assert(proc_packed_layout_find_v36(&layout, 1U) == 0);
    assert(proc_packed_layout_clear_v36(&layout, 1U) == MM_ERR_INVAL);
    a = proc_packed_layout_reserve_v36(&layout, 3U);
    assert(a != 0);
    *a = 0765432UL;
    assert(proc_packed_layout_find_v36(&layout, 2U) == b);
    assert(*b == 0445566UL);
    assert(proc_packed_layout_find_v36(&layout, 3U) == a);
    assert(proc_packed_layout_reserve_v36(&layout, 0U) == 0);
    assert(proc_packed_layout_reserve_v36(&layout, 24U) == 0);
}
int main(void)
{
    unsigned int f = 9U, words = 0U;
    assert(proc_packed_layout_plan_v36(24U, 8U, 24U, &f, &words) == MM_OK);
    assert(f == PROC_PACKED_LAYOUT_SPARSE_V36 && words == 16U);
    assert(proc_packed_layout_plan_v36(24U, 12U, 24U, &f, &words) == MM_OK);
    assert(f == PROC_PACKED_LAYOUT_DENSE_V36 && words == 24U);
    assert(proc_packed_layout_plan_v36(24U, 12U, 23U, &f, &words) == MM_ERR_NOMEM);
    assert(proc_packed_layout_plan_v36(24U, 8U, 15U, &f, &words) == MM_ERR_NOMEM);
    assert(proc_packed_layout_plan_v36(24U, 0U, 24U, &f, &words) == MM_ERR_INVAL);
    exercise(PROC_PACKED_LAYOUT_DENSE_V36, 2U);
    exercise(PROC_PACKED_LAYOUT_SPARSE_V36, 2U);
    puts("packed layout v36: selection, capacity, lookup, clearing, reuse PASS");
    return 0;
}
