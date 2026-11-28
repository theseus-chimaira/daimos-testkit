/* Exercise all four signed and unsigned relational conditions, carry
 * propagation, borrow, and expressions with competing live AC pairs. */
typedef long long S;
typedef unsigned long long U;

S signed_arith(S a, S b, S c)
{
    return (a + b) - c;
}

U unsigned_arith(U a, U b, U c)
{
    return (a - b) + c;
}

int signed_cmp(S a, S b)
{
    int n = 0;
    if (a < b) n += 1;
    if (a <= b) n += 2;
    if (a > b) n += 4;
    if (a >= b) n += 8;
    return n;
}

int unsigned_cmp(U a, U b)
{
    int n = 0;
    if (a < b) n += 1;
    if (a <= b) n += 2;
    if (a > b) n += 4;
    if (a >= b) n += 8;
    return n;
}

extern S svalue(int);
extern U uvalue(int);

S signed_pressure(S a, S b, S c, S d)
{
    return a + ((b + svalue(1)) < (c + svalue(2)) ? c : d);
}

U unsigned_pressure(U a, U b, U c, U d)
{
    return a + ((b + uvalue(1)) >= (c + uvalue(2)) ? c : d);
}
