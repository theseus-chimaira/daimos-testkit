/* v1665 real source-extracted KINIT SWAP/PURE MINIT matrix.
 * All memory backends are selected once, after root selection.
 * This test is C89 and does not simulate a PDP-6 CPU.
 */
static int
case_v1665(unsigned int root, int discovery, kword_t blocks,
    unsigned int expected_pure, unsigned int expected_disk,
    unsigned int expected_probe)
{
    unsigned int expected_patches;
    selected_root_v1613 = root;
    discover_result_v1613 = discovery;
    discover_blocks_v1613 = blocks;
    auxstore_backstore_blocks = 0UL;
    discover_calls_v1613 = 0U;
    pure_installs_v1613 = 0U;
    disk_installs_v1613 = 0U;
    post_calls_v1613 = 0U;
    patches_v1613 = 0U;
    fatals_v1613 = 0U;
    pure_diag_v1613 = 0U;
    proc_swap_reclaim = 0UL;
    proc_swap_service_one = 0UL;
    backstore_bitmap_words = 0UL;
    backstore_init = 0UL;
    backstore_alloc = 0UL;
    backstore_free = 0UL;
    backstore_verify_allocated_v795 = 0UL;

    proc_swap_minit_v481();

    expected_patches = expected_pure ? 2U : expected_disk ? 7U : 0U;
    if (discover_calls_v1613 != expected_probe ||
        pure_installs_v1613 != expected_pure ||
        disk_installs_v1613 != expected_disk ||
        pure_diag_v1613 != expected_pure ||
        post_calls_v1613 !=
            (expected_probe && expected_disk ? 1U : 0U) ||
        patches_v1613 != expected_patches || fatals_v1613 ||
        (expected_pure && (proc_swap_reclaim != 06000UL ||
            proc_swap_service_one != 06001UL)) ||
        (expected_disk && (proc_swap_reclaim != 07000UL ||
            proc_swap_service_one != 07001UL ||
            backstore_verify_allocated_v795 != 07006UL)) ||
        (!expected_pure && !expected_disk &&
            (proc_swap_reclaim || proc_swap_service_one))) {
        fprintf(stderr,
            "FAIL v1665 root=%u discovery=%d blocks=%lu: "
            "probe=%u pure=%u disk=%u post=%u patches=%u fatal=%u\n",
            root, discovery, blocks, discover_calls_v1613,
            pure_installs_v1613, disk_installs_v1613,
            post_calls_v1613, patches_v1613, fatals_v1613);
        return 1;
    }
    return 0;
}

int
main(void)
{
    unsigned int expected_pure =
        DAIMOS_PURE_MRES_ENABLED && KINIT_TAPE_BOOT ? 1U : 0U;
    unsigned int i;

    (void)expected_pure;

    /* A ROOT=auto boot is not a memory-backend decision. A DTC root
     * may have DSK/DRM hardware for LOGSTORE without BACKSTORE.
     */
    if (case_v1665(KINIT_ROOT_AUTO, -1, 0UL, 0U, 0U, 0U))
        return 1;
    if (case_v1665(KINIT_ROOT_AUTO, 0, 0400UL, 0U, 0U, 0U))
        return 2;

#if KINIT_TAPE_BOOT
    if (case_v1665(KINIT_ROOT_DTC, -1, 0UL,
        expected_pure, 0U, 1U))
        return 3;
    if (case_v1665(KINIT_ROOT_DTC, 0, 0UL,
        expected_pure, 0U, 1U))
        return 4;
    if (case_v1665(KINIT_ROOT_DTC, 0, 0400UL, 0U, 1U, 1U))
        return 5;
    if (case_v1665(KINIT_ROOT_DTC, -1, 0400UL,
        expected_pure, 0U, 1U))
        return 6; /* ignored stale BACKSTORE after discovery fails */
#else
    if (case_v1665(KINIT_ROOT_DTC, 0, 0400UL, 0U, 0U, 0U))
        return 7;
#endif

#if D6FS_FS_ENABLED
    for (i = KINIT_ROOT_DSK; i <= KINIT_ROOT_DRM; ++i) {
        if (i == KINIT_ROOT_DTC)
            continue;
        if (case_v1665(i, -1, 0UL, 0U, 1U, 0U))
            return 8;
        if (case_v1665(i, 0, 0400UL, 0U, 1U, 0U))
            return 9;
    }
#else
    /* The selector cannot normally return DSK/DRM in tape-only
     * builds, but a corrupted class must still fail closed.
     */
    for (i = KINIT_ROOT_DSK; i <= KINIT_ROOT_DRM; ++i) {
        if (i == KINIT_ROOT_DTC)
            continue;
        if (case_v1665(i, -1, 0UL, 0U, 0U, 0U))
            return 10;
    }
#endif

    puts("PASS v1665: selected-root and BACKSTORE-exclusive MRES");
    return 0;
}
