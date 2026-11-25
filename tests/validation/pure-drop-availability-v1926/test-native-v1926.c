/* Production DROP with controlled mount publication and native MM rebase. */
#include "dtfs_media.h"
#include "fs_mres.h"

#define SERVICE_V1926 0254000001234UL
static unsigned int boundary_slot_v1926, boundary_fault_v1926;
void
drop_pi_boundary_v1926(void)
{
        if (boundary_fault_v1926 == 1U)
                roots_v1385[boundary_slot_v1926] = 0UL;
        if (boundary_fault_v1926 == 2U)
                roots_v1385[boundary_slot_v1926] ^= 1UL << VFS_PROVIDER_SHIFT;
        if (boundary_fault_v1926 == 3U)
                vfs_mount_root_base = (vnode_t *)0;
        boundary_fault_v1926 = 0U;
}


static int
case_v1926(unsigned int provider, unsigned int mount, unsigned int fault)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        kword_t *image = (kword_t *)(unsigned long)SOURCE;
        kword_t *jump, span, meta, backing;
        unsigned int i, index = mount - 1U;
        int rc;
        reset_prefix_v1384();
        vfs_mount_root_base = roots_v1385;
        ro_v1926 = 0UL;
        boundary_slot_v1926 = index;
        boundary_fault_v1926 = 0U;
        dtfs_media_base = media_v1926;
        tsfs_file_shape_base = shape_v1926;
        tsfs_extent_media_base = extent_v1926;
        d6fs_reader_slots_base = readers_v1926;
        fs_memfs_service_jump = fs_dtfs_service_jump = SERVICE_V1926;
        fs_d6fs_service_jump = fs_tsfs_service_jump = SERVICE_V1926;
        roots_v1385[index] = VFS_NODE(provider, VFS_MOUNT_KIND(mount, 1U), 1U);
        backing = BACKING | (((kword_t)index & 017UL) << PROC_SWAP_MOUNT_SHIFT);
        swap_slots[SLOT].state = backing;
        u[PROC_CRED_OFFSET] = ((kword_t)provider << PROC_SWAP_PROVIDER_SHIFT_V1924) |
            ((index & 020U) ? PROC_SWAP_MOUNT_EXT_BIT : 0UL);
        media_v1926[index] = 0UL;
        shape_v1926[index] = extent_v1926[index] = 0UL;
        readers_v1926[index] = 040000UL;
        jump = &fs_memfs_service_jump;
        if (provider == 5U) jump = &fs_dtfs_service_jump;
        if (provider == 6U) jump = &fs_d6fs_service_jump;
        if (provider == 7U) {
                jump = &fs_tsfs_service_jump;
                media_v1926[index] = (020UL << 18U) | 0200UL;
                shape_v1926[index] = (1UL << 24U);
                extent_v1926[index] = (010UL << 18U) | 0201UL;
        }
        switch (fault) {
        case 1U: *jump = 0UL; break;
        case 2U: *jump = (0254000UL << 18U) | (kword_t)(unsigned long)fs_mres_no_service; break;
        case 3U: *jump = 0260000001234UL; break;
        case 4U: media_v1926[index] = DTFS_MEDIA_RD_SUSPECT_V1522; break;
        case 5U: media_v1926[index] = DTFS_MEDIA_WR_UNCERT_V1522; break;
        case 6U: media_v1926[index] = DTFS_MEDIA_QUIESCING_V1562; break;
        case 7U: media_v1926[index] = DTFS_MEDIA_FORMAT_V2_V1553; break;
        case 8U: shape_v1926[index] = 1UL; break;
        case 9U: extent_v1926[index] = 1UL; break;
        case 10U: dtfs_media_base = (kword_t *)0; break;
        case 11U: tsfs_file_shape_base = (kword_t *)0; break;
        case 12U: tsfs_extent_media_base = (kword_t *)0; break;
        case 13U: d6fs_reader_slots_base = (kword_t *)0; break;
        case 14U: readers_v1926[index] = 0UL; break;
        case 15U: media_v1926[index] = 0UL; break;
        case 16U: shape_v1926[index] = 0UL; break;
        case 17U: extent_v1926[index] = 0UL; break;
        case 18U: /* healthy stamped V1 */
                shape_v1926[index] = 1UL;
                extent_v1926[index] = 2UL;
                break;
        case 19U: /* healthy stamped V2 */
                media_v1926[index] = DTFS_MEDIA_FORMAT_V2_V1553;
                shape_v1926[index] = 1UL;
                extent_v1926[index] = 2UL;
                break;
        case 20U: *jump = 0254000000000UL; break;
        case 21U: /* armed V2 cannot be read-only */
        case 22U: /* armed V2 with valid writable policy */
                media_v1926[index] = DTFS_MEDIA_FORMAT_V2_V1553 |
                    DTFS_MEDIA_INTENT_ARMED_V1553;
                shape_v1926[index] = 1UL;
                extent_v1926[index] = 2UL;
                if (fault == 21U) ro_v1926 = 1UL << index;
                break;
        case 23U: /* legacy media cannot have a V2 arm */
                media_v1926[index] = DTFS_MEDIA_INTENT_ARMED_V1553;
                break;
        case 24U: boundary_fault_v1926 = 1U; break;
        case 25U: boundary_fault_v1926 = 2U; break;
        case 26U: boundary_fault_v1926 = 3U; break;
        }
        span = mm_extents[0].span;
        meta = mm_extents[0].meta;
        rc = proc_pure_ram_drop_v1381(SLOT);
        if (!fault || fault == 18U || fault == 19U || fault == 22U) {
                if (rc != MM_OK || mm_extent_count != 1 ||
                    MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
                    MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
                    u[PROC_SWAP_BACKING_OFFSET] != backing || !check_suffix_v1384())
                        return 1;
        } else {
                if (rc != MM_ERR_INVAL || mm_extent_count != 1 ||
                    mm_extents[0].span != span || mm_extents[0].meta != meta ||
                    VM_PDP6_BASE(p) != SOURCE || !PROC_TRANSITION(p) ||
                    u[PROC_SWAP_BACKING_OFFSET] || u[PROC_FINALIZE_OFFSET] ||
                    swap_slots[SLOT].state != backing ||
                    proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT))
                        return 2;
                for (i = 0U; i < WORDS; ++i)
                        if (image[i] != (i < OMIT ? TEXT_PATTERN : PATTERN + i))
                                return 3;
        }
        if (pi_depth_v1381 || pi_disable_count_v1381 != pi_restore_count_v1381 ||
            alloc_count_v1381 || free_count_v1381)
                return 4;
        return 0;
}

int
main(void)
{
        unsigned int provider, fault, high;
        int rc;
        for (high = 0U; high <= 1U; ++high) {
                for (provider = 4U; provider <= 7U; ++provider) {
                        for (fault = 0U; fault <= 26U; ++fault) {
                                /* All providers share dispatch checks. The
                                 * other faults are specific to mount state. */
                                if (fault >= 4U && fault <= 12U &&
                                    provider != 5U && !(provider == 7U && fault >= 10U))
                                        continue;
                                if (fault >= 13U && fault <= 14U && provider != 6U)
                                        continue;
                                if (fault >= 15U && fault <= 17U && provider != 7U)
                                        continue;
                                if (fault >= 18U && fault <= 19U && provider != 5U)
                                        continue;
                                if (fault >= 21U && fault <= 23U && provider != 5U)
                                        continue;
                                rc = case_v1926(provider, high ? 18U : 1U, fault);
                                if (rc) return (int)(high * 010000U + provider * 01000U + fault * 010U) + rc;
                        }
                }
        }
        return 0;
}
