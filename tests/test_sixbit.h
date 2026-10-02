#ifndef DAIMOS_TEST_SIXBIT_H
#define DAIMOS_TEST_SIXBIT_H

/* Constant-expression SIXBIT packing for static test fixtures. */
#define TEST_SIXCHAR(ch) \
        ((unsigned long)(((unsigned int)(ch) - 040U) & 077U))
#define TEST_SIX6(a,b,c,d,e,f) \
        ((TEST_SIXCHAR(a) << 30) | (TEST_SIXCHAR(b) << 24) | \
        (TEST_SIXCHAR(c) << 18) | (TEST_SIXCHAR(d) << 12) | \
        (TEST_SIXCHAR(e) << 6) | TEST_SIXCHAR(f))

#endif
