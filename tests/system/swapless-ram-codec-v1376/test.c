/*
 * Host regression for the staged swapless mutable-RAM word codec.
 * All payloads are PDP-6 36-bit words. No kernel state is activated.
 */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "kpack_ram_rle_v1376.h"

#define WORD_MAX 0777777777777UL
#define COUNT_MAX 0777777U
#define LITERAL 0400000000000UL
#define REPEAT 0200000000000UL

static void
roundtrip(const kword_t *source, unsigned int words)
{
        kword_t *encoded;
        kword_t *restored;
        int n;
        int actual;
        unsigned int i;

        n = kpack_ram_measure_v1376(source, words);
        assert(n >= 0);
        encoded = (kword_t *)calloc((size_t)n + 2U, sizeof(*encoded));
        restored = (kword_t *)calloc((size_t)words + 2U,
            sizeof(*restored));
        assert(encoded && restored);
        encoded[n] = 01234567UL;
        restored[words] = 07654321UL;
        actual = kpack_ram_encode_v1376(source, words, encoded,
            (unsigned int)n);
        assert(actual == n);
        assert(encoded[n] == 01234567UL);
        assert(kpack_ram_decode_v1376(encoded, (unsigned int)n, restored,
            words) == (int)words);
        for (i = 0U; i < words; ++i)
                assert(restored[i] == source[i]);
        assert(restored[words] == 07654321UL);
        if (n > 0)
                assert(kpack_ram_encode_v1376(source, words, encoded,
                    (unsigned int)n - 1U) == -1);
        free(restored);
        free(encoded);
}

static void
test_patterns(void)
{
        unsigned int n;
        unsigned int i;
        kword_t data[1024];

        assert(kpack_ram_measure_v1376(0, 0U) == 0);
        assert(kpack_ram_encode_v1376(0, 0U, data, 0U) == 0);
        assert(kpack_ram_decode_v1376(0, 0U, data, 0U) == 0);
        assert(kpack_ram_measure_v1376(0, 1U) == -1);
        assert(kpack_ram_decode_v1376(0, 1U, data, 1U) == -1);
        assert(kpack_ram_decode_v1376(data, 1U, 0, 1U) == -1);

        for (n = 1U; n <= 1024U; n *= 2U) {
                for (i = 0U; i < n; ++i)
                        data[i] = 0UL;
                roundtrip(data, n);
                for (i = 0U; i < n; ++i)
                        data[i] = 076543210UL;
                roundtrip(data, n);
                for (i = 0U; i < n; ++i)
                        data[i] = ((kword_t)i * 073211U + 17UL) & WORD_MAX;
                roundtrip(data, n);
                for (i = 0U; i < n; ++i)
                        data[i] = (i % 13U < 9U) ? 0UL : 012345670123UL;
                roundtrip(data, n);
                for (i = 0U; i < n; ++i)
                        data[i] = (i % 5U < 3U) ? 1UL : (kword_t)i;
                roundtrip(data, n);
        }
        data[0] = WORD_MAX;
        roundtrip(data, 1U);
}

static void
test_malformed(void)
{
        kword_t words[8] = { 0UL };
        kword_t result[8] = { 0UL };

        words[0] = 0UL;                /* Zero count */
        assert(kpack_ram_decode_v1376(words, 1U, result, 1U) == -1);
        words[0] = 010000000UL;       /* Reserved control bit */
        assert(kpack_ram_decode_v1376(words, 1U, result, 1U) == -1);
        words[0] = 0600000000001UL;  /* Reserved kind */
        assert(kpack_ram_decode_v1376(words, 1U, result, 1U) == -1);
        words[0] = 3UL;                /* Too many decoded words */
        assert(kpack_ram_decode_v1376(words, 1U, result, 2U) == -1);
        words[0] = REPEAT | 3UL;       /* Missing repeated value */
        assert(kpack_ram_decode_v1376(words, 1U, result, 3U) == -1);
        words[1] = 0UL;                /* Noncanonical repeated zero */
        assert(kpack_ram_decode_v1376(words, 2U, result, 3U) == -1);
        words[1] = 2UL;
        assert(kpack_ram_decode_v1376(words, 2U, result, 3U) == 3);
        assert(result[0] == 2UL && result[1] == 2UL &&
            result[2] == 2UL);
        assert(kpack_ram_decode_v1376(words, 2U, result, 4U) == -1);
        words[0] = LITERAL | 3UL;      /* Truncated literal run */
        assert(kpack_ram_decode_v1376(words, 2U, result, 3U) == -1);
        words[0] = LITERAL | 1UL;
        assert(kpack_ram_decode_v1376(words, 2U, result, 1U) == 1);
        words[2] = 1UL;                /* Trailing token */
        assert(kpack_ram_decode_v1376(words, 3U, result, 1U) == -1);
        words[0] = 1UL;
        words[1] = 1UL;
        assert(kpack_ram_decode_v1376(words, 2U, result, 1U) == -1);
        words[0] = LITERAL | 1UL;
        words[1] = WORD_MAX + 1UL;     /* Not a 36-bit word */
        assert(kpack_ram_decode_v1376(words, 2U, result, 1U) == -1);
        assert(kpack_ram_measure_v1376(words + 1, 1U) == -1);
        assert(kpack_ram_encode_v1376(words + 1, 1U, result, 2U) == -1);
}

static void
test_limit(void)
{
        kword_t *data;
        kword_t *output;
        unsigned int i;
        int encoded;

        data = (kword_t *)calloc((size_t)COUNT_MAX + 1U, sizeof(*data));
        output = (kword_t *)malloc(((size_t)COUNT_MAX + 1U) *
            sizeof(*output));
        assert(data && output);
        assert(kpack_ram_measure_v1376(data, COUNT_MAX) == 1);
        encoded = kpack_ram_encode_v1376(data, COUNT_MAX, output, 1U);
        assert(encoded == 1);
        assert(kpack_ram_decode_v1376(output, 1U, data, COUNT_MAX) ==
            (int)COUNT_MAX);
        assert(kpack_ram_measure_v1376(data, COUNT_MAX + 1U) == -1);
        for (i = 0U; i < COUNT_MAX; ++i)
                data[i] = (kword_t)i + 1UL;
        assert(kpack_ram_measure_v1376(data, COUNT_MAX) == -1);
        free(data);
        free(output);
}

int
main(void)
{
        test_patterns();
        test_malformed();
        test_limit();
        puts("swapless RAM codec v1376: host tests PASS");
        return 0;
}
