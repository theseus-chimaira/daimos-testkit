/* Native source-linked K11 overlap matrix. Guards cover the entire arena. */
#include "proc_pure_bitmap_overlap_v1975.h"

#define BASE 020000UL
#define ARENA 0400UL
#define SRC (BASE + 0100UL)
#define REF 030000UL
#define GUARD 0123456701234UL

extern void bitmap_encode_v1451(kword_t, kword_t, kword_t);
kword_t __test_exit;
kword_t diag_raw_v1975, diag_pattern_v1975, diag_delta_v1975;
kword_t diag_rc_v1975, diag_good_v1975, diag_refused_v1975;
static kword_t before[ARENA];
static kword_t *const arena = (kword_t *)BASE;
static kword_t *const raw = (kword_t *)SRC;
static kword_t *const reference = (kword_t *)REF;

static kword_t
value(kword_t i, kword_t n, unsigned int pattern)
{
        if (pattern == 0U || (pattern == 1U && i % 5UL) ||
            (pattern == 2U && i >= n / 2UL) ||
            (pattern == 3U && i < n / 2UL) ||
            (pattern == 4U && i != 0UL && i != 35UL && i != 36UL))
                return 0UL;
        return 0100000000000UL | (i + 1UL);
}

static void
reset(void)
{
        kword_t i;
        for (i = 0UL; i < ARENA; ++i)
                arena[i] = GUARD;
}

static void
snapshot(void)
{
        kword_t i;
        for (i = 0UL; i < ARENA; ++i)
                before[i] = arena[i];
}

/* Compare the complete arena, not just output or adjacent canaries. */
static int
check(kword_t target, kword_t count, const kword_t *expected)
{
        kword_t i;
        for (i = 0UL; i < ARENA; ++i) {
                kword_t a = BASE + i;
                if (arena[i] != ((a >= target && a < target + count) ?
                    expected[a - target] : before[i]))
                        return 0;
        }
        return 1;
}

int
main(void)
{
        static const kword_t lengths[] = {1UL, 2UL, 35UL, 36UL, 37UL,
            72UL, 73UL};
        static const int deltas[] = {-64, -37, -2, -1, 0, 1, 2, 37, 80};
        kword_t expected[73];
        unsigned int l, p, d;
        kword_t n, i, enc, count, plan, target;
        int rc, plan_rc;

        for (l = 0U; l < sizeof(lengths)/sizeof(lengths[0]); ++l) {
                n = lengths[l];
                diag_raw_v1975 = n;
                for (p = 0U; p < 6U; ++p) {
                        diag_pattern_v1975 = p;
                        enc = (n + 35UL) / 36UL;
                        for (i = 0UL; i < n; ++i) {
                                expected[i] = value(i, n, p);
                                enc += expected[i] != 0UL;
                        }
                        reset();
                        for (i = 0UL; i < n; ++i)
                                raw[i] = expected[i];
                        bitmap_encode_v1451(SRC, n, REF);
                        for (d = 0U; d < sizeof(deltas)/sizeof(deltas[0]); ++d) {
                                target = SRC + deltas[d];
                                diag_delta_v1975 = (kword_t)deltas[d];
                                reset();
                                for (i = 0UL; i < n; ++i)
                                        raw[i] = expected[i];
                                snapshot();
                                count = plan = GUARD;
                                plan_rc = pbm_plan_encode_v1975(SRC, n,
                                    target, enc, &plan);
                                if (!check(0UL, 0UL, reference) ||
                                    (plan_rc == MM_OK ? plan != enc : plan != GUARD))
                                        return 023;
                                rc = pbm_encode_v1975(SRC, n, target, enc, &count);
                                diag_rc_v1975 = rc;
                                if (plan_rc != rc || plan != count) return 024;
                                if (enc >= n) {
                                        if (rc != PBM_NO_GAIN_V1975 || count != GUARD ||
                                            !check(0UL, 0UL, reference))
                                                return 1;
                                        continue;
                                }
                                if (rc == MM_OK) {
                                        if (count != enc || !check(target, enc, reference))
                                                return 2;
                                        ++diag_good_v1975;
                                } else {
                                        if (rc != PBM_OVERLAP_V1975 || count != GUARD ||
                                            !check(0UL, 0UL, reference))
                                                return 3;
                                        /* The forward codec cannot reject disjoint spans. */
                                        if (target + enc <= SRC || SRC + n <= target)
                                                return 4;
                                        ++diag_refused_v1975;
                                }
                                reset();
                                for (i = 0UL; i < enc; ++i)
                                        raw[i] = reference[i];
                                snapshot();
                                rc = pbm_decode_v1975(SRC, enc, target, n);
                                diag_rc_v1975 = rc;
                                if (rc == MM_OK) {
                                        if (!check(target, n, expected))
                                                return 5;
                                        ++diag_good_v1975;
                                } else {
                                        if (rc != PBM_OVERLAP_V1975 ||
                                            !check(0UL, 0UL, expected))
                                                return 6;
                                        if (target + n <= SRC || SRC + enc <= target)
                                                return 7;
                                        ++diag_refused_v1975;
                                }
                        }
                }
        }
        /* Known overlap successes and exact hazard refusals (all zero). */
        reset();
        for (i = 0UL; i < 37UL; ++i) raw[i] = 0UL;
        snapshot(); count = GUARD;
        if (pbm_encode_v1975(SRC, 37UL, SRC, 2UL, &count) != PBM_OVERLAP_V1975 ||
            count != GUARD || !check(0UL, 0UL, reference)) return 010;
        if (pbm_encode_v1975(SRC, 37UL, SRC-1UL, 1UL, &count) != MM_ERR_NOMEM ||
            count != GUARD || !check(0UL, 0UL, reference)) return 011;
        if (pbm_encode_v1975(SRC, 37UL, SRC-1UL, 2UL, &count) != MM_OK ||
            count != 2UL) return 012;
        reset(); raw[0] = 0UL; raw[1] = 0UL; snapshot();
        if (pbm_decode_v1975(SRC, 2UL, SRC, 37UL) != PBM_OVERLAP_V1975 ||
            !check(0UL, 0UL, reference)) return 013;
        if (pbm_decode_v1975(SRC, 2UL, SRC-35UL, 37UL) != MM_OK) return 014;
        /* A partial final mask with a forbidden low bit, zero literal,
         * truncation and extra input must be rejected before any store. */
        for (d = 0U; d < 4U; ++d) {
                reset(); raw[0] = 0UL; raw[1] = 0UL; raw[2] = 0UL;
                if (d == 0U) raw[1] = 1UL;
                if (d == 1U) raw[0] = 0400000000000UL;
                snapshot();
                if (pbm_decode_v1975(SRC, d == 2U ? 1UL :
                    (d == 3U ? 3UL : 2UL), SRC-35UL, 37UL) != MM_ERR_INVAL ||
                    !check(0UL, 0UL, reference)) return 015 + d;
        }
        if (!diag_good_v1975 || !diag_refused_v1975) return 022;
        return 0;
}
