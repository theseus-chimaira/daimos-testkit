#include <stdio.h>

#include "type340.h"
#include "type340cmd.h"

ty340word
ty340_fetch(ty340word address)
{
    (void)address;
    return 0U;
}

void
ty340_store(ty340word address, ty340word value)
{
    (void)address;
    (void)value;
}

void
ty340_lp_int(ty340word x, ty340word y)
{
    (void)x;
    (void)y;
}

void
ty340_rfd(void)
{
}

int
main(void)
{
    ty340word vector_word;

    (void)ty340_reset(NULL);

    if (ty340_instruction_time_half_us(MVCT | IN7) != 6U) {
        fputs("parameter transfer timing mismatch\n", stderr);
        return 1;
    }
    (void)ty340_instruction(MVCT | IN7);

    vector_word = INSFY | YP64 | XP32;
    if (ty340_instruction_time_half_us(vector_word) != 198U) {
        fputs("vector timing mismatch\n", stderr);
        return 1;
    }

    (void)ty340_instruction(ESCP);
    (void)ty340_instruction(MINCR | IN7);
    if (ty340_instruction_time_half_us(
            INCRPT(PR, PUR, PU, PUL)) != 18U) {
        fputs("incremental timing mismatch\n", stderr);
        return 1;
    }

    puts("type340-timing-v1: PASS");
    return 0;
}
