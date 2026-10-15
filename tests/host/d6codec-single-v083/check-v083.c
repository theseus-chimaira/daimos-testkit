/* Verify single-codec compressed DXR header, image, and relocation map. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "d6codec-group-v071.h"
static uint64_t *load(const char *name,size_t *n) {
 FILE *f=fopen(name,"rb");long len;uint64_t *v;size_t i;
 if(!f||fseek(f,0,SEEK_END)||(len=ftell(f))<0||len%8||fseek(f,0,SEEK_SET))return NULL;
 *n=(size_t)len/8;v=calloc(*n?*n:1,sizeof(*v));if(!v)return NULL;
 for(i=0;i<*n;i++){unsigned char b[8];unsigned j;if(fread(b,1,8,f)!=8)return NULL;
  for(j=0;j<8;j++)v[i]|=(uint64_t)b[j]<<(8*j);}
 if(fclose(f))return NULL;
 return v;
}
int main(int argc,char **argv) {
 size_t n,m,image,reloc,head,payload;uint64_t *a,*b,*decoded;
 if(argc!=3)return 2;
 a=load(argv[1],&n);b=load(argv[2],&m);if(!a||!b||n<2||m<4)return 2;
 image=(size_t)(a[1]>>18);reloc=(image+35)/36;
 head=n==2+image+reloc?2:3;
 if(!image||n!=head+image+reloc||m<=3+reloc||
  a[0]!=b[0]||b[1]!=(a[1]|UINT64_C(0100000))||
  (b[2]&0777777)!=0647022||
  (b[2]>>18)!=(head==3?a[2]>>18:0))return 1;
 payload=m-3-reloc;decoded=calloc(image,sizeof(*decoded));if(!decoded)return 2;
 if(d6codec_group_v071_decode(b+3,payload,decoded,image)||
  memcmp(decoded,a+head,image*sizeof(*decoded))||
  memcmp(b+3+payload,a+head+image,reloc*sizeof(*decoded)))return 1;
 printf("PASS v083 grouped DXR image=%zu compressed=%zu reloc=%zu\n",image,payload,reloc);
 free(a);free(b);free(decoded);return 0;
}
