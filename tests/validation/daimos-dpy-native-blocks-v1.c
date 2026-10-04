#include "kcore.h"

#define T342_SI 035UL
#define T342_SO 036UL
#define T342_SPACE 040UL

int __test_exit;
kword_t dpy_text_base;
kword_t dpy_text_top;

extern unsigned int dpy_phys_row(unsigned int logical);
extern void dpy_cell_set(unsigned int prow, unsigned int col, unsigned int ch);
extern void dpy_clear_row(unsigned int prow);

static kword_t screen[42U * 28U];

static kword_t
pack6(kword_t a, kword_t b, kword_t c, kword_t d, kword_t e, kword_t f)
{
        return (a << 30U) | (b << 24U) | (c << 18U) |
            (d << 12U) | (e << 6U) | f;
}

static kword_t
pair(kword_t state, kword_t glyph)
{
        return (state << 6U) | glyph;
}

static kword_t
pack3(kword_t a, kword_t b, kword_t c)
{
        return (a << 24U) | (b << 12U) | c;
}

static int
check(int ok, int code)
{
        return ok ? 0 : code;
}

int
main(void)
{
        kword_t *p;
        int rc;

        dpy_text_base = (kword_t)(unsigned long)screen;
        dpy_text_top = 0UL;
        screen[0] = 012345670123UL;
        dpy_clear_row(0U);
        p = screen;
        rc = check(p[0] == 0UL, 1);
        if (rc != 0) return rc;

        dpy_cell_set(0U, 0U, 'A');
        dpy_cell_set(0U, 1U, 'B');
        dpy_cell_set(0U, 2U, 'C');
        dpy_cell_set(0U, 3U, 'D');
        dpy_cell_set(0U, 4U, 'E');
        dpy_cell_set(0U, 5U, 'F');
        rc = check(p[0] == pack6(1U, 2U, 3U, 4U, 5U, 6U) &&
            p[1] == 0UL, 2);
        if (rc != 0) return rc;

        /* A shifted glyph expands only this six-cell block to two words. */
        dpy_cell_set(0U, 2U, '[');
        rc = check(p[0] == pack3(pair(T342_SI, 1U), pair(T342_SI, 2U),
            pair(T342_SO, 053U)), 3);
        if (rc != 0) return rc;
        rc = check(p[1] == pack3(pair(T342_SI, 4U), pair(T342_SI, 5U),
            pair(T342_SI, 6U)), 4);
        if (rc != 0) return rc;

        /* A complex block stays complex after a primary-set overwrite. */
        dpy_cell_set(0U, 2U, 'C');
        rc = check(p[0] == pack3(pair(T342_SI, 1U), pair(T342_SI, 2U),
            pair(T342_SI, 3U)), 5);
        if (rc != 0) return rc;

        /* Row clear leaves word 1 stale; primary reuse must discard it. */
        dpy_clear_row(0U);
        rc = check(p[0] == 0UL, 6);
        if (rc != 0) return rc;
        dpy_cell_set(0U, 0U, 'Z');
        rc = check(p[0] == pack6(032U, T342_SPACE, T342_SPACE,
            T342_SPACE, T342_SPACE, T342_SPACE) && p[1] == 0UL, 7);
        if (rc != 0) return rc;

        /* Lowercase keeps the historical uppercase terminal semantics. */
        dpy_clear_row(1U);
        dpy_cell_set(1U, 0U, 'a');
        p = screen + 28U;
        rc = check(p[0] == pack6(1U, T342_SPACE, T342_SPACE,
            T342_SPACE, T342_SPACE, T342_SPACE) && p[1] == 0UL, 8);
        if (rc != 0) return rc;

        /* A shifted final cell leaves SO as the block's observable end state. */
        dpy_clear_row(2U);
        dpy_cell_set(2U, 5U, '_');
        p = screen + 56U;
        rc = check(p[1] != 0UL && ((p[1] >> 6U) & 077UL) == T342_SO, 9);
        if (rc != 0) return rc;

        dpy_text_top = 051U;
        rc = check(dpy_phys_row(1U) == 0U, 10);
        if (rc != 0) return rc;
        return 0;
}
