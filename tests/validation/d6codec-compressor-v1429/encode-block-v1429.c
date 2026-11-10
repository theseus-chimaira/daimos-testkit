/*
 * v1429 test-only C89 encoder for the block v1424 format.
 *
 * No permanent workspace, no heap use, no I/O. Literal block
 * headers are backpatched at block completion, so no literal
 * buffer is needed. The caller owns separate src/dst extents.
 */

#define B_MASK_V1429 0777777777777UL

int
block_encode_v1429(const unsigned long *src, unsigned int n,
    unsigned long *dst, unsigned int capacity)
{
    unsigned int pos;
    unsigned int used;
    unsigned int literal_count;
    unsigned int literal_start;

    if (src == 0 || dst == 0 || n == 0U)
        return -1;
    pos = 0U;
    used = 0U;
    literal_count = 0U;
    literal_start = 0U;
    while (pos < n) {
        unsigned int maximum;
        unsigned int zero;
        unsigned int best;
        unsigned int best_dist;

        if (src[pos] > B_MASK_V1429)
            return -1;
        maximum = n - pos;
        if (maximum > 128U)
            maximum = 128U;
        zero = 0U;
        if (src[pos] == 0UL) {
            while (zero < maximum && src[pos + zero] == 0UL)
                ++zero;
        }
        best = 0U;
        best_dist = 0U;
        if (zero < 2U) {
            unsigned int d;
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
                    best_dist = d;
                }
                if (best == 128U)
                    break;
            }
        }
        if (zero >= 2U || best >= 3U) {
            unsigned int length;
            unsigned long command;

            if (literal_count != 0U) {
                dst[literal_start] =
                    ((unsigned long)(literal_count - 1U) << 27);
                literal_count = 0U;
            }
            if (used >= capacity)
                return -1;
            if (zero >= 2U) {
                length = zero;
                command = (1UL << 34) |
                    ((unsigned long)(zero - 1U) << 27);
            } else {
                length = best;
                command = (2UL << 34) |
                    ((unsigned long)(best - 1U) << 27) |
                    ((unsigned long)(best_dist - 1U) << 18);
            }
            dst[used++] = command;
            pos += length;
        } else {
            if (literal_count == 0U) {
                if (used >= capacity)
                    return -1;
                literal_start = used++;
            }
            if (used >= capacity)
                return -1;
            dst[used++] = src[pos++];
            ++literal_count;
            if (literal_count == 128U) {
                dst[literal_start] =
                    ((unsigned long)(literal_count - 1U) << 27);
                literal_count = 0U;
            }
        }
    }
    if (literal_count != 0U)
        dst[literal_start] =
            ((unsigned long)(literal_count - 1U) << 27);
    return (int)used;
}
