#include "dsys.h"
static volatile kword_t private_tag;
int main(void)
{
    unsigned int slot = (unsigned int)dsys_getpid();
    unsigned int i;
    if (slot < 1U || slot > 32U) {
        (void)dsys_writechar(1, '!');
        (void)dsys_exit(1);
        return 1;
    }
    private_tag = 0123456000000UL | (kword_t)slot;
    if (slot == 1U)
        (void)dsys_writechar(1, '<');
    (void)dsys_writechar(1, (int)(slot <= 26U ? 'a' + slot - 1U : '0' + slot - 27U));
    for (i = 0; i < 0400000U; ++i)
        if (private_tag != (0123456000000UL | (kword_t)slot)) {
            (void)dsys_writechar(1, '@');
            (void)dsys_exit(2);
            return 2;
        }
    (void)dsys_writechar(1, (int)(slot <= 26U ? 'A' + slot - 1U : '6' + slot - 27U));
    (void)dsys_exit(0);
    return 0;
}
