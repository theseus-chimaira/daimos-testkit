/* Native PDP-6 UTC settime and invalid-date regression. */
#include "dsys.h"

#define GOOD_TIME (((kword_t)046UL << 26U) | ((kword_t)02UL << 22U) | \
    ((kword_t)034UL << 17U) | ((kword_t)012UL << 12U) | \
    ((kword_t)034UL << 6U) | 056UL)

int main(void)
{
    kword_t before;
    kword_t after;
    int result;

    before = dsys_gettime();
    (void)dsys_writechar(1, '#');
    result = dsys_settime(GOOD_TIME);
    after = dsys_gettime();
    if (before == 0UL) {
        if (result != 0 || after < GOOD_TIME ||
            dsys_settime(0UL) >= 0 || dsys_gettime() < GOOD_TIME)
            (void)dsys_writechar(1, '!');
        else
            (void)dsys_writechar(1, 'Z');
    } else {
        if (result >= 0 || after == 0UL)
            (void)dsys_writechar(1, '!');
        else
            (void)dsys_writechar(1, 'T');
    }
    (void)dsys_writechar(1, '#');
    (void)dsys_halt();
    return 0;
}
