/* Exercise byte-mode starts, unchanged and changed field widths, alignment,
 * whole-word data, zero runs and deferred relocatable expressions. */
struct __attribute__((packed)) packed {
    unsigned a : 3;
    unsigned b : 13;
    unsigned c : 20;
    unsigned d : 5;
    unsigned e : 31;
    char f[7];
};
struct packed values[3] = {
    { 7, 0x1234, 0x23456, 31, 0x12345678, "abc" },
    { 1, 2, 3, 4, 5, "xyz" }
};
char bytes[400] = { 1, 2, 3, 4, 5 };
short halves[9] = { -1, 2, -3, 4 };
long words[400] = { -1, 2, 3, 0, 5 };
unsigned long long pair[3] = { 1ULL << 40, 0, 7 };
char *ptr = bytes + 3;
char text[13] = "hello";
double fp[3] = { 1.0, -2.0 };
int labeldiff(int i)
{
    static const int diff[] = { &&zero - &&zero, &&one - &&zero };
    static const unsigned char small[] = { &&zero - &&zero, &&one - &&zero };
    if (i)
        goto one;
zero:
    return diff[i];
one:
    return small[i];
}
