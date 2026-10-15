/* Validate actual DLINK --pure plus grouped-only DXR compression. C99. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "d6codec-group-v071.h"
static uint64_t *read_words(const char *path, size_t *count)
{
    FILE *f = fopen(path, "rb");
    long bytes;
    uint64_t *p;
    size_t i;
    if (!f || fseek(f, 0, SEEK_END) || (bytes = ftell(f)) < 0 ||
        bytes % 8 || fseek(f, 0, SEEK_SET)) return NULL;
    *count = (size_t)bytes / 8;
    p = calloc(*count ? *count : 1, sizeof(*p));
    if (!p) { fclose(f); return NULL; }
    for (i = 0; i < *count; ++i) {
        unsigned char b[8]; unsigned j;
        if (fread(b, 1, 8, f) != 8) { free(p); fclose(f); return NULL; }
        for (j = 0; j < 8; ++j) p[i] |= (uint64_t)b[j] << (j*8);
    }
    if (fclose(f)) { free(p); return NULL; }
    return p;
}
int main(int argc, char **argv)
{
    uint64_t *orig, *packed, *decoded;
    size_t n, m, image, reloc, count;
    if (argc != 3) return 2;
    orig = read_words(argv[1], &n);
    packed = read_words(argv[2], &m);
    if (!orig || !packed || n < 4 || m < 5) return 2;
    image = (size_t)(orig[1] >> 18);
    reloc = (image + 35) / 36;
    if (!image || n != 3+image+reloc || m <= 3+reloc ||
        !(orig[1]&0200000U) || (orig[1]&0100000U) ||
        packed[1] != (orig[1] | 0100000U) ||
        packed[0] != orig[0] || packed[2] != orig[2]) return 1;
    count = m - 3 - reloc;
    decoded = calloc(image, sizeof(*decoded));
    if (!decoded) return 2;
    if (d6codec_group_v071_decode(packed+3, count, decoded, image) ||
        memcmp(decoded, orig+3, image*sizeof(*decoded)) ||
        memcmp(packed+3+count, orig+3+image, reloc*sizeof(*decoded))) return 1;
    printf("PASS v090 genuine PURE compressed DXR image=%zu payload=%zu\n", image, count);
    free(decoded); free(orig); free(packed);
    return 0;
}
