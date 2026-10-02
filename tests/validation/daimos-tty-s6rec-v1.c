#include "dsys.h"
#include "../test_sixbit.h"

#define S6REC_TEXT_HEADER(len) ((1UL << 30U) | (kword_t)(len))

int
main(void)
{
        static kword_t records[] = {
                S6REC_TEXT_HEADER(5U),
                TEST_SIX6('H', 'E', 'L', 'L', 'O', ' '),
                S6REC_TEXT_HEADER(0U),
                S6REC_TEXT_HEADER(6U),
                TEST_SIX6('W', 'O', 'R', 'L', 'D', '!')
        };
        static kword_t bad_type[] = { 2UL << 30U };
        static kword_t truncated[] = {
                S6REC_TEXT_HEADER(7U),
                TEST_SIX6('T', 'R', 'U', 'N', 'C', ' ')
        };

        if (dsys_write_words(1, bad_type, 1U) != -1 ||
            dsys_write_words(1, truncated, 2U) != -1 ||
            dsys_write_words(1, records, 2U) != 2 ||
            dsys_write_words(1, records + 2, 1U) != 1 ||
            dsys_write_words(1, records + 3, 2U) != 2) {
                (void)dsys_halt();
                return 1;
        }
        (void)dsys_halt();
        return 0;
}
