/* Verify KCC GAS double data and code literals are assembled as 2 words.
 * C89: all values are exactly representable in PDP-10 D format.
 */
volatile double data_one_v1843 = 2.0;
volatile double data_two_v1843 = -4.0;
volatile double data_three_v1843 = 0.25;

int
main(void)
{
    if (data_one_v1843 != 2.0)
        return 1;
    if (data_two_v1843 != -4.0)
        return 2;
    if (data_three_v1843 != 0.25)
        return 3;
    return 0;
}
