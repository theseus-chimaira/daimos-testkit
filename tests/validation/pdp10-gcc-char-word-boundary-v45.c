/* PDP-6 regression: an optimized stack-local 9-bit char array must not
 * interpret MEM_OFFSET (a word offset) as an intra-word byte index.
 * An opaque assembly writer prevents GCC from folding the comparisons.
 * The simulated caller verifies indices 3..8 across two word boundaries.
 */
extern void pdp10_fill_char_line_v45(char *out);

int
main(void)
{
        char line[16];

        pdp10_fill_char_line_v45(line);
        return (line[3] == '@' && line[4] == '?' && line[5] == 'O' &&
            line[6] == 'P' && line[7] == 'E' && line[8] == 'R') ? 0 : 1;
}
