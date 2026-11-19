/* Native GCC-ABI argument lifetime regression for nested function calls.
 *
 * An incoming AC1/AC3 value must survive a nested argument evaluation
 * that calls a helper and clobbers volatile ABI registers.  The bug in
 * KCC used to pass the helper return value as the first argument.
 * All test values are selected at runtime from initialized globals.
 */
int v1373_first = 11;
int v1373_middle = 15;
int v1373_last = 33;

int
v1373_helper(int value)
{
    return value + 7;
}

int
v1373_check(int first, int middle, int last)
{
    return (first == 11 && middle == 22 && last == 33) ? 0 : 1;
}

int
v1373_nested(int first, int middle, int last)
{
    return v1373_check(first, v1373_helper(middle), last);
}

int
main(void)
{
    return v1373_nested(v1373_first, v1373_middle, v1373_last);
}
