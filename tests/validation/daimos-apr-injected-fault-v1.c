#include "dsys.h"

static volatile kword_t spin;

extern void apr_pdl_overflow(void);

int
main(void)
{
        (void)dsys_writechar(1, '<');

        /* argv is not needed: the harness selects PDL through AC1 at entry. */
        if (dsys_getpid() == 2) {
                apr_pdl_overflow();
                (void)dsys_writechar(1, '!');
                (void)dsys_exit(1);
        }
        for (;;)
                spin = (spin + 1UL) & 0777777777777UL;
}
