/* Shared C89 GCC/KCC floating aggregate ABI declarations. */
#ifndef DKG_FLOAT_V1840_H
#define DKG_FLOAT_V1840_H
struct fd2_v1840 { double d; };
struct ff2_v1840 { float f; unsigned long tag; };
struct fd3_v1840 { double d; unsigned long tag; };
struct fd4_v1840 { float f; double d; unsigned long tag; };
struct fd5_v1840 { double d; unsigned long tag[3]; };
struct fd8_v1840 { double d; unsigned long tag[6]; };
struct fd2_v1840 ret_fd2_v1840(double);
struct ff2_v1840 ret_ff2_v1840(float, unsigned long);
struct fd3_v1840 ret_fd3_v1840(double, unsigned long);
struct fd4_v1840 ret_fd4_v1840(float, double, unsigned long);
struct fd5_v1840 ret_fd5_v1840(double, unsigned long);
struct fd8_v1840 ret_fd8_v1840(double, unsigned long,
    unsigned long, unsigned long, unsigned long);
#endif
