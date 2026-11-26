/* Native K10: real EXEC header reader and attach/detach implementation.
 * VFS, VM allocation, and terminal storage service are controlled leaves.
 */
#include "exec.h"
#include "proc_swap.h"
#include "file.h"
#include "vm.h"
#include "proc_storage_map_v28.h"

#define NODE VFS_NODE(7U,VFS_MOUNT_KIND(18U,2U),01234UL)
#define CREDENTIALS 000234567123UL
#define TEXT 0200UL
#define IMAGE 0400UL
#define BSS 017UL
#define MUTABLE 0400000UL

static struct proc slots[3];
static struct proc_swap_record records[3];
static kword_t uarea[PROC_UAREA_WORDS];
static vnode_t roots[18];
struct proc *proc_table;
struct proc *proc_current_ptr;
kword_t proc_current_slot, proc_rt_owner;
kword_t vfs_mount_limit;
vnode_t *vfs_mount_root_base;
kword_t fs_namespace_epoch_v1936;
kword_t kconst_1_1 = 01000001UL;
kword_t __test_exit;
kword_t diag_case_v1976;
static kword_t marker, flags, text, file_mode, uid;
static unsigned int header, creates, loads, destroys;
static int deny_attach, deny_terminal, stored_mode;

extern int exec_image_inspect_v1386(vnode_t, kword_t, kword_t *);

static kword_t
file_size(void)
{
        return header + ((flags & EXEC_DXR_F_COMPRESSED) ? 3UL : IMAGE)
            + (IMAGE + 35UL) / 36UL;
}

int file_lookup_path(const kword_t *path, vnode_t *out)
{
        (void)path;
        *out = NODE;
        return 0;
}
int file_check_access(vnode_t node, unsigned int mode)
{
        (void)node; (void)mode;
        return 0;
}
int file_check_root(void) { return 0; }
int fs_provider_reg_call(void) { return 0; }
void proc_exec_release_v1933(kword_t *hold) { (void)hold; }
int vfs_dtfs_owner_admit_v1562(vnode_t node) { (void)node; return 0; }
int vfs_stat(vnode_t node, struct vfs_stat *st)
{
        if (node != NODE) return -1;
        st->type = 2U;
        st->mode = file_mode;
        st->size_words = file_size();
        st->uid = uid;
        st->gid = 0;
        st->reserved = st->mtime = 0;
        return 0;
}
int vfs_read_words(vnode_t node, unsigned int off, kword_t *out,
    unsigned int count)
{
        if (node != NODE) return -1;
        if (!off && count == 2U) {
                out[0] = 0447062000000UL;
                out[1] = (IMAGE << 18U) | flags | BSS;
                return 2;
        }
        if (off == 2U && count == 1U && header == 3U) {
                out[0] = ((text | marker) << 18U) | 0647022UL;
                return 1;
        }
        return -1;
}
int vm_space_create(struct proc *p, unsigned int slot, kword_t words)
{
        if (slot != 1U || words != IMAGE + BSS + 02020UL) return -1;
        ++creates;
        p->vm_state = 0400002000UL;
        return 0;
}
int vm_space_load_file(struct proc *p, vnode_t node, kword_t off,
    kword_t user, unsigned int words)
{
        (void)p;
        if (node != NODE || off != header || user != 020UL || words != IMAGE)
                return -1;
        ++loads;
        if (deny_attach) roots[17] = 0;
        return 0;
}
int d6codec_decode_vfs_v1458(vnode_t node, kword_t off, kword_t count,
    kword_t packed)
{
        if (node != NODE || off != 3UL || count != 3UL ||
            packed != ((IMAGE << 18U) | 02020UL)) return -1;
        ++loads;
        return 0;
}
int vm_space_destroy(struct proc *p, unsigned int slot)
{
        ++destroys;
        p->vm_state = 0;
        return proc_swap_detach(slot);
}
int proc_storage_expect_v30(unsigned int slot, unsigned int mode)
{
        (void)slot;
        return stored_mode == (int)mode ? 0 : -1;
}
int proc_swap_term_v1666(int slot, struct proc *p, kword_t state)
{
        (void)slot; (void)p; (void)state;
        return deny_terminal ? -1 : 0;
}

static void
reset(unsigned int live)
{
        struct proc *p = &slots[1];
        proc_table = slots;
        proc_swap_records = records;
        vfs_mount_limit = 18UL;
        vfs_mount_root_base = roots;
        roots[17] = VFS_NODE(7U,VFS_MOUNT_KIND(18U,2U),1UL);
        p->meta = 0;
        p->vm_state = 0;
        p->sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(p, live ? PROC_SRUN : PROC_SIDL);
        if (live) {
                PROC_SET_META_LH(p, (kword_t)(unsigned long)uarea);
                p->meta |= (kword_t)PROC_F_UAREA << PROC_FLAGS_SHIFT;
        }
        proc_current_ptr = live ? p : 0;
        proc_current_slot = live ? 1UL : 2UL;
        proc_rt_owner = 0;
        uarea[PROC_CRED_OFFSET] = CREDENTIALS | PROC_SWAP_MUTABLE_V1976;
        records[1].state = 0;
        marker = 0;
        flags = EXEC_DXR_F_PURE;
        text = TEXT;
        header = 3U;
        uid = 0;
        file_mode = 0755UL;
        creates = loads = destroys = 0;
        deny_attach = deny_terminal = 0;
        stored_mode = PROC_STORAGE_RESIDENT;
}

int main(void)
{
        unsigned int i, live;
        int rc, invalid, marked;
        kword_t meta[4], old;
        static const kword_t path[] = {1UL, 0UL};
        for (live = 0U; live < 2U; ++live) {
                for (i = 0U; i < 13U; ++i) {
                        diag_case_v1976 = live * 020U + i;
                        reset(live);
                        marked = i != 0U && i != 1U && i != 8U;
                        if (marked) marker = MUTABLE;
                        if (i == 0U) { header = 2U; flags = 0; }
                        if (i == 3U) flags |= EXEC_DXR_F_COMPRESSED;
                        if (i == 4U) uid = 2UL;
                        if (i == 5U) file_mode = 0775UL;
                        if (i == 6U) file_mode = 0757UL;
                        if (i == 7U) text = IMAGE + 1UL;
                        if (i == 8U) uid = 2UL; /* legacy needs no approval */
                        if (i == 9U) flags = 0; /* eligibility independent of PURE */
                        if (i == 10U) flags |= EXEC_DXR_F_RT_REQUIRED;
                        if (i == 11U) deny_attach = 1;
                        if (i == 12U) { text = 0; flags = 0; }
                        invalid = (i >= 4U && i <= 7U) || i == 10U || i == 11U;
                        rc = exec_image_inspect_v1386(NODE, file_size(), meta);
                        if (i == 7U || i == 10U) {
                                if (rc != -1) return 1;
                        } else if (rc || (meta[1] & 0777777UL) != BSS ||
                            (meta[1] >> 18U) != (flags | (marked ? 1UL : 0UL)) ||
                            (meta[2] >> 18U) != (header == 2U ? 0UL : text))
                                return 2;
                        rc = exec_load_process(&slots[1], 1U, path);
                        if (invalid) {
                                if (rc != -1 || records[1].state || proc_rt_owner ||
                                    (i == 11U ? (creates != 1U || loads != 1U ||
                                        destroys != 1U) : (creates || loads || destroys)))
                                        return 3;
                                continue;
                        }
                        if (rc || creates != 1U || loads != 1U || destroys ||
                            ((records[1].state >> PROC_SWAP_TEXT_SHIFT) !=
                                ((flags & EXEC_DXR_F_PURE) ? text : 0UL))) return 4;
                        if (live) {
                                if ((uarea[PROC_CRED_OFFSET] & PROC_SWAP_EXEC_MASK_V1976) !=
                                    (PROC_SWAP_MOUNT_EXT_BIT | (7UL << 28U) |
                                        (marked ? PROC_SWAP_MUTABLE_V1976 : 0UL)) ||
                                    (uarea[PROC_CRED_OFFSET] & ~PROC_SWAP_EXEC_MASK_V1976) != CREDENTIALS)
                                        return 5;
                        } else if ((slots[1].sched & PROC_SWAP_STAGE_EXEC_MASK_V1976) !=
                            (035UL | (marked ? 040UL : 0UL))) return 6;
                        old = records[1].state;
                        stored_mode = PROC_STORAGE_PACKED;
                        deny_terminal = 1;
                        if (proc_swap_detach(1) != -1 || records[1].state != old)
                                return 7;
                        stored_mode = PROC_STORAGE_RESIDENT;
                        if (proc_swap_detach(1) || records[1].state ||
                            (live ? (uarea[PROC_CRED_OFFSET] != CREDENTIALS) :
                            (slots[1].sched & PROC_SWAP_STAGE_EXEC_MASK_V1976)))
                                return 8;
                }
        }
        return 0;
}
