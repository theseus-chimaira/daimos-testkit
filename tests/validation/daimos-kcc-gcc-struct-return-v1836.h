/* Shared mixed KCC/GCC C89 aggregate return ABI declarations.
 * All objects contain whole PDP-10 words; packed members are a separate ABI.
 * C identifiers stay below KCC's 31-significant-character limit.
 */
#ifndef DAIMOS_KCC_GCC_STRUCT_V1836_H
#define DAIMOS_KCC_GCC_STRUCT_V1836_H
struct ret1_v1836 { unsigned long a; };
struct ret2_v1836 { unsigned long a, b; };
struct ret3_v1836 { unsigned long a, b, c; };
struct ret4_v1836 { unsigned long a, b, c, d; };
struct ret5_v1836 { unsigned long a[5]; };
struct ret8_v1836 { unsigned long a[8]; };
struct ret1_v1836 abi_ret1_v1836(unsigned long);
struct ret2_v1836 abi_ret2_v1836(unsigned long);
struct ret3_v1836 abi_ret3_v1836(unsigned long);
struct ret4_v1836 abi_ret4_v1836(unsigned long);
struct ret5_v1836 abi_ret5_v1836(unsigned long);
struct ret8_v1836 abi_ret8_v1836(unsigned long);
#endif
