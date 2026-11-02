#include "u.h"

int main(void)
{
    kword_t start, before, want, result;
    unsigned int i;
    start = dsys_brk(0UL);
    if (start == (kword_t)-1L) return 10;
    for (i = 0U; i < 255U; ++i) {
        before = dsys_brk(0UL);
        want = before + 02000UL;
        result = dsys_brk(want);
        if (result != want) {
            if (dsys_brk(0UL) != before) return 11;
            if (dsys_brk(start) != start) return 12;
            (void)dsys_writechar(1, 'B');
            (void)dsys_writechar(1, 'R');
            (void)dsys_writechar(1, 'K');
            (void)dsys_writechar(1, '-');
            (void)dsys_writechar(1, 'O');
            (void)dsys_writechar(1, 'O');
            (void)dsys_writechar(1, 'M');
            (void)dsys_writechar(1, '-');
            (void)dsys_writechar(1, 'P');
            (void)dsys_writechar(1, 'A');
            (void)dsys_writechar(1, 'S');
            (void)dsys_writechar(1, 'S');
            return 0;
        }
    }
    (void)dsys_writechar(1, 'X');
    return 13;
}
