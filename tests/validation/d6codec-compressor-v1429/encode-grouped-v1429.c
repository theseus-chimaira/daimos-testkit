/*
 * v1429 test-only C89 encoder for the grouped v1420 format.
 * No static data, no allocation, no I/O. The source must not overlap
 * the destination. Output is accepted only after complete success.
 *
 * The destination needs temporary space for 15 descriptor words and
 * up to 30 literal words per group. At the end of a group, literals
 * move down to follow the actual descriptor count. This avoids
 * permanent scratch and never needs more than 45 temporary words.
 */

#define G_MASK_V1429 0777777777777UL

int
grouped_encode_v1429(const unsigned long *src, unsigned int n,
    unsigned long *dst, unsigned int capacity)
{
    unsigned int pos;
    unsigned int used;

    if (src == 0 || dst == 0 || n == 0U)
        return -1;
    pos = 0U;
    used = 0U;
    while (pos < n) {
        unsigned int group_start;
        unsigned int tokens;
        unsigned int descs;
        unsigned int literals;
        unsigned long flags;
        unsigned int i;

        group_start = used;
        if (used > capacity || capacity - used < 46U)
            return -1;
        for (i = 0U; i < 15U; ++i)
            dst[group_start + 1U + i] = 0UL;
        tokens = 0U;
        descs = 0U;
        literals = 0U;
        flags = 0UL;
        while (tokens < 30U && pos < n) {
            unsigned int maximum;
            unsigned int length;
            unsigned int distance;
            unsigned int best;
            unsigned int d;
            unsigned int zero;
            unsigned long desc;

            maximum = n - pos;
            if (maximum > 127U)
                maximum = 127U;
            zero = src[pos] == 0UL;
            length = 0U;
            distance = 0U;
            best = 0U;
            if (zero) {
                length = 1U;
                while (length < maximum &&
                    src[pos + length] == 0UL)
                    ++length;
                desc = (1UL << 16) | ((unsigned long)length << 9);
            } else {
                unsigned int max_dist;

                max_dist = pos < 128U ? pos : 128U;
                for (d = max_dist; d > 0U; --d) {
                    unsigned int k;

                    k = 0U;
                    while (k < maximum &&
                        src[pos + k] == src[pos + k - d])
                        ++k;
                    if (k > best) {
                        best = k;
                        distance = d;
                    }
                    if (best == 127U)
                        break;
                }
                if (best >= 2U) {
                    length = best;
                    desc = ((unsigned long)length << 9) |
                        (unsigned long)distance;
                } else {
                    length = 1U;
                    desc = 0UL;
                }
            }
            if (zero || best >= 2U) {
                unsigned int slot;

                flags |= 1UL << (29U - tokens);
                slot = group_start + 1U + descs / 2U;
                if ((descs & 1U) == 0U)
                    dst[slot] = desc << 18;
                else
                    dst[slot] |= desc;
                ++descs;
            } else {
                if (src[pos] > G_MASK_V1429)
                    return -1;
                dst[group_start + 16U + literals] = src[pos];
                ++literals;
            }
            pos += length;
            ++tokens;
        }
        dst[group_start] = ((unsigned long)tokens << 30) | flags;
        for (i = 0U; i < literals; ++i)
            dst[group_start + 1U + ((descs + 1U) / 2U) + i] =
                dst[group_start + 16U + i];
        used += 1U + (descs + 1U) / 2U + literals;
    }
    return (int)used;
}
