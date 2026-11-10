/*
 * Native C89 in-memory D6LZ36 fast encoder v1431 (testkit only).
 *
 * Test an inexpensive bounded-distance search without malloc or VFS I/O.
 * The wire format is D6LZ36, but the compressed bytes are not required
 * to match the full-search host encoder: the match choice is deliberately
 * more restricted to reduce encoding time.
 * Destination must not overlap source and capacity must be sufficient;
 * an error leaves the unpublished destination unspecified.
 * A caller can reserve n + ceil(n/36) words, the format's upper bound.
 */
#define D6LZ_WORD_V1431 0777777777777UL

int
d6lz_fast_encode_v1431(const unsigned long *source, unsigned int words,
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
            unsigned int probe;
            unsigned int max_length;

            max_length = words - input;
            if (max_length > 130U)
                max_length = 130U;
            best = 0U;
            best_distance = 0U;
            /*
             * Test distances 1..8, then 12,16,24,32,48,64,96,128.
             * This uses only 16 candidates and no dictionary RAM.
             * The geometrically spaced probes preserve selected long
             * range matches while keeping worst-case work bounded.
             */
            for (probe = 0U; probe < 16U; ++probe) {
                unsigned int distance;
                unsigned int length;

                if (probe < 8U) {
                    distance = probe + 1U;
                } else {
                    unsigned int index;

                    index = probe - 8U;
                    distance = ((index & 1U) ? 16U : 12U) <<
                        (index / 2U);
                }
                if (distance > input)
                    continue;
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
                if (source[input] > D6LZ_WORD_V1431)
                    return -1;
                destination[output++] = source[input++];
            }
        }
        destination[ctrl] = flags;
    }
    return (int)output;
}
