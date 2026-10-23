/* Validate the native eight-byte-per-word representation of raw XIP images.
 * This checks the on-disk format, not the safety of loading arbitrary files. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define XIP_WORDS 04000U
#define XIP_ENTRY 020U
#define MASK18 0777777ULL

static int read_word(FILE *f, uint64_t *value)
{
        unsigned char b[8];
        unsigned int i;
        *value = 0U;
        if (fread(b, 1U, sizeof(b), f) != sizeof(b))
                return -1;
        for (i = 0U; i < sizeof(b); ++i)
                *value |= (uint64_t)b[i] << (i * 8U);
        return (*value >> 36U) == 0U ? 0 : -1;
}

int main(int argc, char **argv)
{
        FILE *f;
        uint64_t w;
        unsigned int i;
        int bad = 0;
        if (argc != 2)
                return 2;
        f = fopen(argv[1], "rb");
        if (f == NULL)
                return 2;
        for (i = 0U; i < XIP_WORDS; ++i) {
                if (read_word(f, &w) != 0) {
                        bad = 1;
                        break;
                }
                if (i == 0U && w != 054506000000ULL)
                        bad = 1;
                else if (i == 1U &&
                    (w >> 18U) != 0200000ULL && !bad)
                        bad = 1;
                else if (i == 1U && (w & MASK18) != XIP_ENTRY)
                        bad = 1;
                else if (i == XIP_ENTRY && ((w >> 27U) != 0201ULL ||
                         ((w >> 18U) & 017ULL) != 0U))
                        bad = 1;
                else if (i == XIP_ENTRY + 1U && w != 040000000000ULL)
                        bad = 1;
                else if (i != 0U && i != 1U && i != XIP_ENTRY &&
                         i != XIP_ENTRY + 1U && w != 0U)
                        bad = 1;
                if (bad)
                        break;
        }
        if (!bad && fgetc(f) != EOF)
                bad = 1;
        if (ferror(f))
                bad = 1;
        fclose(f);
        if (bad) {
                fprintf(stderr, "invalid raw-XIP header/layout at word %o\n", i);
                return 1;
        }
        puts("PASS v218: linker XIP header, PURE, entry, program and padding");
        return 0;
}
