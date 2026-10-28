/* Native-host C99 calendar vectors; production converter is linked as-is. */
#include "time1858.h"
#include <stdio.h>
static int check(unsigned int y,unsigned int m,unsigned int day,
                 unsigned int h,unsigned int min,unsigned int s,
                 kword_t expected)
{
    struct time1858_utc in={y,m,day,h,min,s},out;
    kword_t value=0UL;
    if (time1858_encode(&in,&value)!=0 || value!=expected ||
        time1858_decode(value,&out)!=0 ||
        out.year!=y || out.month!=m || out.day!=day ||
        out.hour!=h || out.minute!=min || out.second!=s) {
        fprintf(stderr,"time1858 failed %u-%u-%u: got %lu expected %lu\n",
                y,m,day,(unsigned long)value,(unsigned long)expected);
        return 1;
    }
    return 0;
}
int main(void)
{
    struct time1858_utc invalid={1900U,2U,29U,0U,0U,0U};
    kword_t t=0;
    int failures=0;
    failures+=check(1858U,11U,17U,0U,0U,0U,0UL);
    failures+=check(1858U,11U,18U,0U,0U,0U,86400UL);
    failures+=check(1970U,1U,1U,0U,0U,0U,TIME1858_UNIX_OFFSET);
    failures+=check(2000U,2U,29U,23U,59U,59U,4458585599UL);
    if (time1858_encode(&invalid,&t)==0) ++failures;
    invalid.year=2000U;
    if (time1858_encode(&invalid,&t)!=0) ++failures;
    printf("time1858-v614: %s\n",failures?"FAIL":"PASS");
    return failures?1:0;
}
