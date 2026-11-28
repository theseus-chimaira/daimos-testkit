typedef long long S;
typedef unsigned long long U;
S div_s(S a, S b) { return a / b; }
S mod_s(S a, S b) { return a % b; }
U div_u(U a, U b) { return a / b; }
U mod_u(U a, U b) { return a % b; }
S mul_s(S a, S b) { return a * b; }
U mul_u(U a, U b) { return a * b; }
S bit_s(S a, S b) { return -(~((a & b) | (a ^ b))); }
S shift_s(S a, int b) { return (a << b) >> b; }
U shift_u(U a, int b) { return (a >> b) << b; }
S power_s(S a) { return a / 16LL; }
S power_mod_s(S a) { return a % -16LL; }
S power_high_s(S a) { return a / (1LL << 40); }
S power_high_mod_s(S a) { return a % (1LL << 40); }
U power_high_u(U a) { return a / (1ULL << 40); }
U power_high_mod_u(U a) { return a % (1ULL << 40); }
S inc(S *p) { return (*p)++; }
S dec(S *p) { return --(*p); }
S widen(int a) { return a; }
U widen_u(unsigned a) { return a; }
S store(S *p, S a) { return *p = a; }
S global;
S store_global(S a) { return global = a; }
S compare_pressure(S a, S b, S c, S d)
{
    return a * ((b + c < c + d) ? b : c) + d;
}
