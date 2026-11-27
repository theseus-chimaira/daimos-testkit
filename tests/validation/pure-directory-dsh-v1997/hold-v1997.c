/* A real unmarked child with substantial BSS and an exact pipe wait. */
#include "dsys.h"
#ifndef HOLD_WORDS
#define HOLD_WORDS 6144U
#endif
static volatile kword_t data[HOLD_WORDS];
int main(void)
{
        kword_t word=0UL;
        data[0]=012345670123UL;
        data[HOLD_WORDS-1U]=076543210765UL;
        if(dsys_read_words(0,&word,1U)!=0) return 1;
        if(data[0]!=012345670123UL || data[HOLD_WORDS-1U]!=076543210765UL) return 2;
        return 57;
}
