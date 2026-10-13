/* Benchmark lossless compression of compiled DAIMOS DXR word containers. */
#include "codec_v004.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
extern int d6lz_codec_compress(const uint64_t *, size_t, uint64_t **, size_t *);
extern int d6lz_codec_decompress(const uint64_t *, size_t, uint64_t *, size_t);
#define MASK36 UINT64_C(0777777777777)
static unsigned long long counts[4], aligned, unaligned, short_match, encoded_words;
static void profile(const uint64_t *w,size_t n,size_t outn){size_t ip=0,op=0;while(op<outn&&ip<n){size_t j;uint64_t control=w[ip++];for(j=0;j<36&&op<outn&&ip<n;j++){uint64_t t=w[ip++];if(!(control & (UINT64_C(1)<<(35-j)))){op++;continue;}unsigned kind=(unsigned)(t>>34);size_t len=(size_t)((t>>18)&65535U);size_t dist=(size_t)(t&262143U);if(kind>2){fprintf(stderr,"invalid token\n");exit(2);}counts[kind]++;if(kind==2){if(dist&1)unaligned++;else aligned++;if(len<=8)short_match++;op+=len/2;}else op+=len;}}encoded_words+=n;}
static int run(const char *path) {
 FILE *fp;long bytes;size_t n,i,m[3];uint64_t *src,*dst,*encoded[3];int k,rc=1;unsigned char b[8];
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
 for(k=0;k<3;k++){encoded[k]=NULL;m[k]=0;
  if((k==0?d6lz_codec_compress(src,n,&encoded[k],&m[k]):d6v004_encode(src,n,k==2,&encoded[k],&m[k]))||
     (k==0?d6lz_codec_decompress(encoded[k],m[k],dst,n):d6v004_decode(encoded[k],m[k],dst,n))||memcmp(src,dst,n*sizeof(*src))) {
    fprintf(stderr,"codec %d FAILED for %s\n",k,path);free(encoded[k]);src-=header;goto done;
  }
  if(k==2)profile(encoded[k],m[k],n);
  free(encoded[k]);
 }
 printf("%s\t%lu\t%lu\t%lu\t%lu\n",path,(unsigned long)n,(unsigned long)m[0],(unsigned long)m[1],(unsigned long)m[2]);rc=0;
 src-=header;
 }
 done:free(src);free(dst);return rc;
}
int main(int argc,char **argv){int i,failed=0;for(i=1;i<argc;i++)failed+=run(argv[i]);printf("PROFILE word=%llu zero=%llu half=%llu aligned=%llu odd=%llu short_half=%llu compressed_input=%llu\n",counts[0],counts[1],counts[2],aligned,unaligned,short_match,encoded_words);return failed?1:0;}
