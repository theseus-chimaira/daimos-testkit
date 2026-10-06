#include "dsys.h"

/*
 * Force a PDP-6 APR protection fault from user mode.  A minimal test image is
 * allocated only a small aligned user extent; logical 077777 is deliberately
 * beyond that protection limit.  Correct kernel behavior is to terminate the
 * offending process rather than spin forever on the still-asserted APR PI6.
 */
int
main(void)
{
        volatile kword_t *bad;
        volatile kword_t value;

        (void)dsys_writechar(1, '<');
        bad = (volatile kword_t *)(unsigned long)077777U;
        value = *bad;
        (void)value;

        /* Reaching this marker means the access was not delivered as a fault. */
        (void)dsys_writechar(1, '!');
        (void)dsys_exit(1);
        return 1;
}
