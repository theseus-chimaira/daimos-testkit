#include "codec_v004.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#define N 256
static uint64_t x=UINT64_C(012345670123);
static uint64_t rnd(void){x^=x<<13;x^=x>>7;x^=x<<17;return x&UINT64_C(0777777777777);}
int main(void){uint64_t a[N],b[N],*c;size_t len,k,j;int mode,fail=0;
 for(k=0;k<6;k++){for(j=0;j<N;j++){if(k==0)a[j]=0;else if(k==1)a[j]=UINT64_C(0123456123456);else if(k==2)a[j]=(j%8)<<18|((j/4)%3);else if(k==3)a[j]=rnd();else if(k==4)a[j]=((j%2)?UINT64_C(0777777):0)<<18|(j%9); else a[j]=((j*13)%17)<<18|((j*13+1)%17);}
  for(mode=0;mode<2;mode++){if(d6v004_encode(a,N,mode,&c,&len)||d6v004_decode(c,len,b,N)||memcmp(a,b,sizeof(a))){fprintf(stderr,"FAIL case=%lu mode=%d\n",(unsigned long)k,mode);fail++;}else printf("case %lu mode %d words %lu\n",(unsigned long)k,mode,(unsigned long)len);free(c);}
 }
 for(k=0;k<250;k++) {size_t n=k%N;for(j=0;j<n;j++)a[j]=(k%3==0)?rnd():((k%3==1)?((j%17)<<18)|(j%11):rnd()&UINT64_C(0777777));
 for(mode=0;mode<2;mode++){if(d6v004_encode(a,n,mode,&c,&len)||d6v004_decode(c,len,b,n)||memcmp(a,b,n*sizeof(a[0]))){fprintf(stderr,"random failure %lu %d\n",(unsigned long)k,mode);fail++;} free(c);}}
 printf("roundtrips: %d failures: %d\n",512,fail);
 return fail?1:0;
}
