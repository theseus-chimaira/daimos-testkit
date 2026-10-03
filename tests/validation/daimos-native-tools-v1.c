#include "u.h"

int
main(int argc, kword_t **argv)
{
        (void)argc;
        (void)argv;
        if (u_puts(1, "NATIVE LINK OK") != 0 || u_crlf(1) != 0)
                return 1;
        return 0;
}
