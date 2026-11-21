/* Native PDP-6: test all 36 SIXBIT positions and counted conversion. */
#include "dsh.h"

int
main(void)
{
    struct dsh_s6 s;
    struct dsh_s6 copy;
    kword_t counted[DSH_S6_MAX_WORDS + 1U];
    char text[DSH_S6_MAX_CHARS + 1U];
    unsigned int i;
    int ch;

    dsh_s6_clear(&s);
    for (i = 0U; i < DSH_S6_MAX_CHARS; ++i) {
        ch = 040 + (int)((i * 17U) & 077U);
        text[i] = (char)ch;
        if (dsh_s6_append(&s, ch) != 0)
            return 1;
        if (s.len != i + 1U)
            return 2;
        if (dsh_s6_get(&s, i) != ch)
            return 3;
    }
    text[DSH_S6_MAX_CHARS] = 0;
    if (dsh_s6_append(&s, 040) != -1)
        return 4;
    for (i = 0U; i < DSH_S6_MAX_CHARS; ++i)
        if (dsh_s6_get(&s, i) != (int)(unsigned char)text[i])
            return 5;
    if (dsh_s6_get(&s, DSH_S6_MAX_CHARS) != -1)
        return 6;
    if (!dsh_s6_eq_text(&s, text))
        return 7;
    if (dsh_s6_pack(&s, counted, DSH_S6_MAX_WORDS) != -1)
        return 8;
    if (dsh_s6_pack(&s, counted, DSH_S6_MAX_WORDS + 1U) != 0)
        return 9;
    dsh_s6_clear(&copy);
    if (dsh_s6_from_counted(&copy, counted) != 0)
        return 10;
    if (!dsh_s6_eq_text(&copy, text))
        return 11;
    if (dsh_s6_copy(&copy, &s) != 0)
        return 12;
    if (dsh_s6_get(&copy, 35U) != (int)(unsigned char)text[35])
        return 13;
    counted[0] = DSH_S6_MAX_CHARS + 1U;
    if (dsh_s6_from_counted(&copy, counted) != -1)
        return 14;
    /* A corrupt length must not index beyond six physical words. */
    copy.len = DSH_S6_MAX_CHARS + 1U;
    if (dsh_s6_get(&copy, DSH_S6_MAX_CHARS) != -1)
        return 15;
    if (dsh_s6_append(&copy, 040) != -1)
        return 16;
    return 0;
}
