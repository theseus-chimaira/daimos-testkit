/* Dedicated large *child* image for the v199 native RUN loader-OOM probe.
 * The parent remains the proven v197 size and needs no special boot path.
 * The 077000-word BSS is present in the DXR header's VM size,
 * requiring a physically separate process extent before this code can run.
 * DXR encodes BSS in 15 bits: the maximum accepted value is 077777.
 */
#include "dsys.h"

static volatile kword_t large_child_reservation[077000];

int
main(void)
{
        large_child_reservation[076777] = 01234567UL;
        (void)dsys_exit(051U);
        return 051;
}
