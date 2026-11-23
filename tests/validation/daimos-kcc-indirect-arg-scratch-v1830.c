/* KCC callback ABI: preserve indirect targets through argument setup.
 * Dynamic 9-bit byte-pointer arithmetic uses PDP-6 AC16 scratch.
 * The five-argument call also exercises stack-passed arguments.
 * C89, no operating-system dependencies. */
volatile unsigned int fail_id_v1830;
static volatile unsigned int calls_v1830;
static volatile unsigned int inner_calls_v1830;

static unsigned int
offset_v1830(void)
{
    ++inner_calls_v1830;
    return 4U;
}

static int
compare0_v1830(void)
{
    ++calls_v1830;
    return 77;
}

static int
compare2_v1830(const unsigned char *a, const unsigned char *b)
{
    ++calls_v1830;
    return ((int)*a * 16) + (int)*b;
}

static int
compare5_v1830(const unsigned char *a, const unsigned char *b,
    const unsigned char *c, const unsigned char *d,
    const unsigned char *e)
{
    ++calls_v1830;
    return (int)*a + (int)*b + (int)*c + (int)*d + (int)*e;
}

static int
dispatch2_v1830(int (*callback)(const unsigned char *,
    const unsigned char *), unsigned char *data, unsigned int index)
{
    return callback(data + index, data + index + 1U);
}

static int
dispatch5_v1830(int (*callback)(const unsigned char *,
    const unsigned char *, const unsigned char *, const unsigned char *,
    const unsigned char *), unsigned char *data, unsigned int index)
{
    return callback(data + index, data + index + 1U,
        data + index + 2U, data + index + 3U, data + index + 4U);
}

static int
dispatch_nested_v1830(int (*callback)(const unsigned char *,
    const unsigned char *), unsigned char *data)
{
    return callback(data + offset_v1830(), data + 1U);
}

static int
dispatch0_v1830(int (*callback)(void))
{
    return callback();
}

int
main(void)
{
    unsigned char data[12];
    unsigned int i;
    int result;

    fail_id_v1830 = 0U;
    calls_v1830 = 0U;
    inner_calls_v1830 = 0U;
    for (i = 0U; i < 12U; ++i)
        data[i] = (unsigned char)(i + 1U);

    result = dispatch2_v1830(compare2_v1830, data, 3U);
    if (result != 69 || calls_v1830 != 1U) {
        fail_id_v1830 = 1U;
        return 1;
    }
    result = dispatch5_v1830(compare5_v1830, data, 2U);
    if (result != 25 || calls_v1830 != 2U) {
        fail_id_v1830 = 2U;
        return 2;
    }
    result = dispatch_nested_v1830(compare2_v1830, data);
    if (result != 82 || calls_v1830 != 3U ||
        inner_calls_v1830 != 1U) {
        fail_id_v1830 = 3U;
        return 3;
    }
    result = dispatch0_v1830(compare0_v1830);
    if (result != 77 || calls_v1830 != 4U) {
        fail_id_v1830 = 4U;
        return 4;
    }
    return 0;
}
