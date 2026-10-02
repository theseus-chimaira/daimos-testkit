#include "u.h"

int
main(void)
{
        if (u_puts(1, "D6LZ-CEXEC-MARKER") != 0 || u_crlf(1) != 0)
                return 1;
        return 0;
}
