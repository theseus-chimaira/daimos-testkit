/* Native PDP-6 UTC rollover, invalid-calendar and non-root privilege gate. */
#include "dsys.h"
#define T(yy,mo,dd,hh,mm,ss) \
    ((((kword_t)(((yy)/10U)<<4U | ((yy)%10U)))<<26U) | \
     ((kword_t)(mo)<<22U) | ((kword_t)(dd)<<17U) | \
     ((kword_t)(hh)<<12U) | ((kword_t)(mm)<<6U) | (kword_t)(ss))

int main(void)
{
    kword_t start = dsys_gettime();
    kword_t target = T(28,2,29,23,59,59);
    kword_t expected = T(28,3,1,0,0,0);
    int ok = 1;
    (void)dsys_writechar(1, '#');
    if (start == 0UL) {
        if (dsys_settime(T(27,2,29,0,0,0)) >= 0 ||
            dsys_settime(T(28,4,31,0,0,0)) >= 0 ||
            dsys_settime(T(28,2,30,0,0,0)) >= 0 ||
            dsys_settime(target) != 0)
            ok = 0;
        if (dsys_sleep(150U) < 0 || dsys_gettime() < expected)
            ok = 0;
    } else if (dsys_settime(target) >= 0) {
        ok = 0;
    }
    if (dsys_procctl(SYS_PROCCTL_SETUID, 1U) != 1)
        ok = 0;
    if (dsys_settime(target) >= 0)
        ok = 0;
    (void)dsys_writechar(1, ok ? (start == 0UL ? 'Z' : 'T') : '!');
    (void)dsys_writechar(1, '#');
    (void)dsys_halt();
    return 0;
}
