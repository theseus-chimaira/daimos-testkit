#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "d6codec-group-v071.h"
static int read_file(const char *name,uint64_t *buf,size_t max,size_t *num)
{
    FILE *f=fopen(name,"rb");size_t n;
    if(!f)return -1;
    n=fread(buf,sizeof(*buf),max,f);
    if(ferror(f)||fgetc(f)!=EOF||fclose(f))return -1;
    *num=n;return 0;
}
int main(int argc,char **argv)
{
    uint64_t packed[256],expected[128],actual[128];size_t p,e,i;
    if(argc!=3||read_file(argv[1],packed,256,&p)||
        read_file(argv[2],expected,128,&e)||
        d6codec_group_v071_decode(packed,p,actual,e))return 1;
    for(i=0;i<e;i++)if(actual[i]!=expected[i])return 1;
    puts("PASS TXG payload decodes into original 80 words");return 0;
}
