#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "d6codec-group-v071.h"
int main(void) {
 uint64_t src[350],enc[800],dec[350]; size_t i,n;
 for(i=0;i<350;i++) src[i]= i%17==0?0 : i%17<6 ? (uint64_t)012345670123 : (uint64_t)(i*761+123);
 if(d6codec_group_v072_encode(src,350,enc,800,&n)) return 1;
 if(d6codec_group_v071_decode(enc,n,dec,350)) { printf("decode fail %zu\n",n); return 2; }
 if(memcmp(src,dec,sizeof(src))) return 3;
 printf("PASS encoded=%zu\n",n);
 return 0;
}
