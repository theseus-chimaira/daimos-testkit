/* D6 codec v003 experimental word/halfword bitmap codec. C99. */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include "codec_v003.h"
#define MASK36 UINT64_C(0777777777777)
#define MASK18 UINT64_C(0777777)
#define MAXLEN 65535U
static uint64_t half(const uint64_t *p, size_t i) { return (p[i/2] >> ((i&1U)?0:18)) & MASK18; }
static void sethalf(uint64_t *p,size_t i,uint64_t v) { if(i&1U) p[i/2]=(p[i/2]&~MASK18)|v; else p[i/2]=(p[i/2]&MASK18)|(v<<18); }
static uint64_t desc(unsigned kind,size_t len,size_t dist) { return ((uint64_t)kind<<34)|((uint64_t)len<<18)|(uint64_t)dist; }
int d6v003_decode(const uint64_t *in,size_t ni,uint64_t *out,size_t no) {
 size_t ip=0,op=0,j; unsigned remaining=0;uint64_t ctrl=0;
 if((ni && !in)||(no && !out))return -1;
 while(op<no){uint64_t t;unsigned kind;size_t len,dist;
  if(!remaining){if(ip==ni)return -1;ctrl=in[ip++];if(ctrl &~MASK36)return -1;remaining=36;}
  if(ip==ni)return -1;
  t=in[ip++];
  if(t&~MASK36)return -1;
  if(!(ctrl & (UINT64_C(1)<<35))){out[op++]=t;}
  else {kind=(unsigned)(t>>34);len=(size_t)((t>>18)&65535U);dist=(size_t)(t&262143U);
   if(!len)return -1;
   if(kind==0){if(!dist||dist>op||len>no-op)return -1;for(j=0;j<len;j++){out[op]=out[op-dist];op++;}}
   else if(kind==1){if(dist||len>no-op)return -1;for(j=0;j<len;j++)out[op++]=0;}
   else if(kind==2){size_t h=op*2;if(!dist||dist>h||len>2*(no-op)|| (len&1U))return -1;for(j=0;j<len/2;j++)out[op+j]=0;
    for(j=0;j<len;j++)sethalf(out,h+j,half(out,h+j-dist));
    op+=len/2;}
   else return -1;
  }
  ctrl<<=1;remaining--;
 }
 return ip==ni?0:-1;
}
int d6v003_encode(const uint64_t *in,size_t n,int use_half,uint64_t **outp,size_t *outn){
 uint64_t *out;size_t pos=0,op=0,cap;
 if(!outp||!outn||(n&&!in)||n>(SIZE_MAX-64)/2)return -1;
 cap=n+(n+35)/36+2;out=(uint64_t *)malloc(cap*sizeof(*out));if(!out)return -1;
 while(pos<n){size_t cp=op++,i;uint64_t ctrl=0;
  for(i=0;i<36&&pos<n;i++) {size_t best=0,bd=0,d,l,lim=n-pos;unsigned kind=0;
   if(lim>MAXLEN)lim=MAXLEN;
   for(l=0;l<lim && in[pos+l]==0;l++);
   if(l>=2){best=l;kind=1;}
   for(d=1;d<=128&&d<=pos;d++){for(l=0;l<lim&&in[pos+l]==in[pos+l-d];l++);if(l>=3&&l>best){best=l;bd=d;kind=0;}}
   if(use_half){size_t h=pos*2, hd,hl, hlim=lim*2; if(hlim>65534)hlim=65534;
    for(hd=1;hd<=256&&hd<=h;hd++){for(hl=0;hl<hlim&&half(in,h+hl)==half(in,h+hl-hd);hl++);hl &= ~(size_t)1;
     if(hl>=4&&hl/2>best){best=hl/2;bd=hd;kind=2;}}
   }
   if(best){ctrl|=UINT64_C(1)<<(35-i);out[op++]=desc(kind,kind==2?best*2:best,kind==1?0:bd);pos+=best;}
   else {if(in[pos]&~MASK36){free(out);return -1;}out[op++]=in[pos++];}
  }
  out[cp]=ctrl;
 }
 *outp=out;*outn=op;return 0;
}
