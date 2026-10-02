#include "dsys.h"

extern int daimos_test_low_uuo(void);

int
main(void)
{
        int rc;

        rc = daimos_test_low_uuo();
        if (rc != -1) {
                (void)dsys_writechar(1, 'X');
                (void)dsys_writechar(1, 'K');
                (void)dsys_writechar(1, 'U');
                (void)dsys_halt();
                return 1;
        }
        if (dsys_writechar(1, 'U') < 0 || dsys_writechar(1, 'O') < 0 ||
            dsys_writechar(1, 'K') < 0) {
                (void)dsys_halt();
                return 1;
        }
        (void)dsys_halt();
        return 0;
}
