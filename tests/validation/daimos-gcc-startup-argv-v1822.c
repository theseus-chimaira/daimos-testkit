/*
 * DAIMOS passes argc in AC1 and an array of pointers to length-prefixed
 * SIXBIT words in AC2. This is not the hosted C char **argv layout.
 * Verify the real GCC main entry ABI, kernel argument storage and console.
 *
 * C89, no allocator, no KCC library and no test-only monitor veneer.
 */
#include <p10stdio-daimos-v1.h>

static int
s6_matches_v1822(const unsigned long *packed, const char *expected)
{
    unsigned int length, index, shift;
    unsigned long character;

    if (packed == (const unsigned long *)0 || expected == (const char *)0)
        return 0;
    length = (unsigned int)(packed[0] & 0777777UL);
    for (index = 0U; expected[index] != 0; ++index) {
        if (index >= length)
            return 0;
        shift = 30U - (index % 6U) * 6U;
        character = (packed[1U + index / 6U] >> shift) & 077UL;
        if (character + 040UL != (unsigned long)(unsigned char)expected[index])
            return 0;
    }
    return index == length;
}

int
main(int argc, unsigned long **argv, unsigned long **envp)
{
    (void)envp;
    if (argc != 3)
        return 11;
    if (argv == (unsigned long **)0 || argv[0] == (unsigned long *)0 ||
        argv[1] == (unsigned long *)0 || argv[2] == (unsigned long *)0)
        return 12;
    if (!s6_matches_v1822(argv[1], "ARG1") ||
        !s6_matches_v1822(argv[2], "ARG2"))
        return 13;
    if (printf("GCC-ARGV-V1822: %d %s\n", argc, "OK") < 0)
        return 14;
    if (puts("GCC-ARGV-V1822-PASS") < 0)
        return 15;
    return 0;
}
