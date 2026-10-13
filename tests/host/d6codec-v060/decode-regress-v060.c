/* Host v060 D6 grouped decode, bounds and round-trip regression. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "d6codec-codec-v060.h"

#define NWORDS 10000U
#define WORDMASK UINT64_C(0777777777777)
#define GUARD UINT64_C(012345670123)

static void require(int okay, const char *message)
{
    if (!okay) {
        fprintf(stderr, "FAIL d6codec-v060: %s\n", message);
        exit(1);
    }
}

static void test_fixed_groups(void)
{
    uint64_t a[] = { UINT64_C(022000000000),
        UINT64_C(0402001000000), UINT64_C(012345023456) };
    uint64_t expa[] = { UINT64_C(012345023456),
        UINT64_C(023456023456), UINT64_C(023456023456) };
    uint64_t b[] = { UINT64_C(031000000000),
        UINT64_C(0402003000000), UINT64_C(011111022222),
        UINT64_C(033333044444) };
    uint64_t expb[] = { UINT64_C(011111022222),
        UINT64_C(033333044444), UINT64_C(022222033333),
        UINT64_C(044444022222) };
    uint64_t out[8];
    unsigned int bit;

    require(d6codec_decode_v060(a, 3U, out, 3U) == 0,
        "distance one decode");
    require(memcmp(out, expa, sizeof(expa)) == 0,
        "distance one output");
    require(d6codec_decode_v060(b, 4U, out, 4U) == 0,
        "distance three decode");
    require(memcmp(out, expb, sizeof(expb)) == 0,
        "distance three output");
    for (bit = 0U; bit < 36U; ++bit) {
        uint64_t save = a[0];
        a[0] ^= UINT64_C(1) << bit;
        out[3] = GUARD;
        (void)d6codec_decode_v060(a, 3U, out, 3U);
        require(out[3] == GUARD, "control mutation output guard");
        a[0] = save;
    }
    a[0] = 0U;
    require(d6codec_decode_v060(a, 3U, out, 3U) == -1,
        "zero token count");
    a[0] = UINT64_C(0370000000000);
    require(d6codec_decode_v060(a, 3U, out, 3U) == -1,
        "31-token control");
    a[0] = UINT64_C(022000000001);
    require(d6codec_decode_v060(a, 3U, out, 3U) == -1,
        "reserved control flag");
    a[0] = UINT64_C(023000000000);
    require(d6codec_decode_v060(a, 3U, out, 3U) == -1,
        "unused matching flag");
    a[0] = UINT64_C(022000000000);
    a[1] = UINT64_C(0402001000001);
    require(d6codec_decode_v060(a, 3U, out, 3U) == -1,
        "odd descriptor padding");
    a[1] = UINT64_C(0602001000000);
    require(d6codec_decode_v060(a, 3U, out, 3U) == -1,
        "kind three");
    a[1] = UINT64_C(0402001000000);
    require(d6codec_decode_v060(a, 2U, out, 3U) == -1,
        "truncated compressed group");
    require(d6codec_decode_v060(a, 3U, out, 2U) == -1,
        "output count mismatch");
    require(d6codec_decode_v060(a, 3U, out, 4U) == -1,
        "insufficient decoded output");
    require(d6codec_decode_v060(a, 4U, out, 3U) == -1,
        "extra compressed words");
}

static void test_stream(void)
{
    uint64_t *source, *decoded, *encoded = NULL;
    uint64_t seed = UINT64_C(012345670123);
    size_t i, packed_words = 0U;

    source = (uint64_t *)malloc(NWORDS * sizeof(*source));
    decoded = (uint64_t *)malloc((NWORDS + 2U) * sizeof(*decoded));
    require(source != NULL && decoded != NULL, "allocation");
    for (i = 0U; i < NWORDS; ++i) {
        seed = (seed * UINT64_C(1664525) + UINT64_C(1013904223)) &
            WORDMASK;
        if ((i % 13U) < 3U)
            source[i] = 0U;
        else if ((i % 29U) < 7U && i >= 7U)
            source[i] = source[i - 7U];
        else
            source[i] = seed;
    }
    require(d6codec_encode_v060(source, NWORDS,
        &encoded, &packed_words) == 0, "encoder success");
    require(packed_words > 0U && packed_words < NWORDS + 400U,
        "bounded output size");
    decoded[0] = GUARD;
    decoded[NWORDS + 1U] = GUARD;
    require(d6codec_decode_v060(encoded, packed_words,
        decoded + 1U, NWORDS) == 0, "roundtrip success");
    require(memcmp(source, decoded + 1U,
        NWORDS * sizeof(*source)) == 0, "roundtrip parity");
    require(decoded[0] == GUARD && decoded[NWORDS + 1U] == GUARD,
        "roundtrip guards");
    for (i = 0U; i < 1000U; ++i) {
        size_t word = (i * 313U) % packed_words;
        unsigned int bit = (unsigned int)((i * 17U) % 36U);
        uint64_t saved = encoded[word];
        encoded[word] ^= UINT64_C(1) << bit;
        decoded[0] = GUARD;
        decoded[NWORDS + 1U] = GUARD;
        (void)d6codec_decode_v060(encoded, packed_words,
            decoded + 1U, NWORDS);
        require(decoded[0] == GUARD && decoded[NWORDS + 1U] == GUARD,
            "corruption bounds guard");
        encoded[word] = saved;
    }
    free(encoded);
    free(decoded);
    free(source);
}

int main(void)
{
    test_fixed_groups();
    test_stream();
    puts("PASS d6codec host v060 exact decode, corruption and bounds");
    return 0;
}
