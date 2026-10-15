/* C99 independent new-format TSFS host adapter regression. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "d6lz-codec.h"
int main(void)
{
    uint64_t input[650], output[650], *encoded=NULL;
    size_t i,n=0;
    for(i=0;i<650;i++)
        input[i]=(i%19==0) ? 0 : (i%17<7 ? UINT64_C(012345670123) : (uint64_t)(i*1187+13));
    if(d6lz_codec_compress(input,650,&encoded,&n) || !encoded || !n)
        return 1;
    if(d6lz_codec_decompress(encoded,n,output,650))return 2;
    for(i=0;i<650;i++)if(input[i]!=output[i])return 3;
    free(encoded);
    printf("PASS v082 grouped TSFS adapter 650 -> %zu words -> 650\n",n);
    return 0;
}
