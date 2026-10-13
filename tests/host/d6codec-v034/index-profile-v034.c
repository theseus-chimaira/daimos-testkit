/* C99: bounded window candidate-index experiment, no allocations. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#define WINDOW 128U
#define MASK36 UINT64_C(0777777777777)
static uint64_t source[WINDOW];
static unsigned bucket(uint64_t w,unsigned bits){return (unsigned)((w^(w>>18)^(w>>9))&((1U<<bits)-1));}
int main(void){unsigned bits,seed;
 for(bits=3;bits<=6;bits++){
  unsigned slots=1U<<bits;
  unsigned long long probes=0, matches=0, misses=0, collisions=0;
  for(seed=1;seed<=100;seed++){
   uint64_t state=(uint64_t)seed*UINT64_C(6364136223846793005);
   unsigned i,j;
   for(i=0;i<WINDOW;i++){state=state*UINT64_C(2862933555777941757)+UINT64_C(3037000493);source[i]=(state>>11)&MASK36;}
   for(i=1;i<WINDOW;i++){
    /* One candidate per slot, most-recent overwrite, no false matches. */
    unsigned table[64]={0};
    for(j=0;j<i;j++)table[bucket(source[j],bits)]=j+1;
    j=table[bucket(source[i],bits)];probes++;
    if(j){if(source[j-1]==source[i])matches++;else collisions++;}
    else misses++;
   }
  }
  printf("slots=%u ram_words=%u probes=%llu exact_matches=%llu hash_collisions=%llu empty=%llu\n",slots,slots,probes,matches,collisions,misses);
 }
 return 0;
}
