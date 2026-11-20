/*
 * Real DAIMOS WRITECHAR backend regression for GCC's stdio formatter v2.
 *
 * The fixture is a native DAIMOS process, not a bare-metal I/O stub.
 * Output text is also checked by the guest PTY harness.  C89 only.
 */
#include <p10stdio-daimos-v1.h>
#include <stdarg.h>

static int
forward_vprintf_v1(const char *format, ...)
{
    int count;
    va_list arguments;

    va_start(arguments, format);
    count = vprintf(format, arguments);
    va_end(arguments);
    return count;
}

int
main(void)
{
    char buffer[32];
    int n;

    n = sprintf(buffer, "%02d %s", 7, "ok");
    if (n != 5 || buffer[0] != '0' || buffer[1] != '7' ||
        buffer[2] != ' ' || buffer[3] != 'o' ||
        buffer[4] != 'k' || buffer[5] != 0)
        return 11;

    n = printf("GCC-DAIMOS-STDIO-V1: %d %s\n", 27, "ok");
    if (n != 27)
        return 12;
    n = forward_vprintf_v1("GCC-VPRINTF-V1: %04d\n", 19);
    if (n != 21)
        return 13;
    if (putchar('>') != '>' || putchar('\n') != '\n')
        return 14;
    if (puts("GCC-PUTS-V1") < 0)
        return 15;
    if (printf("GCC-DAIMOS-STDIO-V1-PASS\n") != 25)
        return 16;
    return 0;
}
