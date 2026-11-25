/* Actual MEMFS runtime/data and backing scanners; existing MM/I/O fixture. */
#define MEMFS_REAL_OWNER_SCAN_V1938 1
#define daimos_memfs_pdp6_test old_memfs_test_v1938
#include "../../target/daimos-memfs-pdp6-v1/test.c"
#undef daimos_memfs_pdp6_test

static kword_t roots_v1938[26], table_v1938[6], records_v1938[2];
static kword_t uarea_v1938[0410], hold_v1938[2];
kword_t *vfs_mount_root_base = roots_v1938;
kword_t vfs_mount_limit = 26;
kword_t *proc_table = table_v1938;
kword_t proc_high_slot = 2;
kword_t *proc_swap_records = records_v1938;
kword_t *proc_exec_resv_head_v1933;

int
daimos_memfs_pdp6_test(void)
{
        struct vfs_name name;
        vnode_t root, node, alias, other, canonical;
        kword_t old_data, old_meta, old_words, packed;
        unsigned int mount, mode, i;
        int base;

        fs.nodes = node_store;
        fs.pool_words = 02000U;
        fs.used_words = 0;
        memfs_mres_fs = fs;
        memfs_data_init(&memfs_mres_fs, fs.pool_words);
        node_store[0].meta = ((kword_t)VFS_TYPE_DIR << 15U) |
            ((kword_t)0777U << 3U) | MEMFS_F_USED | MEMFS_F_WRITABLE;
        name.chars = 1U;
        for (i = 0; i < VFS_NAME_WORDS; ++i)
                name.words[i] = 0;
        name.words[0] = 013000000000UL;
        root = VFS_NODE(4U, MEMFS_KIND_NODE, 0U);
        if (memfs_create(&memfs_mres_fs, root, &name, 0777U, &node))
                return 1;
        alias = VFS_NODE(4U, MEMFS_KIND_NODE, VFS_INDEX(node));
        other = VFS_NODE(4U, MEMFS_KIND_NODE, 2U);
        node_store[2].meta = META_REG_WRITABLE;
        put[0] = 012345670123UL;
        if (memfs_write_words(&memfs_mres_fs, alias, 0, put, 1) != 1 ||
            memfs_write_words(&memfs_mres_fs, other, 0, put, 1) != 1)
                return 2;
        old_data = node_store[VFS_INDEX(alias)].data;
        old_meta = node_store[VFS_INDEX(alias)].meta;
        old_words = memfs_mres_fs.used_words;
        put[0] = 076543210765UL;
        for (mount = 2; mount <= 18; mount += 16) {
                roots_v1938[mount - 1] =
                    VFS_NODE(4U, VFS_MOUNT_KIND(mount, 1U), 0U);
                canonical = VFS_NODE(4U, VFS_MOUNT_KIND(mount, 1U),
                    VFS_INDEX(alias));
                packed = (2UL << 22U) |
                    (((mount - 1U) & 15U) << 18U) | VFS_INDEX(alias);
                for (mode = 0; mode < 4; ++mode) {
                        base = 0100 + (int)(mount * 010U + mode * 0100U);
                        proc_exec_resv_head_v1933 = 0;
                        records_v1938[1] = 0;
                        uarea_v1938[0406] = 0;
                        table_v1938[3] = 0;
                        table_v1938[4] = 0;
                        table_v1938[5] = 0;
                        if (mode == 0) {
                                hold_v1938[0] = 0;
                                hold_v1938[1] = canonical;
                                proc_exec_resv_head_v1933 = hold_v1938;
                        } else if (mode == 1) {
                                table_v1938[5] = (0100000UL << 18U) |
                                    ((mount - 1U) >> 4U);
                                records_v1938[1] = packed;
                        } else {
                                table_v1938[3] =
                                    ((kword_t)(unsigned long)uarea_v1938 << 18U) |
                                    0400000UL;
                                table_v1938[5] = 0200000UL << 18U;
                                uarea_v1938[066] =
                                    ((kword_t)((mount - 1U) >> 4U) << 27U);
                                if (mode == 2) {
                                        table_v1938[4] = 02000U;
                                        records_v1938[1] = packed;
                                } else
                                        uarea_v1938[0406] = packed;
                        }
                        if (memfs_write_words(&memfs_mres_fs, alias, 0, put, 1) != -1)
                                return base + 1;
                        if (memfs_write_words(&memfs_mres_fs, canonical, 1, put, 1) != -1)
                                return base + 2;
                        if (memfs_truncate_words(&memfs_mres_fs, alias, 0) != -1)
                                return base + 3;
                        if (memfs_unlink(&memfs_mres_fs, root, &name) != -1)
                                return base + 4;
                        if (test_memfs_prepare_unmount_v1400() != -1)
                                return base + 5;
                        if (node_store[VFS_INDEX(alias)].data != old_data ||
                            node_store[VFS_INDEX(alias)].meta != old_meta ||
                            memfs_mres_fs.used_words != old_words || !pool_live)
                                return base + 6;
                        if (memfs_read_words(&memfs_mres_fs, alias, 0, got, 1) != 1 ||
                            got[0] != 012345670123UL)
                                return base + 7;
                        if (memfs_write_words(&memfs_mres_fs, other, 0, put, 1) != 1)
                                return base + 010;
                }
                roots_v1938[mount - 1] = 0;
        }
        proc_exec_resv_head_v1933 = 0;
        table_v1938[3] = table_v1938[4] = table_v1938[5] = 0;
        roots_v1938[17] = VFS_NODE(4U, VFS_MOUNT_KIND(18U, 1U), 0U);
        if (memfs_write_words(&memfs_mres_fs, alias, 0, put, 1) != 1 ||
            memfs_truncate_words(&memfs_mres_fs, alias, 0) ||
            memfs_unlink(&memfs_mres_fs, root, &name))
                return 0770;
        return 0;
}
