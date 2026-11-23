/* C89 natural byte+word aggregate shared by GCC and KCC. */
#ifndef DKG_NATBYTE_V1842_H
#define DKG_NATBYTE_V1842_H
struct natural_v1842 {
    unsigned char prefix[5];
    unsigned long marker;
    unsigned char suffix[3];
};
struct natural_v1842 make_nat_v1842(unsigned long);
unsigned long sum_nat_v1842(struct natural_v1842);
unsigned long size_nat_v1842(void);
void update_nat_v1842(struct natural_v1842 *);
#endif
