/* Test the new inspection-only DIRTY selection without weakening normal boot. */
#define main legacy_super_tests
#include "daimos-d6fs-super-recovery-v1.c"
#undef main

int
main(void)
{
        kword_t a[D6FS_SUPER_WORDS];
        kword_t b[D6FS_SUPER_WORDS];
        struct d6fs_super_info info;
        unsigned int copy;

        if (legacy_super_tests() != 0)
                return 1;
        make_super(a, 4UL, D6FS_STATE_CLEAN);
        make_super(b, 5UL, D6FS_STATE_DIRTY);
        if (d6fs_super_select_recovery(a, b, 01000UL,
            &info, &copy) != 0 || copy != 1U ||
            info.sequence != 5UL || info.state != D6FS_STATE_DIRTY)
                return 2;
        /* A corrupted newest copy may not displace a valid predecessor. */
        b[D6FS_SB_MAGIC_VERSION] = 0UL;
        if (d6fs_super_select_recovery(a, b, 01000UL,
            &info, &copy) != 0 || copy != 0U ||
            info.state != D6FS_STATE_CLEAN)
                return 3;
        /* Two valid generations with conflicting UUIDs are ambiguous. */
        make_super(b, 5UL, D6FS_STATE_DIRTY);
        b[D6FS_SB_FS_UUID0] ^= 1UL;
        if (d6fs_super_select_recovery(a, b, 01000UL,
            &info, &copy) == 0)
                return 4;
        puts("daimos-d6fs-recovery-select-v671: PASS");
        return 0;
}
