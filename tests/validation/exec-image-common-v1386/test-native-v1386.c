/*
 * Shared DXR1/DXR2 EXEC and PURE_PREFIX format/load ABI regression.
 * Compile with PDP-6 KCC. The actual shared parser/payload ASM is linked;
 * only immutable VFS and the already accepted full-image D6LZ frontend
 * are replaced by deterministic test providers.
 */
#include "kcore.h"

#define FULL_IMAGE_V1386 01000UL
#define TEXT_IMAGE_V1386 0500UL
#define PURE_PREFIX_V1386 0400UL
#define EXEC_ORIGIN_V1386 020UL
#define MAGIC_V1386 0447062UL
#define TEXT_TAG_V1386 0647022UL
#define PURE_FLAG_V1386 0200000UL
#define COMP_FLAG_V1386 0100000UL
#define IMAGE_BASE_V1386 050000UL
#define OTHER_BASE_V1386 060000UL
#define VNODE_V1386 01234567UL
#define TEXT_PATTERN_V1386 0123456701UL
#define DATA_PATTERN_V1386 076543210UL
#define SENTINEL_V1386 03777777UL
#define RELOC_WORDS_V1386 ((FULL_IMAGE_V1386 + 043UL) / 044UL)

extern int exec_image_inspect_v1386(kword_t, kword_t, kword_t *);
extern int exec_image_apply_v1386(kword_t, kword_t, kword_t *,
    kword_t);

kword_t __test_exit;
kword_t diag_meta0_v1386;
kword_t diag_meta1_v1386;
kword_t diag_meta2_v1386;
kword_t diag_meta3_v1386;
kword_t diag_rc_v1386;
static int image_mode_v1386;
static int read_fault_v1386;
static unsigned int header_count_v1386;
static unsigned int payload_count_v1386;
static unsigned int compressed_count_v1386;
static unsigned int codec_refused_v1386;

static kword_t
expected_word_v1386(unsigned int i)
{
        return i < TEXT_IMAGE_V1386 ? TEXT_PATTERN_V1386 :
            DATA_PATTERN_V1386;
}

static kword_t
file_size_v1386(void)
{
        kword_t words = FULL_IMAGE_V1386;
        if (image_mode_v1386 == 2 || image_mode_v1386 == 9)
                words = 3UL;
        if (image_mode_v1386 == 5)
                words += 2UL; /* malformed trailing payload words */
        return (image_mode_v1386 == 1 ? 2UL : 3UL) +
            words + RELOC_WORDS_V1386;
}

int
vfs_read_words(kword_t vnode, unsigned int offset, kword_t *dst,
    unsigned int count)
{
        unsigned int i;
        if (vnode != VNODE_V1386)
                return -1;
        if (offset == 0U && count == 2U) {
                ++header_count_v1386;
                dst[0] = (MAGIC_V1386 << 18U) | 0UL;
                dst[1] = (FULL_IMAGE_V1386 << 18U) |
                    ((image_mode_v1386 == 2 || image_mode_v1386 == 9) ?
                        COMP_FLAG_V1386 : 0UL) |
                    ((image_mode_v1386 == 1 || image_mode_v1386 == 8) ?
                        0UL : PURE_FLAG_V1386) | 023UL;
                if (image_mode_v1386 == 6)
                        dst[0] = 0UL;
                if (image_mode_v1386 == 7)
                        dst[1] = (0400000UL << 18U) | PURE_FLAG_V1386;
                if (image_mode_v1386 == 10)
                        dst[0] |= FULL_IMAGE_V1386;
                if (read_fault_v1386 == 1)
                        return 1;
                return 2;
        }
        if (offset == 2U && count == 1U) {
                dst[0] = (TEXT_IMAGE_V1386 << 18U) | TEXT_TAG_V1386;
                if (image_mode_v1386 == 3)
                        dst[0] = (TEXT_IMAGE_V1386 << 18U) | 1UL;
                if (image_mode_v1386 == 4)
                        dst[0] = ((FULL_IMAGE_V1386 + 1UL) << 18U) |
                            TEXT_TAG_V1386;
                if (read_fault_v1386 == 2)
                        return 0;
                return 1;
        }
        if ((offset == 2U || offset == 3U) &&
            count == FULL_IMAGE_V1386) {
                ++payload_count_v1386;
                if (read_fault_v1386 == 3)
                        return (int)count - 1;
                for (i = 0U; i < count; ++i)
                        dst[i] = expected_word_v1386(i);
                return (int)count;
        }
        if (offset == 3U && count == PURE_PREFIX_V1386 -
            EXEC_ORIGIN_V1386) {
                ++payload_count_v1386;
                if (read_fault_v1386 == 3)
                        return (int)count - 1;
                for (i = 0U; i < count; ++i)
                        dst[i] = expected_word_v1386(i);
                return (int)count;
        }
        return -1;
}

int
d6lz36_decode_vfs(kword_t vnode, unsigned int off,
    unsigned int compressed_words, kword_t packed)
{
        unsigned int i;
        unsigned int count = (unsigned int)(packed >> 18U);
        kword_t *dest = (kword_t *)(unsigned long)(packed & 0777777UL);
        ++compressed_count_v1386;
        if (vnode != VNODE_V1386 || off != 3U ||
            compressed_words != 3U || count != FULL_IMAGE_V1386 ||
            codec_refused_v1386)
                return -1;
        for (i = 0U; i < count; ++i)
                dest[i] = expected_word_v1386(i);
        return 0;
}

/* The shared source also exports a restoration bridge. That entry is
 * exercised with the actual backing unpacker and VFS stat in v1387.
 * Satisfy the unused dependencies in this image-reader-only fixture.
 */
int
vfs_stat(kword_t vnode, kword_t *stat)
{
        (void)vnode;
        (void)stat;
        return -1;
}

static void
reset_v1386(int mode)
{
        unsigned int i;
        kword_t *a = (kword_t *)(unsigned long)IMAGE_BASE_V1386;
        kword_t *b = (kword_t *)(unsigned long)OTHER_BASE_V1386;
        image_mode_v1386 = mode;
        read_fault_v1386 = 0;
        codec_refused_v1386 = 0U;
        header_count_v1386 = payload_count_v1386 = 0U;
        compressed_count_v1386 = 0U;
        for (i = 0U; i < FULL_IMAGE_V1386 + 0200U; ++i) {
                a[i] = SENTINEL_V1386;
                b[i] = SENTINEL_V1386;
        }
}

static int
check_mode_v1386(int mode, int want_prefix)
{
        kword_t meta[4];
        kword_t *dst = (kword_t *)(unsigned long)IMAGE_BASE_V1386;
        unsigned int i;
        int rc;

        reset_v1386(mode);
        for (i = 0U; i < 4U; ++i)
                meta[i] = 012345UL;
        rc = exec_image_inspect_v1386(VNODE_V1386, file_size_v1386(),
            meta);
        diag_meta0_v1386 = meta[0];
        diag_meta1_v1386 = meta[1];
        diag_meta2_v1386 = meta[2];
        diag_meta3_v1386 = meta[3];
        diag_rc_v1386 = (kword_t)rc;
        if (rc != 0)
                return 1;
        if ((meta[0] & 0777777UL) != FULL_IMAGE_V1386 ||
            (meta[0] >> 18U) != 0UL ||
            (meta[1] & 0777777UL) != 023UL ||
            (meta[2] >> 18U) !=
                (mode == 1 ? 0UL : TEXT_IMAGE_V1386) ||
            (meta[2] & 0777777UL) != (mode == 1 ? 2UL : 3UL) ||
            (meta[3] >> 18U) != RELOC_WORDS_V1386 ||
            (meta[3] & 0777777UL) !=
                ((mode == 2 || mode == 9) ? 3UL : 0UL))
                return 2;
        rc = exec_image_apply_v1386(VNODE_V1386,
            IMAGE_BASE_V1386, meta, want_prefix ?
            PURE_PREFIX_V1386 : 0UL);
        if (want_prefix && (mode == 2 || mode == 9)) {
                if (rc != -2 || payload_count_v1386 ||
                    compressed_count_v1386)
                        return 3;
                for (i = 0U; i < FULL_IMAGE_V1386; ++i)
                    if (dst[i] != SENTINEL_V1386)
                        return 4;
                return 0;
        }
        if (want_prefix && (mode == 1 || mode == 8)) {
                if (rc != -1 || payload_count_v1386)
                        return 5;
                return 0;
        }
        if (rc != 0)
                return 6;
        for (i = 0U; i < FULL_IMAGE_V1386 + 0200U; ++i) {
                kword_t wanted = i < (want_prefix ?
                    PURE_PREFIX_V1386 - EXEC_ORIGIN_V1386 :
                    FULL_IMAGE_V1386) ? expected_word_v1386(i) :
                    SENTINEL_V1386;
                if (dst[i] != wanted)
                        return 7;
        }
        if ((mode == 2 || mode == 9) && compressed_count_v1386 !=
            (want_prefix ? 0U : 1U))
                return 8;
        return 0;
}

static int
check_invalid_v1386(int mode)
{
        kword_t meta[4];
        int rc;
        unsigned int i;
        reset_v1386(mode);
        for (i = 0U; i < 4U; ++i)
                meta[i] = 073231UL;
        rc = exec_image_inspect_v1386(VNODE_V1386, file_size_v1386(),
            meta);
        if (rc != -1)
                return 1;
        for (i = 0U; i < 4U; ++i)
                if (meta[i] != 073231UL)
                        return 2;
        return 0;
}

int
main(void)
{
        int mode, rc;
        for (mode = 0; mode <= 2; ++mode) {
                rc = check_mode_v1386(mode, 0);
                if (rc)
                        return mode * 16 + rc;
                rc = check_mode_v1386(mode, 1);
                if (rc)
                        return 0100 + mode * 16 + rc;
        }
        rc = check_mode_v1386(8, 1);
        if (rc)
                return 0200 + rc;
        for (mode = 3; mode <= 7; ++mode) {
                rc = check_invalid_v1386(mode);
                if (rc)
                        return 0300 + mode * 16 + rc;
        }
        rc = check_invalid_v1386(10);
        if (rc)
                return 0500 + rc;
        reset_v1386(0);
        read_fault_v1386 = 1;
        {
                kword_t meta[4];
                if (exec_image_inspect_v1386(VNODE_V1386,
                    file_size_v1386(), meta) != -1)
                        return 0601;
                read_fault_v1386 = 2;
                if (exec_image_inspect_v1386(VNODE_V1386,
                    file_size_v1386(), meta) != -1)
                        return 0602;
                read_fault_v1386 = 0;
                if (exec_image_inspect_v1386(VNODE_V1386,
                    file_size_v1386(), meta) != 0)
                        return 0603;
                read_fault_v1386 = 3;
                if (exec_image_apply_v1386(VNODE_V1386,
                    IMAGE_BASE_V1386, meta, PURE_PREFIX_V1386) != -1)
                        return 0604;
        }
        return 0;
}
