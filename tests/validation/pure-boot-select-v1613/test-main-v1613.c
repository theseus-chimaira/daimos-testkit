/* Appended after real source-linked proc_swap_minit_v481(). */
static int
check_case_v1613(int rc, kword_t blocks, unsigned int expect_pure,
    unsigned int expect_disk, unsigned int expect_discover)
{
    discover_result_v1613 = rc;
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
    proc_swap_term_v1666 = 0UL;
    backstore_bitmap_words = 0UL;
    backstore_init = 0UL;
    backstore_alloc = 0UL;
    backstore_free = 0UL;
    backstore_verify_allocated_v795 = 0UL;

    proc_swap_minit_v481();

    if (fatals_v1613 || discover_calls_v1613 != expect_discover ||
        pure_installs_v1613 != expect_pure ||
        pure_diag_v1613 != expect_pure ||
        disk_installs_v1613 != expect_disk ||
        post_calls_v1613 != (expect_discover && expect_disk ? 1U : 0U) ||
        patches_v1613 != (expect_pure ? 3U : expect_disk ? 8U : 0U)) {
        fprintf(stderr, "FAIL KINIT v1613 rc=%d blocks=%lu:"
            " discover=%u pure=%u disk=%u post=%u patch=%u fatal=%u\n",
            rc, blocks, discover_calls_v1613, pure_installs_v1613,
            disk_installs_v1613, post_calls_v1613, patches_v1613,
            fatals_v1613);
        return 1;
    }
    if ((expect_pure && (proc_swap_reclaim != 06000UL ||
        proc_swap_service_one != 06001UL ||
        proc_swap_term_v1666 != 06002UL)) ||
        (expect_disk && (proc_swap_reclaim != 07000UL ||
        proc_swap_service_one != 07001UL ||
        proc_swap_term_v1666 != 07007UL)) ||
        (!expect_pure && !expect_disk &&
        (proc_swap_reclaim || proc_swap_service_one ||
         proc_swap_term_v1666))) {
        fputs("FAIL KINIT v1613: wrong resident trampoline patches\n",
            stderr);
        return 1;
    }
    return 0;
}

int
main(void)
{
#if D6FS_FS_ENABLED
    if (check_case_v1613(-1, 0UL, 0U, 1U, 0U))
        return 1;
    if (check_case_v1613(0, 01000UL, 0U, 1U, 0U))
        return 2;
#elif DAIMOS_PURE_MRES_ENABLED
    if (check_case_v1613(-1, 0UL, 1U, 0U, 1U))
        return 3;
    if (check_case_v1613(0, 0UL, 1U, 0U, 1U))
        return 4;
    if (check_case_v1613(0, 01000UL, 0U, 1U, 1U))
        return 5;
#else
    if (check_case_v1613(-1, 0UL, 0U, 0U, 1U))
        return 6;
    if (check_case_v1613(0, 0UL, 0U, 0U, 1U))
        return 7;
    if (check_case_v1613(0, 01000UL, 0U, 1U, 1U))
        return 8;
#endif
    puts("PASS v1613 source-linked KINIT selection");
    return 0;
}
