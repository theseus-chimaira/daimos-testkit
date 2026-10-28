/* Native PDP-6 PCLK reader presence probe: one SYS_EXT_GETTIME call. */
#include "dsys.h"

int main(void)
{
    kword_t t;
    unsigned int month;
    unsigned int day;

    t = dsys_gettime();
    (void)dsys_writechar(1, '#');
    if (t == 0UL) {
        (void)dsys_writechar(1, 'Z');
    } else {
        month = (unsigned int)((t >> 22U) & 017UL);
        day = (unsigned int)((t >> 17U) & 037UL);
        if (month == 0U || month > 12U || day == 0U || day > 31U)
            (void)dsys_writechar(1, '!');
        else
            (void)dsys_writechar(1, 'T');
    }
    (void)dsys_writechar(1, '#');
    (void)dsys_halt();
    return 0;
}
