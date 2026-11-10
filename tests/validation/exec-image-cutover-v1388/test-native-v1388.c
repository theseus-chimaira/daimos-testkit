/*
 * Exercise a throwaway exec_load_process callsite against the actual
 * shared v1386 format parser and FULL payload dispatcher.
 *
 * Only FS, MM, owner admission and the existing D6LZ adapter are mocks.
 * The candidate is NOT linked into production until linked-size and
 * complete boot acceptance justify the extra permanent words.
 */
#include "proc.h"
#include "vfs.h"

#define EXEC_NODE_V1388 VFS_NODE(6U, VFS_MOUNT_KIND(1U, 1U), 0345U)
#define IMAGE_WORDS_V1388 01000U
#define TEXT_WORDS_V1388 0500U
#define RELMAP_WORDS_V1388 ((IMAGE_WORDS_V1388 + 043U) / 044U)
#define IMAGE_BASE_V1388 050000UL
#define DXR_MAGIC_V1388 0447062UL
#define TEXT_TAG_V1388 0647022UL
#define TEXT_PATTERN_V1388 0456732UL
#define DATA_PATTERN_V1388 0123456UL
#define DXR_PURE_V1388 0200000UL
#define DXR_COMP_V1388 0100000UL
#define DXR_RT_V1388 0400000UL

extern int exec_load_process(struct proc *, unsigned int,
    const kword_t *);

kword_t __test_exit;
kword_t proc_rt_owner;
static struct proc proc_v1388;
static int format_v1388;
static int fault_v1388;
static int is_root_v1388;
static unsigned int lookup_v1388;
static unsigned int stat_v1388;
static unsigned int create_v1388;
static unsigned int destroy_v1388;
static unsigned int attach_v1388;
static unsigned int decoded_v1388;
static unsigned int load_v1388;
static unsigned int attached_text_v1388;
static unsigned int attached_pure_v1388;
static unsigned int header_v1388;

static unsigned int
file_words_v1388(void)
{
        return (format_v1388 == 1 ? 2U : 3U) +
            (format_v1388 == 2 ? 3U : IMAGE_WORDS_V1388) +
            RELMAP_WORDS_V1388;
}

int
file_lookup_path(const kword_t *path, vnode_t *node)
{
        ++lookup_v1388;
        if (!path || !node)
                return -1;
        *node = EXEC_NODE_V1388;
        return 0;
}

int
file_check_access(vnode_t vnode, unsigned int mode)
{
        return vnode == EXEC_NODE_V1388 && mode == 1U ? 0 : -1;
}

int
file_check_root(void)
{
        return is_root_v1388 ? 0 : -1;
}

int
vfs_stat(vnode_t node, struct vfs_stat *st)
{
        ++stat_v1388;
        if (node != EXEC_NODE_V1388)
                return -1;
        st->type = VFS_TYPE_REG;
        st->mode = 0U;
        st->reserved = 0UL;
        st->size_words = file_words_v1388();
        st->uid = 0U;
        st->gid = 0U;
        st->mtime = 0UL;
        return 0;
}

int
vfs_read_words(vnode_t node, unsigned int off, kword_t *dst,
    unsigned int nwords)
{
        unsigned int i;
        kword_t flags;
        if (node != EXEC_NODE_V1388)
                return -1;
        flags = (format_v1388 == 2 ? DXR_COMP_V1388 : 0UL) |
            DXR_PURE_V1388 | (format_v1388 == 3 ? DXR_RT_V1388 : 0UL);
        if (off == 0U && nwords == 2U) {
                ++header_v1388;
                dst[0] = (DXR_MAGIC_V1388 << 18U);
                dst[1] = ((kword_t)IMAGE_WORDS_V1388 << 18U) |
                    flags | 020U;
                if (fault_v1388 == 1)
                        dst[0] = 0UL;  /* reject before VM creation */
                return 2;
        }
        if (off == 2U && nwords == 1U) {
                dst[0] = ((kword_t)TEXT_WORDS_V1388 << 18U) |
                    TEXT_TAG_V1388;
                return 1;
        }
        if ((off == (format_v1388 == 1 ? 2U : 3U)) &&
            nwords == IMAGE_WORDS_V1388) {
                ++load_v1388;
                if (fault_v1388 == 2)
                        return (int)nwords - 1;
                for (i = 0U; i < nwords; ++i)
                        dst[i] = i < TEXT_WORDS_V1388 ?
                            TEXT_PATTERN_V1388 : DATA_PATTERN_V1388;
                return (int)nwords;
        }
        return -1;
}

int
d6lz36_decode_vfs(vnode_t node, unsigned int off,
    unsigned int compressed_words, kword_t packed)
{
        unsigned int i;
        unsigned int nwords = (unsigned int)(packed >> 18U);
        kword_t *dst = (kword_t *)(unsigned long)(packed & 0777777UL);
        ++decoded_v1388;
        if (node != EXEC_NODE_V1388 || off != 3U ||
            compressed_words != 3U || nwords != IMAGE_WORDS_V1388)
                return -1;
        if (fault_v1388 == 2)
                return -1;
        for (i = 0U; i < nwords; ++i)
                dst[i] = i < TEXT_WORDS_V1388 ?
                    TEXT_PATTERN_V1388 : DATA_PATTERN_V1388;
        return 0;
}

int
vm_space_create(struct proc *p, unsigned int owner, kword_t words)
{
        ++create_v1388;
        if (!p || owner != 1U || !words || fault_v1388 == 3)
                return -1;
        p->vm_state = (words << 18U) | IMAGE_BASE_V1388;
        return 0;
}

int
vm_space_destroy(struct proc *p, unsigned int owner)
{
        ++destroy_v1388;
        if (p != &proc_v1388 || owner != 1U)
                return -1;
        p->vm_state = 0UL;
        return 0;
}

int
proc_swap_attach(int owner, vnode_t vnode, kword_t text,
    unsigned int pure)
{
        ++attach_v1388;
        attached_text_v1388 = (unsigned int)text;
        attached_pure_v1388 = pure;
        return owner == 1 && vnode == EXEC_NODE_V1388 &&
            fault_v1388 != 4 ? 0 : -1;
}

static void
reset_v1388(int format, int fault, int root)
{
        unsigned int i;
        kword_t *image = (kword_t *)(unsigned long)IMAGE_BASE_V1388;
        format_v1388 = format;
        fault_v1388 = fault;
        is_root_v1388 = root;
        lookup_v1388 = stat_v1388 = create_v1388 = 0U;
        destroy_v1388 = attach_v1388 = decoded_v1388 = 0U;
        load_v1388 = attached_text_v1388 = attached_pure_v1388 = 0U;
        header_v1388 = 0U;
        proc_rt_owner = 0UL;
        proc_v1388.meta = 0UL;
        proc_v1388.vm_state = 0UL;
        proc_v1388.sched = 0UL;
        for (i = 0U; i < IMAGE_WORDS_V1388; ++i)
                image[i] = 0UL;
}

static int
check_v1388(int format, int fault, int root, int expected)
{
        kword_t path[1];
        kword_t *image = (kword_t *)(unsigned long)IMAGE_BASE_V1388;
        unsigned int i;
        int rc;
        path[0] = 1UL;
        reset_v1388(format, fault, root);
        rc = exec_load_process(&proc_v1388, 1U, path);
        if (rc != expected)
                return 1;
        if (lookup_v1388 != 1U || stat_v1388 != 1U ||
            header_v1388 != 1U)
                return 2;
        if (expected != 0 && expected != 1) {
                if (fault == 1 && create_v1388 != 0U)
                        return 3;
                if ((fault == 2 || fault == 4) &&
                    (create_v1388 != 1U || destroy_v1388 != 1U ||
                     proc_v1388.vm_state))
                        return 4;
                if (format == 3 && !root &&
                    (create_v1388 || proc_rt_owner))
                        return 5;
                return 0;
        }
        if (create_v1388 != 1U || destroy_v1388 ||
            attach_v1388 != 1U ||
            (proc_v1388.meta >> 18U) != 020UL ||
            !proc_v1388.vm_state ||
            attached_pure_v1388 != (format == 1 ? 0U : 1U) ||
            attached_text_v1388 !=
                (format == 1 ? 0U : TEXT_WORDS_V1388) ||
            ((format == 2) ? decoded_v1388 != 1U :
                load_v1388 != 1U))
                return 6;
        for (i = 0U; i < IMAGE_WORDS_V1388; ++i)
                if (image[i + 020U] != (i < TEXT_WORDS_V1388 ?
                    TEXT_PATTERN_V1388 : DATA_PATTERN_V1388))
                        return 7;
        return 0;
}

int
main(void)
{
        int rc;
        rc = check_v1388(0, 0, 0, 0);       /* DXR2 plain */
        if (rc)
                return 0100 + rc;
        rc = check_v1388(1, 0, 0, 0);       /* DXR1 compatibility */
        if (rc)
                return 0200 + rc;
        rc = check_v1388(2, 0, 0, 0);       /* DXR2 compressed FULL */
        if (rc)
                return 0300 + rc;
        rc = check_v1388(3, 0, 0, -1);      /* root-only RT refusal */
        if (rc)
                return 0400 + rc;
        rc = check_v1388(3, 0, 1, 1);       /* privileged RT acquired */
        if (rc)
                return 0500 + rc;
        rc = check_v1388(0, 1, 0, -1);      /* bad header */
        if (rc)
                return 0600 + rc;
        rc = check_v1388(0, 2, 0, -1);      /* short payload rollback */
        if (rc)
                return 0700 + rc;
        rc = check_v1388(2, 2, 0, -1);      /* corrupt compressed rollback */
        if (rc)
                return 01000 + rc;
        rc = check_v1388(0, 3, 0, -2);      /* VM NOMEM */
        if (rc)
                return 01100 + rc;
        rc = check_v1388(0, 4, 0, -1);      /* failed PURE attach rollback */
        if (rc)
                return 01200 + rc;
        return 0;
}
