/* Compare userspace-generated D6 codec output with exact source words. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "d6codec-group-v071.h"
static uint64_t *load(const char *path, size_t *count)
{
    FILE *f=fopen(path,"rb");
    uint64_t *words;
    long bytes;
    size_t i;
    if (!f || fseek(f,0,SEEK_END) || (bytes=ftell(f))<0 || bytes%8 || fseek(f,0,SEEK_SET)) return NULL;
    *count=(size_t)bytes/8;
    words=calloc(*count ? *count : 1,sizeof(*words));
    if (!words) return NULL;
    for (i=0;i<*count;i++) {
        unsigned char b[8]; unsigned j;
        if (fread(b,1,8,f)!=8) {free(words);return NULL;}
        for (j=0;j<8;j++) words[i]|=(uint64_t)b[j]<<(8*j);
    }
    if (fclose(f)) {free(words);return NULL;}
    return words;
}
int main(int argc,char **argv)
{
    uint64_t *source,*compressed,*decoded;
    size_t sw,cw;
    int ok;
    if (argc!=3) return 2;
    source=load(argv[1],&sw);compressed=load(argv[2],&cw);
    if (!source||!compressed) return 2;
    decoded=calloc(sw?sw:1,sizeof(*decoded));
    if (!decoded) return 2;
    ok=d6codec_group_v071_decode(compressed,cw,decoded,sw)==0 &&
       memcmp(source,decoded,sw*sizeof(*source))==0;
    printf("%s d6codec-single-v085 extracted parity: input=%zu grouped=%zu words\n",
           ok?"PASS":"FAIL",sw,cw);
    free(decoded);free(compressed);free(source);
    return ok?0:1;
}
