/*
 * Native C89 in-memory D6LZ36 encoder v1430 (testkit only).
 *
 * This reproduces tools/host/d6lz-codec.c without malloc or VFS I/O.
 * Destination must not overlap source and capacity must be sufficient;
 * an error leaves the unpublished destination unspecified.
 * A caller can reserve n + ceil(n/36) words, the format's upper bound.
 */
#define D6LZ_WORD_V1430 0777777777777UL

int
d6lz_encode_v1430(const unsigned long *source, unsigned int words,
    unsigned long *destination, unsigned int capacity)
{
    unsigned int input;
    unsigned int output;

    if (source == 0 || destination == 0 || words == 0U)
        return -1;
    input = 0U;
    output = 0U;
    while (input < words) {
        unsigned int ctrl;
        unsigned int token;
        unsigned long flags;

        if (output >= capacity)
            return -1;
        ctrl = output++;
        flags = 0UL;
        for (token = 0U; token < 36U && input < words; ++token) {
            unsigned int best;
            unsigned int best_distance;
            unsigned int max_distance;
            unsigned int distance;
            unsigned int max_length;

            max_length = words - input;
            if (max_length > 130U)
                max_length = 130U;
            max_distance = input < 128U ? input : 128U;
            best = 0U;
            best_distance = 0U;
            for (distance = 1U; distance <= max_distance; ++distance) {
                unsigned int length;

                length = 0U;
                while (length < max_length &&
                    source[input + length] ==
                    source[input + length - distance])
                    ++length;
                if (length >= 3U && length > best) {
                    best = length;
                    best_distance = distance;
                    if (length == 130U)
                        break;
                }
            }
            if (output >= capacity)
                return -1;
            if (best >= 3U) {
                flags |= 1UL << (35U - token);
                destination[output++] =
                    ((unsigned long)(best - 3U) << 7) |
                    (unsigned long)(best_distance - 1U);
                input += best;
            } else {
                if (source[input] > D6LZ_WORD_V1430)
                    return -1;
                destination[output++] = source[input++];
            }
        }
        destination[ctrl] = flags;
    }
    return (int)output;
}
