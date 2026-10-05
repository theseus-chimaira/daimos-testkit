#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>

#include "mm.h"
#include "mm_internal.h"
#include "proc.h"
#include "vm.h"
#include "vm_pdp6.h"
#include "proc_swap.h"
#include "syscall.h"
#include "module_runtime.h"
#include "kcore_pi.h"
#include "blockset_mres.h"
#include "storage.h"
#include "bstore.h"
#include "exec.h"
#include "memfs.h"
#include "file.h"

static struct proc proc_table_store[PROC_MAX_SLOTS];
struct proc *proc_table = proc_table_store;
unsigned int proc_slots = PROC_MIN_SLOTS;
unsigned int proc_high_slot = 1U;
kword_t proc_current_slot;
kword_t proc_sched_cursor;
kword_t proc_sched_deferred_ticks;
kword_t proc_runq_head;
kword_t proc_rt_owner;
extern unsigned int proc_sched_age_phase;
kword_t mach_kernel_stack_base;
struct file *file_table;
kword_t fs_block_workspace[DSK_WORDS_PER_SECTOR];
extern kword_t proc_tty_line_bases[];

static void check(int ok, const char *what);
int fs_bcache_reclaim(kword_t words);

/* Host references for compact target-assembly process primitives.  Keep the
 * policy tests here; instruction-level coverage belongs to the PDP-6 tests. */
void
proc_runq_add(unsigned int slot)
{
        struct proc *p;

        p = &proc_table[slot];
        if (PROC_STATE(p) != PROC_SRUN)
                return;
        p->sched = (p->sched & ~PROC_SCHED_RH_MASK) |
            (proc_runq_head & PROC_SCHED_RH_MASK);
        proc_runq_head = (kword_t)slot;
}

void
proc_runq_remove(unsigned int slot)
{
        unsigned int cur;
        unsigned int prev;

        prev = 0U;
        cur = (unsigned int)proc_runq_head;
        while (cur != 0U && cur != slot) {
                prev = cur;
                cur = PROC_RUNQ_NEXT(&proc_table[cur]);
        }
        if (cur == 0U)
                return;
        if (prev == 0U)
                proc_runq_head = (kword_t)PROC_RUNQ_NEXT(&proc_table[cur]);
        else
                proc_table[prev].sched =
                    (proc_table[prev].sched & ~PROC_SCHED_RH_MASK) |
                    ((kword_t)PROC_RUNQ_NEXT(&proc_table[cur]) &
                    PROC_SCHED_RH_MASK);
}

kword_t
proc_tty_line_base_get(unsigned int tty)
{
        kword_t word;

        word = proc_tty_line_bases[tty >> 1U];
        return (tty & 1U) != 0U ? (word >> 18U) & 0777777UL :
            word & 0777777UL;
}

void
proc_tty_line_base_set(unsigned int tty, kword_t base)
{
        kword_t *word;

        word = &proc_tty_line_bases[tty >> 1U];
        if ((tty & 1U) != 0U)
                *word = (*word & 0777777UL) | ((base & 0777777UL) << 18U);
        else
                *word = (*word & ~0777777UL) | (base & 0777777UL);
}

int
fs_memory_reclaim(kword_t words, unsigned int level)
{
        if (level == 0U)
                return fs_bcache_reclaim(words);
        return 0;
}

void
file_close_all(void)
{
}

void
proc_sched_resched_current(void)
{
}

void
proc_exit_current(int status)
{
        (void)status;
        check(0, "unexpected proc_exit_current");
}

static kword_t test_copy_words;
static kword_t test_swap_words_read;
static kword_t test_swap_words_written;

int
fs_bcache_reclaim(kword_t words)
{
        (void)words;
        return 0;
}

void
fs_move_words(const kword_t *src, kword_t *dst, unsigned int count)
{
        unsigned int i;

        if (dst < src) {
                for (i = 0U; i < count; ++i)
                        dst[i] = src[i];
        } else if (dst > src) {
                i = count;
                while (i != 0U) {
                        --i;
                        dst[i] = src[i];
                }
        }
        test_copy_words += (kword_t)count;
}

int
tty_putchar(kword_t tty_char)
{
        (void)tty_char;
        return 0;
}

kword_t pdp10_pi_handlers[PDP10_PI_HANDLER_CAPACITY];
kword_t pdp10_pi_level1_dispatch_jump;
kword_t pdp10_pi_level2_dispatch_jump;
kword_t pdp10_pi_level3_dispatch_jump;
kword_t pdp10_pi_level4_dispatch_jump;
kword_t pdp10_pi_level5_dispatch_jump;
kword_t pdp10_pi_level6_dispatch_jump;
kword_t native_sys_putchar_call;
kword_t native_sys_getchar_call;
kword_t tty_write_s6rec_jump;
kword_t tty_read_s6rec_jump;
kword_t ptr_read_words_jump;
kword_t ptp_write_words_jump;
kword_t cr_read_words_jump;
kword_t cp_write_words_jump;
kword_t lpt_putchar_jump;
kword_t lpt_write_s6rec_jump;
kword_t dpy_write_words_jump;
kword_t storage_pi_dsk_jump;
kword_t storage_dct_dsk_jump;
kword_t storage_pi_tape_jump;
kword_t storage_dct_tape_jump;
kword_t storage_clock_dsk_jump;
kword_t dsk270_read_jump;
kword_t dsk270_write_jump;
kword_t drm236_read_jump;
kword_t drm236_write_jump;
kword_t fs_memfs_service_jump;
kword_t sys_memfs_usage_call;
kword_t fs_dtfs_service_jump;
kword_t sys_dtfs_format_jump;
kword_t sys_dtfs_mount_jump;
kword_t fs_d6fs_service_jump;
kword_t fs_tsfs_service_jump;
kword_t sys_dtc_read_block_jump;
kword_t sys_dtc_write_block_jump;
kword_t sys_tsfs_mount_jump;
kword_t memfs_reclaim_jump;
kword_t memfs_shutdown_jump;
kword_t blockset_runtime_service_jump;

kword_t
mach_pi_disable(void)
{
        return 0200UL;
}

void
mach_pi_restore(kword_t state)
{
        check(state == 0200UL, "restore PI state");
}

/* proc_wait_child is a PDP-6 assembly scheduler primitive.  The host MM test
 * never blocks in WAIT; provide the ABI endpoint so resident proc.c links. */
int
proc_wait_child(void)
{
        return -1;
}

/* proc_trim_high is target assembly, but proc.c uses it for ordinary table
 * maintenance.  Keep a small host reference implementation so MM/process
 * lifetime tests exercise the same trailing-FREE rule. */
void
proc_trim_high(void)
{
        while (proc_high_slot > 1U &&
            PROC_IS_FREE(&proc_table[proc_high_slot - 1U]))
                --proc_high_slot;
}

/* Session teardown is validated by the dedicated target session tests.  The
 * host MM regression must not enter that target-only control path. */
int
proc_session_teardown(unsigned int leader_slot, kword_t leader_ctl)
{
        (void)leader_slot;
        (void)leader_ctl;
        check(0, "unexpected proc_session_teardown");
        return -1;
}

/* These process-control helpers are PDP-10 assembly endpoints in the resident
 * kernel.  The host MM test does not exercise process hierarchy, events, or
 * TTY ownership; keep explicit traps here so proc.c can link without silently
 * emulating target-only control paths. */
int
proc_tty_session_has(unsigned int session, unsigned int pgrp,
    unsigned int skip_slot)
{
        (void)session;
        (void)pgrp;
        (void)skip_slot;
        check(0, "unexpected proc_tty_session_has");
        return 0;
}

int
proc_event_send(unsigned int target, unsigned int event, int group)
{
        (void)target;
        (void)event;
        (void)group;
        check(0, "unexpected proc_event_send");
        return -1;
}

int
proc_has_live_user(void)
{
        check(0, "unexpected proc_has_live_user");
        return 0;
}

void
proc_notify_parent(unsigned int parent)
{
        if (parent != 0U)
                check(0, "unexpected proc_notify_parent");
}

kword_t
proc_scope_id(const struct proc *p)
{
        (void)p;
        check(0, "unexpected proc_scope_id");
        return 0UL;
}

void
fs_copy_words(const kword_t *src, kword_t *dst, unsigned int count)
{
        unsigned int i;

        test_copy_words += (kword_t)count;
        for (i = 0U; i < count; ++i)
                dst[i] = src[i];
}

void
fs_zero_words(kword_t *dst, unsigned int count)
{
        unsigned int i;

        for (i = 0U; i < count; ++i)
                dst[i] = 0UL;
}

#define TEST_UAREA_BASE 0600000UL

static void
test_set_uarea(unsigned int slot)
{
        kword_t base;

        base = TEST_UAREA_BASE + (kword_t)slot * PROC_UAREA_WORDS *
            (kword_t)sizeof(kword_t);
        PROC_SET_META_LH(&proc_table[slot], base);
        proc_table[slot].meta |=
            (kword_t)PROC_F_UAREA << PROC_FLAGS_SHIFT;
        fs_zero_words((kword_t *)(unsigned long)base,
            (unsigned int)PROC_UAREA_WORDS);
}

/*
 * Host-side scheduler fixture only.  proc_nice_current() is now a compact
 * PDP-6 assembly leaf because the production path also enforces UID-0 when
 * raising priority.  mm-v1 exercises scheduler ordering and swap-state
 * preservation, not the syscall privilege check (covered by the target and
 * authorization tests), so encode the requested nice value directly here.
 */
static int
test_set_nice(unsigned int slot, int value)
{
        kword_t sched;

        if (value < PROC_NICE_MIN)
                value = PROC_NICE_MIN;
        if (value > PROC_NICE_MAX)
                value = PROC_NICE_MAX;
        sched = proc_table[slot].sched;
        sched &= ~((kword_t)PROC_NICE_MASK << PROC_NICE_SHIFT);
        sched |= (kword_t)(value + (int)PROC_NICE_BIAS) << PROC_NICE_SHIFT;
        proc_table[slot].sched = sched;
        return value;
}

#define TEST_SWAP_BLOCKS 0100U
#define TEST_EXEC_NODE    VFS_NODE(MEMFS_PROVIDER, \
    VFS_MOUNT_KIND(1U, MEMFS_KIND_NODE), 012345U)
static kword_t swap_store[TEST_SWAP_BLOCKS * DSK_WORDS_PER_SECTOR];
static kword_t exec_text[02000];
static int test_exec_pure;
static int test_swap_fail_read;
/* Host-only allocator fixture.  The production bitmap representation and
 * first-fit implementation live solely in backstore.s and are covered by the
 * PDP-6 target test.  mm-v1 needs only allocation ownership semantics while
 * exercising MM/process swap transactions. */
static unsigned char host_backstore_used[TEST_SWAP_BLOCKS];
kword_t *backstore_bitmap;
kword_t backstore_blocks;
kword_t backstore_blocks_used;
unsigned int backstore_enabled;

unsigned int
backstore_bitmap_words(kword_t blocks)
{
        return blocks == 0UL ? 0U : 1U;
}

void
backstore_init(kword_t *bitmap, kword_t blocks)
{
        unsigned int i;

        backstore_bitmap = bitmap;
        backstore_blocks = blocks;
        backstore_blocks_used = 0UL;
        backstore_enabled = 0U;
        for (i = 0U; i < TEST_SWAP_BLOCKS; ++i)
                host_backstore_used[i] = 0U;
}

int
backstore_alloc(kword_t blocks, kword_t reserve, kword_t *firstp)
{
        kword_t first;
        kword_t i;
        kword_t free_blocks;

        if (!backstore_enabled || blocks == 0UL || firstp == 0 ||
            blocks > backstore_blocks || backstore_blocks > TEST_SWAP_BLOCKS)
                return -1;
        free_blocks = backstore_blocks - backstore_blocks_used;
        if (free_blocks <= reserve || blocks > free_blocks - reserve)
                return -1;
        for (first = 0UL; first <= backstore_blocks - blocks; ++first) {
                for (i = 0UL; i < blocks; ++i)
                        if (host_backstore_used[first + i] != 0U)
                                break;
                if (i == blocks) {
                        for (i = 0UL; i < blocks; ++i)
                                host_backstore_used[first + i] = 1U;
                        backstore_blocks_used += blocks;
                        *firstp = first;
                        return 0;
                }
                first += i;
        }
        return -1;
}

void
backstore_free(kword_t first, kword_t blocks)
{
        kword_t i;

        if (blocks == 0UL || first >= backstore_blocks ||
            blocks > backstore_blocks - first)
                return;
        for (i = 0UL; i < blocks; ++i)
                host_backstore_used[first + i] = 0U;
        backstore_blocks_used -= blocks;
}

static int
host_backstore_io(int write, kword_t first, kword_t count, kword_t *buf)
{
        kword_t words;
        unsigned int i;

        if (!write && test_swap_fail_read)
                return -1;
        if (first > TEST_SWAP_BLOCKS || count > TEST_SWAP_BLOCKS - first)
                return -1;
        words = count * DSK_WORDS_PER_SECTOR;
        if (buf == 0)
                return -1;
        for (i = 0U; (kword_t)i < words; ++i) {
                if (!write)
                        buf[i] = swap_store[first * DSK_WORDS_PER_SECTOR + i];
                else
                        swap_store[first * DSK_WORDS_PER_SECTOR + i] = buf[i];
        }
        if (!write)
                test_swap_words_read += words;
        else
                test_swap_words_written += words;
        return 0;
}

kword_t
blockset_tail_blocks(void)
{
        return TEST_SWAP_BLOCKS;
}

int
backstore_read(kword_t first, kword_t blocks, kword_t *buf)
{
        return host_backstore_io(0, first, blocks, buf);
}

int
backstore_write(kword_t first, kword_t blocks, const kword_t *buf)
{
        return host_backstore_io(1, first, blocks, (kword_t *)buf);
}

static kword_t
test_swap_used_blocks(void)
{
        kword_t used;
        unsigned int i;

        used = 0UL;
        for (i = 0U; i < proc_slots; ++i) {
                if (VM_PDP6_BASE(&proc_table[i]) != 0UL)
                        continue;
                used += proc_swap_records[i].state & MM_HALF_MASK;
        }
        return used;
}

int
vfs_stat(vnode_t node, struct vfs_stat *st)
{
        kword_t reloc_words;

        if (node != TEST_EXEC_NODE || st == 0)
                return -1;
        reloc_words = (02000UL + 35UL) / 36UL;
        st->type = VFS_TYPE_REG;
        st->size_words = (test_exec_pure ? EXEC_DXR_EXT_HDR_WORDS :
            EXEC_DXR_BASE_HDR_WORDS) + 02000UL + reloc_words;
        return 0;
}

int
vfs_read_words(vnode_t node, unsigned int off, kword_t *buf,
    unsigned int words)
{
        unsigned int i;

        if (node != TEST_EXEC_NODE || buf == 0)
                return -1;
        if (off == 0U && words == EXEC_DXR_BASE_HDR_WORDS) {
                buf[0] = (PDP10_SIX6('D','X','R',' ',' ',' ') &
                    ((kword_t)0777777UL << 18U));
                buf[1] = 02000UL << 18U;
                if (test_exec_pure)
                        buf[1] |= EXEC_DXR_F_PURE;
                return (int)words;
        }
        if (off == 2U && words == 1U && test_exec_pure) {
                buf[0] = ((kword_t)01000UL << 18U) | EXEC_DXR_TEXT_TAG;
                return 1;
        }
        if (!test_exec_pure || off < EXEC_DXR_EXT_HDR_WORDS ||
            off - EXEC_DXR_EXT_HDR_WORDS > 02000U ||
            words > 02000U - (off - EXEC_DXR_EXT_HDR_WORDS))
                return -1;
        for (i = 0U; i < words; ++i)
                buf[i] = exec_text[off - EXEC_DXR_EXT_HDR_WORDS + i];
        return (int)words;
}

static void
fail(const char *what)
{
        fprintf(stderr, "mm-v1: %s\n", what);
        exit(1);
}

static void
check(int ok, const char *what)
{
        if (!ok)
                fail(what);
}

static void
check_runq(unsigned int expected, const char *what)
{
        unsigned char seen[PROC_MAX_SLOTS];
        unsigned int count;
        unsigned int i;
        unsigned int slot;

        for (i = 0U; i < PROC_MAX_SLOTS; ++i)
                seen[i] = 0U;
        count = 0U;
        slot = (unsigned int)(proc_runq_head & PROC_SCHED_RH_MASK);
        while (slot != 0U) {
                check(slot < proc_slots, "runq slot out of range");
                check(!seen[slot], "runq cycle or duplicate");
                check(PROC_STATE(&proc_table[slot]) == PROC_SRUN,
                    "runq contains non-runnable process");
                seen[slot] = 1U;
                ++count;
                check(count < PROC_MAX_SLOTS, "runq does not terminate");
                slot = PROC_RUNQ_NEXT(&proc_table[slot]);
        }
        check(count == expected, what);
}

int
main(void)
{
        kword_t base;
        kword_t blocker;
        kword_t frag_process;
        kword_t frag_high;
        kword_t multi_p1;
        kword_t multi_p2;
        kword_t multi_p3;
        kword_t uarea_base;
        kword_t pipe_desc;
        kword_t hold_a;
        kword_t hold_b;
        kword_t *src;
        kword_t *dst;
        void *map;
        unsigned int i;
        unsigned int slot;
        unsigned int counts[PROC_MAX_SLOTS];
        unsigned int first;
        unsigned int second;
        unsigned int third;

        /* Equal effective priorities rotate by process-table position without
         * run-queue storage. */
        for (i = 0U; i < proc_slots; ++i) {
                proc_table[i].meta = 0UL;
                VM_SPACE_RESET(&proc_table[i]);
                proc_table[i].sched = PROC_SCHED_DEFAULT;
        }
        proc_runq_head = 0UL;
        for (i = 1U; i < 4U; ++i) {
                proc_table[i].meta = (kword_t)i;
                VM_PDP6_SET_SPACE(&proc_table[i], 02000UL,
                    020000UL + (kword_t)i * 02000UL);
                PROC_SET_STATE(&proc_table[i], PROC_SRUN);
                proc_runq_add(i);
        }
        check_runq(3U, "initial runnable queue");
        proc_runq_remove(2U);
        check_runq(2U, "remove middle runnable");
        proc_runq_add(2U);
        check_runq(3U, "reinsert runnable");
        proc_high_slot = 4U;
        proc_current_slot = 0UL;
        proc_sched_cursor = 0UL;
        check(proc_sched_tick_select() == 1U, "RR first slot");
        check(proc_sched_tick_select() == 2U, "RR second slot");
        check(proc_sched_tick_select() == 3U, "RR third slot");
        check(proc_sched_tick_select() == 1U, "RR wrap slot");

        /* A runnable RT owner overrides ordinary cyclic/nice selection.
         * Sleeping suspends the preference without releasing ownership. */
        proc_rt_owner = 3UL;
        proc_sched_cursor = 1UL;
        check(proc_sched_resched_select() == 3U,
            "RT owner did not override normal selection");
        proc_runq_remove(3U);
        PROC_SET_STATE(&proc_table[3], PROC_SLEEP);
        check(proc_sched_resched_select() != 3U && proc_rt_owner == 3UL,
            "sleeping RT owner retained runnable preference");
        PROC_SET_STATE(&proc_table[3], PROC_SRUN);
        proc_runq_add(3U);
        proc_rt_owner = 0UL;

        /* A partial user quantum is charged once when a software reschedule
         * forces selection before the normal timer quantum expires. */
        proc_current_slot = 1UL;
        proc_sched_cursor = 0UL;
        proc_sched_deferred_ticks = 3UL;
        slot = proc_sched_resched_select();
        check(slot > 0U && slot < 4U,
            "partial quantum reschedule selection");
        check(proc_sched_deferred_ticks == 0UL,
            "partial quantum counter not cleared");

        /* Sleep age advances on the original 64-clock boundary even when
         * ordinary quanta no longer scan the whole descriptor table. */
        proc_current_slot = 0UL;
        proc_runq_remove(3U);
        proc_table[3].sched &= ~PROC_CPU_SLEEP_BITS;
        PROC_SET_STATE(&proc_table[3], PROC_SLEEP);
        proc_sched_age_phase = 0U;
        proc_sched_deferred_ticks = 63UL;
        check(proc_sched_resched_select() != 0U,
            "63-tick coarse-accounting selection");
        check(proc_sched_age_phase == 63U &&
            PROC_SLEEP_AGE(&proc_table[3]) == 0U,
            "sleep age advanced before 64 clocks");
        proc_sched_deferred_ticks = 1UL;
        check(proc_sched_resched_select() != 0U,
            "64th-tick coarse-accounting selection");
        check(proc_sched_age_phase == 0U &&
            PROC_SLEEP_AGE(&proc_table[3]) == 1U,
            "sleep age missed 64-clock boundary");
        proc_table[3].sched &= ~PROC_CPU_SLEEP_BITS;
        PROC_SET_STATE(&proc_table[3], PROC_SRUN);
        proc_runq_add(3U);

        /* Nice changes the selected priority in the expected direction. */
        proc_current_slot = 1UL;
        check(test_set_nice(1U, -10) == -10, "set negative nice");
        proc_current_slot = 2UL;
        check(test_set_nice(2U, 0) == 0, "set default nice");
        proc_current_slot = 3UL;
        check(test_set_nice(3U, 10) == 10, "set positive nice");
        proc_sched_cursor = 0UL;
        check(proc_sched_tick_select() == 1U, "negative nice not favored");

        /* The bounded recent-CPU penalty prevents the favored task from
         * monopolizing the CPU while retaining nice ordering over time. */
        for (i = 0U; i < proc_slots; ++i)
                counts[i] = 0U;
        proc_current_slot = 1UL;
        proc_sched_cursor = 0UL;
        for (i = 0U; i < 1200U; ++i) {
                slot = proc_sched_tick_select();
                check(slot > 0U && slot < proc_slots,
                    "tick selector returned invalid slot");
                ++counts[slot];
                proc_current_slot = (kword_t)slot;
        }
        check(counts[1] > counts[2] && counts[2] > counts[3],
            "nice did not order observed CPU share");

        /* Reset scheduling fields before the MM/swap tests below. */
        proc_current_slot = 0UL;
        proc_sched_cursor = 0UL;
        proc_runq_head = 0UL;
        proc_rt_owner = 0UL;
        for (i = 0U; i < proc_slots; ++i) {
                proc_table[i].meta = 0UL;
                VM_SPACE_RESET(&proc_table[i]);
                proc_table[i].sched = PROC_SCHED_DEFAULT;
        }

        mm_boot_init(0100000UL);
        check(mm_add_free(020000UL, 010000UL) == MM_OK,
            "add low bootstrap range");
        check(mm_add_free(050000UL, 030000UL) == MM_OK,
            "add high bootstrap range");
        check(mm_arena_count == 2,
            "non-adjacent managed arenas were coalesced");
        check(MM_ARENA_BASE(mm_arenas[0]) == 020000UL &&
            MM_ARENA_WORDS(mm_arenas[0]) == 010000UL,
            "low bootstrap arena changed");
        check(MM_ARENA_BASE(mm_arenas[1]) == 050000UL &&
            MM_ARENA_WORDS(mm_arenas[1]) == 030000UL,
            "high bootstrap arena changed");
        check(mm_extent_count == 0,
            "free arenas consumed allocation descriptors");
        check(mm_total_free() == 040000UL &&
            mm_largest_free() == 030000UL,
            "implicit free-space totals incorrect");

        /* Permanent packed MRES must leave allocator bookkeeping once
         * installed.  Removing the used descriptor must trim the managed
         * arena so the physical range cannot become allocatable again. */
        mm_boot_init(0100000UL);
        check(mm_add_free(020000UL, 010000UL) == MM_OK,
            "add permanent MRES test range");
        check(mm_alloc(01000UL, MM_TYPE_MODULE, 7U, MM_ALLOC_LOW, &base) ==
            MM_OK && base == 020000UL, "allocate first permanent MRES");
        check(mm_pin(base) == MM_OK &&
            mm_boot_reserve(base, MM_TYPE_MODULE, 7U) == MM_ERR_INVAL,
            "reserved pinned MRES descriptor");
        check(mm_unpin(base) == MM_OK &&
            mm_boot_reserve(base, MM_TYPE_MODULE, 7U) == MM_OK,
            "commit first permanent MRES");
        check(mm_extent_count == 0 && mm_arena_count == 1 &&
            MM_ARENA_BASE(mm_arenas[0]) == 021000UL &&
            MM_ARENA_WORDS(mm_arenas[0]) == 07000UL,
            "permanent MRES remained in managed arena");
        check(mm_free(base, MM_TYPE_MODULE, 7U) == MM_ERR_INVAL,
            "permanent MRES remained allocator managed");
        check(mm_alloc(01000UL, MM_TYPE_MODULE, 8U, MM_ALLOC_LOW, &base) ==
            MM_OK && base == 021000UL, "allocate second permanent MRES");
        check(mm_boot_reserve(base, MM_TYPE_MODULE, 8U) == MM_OK &&
            mm_extent_count == 0 &&
            MM_ARENA_BASE(mm_arenas[0]) == 022000UL,
            "second permanent MRES did not advance arena base");

        /* Boot free-space bookkeeping has a separate tiny arena table.
         * Adjacent returns must still merge when every arena slot is occupied. */
        mm_boot_init(0100000UL);
        for (i = 0U; i < MM_MAX_ARENAS; ++i)
                check(mm_add_free(01001UL + (kword_t)i * 4UL, 1UL) == MM_OK,
                    "fill arena table for right merge");
        check(mm_arena_count == MM_MAX_ARENAS, "arena table not full");
        check(mm_add_free(01000UL, 1UL) == MM_OK,
            "full-arena right-adjacent add failed");
        check(mm_arena_count == MM_MAX_ARENAS &&
            MM_ARENA_BASE(mm_arenas[0]) == 01000UL &&
            MM_ARENA_WORDS(mm_arenas[0]) == 2UL,
            "full-arena right merge incorrect");

        mm_boot_init(0100000UL);
        for (i = 0U; i < MM_MAX_ARENAS; ++i)
                check(mm_add_free(01000UL + (kword_t)i * 4UL, 1UL) == MM_OK,
                    "fill arena table for left merge");
        check(mm_add_free(01001UL, 1UL) == MM_OK,
            "full-arena left-adjacent add failed");
        check(mm_arena_count == MM_MAX_ARENAS &&
            MM_ARENA_BASE(mm_arenas[0]) == 01000UL &&
            MM_ARENA_WORDS(mm_arenas[0]) == 2UL,
            "full-arena left merge incorrect");

        mm_boot_init(0100000UL);
        for (i = 0U; i < MM_MAX_ARENAS; ++i)
                check(mm_add_free(01001UL + (kword_t)i * 2UL, 1UL) == MM_OK,
                    "fill arena table for bridge merge");
        check(mm_add_free(01002UL, 1UL) == MM_OK,
            "full-arena bridge add failed");
        check(mm_arena_count == MM_MAX_ARENAS - 1 &&
            MM_ARENA_BASE(mm_arenas[0]) == 01001UL &&
            MM_ARENA_WORDS(mm_arenas[0]) == 3UL,
            "full-arena bridge merge incorrect");

        /* Model KINIT's real topology: low permanent space, a high tail above
         * the disposable stack, then a third arena as MRES source packages
         * become dead.  Later reclaim bridges the low/source arenas without
         * ever requiring a fourth arena. */
        mm_boot_init(0100000UL);
        check(mm_add_free(020000UL, 010000UL) == MM_OK,
            "add KINIT low arena");
        check(mm_add_free(077000UL, 01000UL) == MM_OK,
            "add KINIT high arena");
        check(mm_add_free(030000UL, 020000UL) == MM_OK &&
            mm_arena_count == 2, "extend KINIT low arena");
        check(mm_add_free(060000UL, 01000UL) == MM_OK &&
            mm_arena_count == 3, "add KINIT MRES-source arena");
        check(mm_add_free(061000UL, 01000UL) == MM_OK &&
            mm_arena_count == 3, "extend KINIT MRES-source arena");
        check(mm_add_free(050000UL, 010000UL) == MM_OK &&
            mm_arena_count == 2 &&
            MM_ARENA_BASE(mm_arenas[0]) == 020000UL &&
            MM_ARENA_WORDS(mm_arenas[0]) == 042000UL,
            "KINIT reclaim did not bridge managed arenas");

        /* Allocation descriptors now describe allocated memory only. */
        mm_boot_init(0100000UL);
        check(mm_add_free(01000UL, 02000UL) == MM_OK,
            "add descriptor-capacity arena");
        for (i = 0U; i < MM_MAX_EXTENTS; ++i)
                check(mm_alloc(1UL, MM_TYPE_KERNEL_DYNAMIC, i + 1U,
                    MM_ALLOC_LOW, &base) == MM_OK,
                    "fill allocated-only descriptor table");
        check(mm_extent_count == MM_MAX_EXTENTS,
            "allocated-only descriptor table not full");
        check(mm_alloc(1UL, MM_TYPE_KERNEL_DYNAMIC, 0777U,
            MM_ALLOC_LOW, &base) == MM_ERR_DESCRIPTORS,
            "descriptor exhaustion not reported");

        /* Restore the original bootstrap layout for the following tests. */
        mm_boot_init(0100000UL);
        check(mm_add_free(020000UL, 010000UL) == MM_OK,
            "restore low bootstrap range");
        check(mm_add_free(050000UL, 030000UL) == MM_OK,
            "restore high bootstrap range");

        check(mm_alloc_aligned(03000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_HIGH, &base) == MM_OK, "aligned high allocation");
        check((base & 01777UL) == 0UL, "process base is not 02000 aligned");
        check(base == 074000UL, "unexpected high process placement");
        check(mm_free(base, MM_TYPE_PROCESS, 1U) == MM_OK,
            "free aligned process");
        check(mm_extent_count == 0 && mm_arena_count == 2,
            "free crossed reserved bootstrap hole");

        check(mm_alloc(01000UL, MM_TYPE_MODULE, 7U, MM_ALLOC_LOW,
            &base) == MM_OK, "low module allocation");
        check(base == 020000UL, "module did not use low preference");
        check(mm_pin(base) == MM_OK, "pin module");
        check(mm_free(base, MM_TYPE_MODULE, 7U) == MM_ERR_BUSY,
            "pinned module was freed");
        check(mm_unpin(base) == MM_OK, "unpin module");
        check(mm_free(base, MM_TYPE_MODULE, 7U) == MM_OK,
            "free module");

        /*
         * Fragment two free islands around a stopped process.  The 06000-word
         * request can succeed only if MM transactionally moves that process
         * upward, exposing its old range as part of the following free gap.
         * Host virtual addresses are deliberately chosen above mmap_min_addr;
         * they stand in for PDP-6 physical word addresses during the copy.
         */
        map = mmap((void *)(unsigned long)0200000UL, 02000000UL,
            PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED,
            -1, 0);
        check(map != MAP_FAILED, "map host process-copy window");
        check(proc_slots_for_core(0100000UL) == 24U,
            "32K process slot sizing");
        check(proc_slots_for_core(0200000UL) == 40U,
            "64K process slot sizing");
        check(proc_slots_for_core(0300000UL) == 64U,
            "96K process slot sizing");
        check(proc_slots_for_core(0400000UL) == 88U,
            "128K process slot sizing");
        check(proc_slots_for_core(0600000UL) == 128U,
            "192K process slot sizing");
        check(proc_slots_for_core(01000000UL) == 192U,
            "256K process slot sizing");

        /* Keep dynamic swap descriptors in a mapped host-only physical range
         * outside every later allocator scenario. */
        mm_boot_init(0777777UL);
        check(mm_add_free(0700000UL, 01000UL) == MM_OK,
            "add swap descriptor range");
        check(proc_swap_boot_init(proc_slots) == 0,
            "allocate runtime-sized swap descriptor table");
        backstore_enabled = 1U;
        check(backstore_alloc(1UL, TEST_SWAP_BLOCKS, &base) != 0,
            "BACKSTORE reserve did not protect free capacity");
        check(backstore_alloc(1UL, 0UL, &base) == 0 && base == 0UL,
            "BACKSTORE first-fit allocation");
        check(backstore_blocks_used == 1UL,
            "BACKSTORE allocation accounting");
        backstore_free(base, 1UL);
        check(backstore_blocks_used == 0UL,
            "BACKSTORE free accounting");
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 010000UL) == MM_OK,
            "add compaction low range");
        check(mm_add_free(0300000UL, 04000UL) == MM_OK,
            "add compaction high range");
        check(mm_alloc(02000UL, MM_TYPE_MODULE, 7U, MM_ALLOC_LOW,
            &base) == MM_OK && base == 0200000UL,
            "place compaction blocker");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_LOW, &base) == MM_OK && base == 0202000UL,
            "place movable process");
        proc_table[1].meta = 1UL;
        PROC_SET_META_LH(&proc_table[1], 0340000UL);
        proc_table[1].meta |=
            (kword_t)PROC_F_UAREA << PROC_FLAGS_SHIFT;
        PROC_CTL_WORD(&proc_table[1]) = 0UL;
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[1], PROC_SRUN);
        proc_runq_head = 0UL;
        proc_runq_add(1U);
        VM_PDP6_SET_SPACE(&proc_table[1], 02000UL, base);
        src = (kword_t *)(unsigned long)base;
        for (i = 0U; i < 02000U; ++i)
                src[i] = 0123456700000UL + (kword_t)i;

        check(mm_alloc(06000UL, MM_TYPE_KERNEL_DYNAMIC, 9U, MM_ALLOC_LOW,
            &base) == MM_OK, "compact fragmented process range");
        check(base == 0202000UL, "compacted allocation base");
        check(VM_PDP6_BASE(&proc_table[1]) == 0302000UL,
            "process was not moved upward");
        dst = (kword_t *)(unsigned long)VM_PDP6_BASE(&proc_table[1]);
        for (i = 0U; i < 02000U; ++i)
                check(dst[i] == 0123456700000UL + (kword_t)i,
                    "process image changed during move");
        check(PROC_STATE(&proc_table[1]) == PROC_SRUN &&
            PROC_STOP_REASONS(&proc_table[1]) == 0U,
            "MM stop leaked after runnable process move");
        check_runq(1U, "MM move lost runnable queue member");
        proc_current_slot = 1UL;
        check(vm_extent_move(1U, VM_PDP6_BASE(&proc_table[1]),
            VM_SPACE_WORDS(&proc_table[1]),
            VM_PDP6_BASE(&proc_table[1]) + VM_EXTENT_ALIGN_WORDS) == MM_ERR_BUSY,
            "current process was movable");
        proc_current_slot = 0UL;
        check(mm_pin(VM_PDP6_BASE(&proc_table[1])) == MM_OK,
            "pin moved process");
        check(!vm_space_can_swap(&proc_table[1]),
            "pinned process remained swappable");
        check(mm_unpin(VM_PDP6_BASE(&proc_table[1])) == MM_OK,
            "unpin moved process");
        PROC_CTL_WORD(&proc_table[1]) |= PROC_USER_MAP_BIT;
        check(vm_extent_move(1U, VM_PDP6_BASE(&proc_table[1]),
            VM_SPACE_WORDS(&proc_table[1]),
            VM_PDP6_BASE(&proc_table[1]) + VM_EXTENT_ALIGN_WORDS) == MM_ERR_BUSY,
            "live user mapping was movable");
        PROC_CTL_WORD(&proc_table[1]) &= ~PROC_USER_MAP_BIT;

        /* Compaction may need more than one process move.  Exercise three
         * consecutive moves while preserving the executive state that makes
         * those processes interesting: an interruptible pipe sleeper, a WAIT
         * sleeper, and a job-control stopped process.  The file table lives in
         * the stable u-area, so duplicate descriptors for the same pipe must
         * remain byte-for-byte unchanged while the user extent moves. */
        proc_runq_head = 0UL;
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 016000UL) == MM_OK,
            "add multi-move compaction range");
        check(mm_alloc(02000UL, MM_TYPE_KERNEL_DYNAMIC, 7U, MM_ALLOC_LOW,
            &blocker) == MM_OK && blocker == 0200000UL,
            "allocate multi-move low blocker");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_LOW, &multi_p1) == MM_OK && multi_p1 == 0202000UL,
            "allocate pipe sleeper extent");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 2U,
            MM_ALLOC_LOW, &multi_p2) == MM_OK && multi_p2 == 0204000UL,
            "allocate WAIT sleeper extent");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 3U,
            MM_ALLOC_LOW, &multi_p3) == MM_OK && multi_p3 == 0206000UL,
            "allocate stopped extent");
        check(mm_free(blocker, MM_TYPE_KERNEL_DYNAMIC, 7U) == MM_OK,
            "free multi-move low blocker");

        proc_table[1].meta = 1UL;
        test_set_uarea(1U);
        uarea_base = PROC_UAREA_BASE(&proc_table[1]);
        proc_table[1].sched = PROC_SCHED_DEFAULT |
            ((kword_t)PROC_WAIT_INTR << PROC_WAIT_SHIFT) | 012345UL;
        PROC_SET_STATE(&proc_table[1], PROC_SLEEP);
        VM_PDP6_SET_SPACE(&proc_table[1], 02000UL, multi_p1);
        pipe_desc = VFS_NODE(7U, 1U, 01234U) | FILE_META_READ;
        PROC_UAREA_WORD(&proc_table[1], PROC_FILE_TABLE_OFFSET + 6UL) =
            pipe_desc;
        PROC_UAREA_WORD(&proc_table[1], PROC_FILE_TABLE_OFFSET + 7UL) = 0777UL;
        PROC_UAREA_WORD(&proc_table[1], PROC_FILE_TABLE_OFFSET + 14UL) =
            pipe_desc;
        PROC_UAREA_WORD(&proc_table[1], PROC_FILE_TABLE_OFFSET + 15UL) = 0777UL;

        proc_table[2].meta = 2UL;
        test_set_uarea(2U);
        proc_table[2].sched = PROC_SCHED_DEFAULT |
            ((kword_t)PROC_WAIT_CHILD << PROC_WAIT_SHIFT);
        PROC_SET_STATE(&proc_table[2], PROC_SLEEP);
        VM_PDP6_SET_SPACE(&proc_table[2], 02000UL, multi_p2);

        proc_table[3].meta = 3UL;
        test_set_uarea(3U);
        PROC_CTL_WORD(&proc_table[3]) =
            (kword_t)PROC_STOP_JOB << PROC_STOP_SHIFT;
        proc_table[3].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[3], PROC_STOP);
        VM_PDP6_SET_SPACE(&proc_table[3], 02000UL, multi_p3);
        proc_high_slot = 4U;

        check(mm_alloc(010000UL, MM_TYPE_KERNEL_DYNAMIC, 9U, MM_ALLOC_LOW,
            &base) == MM_OK, "compact through three process extents");
        check(base == 0200000UL, "multi-move compacted allocation base");
        check(VM_PDP6_BASE(&proc_table[1]) == 0214000UL &&
            VM_PDP6_BASE(&proc_table[2]) == 0212000UL &&
            VM_PDP6_BASE(&proc_table[3]) == 0210000UL,
            "multi-move process placement incorrect");
        check(PROC_STATE(&proc_table[1]) == PROC_SLEEP &&
            PROC_WAIT_CLASS(&proc_table[1]) == PROC_WAIT_INTR &&
            PROC_WAIT_CHANNEL(&proc_table[1]) == 012345UL,
            "pipe sleeper state changed during compaction");
        check(PROC_STATE(&proc_table[2]) == PROC_SLEEP &&
            PROC_WAIT_CLASS(&proc_table[2]) == PROC_WAIT_CHILD &&
            PROC_WAIT_CHANNEL(&proc_table[2]) == 0UL,
            "WAIT sleeper state changed during compaction");
        check(PROC_STATE(&proc_table[3]) == PROC_STOP &&
            PROC_STOP_REASONS(&proc_table[3]) == PROC_STOP_JOB,
            "job-control stop changed during compaction");
        check(PROC_UAREA_BASE(&proc_table[1]) == uarea_base &&
            PROC_UAREA_WORD(&proc_table[1], PROC_FILE_TABLE_OFFSET + 6UL) ==
            pipe_desc &&
            PROC_UAREA_WORD(&proc_table[1], PROC_FILE_TABLE_OFFSET + 7UL) ==
            0777UL &&
            PROC_UAREA_WORD(&proc_table[1], PROC_FILE_TABLE_OFFSET + 14UL) ==
            pipe_desc &&
            PROC_UAREA_WORD(&proc_table[1], PROC_FILE_TABLE_OFFSET + 15UL) ==
            0777UL, "duplicate pipe descriptors changed during compaction");
        check(!PROC_TRANSITION(&proc_table[1]) &&
            !PROC_TRANSITION(&proc_table[2]) &&
            !PROC_TRANSITION(&proc_table[3]),
            "compaction left process transition state set");
        check(mm_free(base, MM_TYPE_KERNEL_DYNAMIC, 9U) == MM_OK,
            "free multi-move compacted allocation");
        for (i = 1U; i <= 3U; ++i) {
                check(mm_free(VM_PDP6_BASE(&proc_table[i]),
                    MM_TYPE_PROCESS, i) == MM_OK,
                    "free multi-move process extent");
                proc_table[i].meta = 0UL;
                proc_table[i].sched = 0UL;
                VM_SPACE_RESET(&proc_table[i]);
        }
        proc_high_slot = 4U;

        /* A live user mapping is an immovable and unswappable island.  If the
         * free total is sufficient but the island prevents an aligned fit, MM
         * must report genuine fragmentation rather than misclassifying it as
         * core exhaustion. */
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 06000UL) == MM_OK,
            "add mapping-held fragmentation range");
        check(mm_alloc(02000UL, MM_TYPE_KERNEL_DYNAMIC, 7U, MM_ALLOC_LOW,
            &hold_a) == MM_OK && hold_a == 0200000UL,
            "allocate mapping-held low holder");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_LOW, &multi_p1) == MM_OK && multi_p1 == 0202000UL,
            "allocate mapping-held process");
        check(mm_free(hold_a, MM_TYPE_KERNEL_DYNAMIC, 7U) == MM_OK,
            "free mapping-held low holder");
        proc_table[1].meta = 1UL;
        test_set_uarea(1U);
        PROC_CTL_WORD(&proc_table[1]) |= PROC_USER_MAP_BIT;
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[1], PROC_SLEEP);
        VM_PDP6_SET_SPACE(&proc_table[1], 02000UL, multi_p1);
        proc_high_slot = 2U;
        check(mm_alloc_aligned(04000UL, 02000UL, MM_TYPE_KERNEL_DYNAMIC, 9U,
            MM_ALLOC_LOW, &base) == MM_ERR_FRAGMENTED,
            "mapping-held island was not reported as fragmentation");
        check(VM_PDP6_BASE(&proc_table[1]) == multi_p1 &&
            PROC_USER_MAPPING_HELD(&proc_table[1]),
            "mapping-held island moved during failed compaction");
        PROC_CTL_WORD(&proc_table[1]) &= ~PROC_USER_MAP_BIT;
        check(mm_free(multi_p1, MM_TYPE_PROCESS, 1U) == MM_OK,
            "free mapping-held process");
        proc_table[1].meta = 0UL;
        proc_table[1].sched = 0UL;
        VM_SPACE_RESET(&proc_table[1]);

        /* Physical pins have the same fragmentation semantics as user-mapping
         * holds, but exercise the MM pin count rather than process control. */
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 06000UL) == MM_OK,
            "add pinned fragmentation range");
        check(mm_alloc(02000UL, MM_TYPE_KERNEL_DYNAMIC, 7U, MM_ALLOC_LOW,
            &hold_a) == MM_OK && hold_a == 0200000UL,
            "allocate pinned low holder");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_LOW, &multi_p1) == MM_OK && multi_p1 == 0202000UL,
            "allocate pinned process");
        check(mm_free(hold_a, MM_TYPE_KERNEL_DYNAMIC, 7U) == MM_OK,
            "free pinned low holder");
        proc_table[1].meta = 1UL;
        test_set_uarea(1U);
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[1], PROC_SLEEP);
        VM_PDP6_SET_SPACE(&proc_table[1], 02000UL, multi_p1);
        check(mm_pin(multi_p1) == MM_OK, "pin fragmentation island");
        proc_high_slot = 2U;
        check(mm_alloc_aligned(04000UL, 02000UL, MM_TYPE_KERNEL_DYNAMIC, 9U,
            MM_ALLOC_LOW, &base) == MM_ERR_FRAGMENTED,
            "pinned island was not reported as fragmentation");
        check(VM_PDP6_BASE(&proc_table[1]) == multi_p1 &&
            mm_is_pinned(multi_p1),
            "pinned island moved during failed compaction");
        check(mm_unpin(multi_p1) == MM_OK, "unpin fragmentation island");
        check(mm_free(multi_p1, MM_TYPE_PROCESS, 1U) == MM_OK,
            "free pinned process");
        proc_table[1].meta = 0UL;
        proc_table[1].sched = 0UL;
        VM_SPACE_RESET(&proc_table[1]);
        proc_high_slot = 4U;

        /* Reclaim must continue when the first swap raises total free core
         * above the request but still leaves only fragmented islands.  The
         * second sleeper is at the top of core and cannot be compacted upward;
         * swapping both sleepers is therefore required to make a 06000-word
         * aligned extent next to the permanent middle blocker. */
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 012000UL) == MM_OK,
            "add multi-swap reclaim range");
        check(mm_alloc(02000UL, MM_TYPE_KERNEL_DYNAMIC, 6U, MM_ALLOC_LOW,
            &hold_a) == MM_OK && hold_a == 0200000UL,
            "allocate multi-swap low holder");
        check(mm_alloc(02000UL, MM_TYPE_KERNEL_DYNAMIC, 7U, MM_ALLOC_LOW,
            &blocker) == MM_OK && blocker == 0202000UL,
            "allocate multi-swap permanent blocker");
        check(mm_alloc(02000UL, MM_TYPE_KERNEL_DYNAMIC, 8U, MM_ALLOC_LOW,
            &hold_b) == MM_OK && hold_b == 0204000UL,
            "allocate multi-swap middle holder");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_LOW, &multi_p1) == MM_OK && multi_p1 == 0206000UL,
            "allocate first multi-swap sleeper");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 2U,
            MM_ALLOC_LOW, &multi_p2) == MM_OK && multi_p2 == 0210000UL,
            "allocate second multi-swap sleeper");
        check(mm_free(hold_a, MM_TYPE_KERNEL_DYNAMIC, 6U) == MM_OK &&
            mm_free(hold_b, MM_TYPE_KERNEL_DYNAMIC, 8U) == MM_OK,
            "free multi-swap reclaim islands");
        for (i = 1U; i <= 2U; ++i) {
                proc_table[i].meta = (kword_t)i;
                test_set_uarea(i);
                proc_table[i].sched = PROC_SCHED_DEFAULT |
                    ((kword_t)PROC_WAIT_INTR << PROC_WAIT_SHIFT);
                PROC_SET_STATE(&proc_table[i], PROC_SLEEP);
        }
        VM_PDP6_SET_SPACE(&proc_table[1], 02000UL, multi_p1);
        VM_PDP6_SET_SPACE(&proc_table[2], 02000UL, multi_p2);
        check(proc_swap_attach(1U, TEST_EXEC_NODE, 0UL, 0U) == 0 &&
            proc_swap_attach(2U, TEST_EXEC_NODE, 0UL, 0U) == 0,
            "attach multi-swap sleepers");
        proc_high_slot = 3U;
        check(mm_alloc_aligned(06000UL, 02000UL, MM_TYPE_KERNEL_DYNAMIC, 9U,
            MM_ALLOC_LOW, &base) == MM_OK,
            "fragmented reclaim stopped after first swap");
        check(base == 0204000UL &&
            !VM_SPACE_ACTIVE(&proc_table[1]) &&
            !VM_SPACE_ACTIVE(&proc_table[2]),
            "multi-swap reclaim did not remove both sleepers");
        check(mm_free(base, MM_TYPE_KERNEL_DYNAMIC, 9U) == MM_OK,
            "free multi-swap reclaim allocation");
        check(mm_free(blocker, MM_TYPE_KERNEL_DYNAMIC, 7U) == MM_OK,
            "free multi-swap permanent blocker");
        proc_swap_detach(1U);
        proc_swap_detach(2U);
        for (i = 1U; i <= 2U; ++i) {
                proc_table[i].meta = 0UL;
                proc_table[i].sched = 0UL;
                VM_SPACE_RESET(&proc_table[i]);
        }
        proc_high_slot = 4U;

        /* The corrected direct-slide compactor may overlap-move a sleeping
         * process into the combined source/free span even when neither free
         * island alone is image-sized.  This should satisfy the allocation
         * without needlessly swapping the process. */
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 010000UL) == MM_OK,
            "add fragmented reclaim range");
        check(mm_alloc(02000UL, MM_TYPE_KERNEL_DYNAMIC, 7U, MM_ALLOC_LOW,
            &blocker) == MM_OK && blocker == 0200000UL,
            "allocate fragmented reclaim low blocker");
        check(mm_alloc_aligned(04000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_LOW, &frag_process) == MM_OK && frag_process == 0202000UL,
            "allocate fragmented reclaim process");
        check(mm_alloc(02000UL, MM_TYPE_KERNEL_DYNAMIC, 8U, MM_ALLOC_LOW,
            &frag_high) == MM_OK && frag_high == 0206000UL,
            "allocate fragmented reclaim high blocker");
        check(mm_free(blocker, MM_TYPE_KERNEL_DYNAMIC, 7U) == MM_OK &&
            mm_free(frag_high, MM_TYPE_KERNEL_DYNAMIC, 8U) == MM_OK,
            "free fragmented reclaim islands");
        proc_table[1].meta = 1UL;
        test_set_uarea(1U);
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[1], PROC_SLEEP);
        VM_PDP6_SET_SPACE(&proc_table[1], 04000UL, frag_process);
        check(proc_swap_attach(1U, TEST_EXEC_NODE, 0UL, 0U) == 0,
            "attach fragmented reclaim process");
        check(mm_alloc_aligned(04000UL, 02000UL, MM_TYPE_KERNEL_DYNAMIC, 9U,
            MM_ALLOC_LOW, &base) == MM_OK,
            "swap reclaim after fragmented compaction");
        check(base == 0200000UL && VM_SPACE_ACTIVE(&proc_table[1]) &&
            VM_PDP6_BASE(&proc_table[1]) != frag_process,
            "direct-slide compaction did not move sleeping process");
        check(mm_free(base, MM_TYPE_KERNEL_DYNAMIC, 9U) == MM_OK,
            "free fragmented reclaim allocation");
        proc_swap_detach(1U);
        proc_runq_remove(1U);
        proc_table[1].meta = 0UL;
        proc_table[1].sched = 0UL;
        VM_SPACE_RESET(&proc_table[1]);

        /* Runtime correctness uses whole-image, whole-sector swap.  Keep the
         * executable-backing record in the stable u-area while nonresident;
         * clean-text reload remains a later optimization. */
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 0200000UL) == MM_OK,
            "add pure swap range");
        check(mm_alloc_aligned(04000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_HIGH, &base) == MM_OK, "allocate pure swap process");
        proc_table[1].meta = 1UL;
        test_set_uarea(1U);
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[1], PROC_STOP);
        VM_PDP6_SET_SPACE(&proc_table[1], 04000UL, base);
        src = (kword_t *)(unsigned long)base;
        for (i = 0U; i < 01000U; ++i)
                exec_text[i] = 0400000000000UL + (kword_t)i;
        for (i = 0U; i < 04000U; ++i)
                src[i] = 0500000000000UL + (kword_t)i;
        for (i = 0U; i < 01000U; ++i)
                src[020U + i] = exec_text[i];
        check(PROC_SWAP_RECORD_WORDS == 1U,
            "swap record is not one resident word");
        test_swap_words_read = 0UL;
        test_swap_words_written = 0UL;
        test_exec_pure = 1;
        check(proc_swap_attach(1U, TEST_EXEC_NODE, 01000UL, 1U) == 0,
            "pack pure executable swap state");
        check(proc_swap_records[1].state != 0UL,
            "resident packed swap state is empty");
        check(proc_swap_out(1U) == 0, "swap out pure process");
        check(PROC_STATE(&proc_table[1]) == PROC_STOP &&
            VM_PDP6_BASE(&proc_table[1]) == 0UL, "pure process not swapped");
        PROC_SET_STATE(&proc_table[1], PROC_SRUN);
        proc_runq_head = 0UL;
        proc_runq_add(1U);
        check_runq(1U, "swapped runnable queued");
        proc_high_slot = 2UL;
        proc_sched_cursor = 0UL;
        check(VM_PDP6_BASE(&proc_table[1]) == 0UL &&
            proc_swap_records[1].state != 0UL,
            "swapped runnable process not recognized");
        check(proc_sched_resched_select() == 0U,
            "scheduler tried to run swapped process in PI context");
        check(proc_swap_service_one() == 1,
            "slot-0 service did not swap in runnable process");
        check(VM_SPACE_ACTIVE(&proc_table[1]),
            "slot-0 service left runnable process swapped");
        proc_runq_remove(1U);
        PROC_SET_STATE(&proc_table[1], PROC_STOP);
        check_runq(0U, "stopped swapped process remained queued");
        proc_high_slot = 4U;
        check(test_swap_used_blocks() == 0UL,
            "slot-0 service did not release swap blocks");
        test_swap_words_read = 0UL;
        test_swap_words_written = 0UL;
        check(proc_swap_out(1U) == 0,
            "swap out pure process for direct restore");
        check(test_swap_used_blocks() ==
            04000UL / DSK_WORDS_PER_SECTOR,
            "whole-image pure process consumed unexpected swap blocks");
        check(proc_swap_in(1U) == 0, "swap in pure process");
        src = (kword_t *)(unsigned long)VM_PDP6_BASE(&proc_table[1]);
        for (i = 0U; i < 01000U; ++i)
                check(src[020U + i] == exec_text[i],
                    "pure text was not reloaded from executable");
        for (i = 01020U; i < 04000U; ++i)
                check(src[i] == 0500000000000UL + (kword_t)i,
                    "pure writable tail changed across swap");
        check(test_swap_used_blocks() == 0UL, "pure swap blocks not released");
        check(test_swap_words_written == 04000UL &&
            test_swap_words_read == test_swap_words_written,
            "pure whole-image swap transfer length incorrect");
        check(mm_free(VM_PDP6_BASE(&proc_table[1]), MM_TYPE_PROCESS, 1U) == MM_OK,
            "free pure swap process");
        check(proc_swap_records[1].state != 0UL,
            "swap-in did not restore resident packed state");
        proc_swap_detach(1U);

        /* UNKNOWN is conservative and therefore swaps the complete image. */
        check(mm_alloc_aligned(04000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_HIGH, &base) == MM_OK, "allocate unknown swap process");
        proc_table[1].meta = 1UL;
        test_set_uarea(1U);
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[1], PROC_SLEEP);
        VM_PDP6_SET_SPACE(&proc_table[1], 04000UL, base);
        proc_current_slot = 1UL;
        check(test_set_nice(1U, 7) == 7, "set swap nice state");
        proc_current_slot = 0UL;
        src = (kword_t *)(unsigned long)base;
        for (i = 0U; i < 04000U; ++i)
                src[i] = 0600000000000UL + (kword_t)i;
        test_exec_pure = 0;
        check(proc_swap_attach(1U, TEST_EXEC_NODE, 01000UL, 0U) == 0,
            "pack unknown executable swap state");
        check(proc_swap_out(1U) == 0, "swap out unknown process");
        check(test_swap_used_blocks() ==
            04000UL / DSK_WORDS_PER_SECTOR,
            "unknown executable did not swap complete image");
        check(proc_swap_in(1U) == 0, "swap in unknown process");
        check(test_swap_words_written == 010000UL &&
            test_swap_words_read == test_swap_words_written,
            "unknown whole-image swap transfer length incorrect");
        check(PROC_STATE(&proc_table[1]) == PROC_SLEEP,
            "swap-in did not restore process state");
        check((int)PROC_NICE_ENCODED(&proc_table[1]) -
            (int)PROC_NICE_BIAS == 7,
            "swap-in did not preserve nice state");
        src = (kword_t *)(unsigned long)VM_PDP6_BASE(&proc_table[1]);
        for (i = 0U; i < 04000U; ++i)
                check(src[i] == 0600000000000UL + (kword_t)i,
                    "unknown process changed across swap");
        check(mm_free(VM_PDP6_BASE(&proc_table[1]), MM_TYPE_PROCESS, 1U) == MM_OK,
            "free unknown swap process");
        proc_swap_detach(1U);

        /* The scheduler cursor is authoritative for an equal-priority swapped
         * winner.  Slot-0 swap service must restore that same process rather
         * than rescanning from slot 1 and defeating round-robin fairness. */
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 0200000UL) == MM_OK,
            "add swap fairness range");
        proc_runq_head = 0UL;
        for (i = 1U; i <= 2U; ++i) {
                check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, i,
                    MM_ALLOC_HIGH, &base) == MM_OK,
                    "allocate swap fairness process");
                proc_table[i].meta = (kword_t)i;
                test_set_uarea(i);
                proc_table[i].sched = PROC_SCHED_DEFAULT;
                PROC_SET_STATE(&proc_table[i], PROC_SRUN);
                proc_runq_add(i);
                VM_PDP6_SET_SPACE(&proc_table[i], 02000UL, base);
                check(proc_swap_attach(i, TEST_EXEC_NODE, 0UL, 0U) == 0,
                    "attach swap fairness process");
                check(proc_swap_out(i) == 0,
                    "swap out fairness process");
        }
        proc_high_slot = 3U;
        proc_sched_cursor = 1UL;
        check(proc_sched_resched_select() == 0U &&
            proc_sched_cursor == (2UL | PROC_SCHED_SWAP_REQUEST),
            "scheduler did not select round-robin swapped winner");
        check(proc_swap_service_one() == 2,
            "slot-0 service ignored scheduler swapped winner");
        check(VM_SPACE_ACTIVE(&proc_table[2]) &&
            !VM_SPACE_ACTIVE(&proc_table[1]),
            "slot-0 service restored wrong equal-priority process");
        check(mm_free(VM_PDP6_BASE(&proc_table[2]), MM_TYPE_PROCESS, 2U) ==
            MM_OK, "free restored fairness process");
        proc_swap_detach(2U);
        proc_swap_detach(1U);
        proc_runq_head = 0UL;
        proc_table[1].meta = 0UL;
        proc_table[1].sched = 0UL;
        VM_SPACE_RESET(&proc_table[1]);
        proc_table[2].meta = 0UL;
        proc_table[2].sched = 0UL;
        VM_SPACE_RESET(&proc_table[2]);
        proc_high_slot = 4U;

        /* CONT operates entirely on resident descriptor/u-area state, so a
         * swapped stopped job becomes logically runnable first and is then
         * restored by the ordinary slot-0 swap service. */
        proc_runq_head = 0UL;
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 0200000UL) == MM_OK,
            "add swapped CONT range");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_HIGH, &base) == MM_OK, "allocate swapped CONT process");
        proc_table[1].meta = 1UL |
            ((kword_t)PROC_F_UAREA << PROC_FLAGS_SHIFT);
        PROC_SET_META_LH(&proc_table[1], 0300000UL);
        PROC_UAREA_WORD(&proc_table[1], PROC_FDCTL_OFFSET) =
            (kword_t)PROC_STOP_JOB << PROC_STOP_SHIFT;
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[1], PROC_STOP);
        proc_table[1].sched |=
            ((kword_t)6UL << PROC_CPU_SHIFT) |
            ((kword_t)5UL << PROC_SLEEP_SHIFT);
        VM_PDP6_SET_SPACE(&proc_table[1], 02000UL, base);
        check(proc_swap_attach(1U, TEST_EXEC_NODE, 0UL, 0U) == 0,
            "attach swapped CONT process");
        check(proc_swap_out(1U) == 0, "swap out stopped job");
        check(proc_event_apply(1U, SYS_EVENT_CONT) == 0 &&
            PROC_STATE(&proc_table[1]) == PROC_SRUN &&
            !VM_SPACE_ACTIVE(&proc_table[1]),
            "CONT did not make swapped stopped job runnable");
        check(PROC_CPU_PENALTY(&proc_table[1]) == 0U &&
            PROC_SLEEP_AGE(&proc_table[1]) == 0U,
            "CONT did not clear stale scheduler accounting");
        check_runq(1U, "CONT did not queue runnable stopped job");
        proc_high_slot = 2U;
        proc_sched_cursor = 0UL;
        check(proc_sched_resched_select() == 0U &&
            proc_sched_cursor == (1UL | PROC_SCHED_SWAP_REQUEST),
            "scheduler did not request swapped continued job");
        check(proc_swap_service_one() == 1 && VM_SPACE_ACTIVE(&proc_table[1]),
            "continued stopped job did not swap in");
        check(mm_free(VM_PDP6_BASE(&proc_table[1]), MM_TYPE_PROCESS, 1U) ==
            MM_OK, "free swapped CONT process");
        proc_swap_detach(1U);
        proc_table[1].meta = 0UL;
        proc_table[1].sched = 0UL;
        VM_SPACE_RESET(&proc_table[1]);
        proc_high_slot = 4U;


        /* A process image larger than available swap must fail atomically:
         * it stays resident and no swap blocks become charged. */
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 0200000UL) == MM_OK,
            "add swap exhaustion range");
        check(mm_alloc_aligned((kword_t)(TEST_SWAP_BLOCKS + 020U) *
            DSK_WORDS_PER_SECTOR, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_HIGH, &base) == MM_OK,
            "allocate swap exhaustion process");
        proc_table[1].meta = 1UL;
        test_set_uarea(1U);
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[1], PROC_SLEEP);
        VM_PDP6_SET_SPACE(&proc_table[1],
            (kword_t)(TEST_SWAP_BLOCKS + 020U) * DSK_WORDS_PER_SECTOR, base);
        check(proc_swap_attach(1U, TEST_EXEC_NODE, 0UL, 0U) == 0,
            "attach swap exhaustion process");
        check(proc_swap_out(1U) != 0 && VM_SPACE_ACTIVE(&proc_table[1]) &&
            test_swap_used_blocks() == 0UL,
            "swap exhaustion changed resident process state");
        check(vm_space_destroy(&proc_table[1], 1U) == 0 &&
            proc_swap_records[1].state == 0UL,
            "destroy after swap exhaustion kept backing state");

        /* A swap-in disk error leaves the nonresident image intact for the
         * caller to terminate, and VM destruction releases its swap charge
         * exactly once. */
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 0200000UL) == MM_OK,
            "add swap read failure range");
        check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, 1U,
            MM_ALLOC_HIGH, &base) == MM_OK,
            "allocate swap read failure process");
        proc_table[1].meta = 1UL;
        test_set_uarea(1U);
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&proc_table[1], PROC_SLEEP);
        VM_PDP6_SET_SPACE(&proc_table[1], 02000UL, base);
        check(proc_swap_attach(1U, TEST_EXEC_NODE, 0UL, 0U) == 0,
            "attach swap read failure process");
        check(proc_swap_out(1U) == 0 && test_swap_used_blocks() != 0UL,
            "prepare swap read failure process");
        test_swap_fail_read = 1;
        check(proc_swap_in(1U) != 0, "forced swap read failure succeeded");
        test_swap_fail_read = 0;
        check(!VM_SPACE_ACTIVE(&proc_table[1]) &&
            test_swap_used_blocks() != 0UL,
            "swap read failure lost recoverable backing");
        check(vm_space_destroy(&proc_table[1], 1U) == 0 &&
            test_swap_used_blocks() == 0UL &&
            proc_swap_records[1].state == 0UL,
            "destroy after swap read failure leaked swap blocks");

        /* Victim ranking follows scheduler state: a long sleeper wins over a
         * positively-niced runnable task, while current and pinned processes
         * are never candidates. */
        mm_boot_init(0400000UL);
        check(mm_add_free(0200000UL, 0200000UL) == MM_OK,
            "add victim selection range");
        for (i = 1U; i < 4U; ++i) {
                check(mm_alloc_aligned(02000UL, 02000UL, MM_TYPE_PROCESS, i,
                    MM_ALLOC_LOW, &base) == MM_OK,
                    "allocate victim process");
                proc_table[i].meta = (kword_t)i;
                test_set_uarea(i);
                VM_PDP6_SET_SPACE(&proc_table[i], 02000UL, base);
                check(proc_swap_attach((int)i, TEST_EXEC_NODE, 0UL, 0U) == 0,
                    "attach victim process");
                proc_table[i].sched = PROC_SCHED_DEFAULT;
                PROC_SET_STATE(&proc_table[i], PROC_SRUN);
        }
        proc_current_slot = 2UL;
        check(test_set_nice(2U, 12) == 12, "set victim positive nice");
        proc_current_slot = 0UL;
        PROC_SET_STATE(&proc_table[1], PROC_SLEEP);
        proc_table[1].sched |=
            ((kword_t)PROC_SLEEP_MASK << PROC_SLEEP_SHIFT) |
            ((kword_t)PROC_WAIT_EVENT << PROC_WAIT_SHIFT);
        first = (unsigned int)proc_swap_victim(0U);
        check(first == 1U, "long sleeper not preferred victim");
        PROC_CTL_WORD(&proc_table[1]) |= PROC_USER_MAP_BIT;
        check(proc_swap_victim(0U) != 1,
            "live user mapping selected as swap victim");
        PROC_CTL_WORD(&proc_table[1]) &= ~PROC_USER_MAP_BIT;
        PROC_SET_STATE(&proc_table[1], PROC_SRUN);
        proc_table[1].sched = PROC_SCHED_DEFAULT;
        second = (unsigned int)proc_swap_victim(0U);
        check(second == 2U, "positive nice runnable not preferred victim");
        proc_current_slot = 2UL;
        third = (unsigned int)proc_swap_victim(0U);
        check(third != 2U, "running process selected as swap victim");
        proc_current_slot = 0UL;
        check(mm_pin(VM_PDP6_BASE(&proc_table[2])) == MM_OK,
            "pin victim candidate");
        check(proc_swap_victim(0U) != 2,
            "pinned process selected as swap victim");
        check(mm_unpin(VM_PDP6_BASE(&proc_table[2])) == MM_OK,
            "unpin victim candidate");
        for (i = 1U; i < 4U; ++i)
                check(vm_space_destroy(&proc_table[i], i) == 0,
                    "destroy victim process");

        check(munmap(map, 02000000UL) == 0, "unmap process-copy window");

        puts("mm-v1: PASS");
        return 0;
}
