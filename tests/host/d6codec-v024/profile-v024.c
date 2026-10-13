/* C99 profile of native word-match search distance potential.
 * Reuses the proven v006 compressor, analyzes valid paired descriptors.
 */
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../d6codec-v006/codec_v006.h"
#define MASK36 UINT64_C(0777777777777)
static unsigned long long hist[5], matchwords[5], inputwords;
static unsigned long long kindcounts[4];
static int profile(const char *path){
 FILE *fp=fopen(path,"rb");long bytes;size_t n,i,h,r,ip,op;uint64_t *src=NULL,*enc=NULL;unsigned char b[8];int result=1;
 if(!fp)return 1;
 if(fseek(fp,0,SEEK_END)||(bytes=ftell(fp))<0||(bytes%8)!=0||fseek(fp,0,SEEK_SET))goto end;
 n=(size_t)bytes/8;src=calloc(n?n:1,sizeof(*src));if(!src)goto end;
 for(i=0;i<n;i++){unsigned j;if(fread(b,1,8,fp)!=8)goto end;for(j=0;j<8;j++)src[i]|=(uint64_t)b[j]<<(j*8);if(src[i]&~MASK36)goto end;}
 if(n<3)goto end;
 h=2;r=((size_t)(src[1]>>18)+35)/36;
 if(n==3+(size_t)(src[1]>>18)+r)h=3;
 else if(n!=2+(size_t)(src[1]>>18)+r)goto end;
 n=(size_t)(src[1]>>18);inputwords+=n;
 if(d6v006_encode(src+h,n,&enc,&r))goto end;
 ip=0;op=0;
 while(ip<r){uint64_t ctrl=enc[ip++],flags=ctrl&((UINT64_C(1)<<30)-1);size_t count=(size_t)(ctrl>>30),nm=0,di,li,j;
  for(j=0;j<count;j++)if(flags&(UINT64_C(1)<<(29-j)))nm++;
  di=ip;li=ip+(nm+1)/2;
  for(j=0;j<count;j++){
   if(flags&(UINT64_C(1)<<(29-j))){uint64_t t;size_t z=di-ip;unsigned k;size_t len,dist;
    t=enc[ip+z/2];t=(z&1)?t&0777777:t>>18;di++;
    k=(unsigned)(t>>16);len=(size_t)((t>>9)&0177);dist=(size_t)(t&0777);
    if(k>3)goto end;
    kindcounts[k]++;
    if(k==0){unsigned bin=dist==1?0:dist<=8?1:dist<=32?2:dist<=128?3:4;hist[bin]++;matchwords[bin]+=len;}
    op+=len;
   }else{li++;op++;}
  }
  ip=li;
 }
 result=0;
 end:fclose(fp);free(src);free(enc);return result;
}
int main(int argc,char **argv){int i,ok=0;for(i=1;i<argc;i++){if(profile(argv[i])){fprintf(stderr,"FAILED %s\n",argv[i]);return 1;}ok++;}printf("files=%d source_words=%llu word_matches=%llu half_matches=%llu zero_matches=%llu\n",ok,inputwords,kindcounts[0],kindcounts[2],kindcounts[1]);for(i=0;i<5;i++){const char *names[]={"1","2-8","9-32","33-128","129-511"};printf("distance=%s matches=%llu represented_words=%llu\n",names[i],hist[i],matchwords[i]);}return 0;}
