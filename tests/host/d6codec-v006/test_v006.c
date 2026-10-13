/* Deterministic round-trip and malformed-stream tests. */
#include "codec_v006.h"
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#define N 257
#define MASK UINT64_C(0777777777777)
static uint64_t state=UINT64_C(012345670123);
static uint64_t rnd(void){state^=state<<13;state^=state>>7;state^=state<<17;return state&MASK;}
int main(void){uint64_t src[N],dst[N],*enc=NULL;size_t k,i,n,ne;int bad=0;
 for(k=0;k<600;k++){
  n=k%N;
  for(i=0;i<n;i++){
   if(k%6==0)src[i]=0;
   else if(k%6==1)src[i]=UINT64_C(0123456123456);
   else if(k%6==2)src[i]=rnd();
   else if(k%6==3)src[i]=((uint64_t)(i%17)<<18)|(uint64_t)((i+1)%17);
   else if(k%6==4)src[i]=(i%5)?UINT64_C(0777777):0;
   else src[i]=i%13?((uint64_t)(i%13)<<18):rnd();
  }
  if(d6v006_encode(src,n,&enc,&ne)||d6v006_decode(enc,ne,dst,n)||memcmp(src,dst,n*sizeof(src[0]))){fprintf(stderr,"roundtrip error %lu\n",(unsigned long)k);bad++;}
  if(ne && n && d6v006_decode(enc,ne-1,dst,n)==0){fprintf(stderr,"accepted truncated stream %lu\n",(unsigned long)k);bad++;}
  free(enc);enc=NULL;
 }
 {uint64_t invalid[]={UINT64_C(1)<<29,0};if(d6v006_decode(invalid,2,dst,1)==0)bad++;}
 {uint64_t invalid[]={UINT64_C(31)<<30,0};if(d6v006_decode(invalid,2,dst,1)==0)bad++;}
 printf("600 roundtrips and truncation checks, malformed headers: failures=%d\n",bad);
 return bad?1:0;
}
