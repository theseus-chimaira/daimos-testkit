#include "kinit.h"

int
kfs_boot_v2_prepare(void)
{
        kinit_put6((kword_t)SIXBIT("DEVICE"));
        kinit_put6((kword_t)SIXBIT(" TEST "));
        kinit_put6((kword_t)SIXBIT("OK    "));
        kinit_newline();
        kinit_halt();
        return -1;
}
