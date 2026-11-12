/* Source-linked C89 test of the real userspace DTFS media probe.
 * No actual tape hardware is needed for these format-lifetime cases. */
#include "dtfs_media.h"
#include "dtfs_probe.h"
#include "dsys.h"
#include <stdio.h>
#include <string.h>

static kword_t dir_words[DTFS_BLOCK_WORDS];
static kword_t id_words[DTFS_BLOCK_WORDS];
static unsigned int read_count;
static int fail_identity_read;

int
dsys_dtc_read_block(unsigned int unit, unsigned int block, kword_t *dst)
{
        const kword_t *source;

        if (unit != 3U)
                return -1;
        ++read_count;
        if (block == DTFS_DIR_BLOCK)
                source = dir_words;
        else if (block == DTFS_ID_BLOCK_V1520 && !fail_identity_read)
                source = id_words;
        else
                return -1;
        memcpy(dst, source, sizeof(dir_words));
        return 0;
}

static void
make_native(void)
{
        memset(dir_words, 0, sizeof(dir_words));
        memset(id_words, 0, sizeof(id_words));
        dir_words[0] = (kword_t)DTFS_OWNER_RESERVED << 31U;
        dir_words[14] = (kword_t)DTFS_OWNER_RESERVED << 21U;
        dir_words[82] = ((kword_t)DTFS_OWNER_NATIVE_TAG << 11U) |
            ((kword_t)DTFS_OWNER_NATIVE_TAG << 6U) |
            ((kword_t)DTFS_OWNER_NATIVE_TAG << 1U);
        dir_words[DTFS_MAGIC_WORD] = DTFS_NATIVE_MAGIC;
        read_count = 0U;
        fail_identity_read = 0;
}

static void
stamp_native(void)
{
        id_words[DTFS_ID_MAGIC_WORD_V1520] = DTFS_ID_MAGIC_V1520;
        id_words[DTFS_ID_HIGH_WORD_V1520] = 0123456701234UL;
        id_words[DTFS_ID_LOW_WORD_V1520] = 0654321076543UL;
        id_words[DTFS_ID_CHECK_WORD_V1520] =
            (~(id_words[0] ^ id_words[1] ^ id_words[2])) &
            DTFS_ID_WORD_MASK_V1520;
}

static int
expect_result(const char *name, int wanted, unsigned int wanted_reads)
{
        int got;

        read_count = 0U;
        got = dtfs_probe_unit(3U, 0);
        if (got != wanted || read_count != wanted_reads) {
                fprintf(stderr, "FAIL v1520: %s result=%d expected=%d"
                    " reads=%u expected=%u\n", name, got, wanted,
                    read_count, wanted_reads);
                return -1;
        }
        printf("PASS v1520: %s\n", name);
        return 0;
}

int
main(void)
{
        make_native();
        if (expect_result("legacy zero reserved block", SYS_DTFS_TYPE_NATIVE,
            2U) != 0)
                return 1;
        stamp_native();
        if (expect_result("72-bit identity stamp", SYS_DTFS_TYPE_NATIVE,
            2U) != 0)
                return 1;
        ++id_words[DTFS_ID_CHECK_WORD_V1520];
        if (expect_result("bad identity checksum", -1, 2U) != 0)
                return 1;
        stamp_native();
        id_words[DTFS_ID_USED_WORDS_V1520] = 1UL;
        if (expect_result("nonzero identity padding", -1, 2U) != 0)
                return 1;
        make_native();
        id_words[DTFS_ID_LOW_WORD_V1520] = 1UL;
        if (expect_result("partial identity cannot downgrade to legacy",
            -1, 2U) != 0)
                return 1;
        make_native();
        stamp_native();
        id_words[DTFS_ID_LOW_WORD_V1520] = 0UL;
        if (expect_result("zero identity half", -1, 2U) != 0)
                return 1;
        make_native();
        fail_identity_read = 1;
        if (expect_result("missing physical header", -1, 2U) != 0)
                return 1;
        make_native();
        dir_words[DTFS_MAGIC_WORD] = 0UL;
        if (expect_result("nonnative directory is not identity-stamped",
            -1, 2U) != 0)
                return 1;
        if (dtfs_probe_unit(8U, 0) != -1)
                return 1;
        puts("PASS v1520: invalid physical unit refused");
        return 0;
}
