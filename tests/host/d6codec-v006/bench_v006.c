/* Benchmark lossless compression of compiled DAIMOS DXR word containers. */
#include "codec_v006.h"
#include "../d6codec-v004/codec_v004.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
extern int d6lz_codec_compress(const uint64_t *, size_t, uint64_t **, size_t *);
extern int d6lz_codec_decompress(const uint64_t *, size_t, uint64_t *, size_t);
#define MASK36 UINT64_C(0777777777777)
static int run(const char *path) {
 FILE *fp;long bytes;size_t n,i,m[4];uint64_t *src,*dst,*encoded[4];int k,rc=1;unsigned char b[8];
 fp=fopen(path,"rb");if(!fp){perror(path);return 1;}
 if(fseek(fp,0,SEEK_END)|| (bytes=ftell(fp))<0 || (bytes%8)!=0 || fseek(fp,0,SEEK_SET)){fclose(fp);return 1;}
 n=(size_t)(bytes/8);src=(uint64_t *)calloc(n?n:1,sizeof(*src));dst=(uint64_t *)calloc(n?n:1,sizeof(*dst));
 if(!src||!dst){fclose(fp);free(src);free(dst);return 1;}
 for(i=0;i<n;i++){unsigned j;if(fread(b,1,8,fp)!=8)break;for(j=0;j<8;j++)src[i]|=(uint64_t)b[j]<<(8*j);if(src[i]&~MASK36)break;}
 fclose(fp);if(i!=n){fprintf(stderr,"invalid DXR container: %s\n",path);goto done;}
 {size_t image, reloc, header;uint64_t dxr=((uint64_t)('D'-32)<<12)|((uint64_t)('X'-32)<<6)|(uint64_t)('R'-32);uint64_t tx2=((uint64_t)('T'-32)<<12)|((uint64_t)('X'-32)<<6)|(uint64_t)('2'-32);
 if(n<2 || ((src[0]>>18)&262143U)!=dxr) goto done;
 image=(size_t)(src[1]>>18);reloc=(image+35)/36;
 if(n==2+image+reloc)header=2;else if(n==3+image+reloc && (src[2]&262143U)==tx2)header=3;else goto done;
 if(!image)goto done;
 src+=header;n=image;
 for(k=0;k<4;k++){encoded[k]=NULL;m[k]=0;
  if((k==0?d6lz_codec_compress(src,n,&encoded[k],&m[k]):k==3?d6v006_encode(src,n,&encoded[k],&m[k]):d6v004_encode(src,n,k==2,&encoded[k],&m[k]))||
     (k==0?d6lz_codec_decompress(encoded[k],m[k],dst,n):k==3?d6v006_decode(encoded[k],m[k],dst,n):d6v004_decode(encoded[k],m[k],dst,n))||memcmp(src,dst,n*sizeof(*src))) {
    fprintf(stderr,"codec %d FAILED for %s\n",k,path);free(encoded[k]);goto done;
  }
  free(encoded[k]);
 }
 printf("%s\t%lu\t%lu\t%lu\t%lu\t%lu\n",path,(unsigned long)n,(unsigned long)m[0],(unsigned long)m[1],(unsigned long)m[2],(unsigned long)m[3]);rc=0;
 src-=header;
 }
 done:free(src);free(dst);return rc;
}
int main(int argc,char **argv){int i,failed=0;puts("file\twords\td6lz36\tv003-word\tv003-half\tv006-paired");for(i=1;i<argc;i++)failed+=run(argv[i]);return failed?1:0;}
