/* v1668: genuine root-aware KINIT selector with no DISK MRES.
 * The runner prefixes v1613 fixtures and appends the extracted
 * unmodified production MINIT bodies before these tests.
 */

static kword_t auxstore_logstore_start;
static kword_t auxstore_logstore_blocks;
static unsigned int logstore_calls_v1668;

static void
logstore_boot_configure(kword_t start, kword_t blocks)
{
        if (start == 0200UL && blocks == 0400UL)
                ++logstore_calls_v1668;
        else
                logstore_calls_v1668 += 100U;
}

/* Forward declaration for the extracted second AUXSTORE MINIT.
 * This is supplied to avoid requiring unrelated service fixtures.
 */
void auxstore_minit(void);

static void
reset_v1668(unsigned int root, int discovered, kword_t blocks)
{
        selected_root_v1613 = root;
        discover_result_v1613 = discovered;
        discover_blocks_v1613 = blocks;
        auxstore_backstore_blocks = 0UL;
        auxstore_logstore_blocks = 0UL;
        auxstore_logstore_start = 0UL;
        discover_calls_v1613 = 0U;
        pure_installs_v1613 = 0U;
        disk_installs_v1613 = 0U;
        post_calls_v1613 = 0U;
        patches_v1613 = 0U;
        fatals_v1613 = 0U;
        pure_diag_v1613 = 0U;
        logstore_calls_v1668 = 0U;
        proc_swap_reclaim = 0UL;
        proc_swap_service_one = 0UL;
        proc_swap_term_v1666 = 0UL;
        backstore_bitmap_words = 0UL;
        backstore_init = 0UL;
        backstore_alloc = 0UL;
        backstore_free = 0UL;
        backstore_verify_allocated_v795 = 0UL;
}

static int
check_v1668(unsigned int expected_pure, unsigned int expected_fatal,
    unsigned int expected_discover)
{
        if (pure_installs_v1613 != expected_pure ||
            disk_installs_v1613 != 0U ||
            fatals_v1613 != expected_fatal ||
            discover_calls_v1613 != expected_discover ||
            pure_diag_v1613 != expected_pure ||
            patches_v1613 != (expected_pure ? 3U : 0U) ||
            post_calls_v1613 != 0U ||
            (expected_pure && (proc_swap_reclaim != 06000UL ||
                proc_swap_service_one != 06001UL ||
                proc_swap_term_v1666 != 06002UL)) ||
            (!expected_pure && (proc_swap_reclaim ||
                proc_swap_service_one || proc_swap_term_v1666)) ||
            backstore_bitmap_words || backstore_init ||
            backstore_alloc || backstore_free ||
            backstore_verify_allocated_v795) {
                fprintf(stderr,
                    "FAIL v1668: root=%u discovered=%d blocks=%lu "
                    "pure=%u disk=%u fatal=%u probe=%u post=%u "
                    "patch=%u\n", selected_root_v1613,
                    discover_result_v1613, discover_blocks_v1613,
                    pure_installs_v1613, disk_installs_v1613,
                    fatals_v1613, discover_calls_v1613,
                    post_calls_v1613, patches_v1613);
                return 1;
        }
        return 0;
}

static int
first_pass_v1668(unsigned int root, int discovered, kword_t blocks,
    unsigned int pure, unsigned int fatal, unsigned int probes)
{
        reset_v1668(root, discovered, blocks);
        proc_swap_minit_v481();
        return check_v1668(pure, fatal, probes);
}

static int
second_pass_v1668(unsigned int positive)
{
        reset_v1668(KINIT_ROOT_DTC, 0, 0UL);
        proc_swap_minit_v481();
        if (check_v1668(1U, 0U, 1U))
                return 1;
        discover_blocks_v1613 = positive ? 0400UL : 0UL;
        auxstore_logstore_start = 0200UL;
        auxstore_logstore_blocks = 0400UL;
        auxstore_minit();
        if (check_v1668(1U, positive ? 1U : 0U, 2U) ||
            logstore_calls_v1668 != (positive ? 0U : 1U)) {
                fprintf(stderr,
                    "FAIL v1668: second AUXSTORE discovery blocks=%lu "
                    "fatal=%u logstore=%u\n", discover_blocks_v1613,
                    fatals_v1613, logstore_calls_v1668);
                return 1;
        }
        return 0;
}

int
main(void)
{
        unsigned int root;

        if (first_pass_v1668(KINIT_ROOT_DTC, -1, 0UL,
                1U, 0U, 1U) ||
            first_pass_v1668(KINIT_ROOT_DTC, 0, 0UL,
                1U, 0U, 1U) ||
            first_pass_v1668(KINIT_ROOT_DTC, -1, 0400UL,
                1U, 0U, 1U) ||
            first_pass_v1668(KINIT_ROOT_DTC, 0, 0400UL,
                0U, 1U, 1U) ||
            first_pass_v1668(KINIT_ROOT_DTC, 0, 1UL,
                0U, 1U, 1U))
                return 1;
        for (root = KINIT_ROOT_AUTO; root <= KINIT_ROOT_DRM; ++root) {
                if (root == KINIT_ROOT_DTC)
                        continue;
                if (first_pass_v1668(root, 0, 0400UL,
                        0U, 1U, 0U))
                        return 2;
        }
        if (second_pass_v1668(0U) || second_pass_v1668(1U))
                return 3;
        puts("PASS v1668: only PURE, positive BACKSTORE and root fail closed");
        return 0;
}
