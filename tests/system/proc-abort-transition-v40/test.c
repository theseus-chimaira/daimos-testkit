/* Exercise the real proc_slot_discard() with an instrumented VM destructor. */
#include <assert.h>
#include <stdio.h>
#include "proc.h"

static struct proc descriptors[PROC_MIN_SLOTS];
struct proc *proc_table = descriptors;
kword_t proc_rt_owner;
static int fail_destroy;
static int destroy_calls;

kword_t proc_scope_id(const struct proc *p) { (void)p; return 0UL; }
int vm_space_destroy(struct proc *p, unsigned int slot)
{
    assert(slot == 1U);
    assert(PROC_TRANSITION(p));
    ++destroy_calls;
    return fail_destroy ? -1 : 0;
}
void proc_tty_release_session(unsigned int session, unsigned int slot)
{ (void)session; (void)slot; }
int proc_uarea_release(unsigned int slot, struct proc *p)
{ (void)slot; (void)p; return 0; }
void proc_runq_remove(unsigned int slot) { (void)slot; }
void proc_trim_high(void) {}
int main(void)
{
    struct proc *p = &descriptors[1];
    p->meta = 1UL;
    PROC_SET_STATE(p, PROC_SRUN);
    fail_destroy = 1;
    assert(proc_slot_discard(1U) == -1);
    assert(destroy_calls == 1 && !PROC_TRANSITION(p));
    fail_destroy = 0;
    assert(proc_slot_discard(1U) == 0);
    assert(destroy_calls == 2 && PROC_IS_FREE(p));
    assert(proc_slot_discard(1U) == 0 && destroy_calls == 2);
    puts("proc abort v40: transition held during destroy, rollback, reuse PASS");
    return 0;
}
