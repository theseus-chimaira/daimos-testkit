#include "u.h"

int
main(void)
{
        kword_t ready;

        (void)dsys_writechar(1, 'R');
        ready = (kword_t)'r';
        if (dsys_write_words(3, &ready, 1U) != 1)
                return 1;
        (void)dsys_readchar(0);
        (void)dsys_exit(0);
        return 0;
}
