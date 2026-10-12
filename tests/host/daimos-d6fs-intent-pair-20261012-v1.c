/* C99 host prototype: two-copy 36-bit D6FS metadata intent selector.
 * Uses constant stack memory; no allocation and no compiler complex type.
 * THIS DOES NOT ENFORCE DISK WRITE BARRIERS OR PROVIDE REPLAY.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define WORD_MASK UINT64_C(0777777777777)
#define MAGIC UINT64_C(064651164217)
#define BLOCK_WORDS 128U
#define RECORD_WORDS 12U
#define STATE_EMPTY 0U
#define STATE_PREPARE 1U
#define STATE_COMMIT 2U
static uint64_t block[2][BLOCK_WORDS];
static uint64_t torn[BLOCK_WORDS];

static uint64_t digest(const uint64_t *words)
{
        uint64_t acc = UINT64_C(061545612345);
        unsigned int i;
        for (i = 0; i < RECORD_WORDS - 1U; ++i) {
                /* Rotate in the 36-bit domain, then XOR each word. */
                acc = ((acc << 7) | (acc >> 29)) & WORD_MASK;
                acc ^= words[i] & WORD_MASK;
        }
        return acc & WORD_MASK;
}

static void encode(uint64_t *b, uint64_t sequence, uint64_t state)
{
        unsigned int i;
        memset(b, 0, BLOCK_WORDS * sizeof(*b));
        b[0] = MAGIC;
        b[1] = 1U;
        b[2] = sequence;
        b[3] = state;
        b[4] = 297U; /* FCB */
        b[5] = 0U; /* parent */
        b[6] = 42U; /* directory slot */
        b[7] = 6U; /* directory entry size */
        b[8] = UINT64_C(012345670123);
        b[9] = UINT64_C(076543210765);
        b[10] = 0U; /* flags, reserved */
        for (i = 0; i < RECORD_WORDS - 1U; ++i)
                b[i] &= WORD_MASK;
        b[11] = digest(b);
}

static int valid(const uint64_t *b)
{
        unsigned int i;
        if (b[0] != MAGIC || b[1] != 1U || b[3] > STATE_COMMIT ||
            b[2] == 0U || b[11] != digest(b))
                return 0;
        for (i = 0; i < BLOCK_WORDS; ++i)
                if ((b[i] & ~WORD_MASK) != 0U)
                        return 0;
        for (i = RECORD_WORDS; i < BLOCK_WORDS; ++i)
                if (b[i] != 0U)
                        return 0;
        return 1;
}

static int choose(const uint64_t *a, const uint64_t *b)
{
        int va = valid(a), vb = valid(b);
        if (!va && !vb)
                return -1;
        if (!va)
                return 1;
        if (!vb)
                return 0;
        /* Equal sequence but different contents must never be guessed. */
        if (a[2] == b[2])
                return memcmp(a, b, BLOCK_WORDS * sizeof(*a)) ? -1 : 0;
        return a[2] > b[2] ? 0 : 1;
}

int main(void)
{
        unsigned int i;
        encode(block[0], 1U, STATE_PREPARE);
        encode(block[1], 2U, STATE_COMMIT);
        if (choose(block[0], block[1]) != 1)
                return 1;
        /* Simulate every possible prefix of an interrupted block overwrite. */
        for (i = 0; i <= BLOCK_WORDS; ++i) {
                memcpy(torn, block[0], sizeof(torn));
                memcpy(torn, block[1], i * sizeof(uint64_t));
                if (choose(torn, block[0]) < 0) {
                        /* A damaged newer slot still has an intact older slot. */
                        fprintf(stderr, "no valid selection at cut %u\n", i);
                        return 2;
                }
                if (valid(torn) && memcmp(torn, block[0], sizeof(torn)) != 0 &&
                    memcmp(torn, block[1], sizeof(torn)) != 0) {
                        fprintf(stderr, "unexpected valid mixed record %u\n", i);
                        return 3;
                }
        }
        /* Equal generation disagreement is a fatal ambiguity. */
        memcpy(torn, block[0], sizeof(torn));
        torn[4]++;
        torn[11] = digest(torn);
        if (choose(torn, block[0]) != -1)
                return 4;
        printf("PASS: intent pair, 129 interrupted-write prefixes, conflict rejection\n");
        return 0;
}
