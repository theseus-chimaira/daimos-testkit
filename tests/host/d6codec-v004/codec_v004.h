#ifndef D6CODEC_V004_H
#define D6CODEC_V004_H
#include <stddef.h>
#include <stdint.h>
int d6v004_encode(const uint64_t *,size_t,int,uint64_t **,size_t *);
int d6v004_decode(const uint64_t *,size_t,uint64_t *,size_t);
#endif
