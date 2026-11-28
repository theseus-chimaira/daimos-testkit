/* String initialization of packed character arrays must initialize each
 * element, including truncation, terminator and zero padding, without
 * shifting the next packed field or array element. */
struct __attribute__((packed)) record {
    char lead;
    char text[5];
    unsigned char exact[2];
    char tail;
};
static volatile struct record data[2] = {
    {'L', "ab", "cd", 'R'},
    {'X', "12345", "ef", 'Y'}
};

int main(void)
{
    if (data[0].lead != 'L' || data[0].tail != 'R' ||
        data[1].lead != 'X' || data[1].tail != 'Y')
        return 1;
    if (data[0].text[0] != 'a' || data[0].text[1] != 'b' ||
        data[0].text[2] || data[0].text[3] || data[0].text[4])
        return 2;
    if (data[0].exact[0] != 'c' || data[0].exact[1] != 'd')
        return 3;
    if (data[1].text[0] != '1' || data[1].text[4] != '5' ||
        data[1].exact[0] != 'e' || data[1].exact[1] != 'f')
        return 4;
    return 0;
}
