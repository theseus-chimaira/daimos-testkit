/*
 * GCC PDP-10 variadic console ABI regression with a recording sink.
 *
 * This is a bare-metal test of calling convention and failure handling,
 * NOT an execution of the DAIMOS monitor.  The test-owned
 * dsys_writechar implementation only records arguments.  A separate
 * DAIMOS guest test must validate the real monitor WRITECHAR syscall.
 */
#include <p10stdio-daimos-v1.h>
#include <stdarg.h>

volatile unsigned int fail_id;
static char observed_v1[128];
static unsigned int count_v1;
static unsigned int attempts_v1;
static unsigned int maximum_v1;

int
dsys_writechar(int fd, int character)
{
    ++attempts_v1;
    if (fd != 1 || count_v1 >= maximum_v1 ||
        count_v1 >= sizeof(observed_v1) - 1)
        return -1;
    observed_v1[count_v1++] = (char)character;
    observed_v1[count_v1] = 0;
    return 0;
}

static void
reset_v1(unsigned int maximum)
{
    count_v1 = 0;
    attempts_v1 = 0;
    maximum_v1 = maximum;
    observed_v1[0] = 0;
}

static int
same_v1(const char *expected)
{
    unsigned int i = 0;
    while (observed_v1[i] == expected[i] && expected[i] != 0)
        ++i;
    return observed_v1[i] == expected[i];
}

static void
check_v1(int ok, unsigned int id)
{
    if (!ok) {
        fail_id = id;
        /* Returning nonzero from main gives an observable guest failure
         * through the ordinary upstream runtime, without fake abort. */
    }
}

static int
forward_vprintf_v1(const char *fmt, ...)
{
    va_list ap;
    int n;
    va_start(ap, fmt);
    n = vprintf(fmt, ap);
    va_end(ap);
    return n;
}

int
main(void)
{
    int n;

    fail_id = 0;
    reset_v1(127);
    n = printf("%d:%s:%04x", 27, "ok", 10U);
    check_v1(n == 10 && same_v1("27:ok:000a") &&
             attempts_v1 == 10U, 1);
    if (fail_id != 0)
        return 1;

    reset_v1(127);
    n = forward_vprintf_v1("Q%u!", 512U);
    check_v1(n == 5 && same_v1("Q512!") &&
             attempts_v1 == 5U, 2);
    if (fail_id != 0)
        return 2;

    reset_v1(127);
    n = putchar('Z');
    check_v1(n == 'Z' && same_v1("Z") && attempts_v1 == 1U, 3);
    if (fail_id != 0)
        return 3;

    reset_v1(127);
    n = puts("HI");
    check_v1(n >= 0 && same_v1("HI\n") && attempts_v1 == 3U, 4);
    if (fail_id != 0)
        return 4;

    /* The third write fails. The formatter must not keep calling
     * the sink while finishing the remaining digits/padding. */
    reset_v1(2);
    n = printf("%08d", 42);
    check_v1(n == -1 && count_v1 == 2U &&
             attempts_v1 == 3U && same_v1("00"), 5);
    if (fail_id != 0)
        return 5;

    reset_v1(0);
    n = putchar('A');
    check_v1(n == EOF && count_v1 == 0U && attempts_v1 == 1U, 6);
    if (fail_id != 0)
        return 6;

    return 0;
}
