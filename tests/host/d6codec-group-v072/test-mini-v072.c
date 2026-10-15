#include <stdio.h>
#include <stdint.h>
#include "d6codec-group-v071.h"
int main(void){uint64_t in[40],buf[100],out[40];size_t n,i;for(i=0;i<40;i++)in[i]=(i<8)?7:i;for(size_t count=1;count<=40;count++){if(d6codec_group_v072_encode(in,count,buf,100,&n))return 1; if(d6codec_group_v071_decode(buf,n,out,count)){printf("FAILED count=%zu n=%zu ctrl=%llo\n",count,n,(unsigned long long)buf[0]);for(i=0;i<n;i++)printf("%zu:%llo ",i,(unsigned long long)buf[i]);printf(" expected:");for(i=0;i<count;i++)printf(" %llo",(unsigned long long)in[i]);puts("");return 2;}}puts("PASS");return 0;}
