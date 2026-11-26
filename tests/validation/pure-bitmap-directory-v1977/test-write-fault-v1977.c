/* Inject a late error after real stores. The wrapper must not convert
 * it to success or a normal refusal, even if the stores completed. */
#include "proc_pure_bitmap_directory_v1977.h"
kword_t __test_exit;
int main(void)
{
        kword_t *raw = (kword_t *)020000UL;
        kword_t *packed = (kword_t *)030000UL;
        kword_t count;
        unsigned int i;
        for (i=0U;i<37U;++i) raw[i]=0UL;
        raw[0]=1UL;
        if (pbmd_encode_v1977(020000UL,37UL,030000UL,37UL,0U,&count)
            != PBMD_WRITE_FAULT_V1977 || count!=3UL || packed[0]!=0400000000000UL ||
            packed[1] || packed[2]!=1UL) return 1;
        raw[0]=0UL;
        if (pbmd_decode_v1977(030000UL,3UL,020000UL,37UL,1U)
            != PBMD_WRITE_FAULT_V1977 || raw[0]!=1UL) return 2;
        return 0;
}
