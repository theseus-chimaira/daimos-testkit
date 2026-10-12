/*
 * Host-only D6FS record append undo journal experiment.
 * Does NOT implement kernel recovery, durability barriers, or a disk format.
 *
 * Block 0: existing file tail (possibly overwritten).
 * Block 1: allocation bitmap.
 * Block 2: allocation summary.
 * Block 3: FCB block, including neighboring FCBs.
 * Blocks 4..7: full-block undo images.
 * Blocks 8..9: alternating journal state blocks.
 *
 * Assumption for this model only: a successful block write is persistent
 * before the next write starts. An interrupted write may persist any prefix
 * of its 128 words. This is NOT a verified hardware assumption.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define WORDS 128U
#define CHANGED 4U
#define BLOCKS 10U
#define HDR_A 8U
#define HDR_B 9U
#define MASK UINT64_C(0777777777777)
#define MAGIC UINT64_C(064651166123)
#define EMPTY 0U
#define PREPARE 1U
#define COMMIT 2U
#define STEPS (CHANGED + 1U + CHANGED + 1U)

static uint64_t media[BLOCKS][WORDS];
static uint64_t original[BLOCKS][WORDS];
static uint64_t before[CHANGED][WORDS];
static uint64_t after[CHANGED][WORDS];
static uint64_t record[WORDS];
static unsigned long checks;

static uint64_t
checksum(const uint64_t *p)
{
        uint64_t v = UINT64_C(061545612345);
        unsigned int i;
        for (i = 0U; i < WORDS - 1U; ++i) {
                v = ((v << 7) | (v >> 29)) & MASK;
                v ^= p[i] & MASK;
        }
        return v;
}

static void
make_header(unsigned int seq, unsigned int state)
{
        unsigned int i;
        memset(record, 0, sizeof(record));
        record[0] = MAGIC;
        record[1] = 1U;
        record[2] = seq;
        record[3] = state;
        for (i = 0U; i < CHANGED; ++i)
                record[4U + i] = checksum(before[i]);
        record[WORDS - 1U] = checksum(record);
}

static int
valid(const uint64_t *p)
{
        unsigned int i;
        if (p[0] != MAGIC || p[1] != 1U || p[2] == 0U ||
            p[3] > COMMIT || p[WORDS - 1U] != checksum(p))
                return 0;
        for (i = 0U; i < WORDS; ++i)
                if ((p[i] & ~MASK) != 0U)
                        return 0;
        for (i = 8U; i < WORDS - 1U; ++i)
                if (p[i] != 0U)
                        return 0;
        return 1;
}

static int
choose(void)
{
        const uint64_t *a = media[HDR_A], *b = media[HDR_B];
        int va = valid(a), vb = valid(b);
        if (!va && !vb)
                return -1;
        if (!va)
                return HDR_B;
        if (!vb)
                return HDR_A;
        if (a[2] == b[2])
                return memcmp(a, b, WORDS * sizeof(*a)) ? -1 : (int)HDR_A;
        return a[2] > b[2] ? HDR_A : HDR_B;
}

static void
write_prefix(unsigned int block, const uint64_t *src, unsigned int n)
{
        memcpy(media[block], src, n * sizeof(*src));
}

static void
append_step(unsigned int step, unsigned int n)
{
        if (step < CHANGED)
                write_prefix(CHANGED + step, before[step], n);
        else if (step == CHANGED) {
                make_header(2U, PREPARE);
                write_prefix(HDR_B, record, n);
        } else if (step < CHANGED * 2U + 1U)
                write_prefix(step - CHANGED - 1U,
                    after[step - CHANGED - 1U], n);
        else {
                make_header(3U, COMMIT);
                write_prefix(HDR_A, record, n);
        }
}

static void
undo_step(unsigned int step, unsigned int n)
{
        if (step < CHANGED)
                write_prefix(step, media[CHANGED + step], n);
        else {
                make_header(3U, EMPTY);
                write_prefix(HDR_A, record, n);
        }
}

static int
recover(void)
{
        int which = choose();
        unsigned int i;
        if (which < 0)
                return -1;
        if (media[which][3] != PREPARE)
                return 0;
        for (i = 0U; i < CHANGED; ++i)
                if (checksum(media[CHANGED + i]) !=
                    media[which][4U + i])
                        return -1;
        for (i = 0U; i <= CHANGED; ++i)
                undo_step(i, WORDS);
        return 0;
}

static int
verify(unsigned int scenario, unsigned int step, unsigned int cut)
{
        int selected = choose();
        unsigned int i;
        if (selected < 0)
                return 1;
        for (i = 0U; i < CHANGED; ++i)
                if (memcmp(media[i],
                    media[selected][3] == COMMIT ? after[i] : before[i],
                    sizeof(before[i])) != 0) {
                        fprintf(stderr, "FAIL scenario %u step %u cut %u block %u\n",
                            scenario, step, cut, i);
                        return 1;
                }
        ++checks;
        return 0;
}

static void
setup(unsigned int scenario)
{
        unsigned int i, j;
        memset(original, 0, sizeof(original));
        for (i = 0U; i < CHANGED; ++i) {
                for (j = 0U; j < WORDS; ++j) {
                        before[i][j] = i * 301U + j * 17U + scenario;
                        after[i][j] = i * 127U + j * 29U + 1000U + scenario;
                }
                memcpy(original[i], before[i], sizeof(before[i]));
        }
        /* Existing capacity: no freemap or summary write. */
        if (scenario == 1U) {
                memcpy(after[1], before[1], sizeof(after[1]));
                memcpy(after[2], before[2], sizeof(after[2]));
        }
        /* Block-aligned EOF: no in-place old-tail overwrite. */
        if (scenario == 2U)
                memcpy(after[0], before[0], sizeof(after[0]));
        make_header(1U, EMPTY);
        memcpy(original[HDR_A], record, sizeof(record));
}

int
main(void)
{
        unsigned int scenario, step, cut, i, rstep, rcut;
        uint64_t saved[BLOCKS][WORDS];

        for (scenario = 0U; scenario < 3U; ++scenario) {
                setup(scenario);
                /* Interrupt each append backing write at every word prefix. */
                for (step = 0U; step < STEPS; ++step)
                        for (cut = 0U; cut <= WORDS; ++cut) {
                                memcpy(media, original, sizeof(media));
                                for (i = 0U; i < step; ++i)
                                        append_step(i, WORDS);
                                append_step(step, cut);
                                if (recover() != 0 ||
                                    verify(scenario, step, cut) != 0)
                                        return 1;
                        }
                /* Interrupt replay itself, then reboot/replay again. */
                memcpy(media, original, sizeof(media));
                for (i = 0U; i <= CHANGED; ++i)
                        append_step(i, WORDS);
                for (i = CHANGED + 1U; i < STEPS - 1U; ++i)
                        append_step(i, WORDS);
                memcpy(saved, media, sizeof(saved));
                for (rstep = 0U; rstep <= CHANGED; ++rstep)
                        for (rcut = 0U; rcut <= WORDS; ++rcut) {
                                memcpy(media, saved, sizeof(media));
                                for (i = 0U; i < rstep; ++i)
                                        undo_step(i, WORDS);
                                undo_step(rstep, rcut);
                                if (recover() != 0 ||
                                    verify(scenario, rstep, rcut) != 0)
                                        return 2;
                        }
        }
        /* Refuse to invent a recovery decision when both markers are
         * damaged, or when the required durable undo payload is damaged. */
        setup(0U);
        memcpy(media, original, sizeof(media));
        for (i = 0U; i <= CHANGED + 1U; ++i)
                append_step(i, WORDS);
        media[CHANGED][0] ^= 1U;
        if (recover() == 0) {
                fputs("FAIL: accepted corrupt undo block\n", stderr);
                return 3;
        }
        media[HDR_A][0] = 0U;
        media[HDR_B][0] = 0U;
        if (recover() == 0) {
                fputs("FAIL: accepted missing commit markers\n", stderr);
                return 4;
        }
        /* A same-generation disagreement must not select a winner. */
        make_header(5U, PREPARE);
        memcpy(media[HDR_A], record, sizeof(record));
        make_header(5U, COMMIT);
        memcpy(media[HDR_B], record, sizeof(record));
        if (choose() >= 0) {
                fputs("FAIL: accepted conflicting generations\n", stderr);
                return 5;
        }
        /* Negative test: if the device persists COMMIT before the last FCB
         * write, recovery cannot distinguish that from a complete commit.
         * This demonstrates the missing hardware ordering guarantee. */
        setup(0U);
        memcpy(media, original, sizeof(media));
        for (i = 0U; i < STEPS - 2U; ++i)
                append_step(i, WORDS);
        append_step(STEPS - 1U, WORDS); /* commit overtakes final FCB */
        if (recover() != 0 || choose() != (int)HDR_A ||
            memcmp(media[3], after[3], sizeof(after[3])) == 0) {
                fputs("FAIL: missing commit/reordering counterexample\n",
                    stderr);
                return 6;
        }
        printf("PASS: %lu append/replay interruption cuts in 3 scenarios\n",
            checks);
        puts("PASS: damaged undo, missing markers, generation-conflict rejection");
        puts("PASS: demonstrated unsafe COMMIT-before-FCB reordering");
        puts("MODEL ONLY: no durable write barriers, journal format, or boot replay");
        return 0;
}
