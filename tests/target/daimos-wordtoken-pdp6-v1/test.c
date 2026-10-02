#include "wordtoken.h"

kword_t daimos_wordtoken_pdp6_result;

int
daimos_wordtoken_pdp6_test(void)
{
        if (WORDTOKEN6_BITS != 6U || WORDTOKEN6_PER_WORD != 6U ||
            WORDTOKEN6_MASK != 077U || WORDTOKEN6_FIRST_SHIFT != 30 ||
            WORDTOKEN6_PAD_BITS != 0U)
                return 1;
        if (WORDTOKEN7_BITS != 7U || WORDTOKEN7_PER_WORD != 5U ||
            WORDTOKEN7_MASK != 0177U || WORDTOKEN7_FIRST_SHIFT != 29 ||
            WORDTOKEN7_PAD_BITS != 1U)
                return 2;
        if (WORDTOKEN8_BITS != 8U || WORDTOKEN8_PER_WORD != 4U ||
            WORDTOKEN8_MASK != 0377U || WORDTOKEN8_FIRST_SHIFT != 28 ||
            WORDTOKEN8_PAD_BITS != 4U)
                return 3;
        if (WORDTOKEN12_BITS != 12U || WORDTOKEN12_PER_WORD != 3U ||
            WORDTOKEN12_MASK != 07777U || WORDTOKEN12_FIRST_SHIFT != 24 ||
            WORDTOKEN12_PAD_BITS != 0U)
                return 4;
        return 0;
}
