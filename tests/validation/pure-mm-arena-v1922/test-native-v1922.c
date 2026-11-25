/* Native tests for shared arena proof and actual MM mutation leaves. */
extern int mm_pure_range_v1922(kword_t, kword_t);
extern int mm_pure_table_v1922(void);
extern kword_t proc_pure_owner_v1918(unsigned int, unsigned int,
    kword_t, kword_t, unsigned int);
extern int proc_pure_full_owners_v1917(unsigned int, kword_t, kword_t,
    kword_t, kword_t, unsigned int, unsigned int);
#define ARENA_V1922(base, words) (((kword_t)(words) << 18U) | (base))

static void
reset_v1922(void)
{
        reset_prefix_v1384();
        mm_core_words = 0100000UL;
        mm_arena_count = 1;
        mm_arenas[0] = ARENA_V1922(040000UL, 040000UL);
        mm_arenas[1] = mm_arenas[2] = 0UL;
}

static int
arena_case_v1922(unsigned int kind)
{
        int expected = MM_ERR_INVAL;
        kword_t base = SOURCE, size = WORDS;
        reset_v1922();
        switch (kind) {
        case 1U: expected = MM_OK; break;
        case 2U: mm_arena_count = -1; break;
        case 3U: mm_arena_count = MM_MAX_ARENAS + 1; break;
        case 4U: mm_arenas[0] = 040000UL; break;
        case 5U: mm_core_words = 051000UL; break;
        case 6U: mm_core_words = 01000001UL; break;
        case 7U: mm_arena_count = 0; expected = MM_ERR_FRAGMENTED; break;
        case 8U: mm_arena_count = 2; mm_arenas[1] = ARENA_V1922(060000UL, 0200UL); break;
        case 9U: mm_arena_count = 2; mm_arenas[1] = ARENA_V1922(030000UL, 0200UL); break;
        case 10U: mm_arena_count = 2; mm_arenas[1] = ARENA_V1922(077600UL, 0400UL); break;
        case 11U: mm_arena_count = 2; mm_arenas[1] = 0UL; break;
        case 12U: mm_arenas[0] = ARENA_V1922(050400UL, 02000UL); expected = MM_ERR_FRAGMENTED; break;
        case 13U: mm_arenas[0] = ARENA_V1922(050000UL, 02000UL); expected = MM_OK; break;
        case 14U: base = 0UL; break;
        case 15U: size = 0UL; break;
        case 16U: mm_core_words = 01000000UL; mm_arenas[0] = ARENA_V1922(0776000UL, 02000UL); base = 0776000UL; expected = MM_OK; break;
        case 17U: mm_core_words = 01000000UL; mm_arenas[0] = ARENA_V1922(0776000UL, 02001UL); base = 0776000UL; break;
        case 18U: mm_arena_count = 3; mm_arenas[0] = ARENA_V1922(040000UL, 01000UL); mm_arenas[1] = ARENA_V1922(050000UL, 02000UL); mm_arenas[2] = ARENA_V1922(060000UL, 02000UL); expected = MM_OK; break;
        }
        if (mm_pure_range_v1922(base, size) != expected)
                return 1;
        return 0;
}

static int
table_case_v1922(unsigned int kind)
{
        int expected = MM_ERR_INVAL;
        reset_v1922();
        mm_arena_count = 3;
        mm_arenas[0] = ARENA_V1922(040000UL, 01000UL);
        mm_arenas[1] = ARENA_V1922(050000UL, 04000UL);
        mm_arenas[2] = ARENA_V1922(060000UL, 02000UL);
        add_extent(052000UL, 0200UL, MM_TYPE_MODULE);
        add_extent(060000UL, 02000UL, MM_TYPE_KERNEL_DYNAMIC);
        switch (kind) {
        case 1U: expected = MM_OK; break;
        case 2U: mm_extents[1].span = ARENA_V1922(054000UL, 0200UL); break;
        case 3U: mm_extents[1].span = ARENA_V1922(053600UL, 0400UL); break;
        case 4U: mm_extents[1].span = ARENA_V1922(052000UL, 0UL); break;
        case 5U: mm_extents[1].span = ARENA_V1922(051000UL, 0200UL); break;
        case 6U: mm_extent_capacity = 2; break;
        case 7U: mm_extent_count = MM_MAX_EXTENTS + 1; break;
        case 8U: mm_extent_count = -1; break;
        case 9U: mm_extents[2].span = ARENA_V1922(060000UL, 02001UL); break;
        case 10U: mm_arenas[2] = ARENA_V1922(060000UL, 0UL); break;
        case 11U: mm_extent_count = 0; mm_arena_count = 4; break;
        case 12U: mm_extent_count = 0; mm_arena_count = 0; expected = MM_OK; break;
        }
        if (mm_pure_table_v1922() != expected)
                return 1;
        if (proc_pure_owner_v1918(SLOT, MM_TYPE_PROCESS, SOURCE, WORDS, 0U) !=
            (expected == MM_OK && kind != 12U ? SOURCE : 0UL))
                return 2;
        return 0;
}

static int
mutation_case_v1922(unsigned int kind)
{
        kword_t span, meta;
        int rc, expected = MM_ERR_INVAL;
        reset_v1922();
        if (kind == 1U) {
                mm_arena_count = MM_MAX_ARENAS + 1;
                if (mm_pin(SOURCE) != MM_OK) return 1;
                span = mm_extents[0].span; meta = mm_extents[0].meta;
                rc = mm_pure_rebase_pinned_v1381(SOURCE, SLOT, OMIT, WORDS);
        } else {
                if (proc_pure_ram_drop_v1381(SLOT) != MM_OK ||
                    mm_pin(SOURCE + OMIT) != MM_OK) return 2;
                if (kind == 2U) {
                        mm_arenas[0] = ARENA_V1922(SOURCE + OMIT, SUFFIX);
                        expected = MM_ERR_FRAGMENTED;
                } else if (kind == 3U) {
                        mm_arena_count = MM_MAX_ARENAS + 1;
                } else if (kind == 4U) {
                        mm_arena_count = 2;
                        mm_arenas[1] = 0UL;
                } else if (kind == 5U) {
                        mm_arenas[0] = ARENA_V1922(SOURCE + OMIT, SUFFIX - 1UL);
                } else {
                        if (mm_pure_claim_prefix_v1384(SOURCE + OMIT, SLOT, OMIT, WORDS) != MM_OK) return 3;
                        mm_arenas[0] = ARENA_V1922(SOURCE + OMIT, SUFFIX);
                }
                span = mm_extents[0].span; meta = mm_extents[0].meta;
                if (kind == 6U)
                        rc = mm_pure_release_prefix_v1384(SOURCE, SLOT, OMIT, WORDS);
                else if (kind == 7U)
                        rc = mm_pure_commit_prefix_v1384(SOURCE, SLOT, OMIT, WORDS);
                else
                        rc = mm_pure_claim_prefix_v1384(SOURCE + OMIT, SLOT, OMIT, WORDS);
        }
        if (rc != expected || mm_extent_count != 1 || !check_no_mutation_v1381(span, meta) || !check_suffix_v1384())
                return 4;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;
        for (kind = 1U; kind <= 18U; ++kind) {
                rc = arena_case_v1922(kind);
                if (rc) return (int)(kind * 010U) + rc;
        }
        for (kind = 1U; kind <= 12U; ++kind) {
                rc = table_case_v1922(kind);
                if (rc) return 01000 + (int)(kind * 010U) + rc;
        }
        for (kind = 1U; kind <= 7U; ++kind) {
                rc = mutation_case_v1922(kind);
                if (rc) return 02000 + (int)(kind * 010U) + rc;
        }
        return 0;
}
