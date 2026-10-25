#include "dsys.h"
/* 63 independently mapped 4096-word resident images exceed 256K once
 * kernel, per-process u-areas, and startup reservations are included. */
static volatile kword_t pressure_data[010000];
static volatile kword_t private_tag;
static void marker(unsigned int slot, int opening, int closing)
{
    static const char hex[] = "0123456789ABCDEF";
    (void)dsys_writechar(1, opening);
    (void)dsys_writechar(1, hex[(slot >> 4) & 15U]);
    (void)dsys_writechar(1, hex[slot & 15U]);
    (void)dsys_writechar(1, closing);
}
int main(void)
{
    unsigned int slot = (unsigned int)dsys_getpid();
    unsigned int i;
    if (slot < 1U || slot > 63U) {
        (void)dsys_writechar(1, '!');
        (void)dsys_exit(1);
        return 1;
    }
    private_tag = 0123456000000UL | (kword_t)slot;
    pressure_data[0] = private_tag;
    pressure_data[07777] = private_tag ^ 077777UL;
    if (slot == 1U)
        (void)dsys_writechar(1, '<');
    marker(slot, '[', ']');
    for (i = 0; i < 0400000U; ++i)
        if (private_tag != (0123456000000UL | (kword_t)slot) || pressure_data[0] != private_tag || pressure_data[07777] != (private_tag ^ 077777UL)) {
            (void)dsys_writechar(1, '@');
            (void)dsys_exit(2);
            return 2;
        }
    marker(slot, '{', '}');
    (void)dsys_exit(0);
    return 0;
}
