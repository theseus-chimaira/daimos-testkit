/*
 * Fixed-point floating sprintf ABI and rounding regression.
 * KCC/DAIMOS PDP-6 and KA10+ portable software D-format.
 * The original GCC 930513-1.c regression is compiled separately.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int
expect_fixed(char *want, char *format, double value)
{
        char actual[64];
        int n;
        int expected;

        n = sprintf(actual, format, value);
        expected = (int)strlen(want);
        if (n != expected)
                return 1;
        if (strcmp(actual, want) != 0)
                return 2;
        return 0;
}

int
main(void)
{
        char actual[64];
        int (*formatter)(char *, char *, ...);

        formatter = sprintf;
        if ((*formatter)(actual, "%.0f", 5.0) != 1 ||
            strcmp(actual, "5") != 0)
                return 10;
        if (expect_fixed("0", "%.0f", 0.0) != 0)
                return 11;
        if (expect_fixed("2", "%.0f", 2.4) != 0)
                return 12;
        if (expect_fixed("2", "%.0f", 2.5) != 0)
                return 13;
        if (expect_fixed("4", "%.0f", 3.5) != 0)
                return 14;
        if (expect_fixed("-2", "%.0f", -2.5) != 0)
                return 15;
        if (expect_fixed("-4", "%.0f", -3.5) != 0)
                return 16;
        if (expect_fixed("-0", "%.0f", -0.25) != 0)
                return 17;
        if (expect_fixed("+0000005", "%+08.0f", 5.0) != 0)
                return 18;
        if (expect_fixed("25", "%.0f", 25.0) != 0)
                return 19;
        if (expect_fixed("256", "%.0f", 256.0) != 0)
                return 20;
        if (expect_fixed("33554432", "%.0f", 33554432.0) != 0)
                return 21;
        if (expect_fixed("268435456", "%.0f", 268435456.0) != 0)
                return 25;
        if (expect_fixed("8589934592", "%.0f", 8589934592.0) != 0)
                return 26;
        if (expect_fixed("34359738367", "%.0f", 34359738367.0) != 0)
                return 27;
        if (expect_fixed("0", "%.0f", 0.5) != 0)
                return 28;
        if (expect_fixed("1", "%.0f", 0.75) != 0)
                return 29;
        if (expect_fixed("2", "%.0f", 1.5) != 0)
                return 30;
        if (sprintf(actual, "%d %s", 37, "ok") != 5 ||
            strcmp(actual, "37 ok") != 0)
                return 22;
        if (sprintf(actual, "%.1f", 5.0) != -1)
                return 23;
        if (printf("DAIMOS-SPRINTF-FLOAT-V33-PASS\n") <= 0)
                return 24;
        return 0;
}
