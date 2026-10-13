#ifndef D6CODEC_V003_H
#define D6CODEC_V003_H
#include <stddef.h>
#include <stdint.h>
int d6v003_encode(const uint64_t *,size_t,int,uint64_t **,size_t *);
int d6v003_decode(const uint64_t *,size_t,uint64_t *,size_t);
#endif
