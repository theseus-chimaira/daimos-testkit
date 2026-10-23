/*
 * Test-only host DXR padding utility (C99, no target RAM usage).
 * Enlarge an otherwise valid linked DXR image while preserving its entry,
 * text metadata and relocation bitmap. Use d6lz -x afterward to compress
 * the zero-filled extra image words into an ordinary, valid DXR2.
 * Binary word containers are little-endian uint64_t with 36 significant bits.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define TARGET_WORDS 0300000UL
#define HALF_MASK 0777777ULL
#define DXR_MAGIC 0447062ULL

static uint64_t
read_word(FILE *fp)
{
        unsigned char b[8];
        unsigned int i;
        uint64_t v;

        if (fread(b, 1U, sizeof b, fp) != sizeof b) {
                fprintf(stderr, "v201-pad: short input\n");
                exit(1);
        }
        v = 0ULL;
        for (i = 0U; i < 8U; ++i)
                v |= (uint64_t)b[i] << (i * 8U);
        if ((v >> 36U) != 0ULL) {
                fprintf(stderr, "v201-pad: non-36-bit source word\n");
                exit(1);
        }
        return v;
}

static void
write_word(FILE *fp, uint64_t w)
{
        unsigned char b[8];
        unsigned int i;

        for (i = 0U; i < 8U; ++i)
                b[i] = (unsigned char)(w >> (i * 8U));
        if (fwrite(b, 1U, sizeof b, fp) != sizeof b) {
                fprintf(stderr, "v201-pad: output write failed\n");
                exit(1);
        }
}

int
main(int argc, char **argv)
{
        FILE *in;
        FILE *out;
        long bytes;
        size_t word_count;
        size_t old_words;
        size_t old_reloc;
        size_t new_reloc;
        size_t header_words;
        size_t i;
        uint64_t first;
        uint64_t second;

        if (argc != 3) {
                fprintf(stderr, "usage: v201-pad input.dxr padded.dxr\n");
                return 2;
        }
        in = fopen(argv[1], "rb");
        if (in == NULL || fseek(in, 0L, SEEK_END) != 0 ||
            (bytes = ftell(in)) < 0L || bytes % 8L != 0L ||
            fseek(in, 0L, SEEK_SET) != 0) {
                fprintf(stderr, "v201-pad: cannot read source DXR\n");
                return 1;
        }
        word_count = (size_t)(bytes / 8L);
        if (word_count < 3U) {
                fprintf(stderr, "v201-pad: source DXR too short\n");
                return 1;
        }
        first = read_word(in);
        second = read_word(in);
        old_words = (size_t)((second >> 18U) & HALF_MASK);
        old_reloc = (old_words + 35U) / 36U;
        new_reloc = (TARGET_WORDS + 35U) / 36U;
        if (((first >> 18U) & HALF_MASK) != DXR_MAGIC ||
            old_words == 0U || old_words > TARGET_WORDS ||
            (second & 0100000ULL) != 0ULL) {
                fprintf(stderr, "v201-pad: invalid or compressed source DXR\n");
                return 1;
        }
        if (word_count == 2U + old_words + old_reloc)
                header_words = 2U;
        else if (word_count == 3U + old_words + old_reloc)
                header_words = 3U;
        else {
                fprintf(stderr, "v201-pad: inconsistent DXR geometry\n");
                return 1;
        }
        out = fopen(argv[2], "wb");
        if (out == NULL) {
                fprintf(stderr, "v201-pad: cannot open output\n");
                return 1;
        }
        write_word(out, first);
        write_word(out, ((uint64_t)TARGET_WORDS << 18U) |
            (second & HALF_MASK));
        if (header_words == 3U)
                write_word(out, read_word(in));
        for (i = 0U; i < old_words; ++i)
                write_word(out, read_word(in));
        for (; i < TARGET_WORDS; ++i)
                write_word(out, 0ULL);
        for (i = 0U; i < old_reloc; ++i)
                write_word(out, read_word(in));
        for (; i < new_reloc; ++i)
                write_word(out, 0ULL);
        if (fclose(out) != 0 || fclose(in) != 0) {
                fprintf(stderr, "v201-pad: close failed\n");
                return 1;
        }
        return 0;
}
