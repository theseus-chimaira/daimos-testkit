#include "monitorfs.h"
#include "proc.h"
#include "proc_swap.h"

#define HALF_MASK 0777777UL
#define S6(a,b,c,d,e,f) \
        (((kword_t)((a) - 040) << 30U) | ((kword_t)((b) - 040) << 24U) | \
         ((kword_t)((c) - 040) << 18U) | ((kword_t)((d) - 040) << 12U) | \
         ((kword_t)((e) - 040) << 6U) | (kword_t)((f) - 040))

static struct proc proc_store[2];
static struct proc_swap_record swap_store[2];
static kword_t image[02040];

struct proc *proc_table = proc_store;
unsigned int proc_slots = 2U;
unsigned int proc_high_slot = 2U;
struct proc_swap_record *proc_swap_records = swap_store;
kword_t proc_swap_blocks_used;
kword_t mfsdev_names[MONITORFS_DEV_COUNT];
kword_t mfsdev_d6set_members;
kword_t mfsdev_io_in;
kword_t mfsdev_io_out;
kword_t mfsdev_storage_errors;
kword_t mfsdev_drm_reads;
kword_t mfsdev_drm_writes;
kword_t mfsdev_d6set_reads;
kword_t mfsdev_d6set_writes;
kword_t daimos_monitorfs_wordio_result;

kword_t
proc_scope_id(const struct proc *p)
{
        (void)p;
        return 0400UL; /* domain 1 in bits 8..15 */
}

static void
put_record(unsigned int off, unsigned int chars, kword_t a, kword_t b,
    kword_t c)
{
        image[off] = chars;
        image[off + 1U] = a;
        image[off + 2U] = b;
        image[off + 3U] = c;
}

static int
record_is(const kword_t *w, unsigned int n, unsigned int chars,
    kword_t a, kword_t b, kword_t c)
{
        unsigned int payload;

        payload = (chars + 5U) / 6U;
        if (n != payload + 1U || w[0] != (010000000000UL | chars))
                return 0;
        if (payload > 0U && w[1] != a)
                return 0;
        if (payload > 1U && w[2] != b)
                return 0;
        if (payload > 2U && w[3] != c)
                return 0;
        return 1;
}

int
daimos_monitorfs_wordio_test(void)
{
        struct vfs_name name;
        struct vfs_stat st;
        kword_t w[8];
        vnode_t node;
        vnode_t found;
        unsigned int meta;
        int n;

        proc_store[1].meta = 0UL;
        PROC_SET_PARENT_SLOT(&proc_store[1], 0U);
        proc_store[1].sched = 0UL;
        PROC_SET_STATE(&proc_store[1], PROC_SRUN);
        proc_store[1].vm_state = ((kword_t)02040UL << 18U) |
            ((kword_t)(unsigned long)image & HALF_MASK);

        meta = 040U; /* 02040 - 02000 */
        image[meta] = ((kword_t)2U << 18U) | 2U; /* argc,,envc */
        image[meta + 1U] = 0100UL;
        image[meta + 2U] = 0104UL;
        image[meta + 3U] = 0106UL;
        image[meta + 4U] = 0110UL;
        put_record(0100U, 16U, S6('/','S','Y','S','T','E'),
            S6('M','/','E','X','E','C'), S6('/','D','S','H',' ',' '));
        put_record(0104U, 2U, S6('-','X',' ',' ',' ',' '), 0UL, 0UL);
        put_record(0106U, 6U, S6('H','O','M','E','=','/'), 0UL, 0UL);
        put_record(0110U, 9U, S6('U','S','E','R','=','R'),
            S6('O','O','T',' ',' ',' '), 0UL);

        name.chars = 1U;
        name.words[0] = S6('1',' ',' ',' ',' ',' ');
        name.words[1] = 0UL;
        name.words[2] = 0UL;
        name.words[3] = 0UL;
        node = VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_ROOT, 0U);
        if (mfsproc_lookup(node, &name, &found) != 0 ||
            found != VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_DIR, 1U))
                return 020;
        name.chars = 4U;
        name.words[0] = S6('N','A','M','E',' ',' ');
        if (mfsproc_lookup(found, &name, &node) != 0 ||
            node != VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_FILE,
            MONITORFS_PROCESS_INDEX(1U, MONITORFS_PROCESS_LEAF_NAME)))
                return 021;
        if (mfsproc_stat(node, &st) != 0 || st.type != VFS_TYPE_REG ||
            st.mode != 0444U)
                return 022;

        node = VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_FILE,
            MONITORFS_PROCESS_INDEX(1U, MONITORFS_PROCESS_LEAF_STATE));
        n = mfsproc_read_words(node, 0UL, w, 8U);
        if (!record_is(w, (unsigned int)n, 3U,
            S6('R','U','N',' ',' ',' '), 0UL, 0UL))
                return 1;
        if (mfsproc_read_words(node, 2UL, w, 8U) != 0)
                return 2;

        node = VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_FILE,
            MONITORFS_PROCESS_INDEX(1U, MONITORFS_PROCESS_LEAF_NAME));
        n = mfsproc_read_words(node, 0UL, w, 8U);
        if (!record_is(w, (unsigned int)n, 3U,
            S6('D','S','H',' ',' ',' '), 0UL, 0UL))
                return 3;

        node = VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_FILE,
            MONITORFS_PROCESS_INDEX(1U, MONITORFS_PROCESS_LEAF_CMDLINE));
        n = mfsproc_read_words(node, 0UL, w, 8U);
        if (!record_is(w, (unsigned int)n, 16U,
            S6('/','S','Y','S','T','E'), S6('M','/','E','X','E','C'),
            S6('/','D','S','H',' ',' ')))
                return 4;
        n = mfsproc_read_words(node, 4UL, w, 8U);
        if (!record_is(w, (unsigned int)n, 2U,
            S6('-','X',' ',' ',' ',' '), 0UL, 0UL))
                return 5;
        if (mfsproc_read_words(node, 6UL, w, 8U) != 0)
                return 6;

        node = VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_FILE,
            MONITORFS_PROCESS_INDEX(1U, MONITORFS_PROC_LEAF_ENV));
        n = mfsproc_read_words(node, 0UL, w, 8U);
        if (!record_is(w, (unsigned int)n, 6U,
            S6('H','O','M','E','=','/'), 0UL, 0UL))
                return 7;
        n = mfsproc_read_words(node, 2UL, w, 8U);
        if (!record_is(w, (unsigned int)n, 9U,
            S6('U','S','E','R','=','R'), S6('O','O','T',' ',' ',' '), 0UL))
                return 8;
        if (mfsproc_read_words(node, 5UL, w, 8U) != 0)
                return 9;

        node = VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_FILE,
            MONITORFS_DOMAIN_TAG |
            MONITORFS_PROCESS_INDEX(1U, MONITORFS_DOMAIN_LEAF_PROCESSES));
        n = mfsproc_read_words(node, 0UL, w, 8U);
        if (!record_is(w, (unsigned int)n, 1U,
            S6('1',' ',' ',' ',' ',' '), 0UL, 0UL))
                return 10;

        node = VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_FILE,
            MONITORFS_DOMAIN_TAG |
            MONITORFS_PROCESS_INDEX(1U, MONITORFS_DOMAIN_LEAF_PIDS));
        n = mfsproc_read_words(node, 0UL, w, 8U);
        if (!record_is(w, (unsigned int)n, 4U,
            S6('0','0','1',' ',' ',' '), 0UL, 0UL))
                return 11;
        if (mfsproc_read_words(node, 2UL, w, 8U) != 0)
                return 12;

        /* A cwd may outlive its synthetic process.  The already-resolved
         * directory vnode must remain traversable so "cd .." can escape,
         * while process leaves still require a live process. */
        node = VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_DIR, 0377U);
        if (mfsproc_stat(node, &st) != 0 || st.type != VFS_TYPE_DIR ||
            st.mode != 0555U)
                return 13;
        node = VFS_NODE(MONITORFS_PROCESS_PROVIDER,
            MONITORFS_PROCESS_KIND_FILE,
            MONITORFS_PROCESS_INDEX(0377U, MONITORFS_PROCESS_LEAF_STATE));
        if (mfsproc_stat(node, &st) == 0)
                return 14;
        return 0;
}
