/*
 * Isolated real KINIT SWAP MINIT selection. The runner appends the
 * unmodified proc_swap_minit_v481 source from module_minit.c below.
 * Only transient discovery and MRES installation are controlled.
 *
 * C89 on the test host. This does not emulate PDP-6 execution or
 * replace the full-guest acceptance still needed after v1613.
 */
#include <stdio.h>

typedef unsigned long kword_t;
#define SIXBIT(s) 0UL

/* Root selection now runs before SWAP MINIT. Preserve the historic
 * dedicated-root v1613 matrix, while enabling source-linked tests
 * to supply an actual selected root for ROOT=auto in v1665.
 */
#define KINIT_ROOT_AUTO 0U
#define KINIT_ROOT_DSK  1U
#define KINIT_ROOT_DTC  2U
#define KINIT_ROOT_DRM  3U
static unsigned int selected_root_v1613 =
    D6FS_FS_ENABLED ? KINIT_ROOT_DSK : KINIT_ROOT_DTC;

static unsigned int
root_select_class(void)
{
    return selected_root_v1613;
}

static const kword_t proc_pure_mres_package_v1612[1] = { 1UL };
static kword_t proc_swap_reclaim;
static kword_t proc_swap_service_one;
static kword_t backstore_bitmap_words;
static kword_t backstore_init;
static kword_t backstore_alloc;
static kword_t backstore_free;
static kword_t backstore_verify_allocated_v795;

static int discover_result_v1613;
static kword_t discover_blocks_v1613;
static kword_t auxstore_backstore_blocks;
static unsigned int discover_calls_v1613;
static unsigned int pure_installs_v1613;
static unsigned int disk_installs_v1613;
static unsigned int post_calls_v1613;
static unsigned int patches_v1613;
static unsigned int fatals_v1613;
static unsigned int pure_diag_v1613;

int
auxstore_boot_discover(void)
{
    ++discover_calls_v1613;
    /* Real discovery always resets the published value first. */
    auxstore_backstore_blocks = discover_blocks_v1613;
    return discover_result_v1613;
}

void
auxstore_post_minits(void)
{
    ++post_calls_v1613;
}

void
minit_fatal(kword_t name)
{
    (void)name;
    ++fatals_v1613;
}

void
minit_diag_loaded(kword_t name)
{
    (void)name;
    ++pure_diag_v1613;
}

int
mres_install(const kword_t *p, unsigned int *base)
{
    if (p != proc_pure_mres_package_v1612)
        return -1;
    ++pure_installs_v1613;
    *base = 04000U;
    return 0;
}

unsigned int
mres_export(const kword_t *p, unsigned int base, unsigned int index)
{
    if (p != proc_pure_mres_package_v1612 || base != 04000U ||
        index > 1U)
        return 0U;
    return 06000U + index;
}

static unsigned int
minit_install(kword_t name)
{
    (void)name;
    ++disk_installs_v1613;
    return 05000U;
}

static unsigned int
minit_export(kword_t name, unsigned int base, unsigned int index)
{
    (void)name;
    if (base != 05000U || index > 6U)
        return 0U;
    return 07000U + index;
}

static void
storage_patch_jump(kword_t *p, unsigned int address)
{
    ++patches_v1613;
    *p = (kword_t)address;
}

/* The runner appends the actual source here, before the test main. */
