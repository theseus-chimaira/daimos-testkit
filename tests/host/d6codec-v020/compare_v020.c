/* C99: compare v006 paired streams with/without odd halfword distances. */
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../d6codec-v006/codec_v006.h"
extern int d6v020_encode(const uint64_t *, size_t, uint64_t **, size_t *);
#define MASK36 UINT64_C(0777777777777)
static int measure(const char *path, size_t *nw, size_t *normal, size_t *even) {
 FILE *fp=fopen(path,"rb"); uint64_t *src=NULL,*out=NULL,*a=NULL,*b=NULL;long bytes;size_t n,i,h,reloc;unsigned char buf[8];int rc=1;
 if(!fp)return -1;
 if(fseek(fp,0,SEEK_END)||(bytes=ftell(fp))<0||(bytes%8)!=0||fseek(fp,0,SEEK_SET))goto done;
 n=(size_t)bytes/8;src=calloc(n?n:1,sizeof(*src));if(!src)goto done;
 for(i=0;i<n;i++){unsigned j;if(fread(buf,1,8,fp)!=8)goto done;for(j=0;j<8;j++)src[i]|=(uint64_t)buf[j]<<(j*8);if(src[i]&~MASK36)goto done;}
 if(n<3)goto done;
 h=2;reloc=((size_t)(src[1]>>18)+35)/36;
 if(n==3+(size_t)(src[1]>>18)+reloc)h=3;
 else if(n!=2+(size_t)(src[1]>>18)+reloc)goto done;
 n=(size_t)(src[1]>>18);out=calloc(n?n:1,sizeof(*out));if(!out)goto done;
 if(d6v006_encode(src+h,n,&a,normal)||d6v020_encode(src+h,n,&b,even))goto done;
 if(d6v006_decode(a,*normal,out,n)||memcmp(out,src+h,n*sizeof(*out)))goto done;
 memset(out,0,n*sizeof(*out));
 if(d6v006_decode(b,*even,out,n)||memcmp(out,src+h,n*sizeof(*out)))goto done;
 *nw=n;rc=0;
 done:if(fp)fclose(fp);free(src);free(out);free(a);free(b);return rc;
}
int main(int argc,char **argv) {size_t sum=0,normal=0,even=0;int i,ok=0,bad=0;for(i=1;i<argc;i++){size_t w=0,a=0,b=0;int rc=measure(argv[i],&w,&a,&b);if(rc){bad++;continue;}printf("%s\t%zu\t%zu\t%zu\t%ld\n",argv[i],w,a,b,(long)b-(long)a);sum+=w;normal+=a;even+=b;ok++;}fprintf(stderr,"TOTAL files=%d rejected=%d words=%zu original=%zu even=%zu delta=%ld\n",ok,bad,sum,normal,even,(long)even-(long)normal);return bad?1:0;}
