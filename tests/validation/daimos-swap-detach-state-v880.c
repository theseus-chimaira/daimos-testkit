/*
 * Production proc_swap_detach() fault injection. Only this function's
 * section is linked: all unrelated swap services are discarded.
 */
#include "proc.h"
#include "proc_swap.h"
#include "bstore.h"
#include "proc_storage_map_v28.h"
#include <stdio.h>

static struct proc slots[4];
static struct proc_swap_record swaps[4];
static kword_t allocated;
static int free_calls;
static int publish_calls;
static int failures;

struct proc *proc_table = slots;
static int disk_mode = 1;
kword_t *backstore_bitmap = &allocated;
kword_t backstore_blocks = 040;
kword_t backstore_blocks_used;
unsigned int backstore_enabled = 1;

static void
setup(kword_t first, kword_t blocks, kword_t mask)
{
    slots[2].meta = 0UL;
    slots[2].vm_state = 04000UL << 18;
    slots[2].sched = (kword_t)PROC_SRUN << PROC_STATE_SHIFT;
    swaps[2].state = (first << 18) | blocks;
    proc_swap_records = swaps;
    proc_swap_blocks_used = blocks;
    allocated = mask;
    free_calls = 0;
    publish_calls = 0;
    disk_mode = 1;
}

int
backstore_verify_allocated_v795(kword_t first, kword_t blocks)
{
    kword_t i;
    if (!backstore_enabled || !allocated || !blocks ||
        first >= backstore_blocks ||
        blocks > backstore_blocks - first)
        return -1;
    for (i = first; i < first + blocks; ++i) {
        if ((allocated & (1UL << i)) == 0UL)
            return -1;
    }
    return 0;
}

void
backstore_free(kword_t first, kword_t blocks)
{
    kword_t i;
    ++free_calls;
    if (backstore_verify_allocated_v795(first, blocks) != 0) {
        ++failures;
        return;
    }
    for (i = first; i < first + blocks; ++i)
        allocated &= ~(1UL << i);
}

int
proc_storage_publish_v30(unsigned int slot, unsigned int old_state,
    unsigned int new_state)
{
    ++publish_calls;
    if (slot != 2U || old_state != 1U || new_state != 0U ||
        disk_mode != 1) {
        ++failures;
        return -1;
    }
    disk_mode = 0;
    return 0;
}

void
proc_swap_storage_invariant_v30(void)
{
    ++failures;
}

static void
check(int ok, const char *what)
{
    if (!ok) {
        ++failures;
        fprintf(stderr, "FAIL: %s\n", what);
    }
}

int
main(void)
{
    kword_t span;
    span = (1UL << 010) | (1UL << 011) | (1UL << 012);

    setup(010, 3, span & ~(1UL << 011));
    check(proc_swap_detach(2) == -1, "missing allocation rejected");
    check(swaps[2].state == ((010UL << 18) | 3UL),
        "missing allocation retains record");
    check(proc_swap_blocks_used == 3UL, "missing allocation retains count");
    check(free_calls == 0 && publish_calls == 0,
        "missing allocation no free or publication");

    allocated = span;
    check(proc_swap_detach(2) == 0, "complete allocation detached");
    check(swaps[2].state == 0UL, "complete allocation clears record");
    check(proc_swap_blocks_used == 0UL, "complete allocation correct count");
    check(allocated == 0UL, "complete allocation releases backing bits");
    check(free_calls == 1 && publish_calls == 1 && disk_mode == 0,
        "complete allocation publishes state exactly once");
    check(proc_swap_detach(2) == 0 && free_calls == 1,
        "duplicate detach does not free again");

    setup(010, 3, span);
    proc_swap_blocks_used = 2UL;
    check(proc_swap_detach(2) == -1, "underflow rejected");
    check(free_calls == 0 && swaps[2].state != 0UL,
        "underflow leaves backing ownership");

    setup(037, 3, span);
    check(proc_swap_detach(2) == -1, "out-of-bounds rejected");
    check(free_calls == 0 && swaps[2].state != 0UL,
        "out-of-bounds retains backing ownership");

    setup(010, 0, span);
    check(proc_swap_detach(2) == -1, "zero-block disk record rejected");
    check(free_calls == 0 && swaps[2].state != 0UL,
        "zero-block retains backing ownership");

    if (failures != 0) {
        fprintf(stderr, "v880: %d ownership failures\n", failures);
        return 1;
    }
    puts("v880: disk detach failed/success/retry/idempotence PASS");
    return 0;
}
