/* v1555: strict C89 host test for the real DTFS native probe.
 * Raw physical directory and RBN0 I/O are deterministic test callbacks.
 * Probe success never authorizes a writable mount: KCORE rechecks RBN0.
 */
#include "dtfs_media.h"
#include "dtfs_intent_v1550.h"
#include "dtfs_probe.h"
#include "dsys.h"
#include <stdio.h>
#include <string.h>

static kword_t dir_words[DTFS_BLOCK_WORDS];
static kword_t id_words[DTFS_BLOCK_WORDS];
static unsigned int raw_reads;
static int fail_id_read;

int
dsys_dtc_read_block(unsigned int unit, unsigned int block, kword_t *out)
{
        const kword_t *input;

        if (unit != 3U)
                return -1;
        ++raw_reads;
        if (block == DTFS_DIR_BLOCK)
                input = dir_words;
        else if (block == DTFS_ID_BLOCK_V1520 && !fail_id_read)
                input = id_words;
        else
                return -1;
        memcpy(out, input, sizeof(id_words));
        return 0;
}

static void
make_valid_dir(void)
{
        memset(dir_words, 0, sizeof(dir_words));
        dir_words[0] = (kword_t)DTFS_OWNER_RESERVED << 31U;
        dir_words[14] = (kword_t)DTFS_OWNER_RESERVED << 21U;
        dir_words[82] = ((kword_t)DTFS_OWNER_NATIVE_TAG << 11U) |
            ((kword_t)DTFS_OWNER_NATIVE_TAG << 6U) |
            ((kword_t)DTFS_OWNER_NATIVE_TAG << 1U);
        dir_words[DTFS_MAGIC_WORD] = DTFS_NATIVE_MAGIC;
}

static void
stamp(int v2)
{
        memset(id_words, 0, sizeof(id_words));
        id_words[0] = v2 ? DTFS_INTENT_MAGIC_V1550 : DTFS_ID_MAGIC_V1520;
        id_words[1] = 0123456701234UL;
        id_words[2] = 0654321076543UL;
        id_words[3] = (~(id_words[0] ^ id_words[1] ^ id_words[2])) &
            DTFS_ID_WORD_MASK_V1520;
        if (v2) {
                id_words[4] = 0UL;
                id_words[5] = (~(id_words[0] ^ id_words[1] ^
                    id_words[2] ^ id_words[4] ^ DTFS_INTENT_SALT_V1550)) &
                    DTFS_ID_WORD_MASK_V1520;
        }
}

static void
seal(void)
{
        id_words[3] = (~(id_words[0] ^ id_words[1] ^ id_words[2])) &
            DTFS_ID_WORD_MASK_V1520;
        id_words[5] = (~(id_words[0] ^ id_words[1] ^ id_words[2] ^
            id_words[4] ^ DTFS_INTENT_SALT_V1550)) &
            DTFS_ID_WORD_MASK_V1520;
}

static int
check(const char *name, int expected)
{
        int actual;

        raw_reads = 0U;
        actual = dtfs_probe_unit(3U, 0);
        if (actual != expected || raw_reads != 2U) {
                fprintf(stderr, "FAIL v1555 %s: got %d reads %u, expected %d\n",
                    name, actual, raw_reads, expected);
                return 1;
        }
        printf("PASS v1555: %s\n", name);
        return 0;
}

int
main(void)
{
        make_valid_dir();
        stamp(1);
        if (check("DTVOL2 CLEAN format probed", SYS_DTFS_TYPE_NATIVE))
                return 1;
        id_words[4] = DTFS_INTENT_DIRTY_V1550;
        seal();
        if (check("DTVOL2 DIRTY refused", -1))
                return 1;
        stamp(1);
        id_words[5] ^= 1UL;
        if (check("torn DTVOL2 seal refused", -1))
                return 1;
        stamp(1);
        id_words[64] = 1UL;
        if (check("DTVOL2 reserved padding refused", -1))
                return 1;
        stamp(1);
        id_words[4] = 1UL;
        seal();
        if (check("unknown checked V2 state refused", -1))
                return 1;
        stamp(1);
        id_words[1] = 0UL;
        seal();
        if (check("zero upper identity refused", -1))
                return 1;
        stamp(1);
        id_words[2] = 0UL;
        seal();
        if (check("zero lower identity refused", -1))
                return 1;
        stamp(0);
        if (check("DTVOL1 remains probeable", SYS_DTFS_TYPE_NATIVE))
                return 1;
        memset(id_words, 0, sizeof(id_words));
        if (check("zero legacy remains probeable", SYS_DTFS_TYPE_NATIVE))
                return 1;
        id_words[2] = 1UL;
        if (check("partial nonlegacy refused", -1))
                return 1;
        stamp(1);
        fail_id_read = 1;
        if (check("unreadable V2 header refused", -1))
                return 1;
        if (dtfs_probe_unit(8U, 0) != -1)
                return 1;
        puts("PASS v1555: outside physical unit range refused");
        return 0;
}
