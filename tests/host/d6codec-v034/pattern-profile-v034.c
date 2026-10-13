/* C99: compare 128-word exhaustive candidate matches with a one-entry
 * hash bucket on deterministic data patterns. No dynamic allocations. */
#include <stdint.h>
#include <stdio.h>
#define N 512U
#define W 128U
#define MASK36 UINT64_C(0777777777777)
static uint64_t a[N];
static unsigned key(uint64_t x,unsigned b){return (unsigned)((x^(x>>18)^(x>>9))&((1U<<b)-1));}
static void run(const char *name,unsigned mode){unsigned bits,i;uint64_t state=UINT64_C(0x123456789a);
 for(i=0;i<N;i++){
  state=state*UINT64_C(6364136223846793005)+1;
  if(mode==0)a[i]=(state>>18)&MASK36;
  else if(mode==1)a[i]=i%17;
  else if(mode==2)a[i]=(i%64)<32?(uint64_t)(i%32):((state>>18)&MASK36);
  else a[i]=42;
 }
 for(bits=3;bits<=6;bits++){
  unsigned table[64]={0};unsigned full=0,found=0,missed=0,false_candidates=0;
  for(i=0;i<N;i++){
   unsigned lower=i>W?i-W:0,dist,any=0,candidate;
   for(dist=1;dist<=i-lower;dist++)if(a[i-dist]==a[i]){any=1;break;}
   candidate=table[key(a[i],bits)];
   if(candidate && candidate-1>=lower){if(a[candidate-1]==a[i])found++;else false_candidates++;}
   if(any){full++;if(!candidate || candidate-1<lower || a[candidate-1]!=a[i])missed++;}
   table[key(a[i],bits)]=i+1;
  }
  printf("%s slots=%u full_ref_positions=%u index_hits=%u lost_ref_positions=%u false_candidates=%u\n",name,1U<<bits,full,found,missed,false_candidates);
 }
}
int main(void){run("random",0);run("period17",1);run("mixed",2);run("uniform",3);return 0;}
