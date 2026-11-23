/* GCC C89 caller of unmodified KCC-built DAIMOS printf/sprintf entries.
 * No GCC-native stdio formatter or test-only monitor sink is linked.
 * A KCC va_list is internal to the KCC callee, never passed from GCC.
 */
extern int printf(char *, ...);
extern int sprintf(char *, char *, ...);

static int
same_text_v1838(const char *got, const char *expected)
{
    while (*got != 0 && *got == *expected) {
        ++got;
        ++expected;
    }
    return *got == *expected;
}

int
main(void)
{
    char result[48];
    int count;
    int negative;
    unsigned int octal;
    char *label;

    negative = -17;
    octal = 0123U;
    label = "XY";
    count = sprintf(result, "MIX:%d:%s:%o", negative, label, octal);
    if (!same_text_v1838(result, "MIX:-17:XY:123") || count != 14)
        return 11;
    count = printf("KCC-VARARGS-V1838: %d %s %o\n", 23, "OK", 0172U);
    if (count <= 0)
        return 12;
    return 0;
}
