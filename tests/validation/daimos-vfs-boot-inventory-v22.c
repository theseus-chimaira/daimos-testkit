/* Native PDP-6 exercise of production root-select membership decoding and
 * boot-capacity planning. Stubs replace physical root probes, not planner
 * or root-selection logic. All constants/bit positions match root handoff. */
#include "kinit.h"
#include "root_select.h"
#include "vfs_mount_capacity_v1.h"
#include "module.h"

kword_t kinit_boot_handoff[2];
int __test_exit;
static unsigned int target_class;
static unsigned int target_mask;
static unsigned int selected_tape_mask;
static kword_t selector;
static unsigned int installed_classes = 7U;

unsigned int
module_service_get(unsigned int service)
{
        unsigned int bit;

        bit = 0U;
        if (service == MODULE_SERVICE_DSK_READ_SECTOR ||
            service == MODULE_SERVICE_DSK_WRITE_SECTOR)
                bit = 1U;
        else if (service == MODULE_SERVICE_DRM_READ_BLOCK ||
            service == MODULE_SERVICE_DRM_WRITE_BLOCK)
                bit = 2U;
        else if (service == MODULE_SERVICE_DTC_READ_BLOCK ||
            service == MODULE_SERVICE_DTC_WRITE_BLOCK)
                bit = 4U;
        return (installed_classes & bit) != 0U ? 01000U : 0U;
}

kword_t
kinit_read_switches(void)
{
        return selector;
}

int
d6fs_boot_select(unsigned int root_class, unsigned int ordinal)
{
        unsigned int physical;
        unsigned int logical;

        if (root_class != target_class || ordinal != 0U)
                return -1;
        logical = 0U;
        for (physical = 0U; physical < 4U; ++physical) {
                kword_t half;
                unsigned int i;

                if ((target_mask & (1U << physical)) == 0U)
                        continue;
                if (logical >= 4U)
                        return -1;
                half = ((kword_t)physical << 16U) | 0123UL;
                i = logical / 2U;
                if ((logical & 1U) == 0U)
                        kinit_boot_handoff[i] =
                            (kinit_boot_handoff[i] & 0777777UL) |
                            (half << 18U);
                else
                        kinit_boot_handoff[i] =
                            (kinit_boot_handoff[i] & 0777777000000UL) |
                            half;
                ++logical;
        }
        return logical != 0U ? 0 : -1;
}

int
tsfs_boot_select(unsigned int ordinal)
{
        return target_class == KINIT_ROOT_DTC && ordinal == 0U &&
            selected_tape_mask != 0U ? 0 : -1;
}

unsigned int
tsfs_boot_selected_unit_mask_v22(void)
{
        return selected_tape_mask;
}

static int
check(unsigned int root_class, unsigned int selected_mask,
    unsigned int expected)
{
        unsigned int got;

        target_class = root_class;
        target_mask = selected_mask;
        selected_tape_mask = selected_mask;
        selector = (kword_t)root_class;
        installed_classes = 7U;
        root_select_minit();
        if (root_select_class() != root_class)
                return -1;
        got = root_select_mount_capacity_v22();
        return got == expected ? 0 : -1;
}

int
main(void)
{
#if KINIT_FULL
        if (check(KINIT_ROOT_DSK, 01U, 9U) != 0 ||
            check(KINIT_ROOT_DSK, 012U, 8U) != 0 ||
            check(KINIT_ROOT_DSK, 017U, 6U) != 0 ||
            check(KINIT_ROOT_DRM, 010U, 9U) != 0)
                return 1;
#if KINIT_TAPE_BOOT
        if (check(KINIT_ROOT_DTC, 01U, 9U) != 0 ||
            check(KINIT_ROOT_DTC, 024U, 8U) != 0 ||
            check(KINIT_ROOT_DTC, 0377U, 2U) != 0)
                return 2;
#endif
#else
        if (check(KINIT_ROOT_DSK, 01U, 4U) != 0 ||
            check(KINIT_ROOT_DSK, 017U, 1U) != 0)
                return 3;
#endif
        /* Only the DSK controller passed its probe: no phantom drum or
         * DECtape slots, but full builds still expose MEMFS as one mount. */
#if KINIT_FULL
        if (check(KINIT_ROOT_DSK, 01U, 9U) != 0)
                return 5;
        installed_classes = 1U;
        if (root_select_mount_capacity_v22() != 5U)
                return 6;
        installed_classes = 0U;
        if (root_select_mount_capacity_v22() != 0U)
                return 7;             /* selected root transport vanished */
#if KINIT_TAPE_BOOT
        if (check(KINIT_ROOT_DTC, 024U, 8U) != 0)
                return 8;
        installed_classes = 4U;       /* only tape controller detected */
        if (root_select_mount_capacity_v22() != 8U)
                return 9;             /* DTC8 - 2 root + MEMFS1 + root1 */
#endif
#endif
        selector = (kword_t)KINIT_ROOT_DSK;
        target_class = KINIT_ROOT_AUTO;
        root_select_minit();
        if (root_select_class() != KINIT_ROOT_AUTO ||
            root_select_mount_capacity_v22() != 0U)
                return 4;
        return 0;
}
