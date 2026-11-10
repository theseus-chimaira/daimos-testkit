/*
 * PDP-6 native in-memory encoder comparison, testkit only.
 *
 * No disk I/O, malloc, persistent arrays, or dynamic allocation.
 * All variants accept the same source and caller-owned destination.
 * D6LZ36 follows the exact greedy matching rule of DAIMOS
 * tools/host/d6lz-codec.c, but uses a caller-owned output buffer.
 * Block and grouped follow their independent v1420/v1421 reference
 * encoders. Returning -1 signals capacity or invalid input.
 *
 * This is NOT a proposed production implementation. These are
 * mechanically comparable C89 test encoders for PDP-6 measurements.
 */

typedef unsigned long word_v1429;

#define MASK_V1429 0777777777777UL
#define HALF_V1429 0777777UL

int
d6lz36_encode_v1429(const word_v1429 *src, unsigned int n,
    word_v1429 *dst, unsigned int capacity)
{
    unsigned int pos, out, tok, d, limit, best, best_dist;
    unsigned int len, maxlen, control_slot;
    word_v1429 control;

    if (!src || !dst || n == 0 || n > HALF_V1429)
        return -1;
    pos = out = 0;
    while (pos < n) {
        if (out >= capacity)
            return -1;
        control_slot = out++;
        control = 0UL;
        for (tok = 0; tok < 36U && pos < n; ++tok) {
            best = best_dist = 0;
            limit = pos < 128U ? pos : 128U;
            maxlen = n - pos;
            if (maxlen > 130U)
                maxlen = 130U;
            for (d = 1; d <= limit; ++d) {
                len = 0;
                while (len < maxlen &&
                    src[pos + len] == src[pos + len - d])
                    ++len;
                if (len >= 3U && len > best) {
                    best = len;
                    best_dist = d;
                    if (best == 130U)
                        break;
                }
            }
            if (out >= capacity)
                return -1;
            if (best >= 3U) {
                control |= 1UL << (35U - tok);
                dst[out++] = ((word_v1429)(best - 3U) << 7) |
                    (word_v1429)(best_dist - 1U);
                pos += best;
            } else {
                if ((src[pos] & ~MASK_V1429) != 0UL)
                    return -1;
                dst[out++] = src[pos++];
            }
        }
        dst[control_slot] = control;
    }
    return (int)out;
}

int
d6block_encode_v1429(const word_v1429 *src, unsigned int n,
    word_v1429 *dst, unsigned int capacity)
{
    unsigned int pos, out, start, literals, limit, zeros, d, len;
    unsigned int best, best_dist, maximum;

    if (!src || !dst || !n || n > HALF_V1429)
        return -1;
    pos = out = 0;
    start = literals = 0;
    while (pos < n) {
        maximum = n - pos;
        if (maximum > 128U)
            maximum = 128U;
        zeros = 0;
        if (src[pos] == 0UL) {
            while (zeros < maximum && src[pos + zeros] == 0UL)
                ++zeros;
        }
        best = best_dist = 0;
        if (zeros < 2U) {
            limit = pos < 128U ? pos : 128U;
            for (d = limit; d != 0U; --d) {
                len = 0;
                while (len < maximum &&
                    src[pos + len] == src[pos + len - d])
                    ++len;
                if (len > best) {
                    best = len;
                    best_dist = d;
                }
                if (best == 128U)
                    break;
            }
        }
        if (zeros >= 2U || best >= 3U) {
            if (literals) {
                dst[start] = (word_v1429)(literals - 1U) << 27;
                literals = 0;
            }
            if (out >= capacity)
                return -1;
            if (zeros >= 2U) {
                dst[out++] = (1UL << 34) |
                    ((word_v1429)(zeros - 1U) << 27);
                pos += zeros;
            } else {
                dst[out++] = (2UL << 34) |
                    ((word_v1429)(best - 1U) << 27) |
                    ((word_v1429)(best_dist - 1U) << 18);
                pos += best;
            }
        } else {
            if (!literals) {
                if (out >= capacity)
                    return -1;
                start = out++;
            }
            if (out >= capacity)
                return -1;
            if ((src[pos] & ~MASK_V1429) != 0UL)
                return -1;
            dst[out++] = src[pos++];
            ++literals;
            if (literals == 128U) {
                dst[start] = (word_v1429)(literals - 1U) << 27;
                literals = 0;
            }
        }
    }
    if (literals)
        dst[start] = (word_v1429)(literals - 1U) << 27;
    return (int)out;
}

int
d6grouped_encode_v1429(const word_v1429 *src, unsigned int n,
    word_v1429 *dst, unsigned int capacity)
{
    unsigned int pos, out, tok, matches, literal_count, limit;
    unsigned int maxlen, zeros, best, best_dist, d, len, i;
    word_v1429 flags, desc[15], literal[30], token;

    if (!src || !dst || !n || n > HALF_V1429)
        return -1;
    pos = out = 0;
    while (pos < n) {
        tok = matches = literal_count = 0;
        flags = 0UL;
        for (i = 0; i < 15U; ++i)
            desc[i] = 0UL;
        while (tok < 30U && pos < n) {
            maxlen = n - pos;
            if (maxlen > 127U)
                maxlen = 127U;
            zeros = 0;
            if (src[pos] == 0UL) {
                zeros = 1;
                while (zeros < maxlen && src[pos + zeros] == 0UL)
                    ++zeros;
            }
            if (zeros) {
                token = (1UL << 16) |
                    ((word_v1429)zeros << 9);
                pos += zeros;
            } else {
                best = best_dist = 0;
                limit = pos < 128U ? pos : 128U;
                for (d = limit; d != 0U; --d) {
                    len = 0;
                    while (len < maxlen &&
                        src[pos + len] == src[pos + len - d])
                        ++len;
                    if (len > best) {
                        best = len;
                        best_dist = d;
                    }
                    if (best == 127U)
                        break;
                }
                if (best >= 2U) {
                    token = ((word_v1429)best << 9) |
                        (word_v1429)best_dist;
                    pos += best;
                } else {
                    if ((src[pos] & ~MASK_V1429) != 0UL)
                        return -1;
                    literal[literal_count++] = src[pos++];
                    ++tok;
                    continue;
                }
            }
            flags |= 1UL << (29U - tok);
            if ((matches & 1U) == 0U)
                desc[matches >> 1] = token << 18;
            else
                desc[matches >> 1] |= token;
            ++matches;
            ++tok;
        }
        limit = 1U + ((matches + 1U) >> 1) + literal_count;
        if (limit > capacity - out)
            return -1;
        dst[out++] = ((word_v1429)tok << 30) | flags;
        for (i = 0; i < (matches + 1U) / 2U; ++i)
            dst[out++] = desc[i];
        for (i = 0; i < literal_count; ++i)
            dst[out++] = literal[i];
    }
    return (int)out;
}
