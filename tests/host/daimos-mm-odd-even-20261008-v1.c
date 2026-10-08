/* Host-only model of PDP-6 36-bit spans and paired 18-bit metadata.
 * Test the difficult part: shifts through odd/even pair boundaries. */
#include <stdint.h>
#include <stdio.h>
#define CAP 32U
#define HALF 0777777UL
static uint64_t spans[CAP];
static uint64_t metadata[(CAP+1U)/2U];
static unsigned count;
static unsigned failures;
static uint64_t reference_spans[CAP];
static unsigned reference_meta[CAP];
static unsigned get(unsigned i);
static void verify(void) {
    unsigned i;
    for (i=0;i<count;++i)
        if (spans[i]!=reference_spans[i] || get(i)!=reference_meta[i]) ++failures;
}

static unsigned get(unsigned i) {
    return (unsigned)((metadata[i/2U] >> ((i&1U)?0U:18U)) & HALF);
}
static void put(unsigned i, unsigned v) {
    const unsigned shift=(i&1U)?0U:18U;
    const uint64_t mask=(uint64_t)HALF << shift;
    metadata[i/2U]=(metadata[i/2U]&~mask)|((uint64_t)(v&HALF)<<shift);
}
static int insert(unsigned pos,uint64_t span,unsigned meta) {
    unsigned i;
    if(pos>count || count==CAP || (span>>36)!=0 || meta>HALF) return -1;
    for(i=count;i>pos;--i) { spans[i]=spans[i-1U]; put(i,get(i-1U)); }
    for(i=count;i>pos;--i) { reference_spans[i]=reference_spans[i-1U]; reference_meta[i]=reference_meta[i-1U]; }
    reference_spans[pos]=span; reference_meta[pos]=meta;
    spans[pos]=span; put(pos,meta); ++count; verify(); return 0;
}
static int erase(unsigned pos) {
    unsigned i;
    if(pos>=count) return -1;
    for(i=pos;i+1U<count;++i) { spans[i]=spans[i+1U]; put(i,get(i+1U)); }
    for(i=pos;i+1U<count;++i) { reference_spans[i]=reference_spans[i+1U]; reference_meta[i]=reference_meta[i+1U]; }
    --count; put(count,0U); verify(); return 0;
}
int main(void) {
    unsigned round,i,j,p,m;
    uint64_t span;
    for(round=0;round<2000U;++round) {
        for(i=0;i<CAP;++i) {
            p=(i*13U+round)% (count+1U);
            span=((uint64_t)(round+i+1U)<<18) | (round^i);
            m=(round*17U+i*31U)&HALF;
            if(insert(p,span,m)) return 1;
        }
        for(j=0;j<CAP;++j) {
            p=(j*7U+round)%count;
            if(erase(p)) return 2;
        }
        if(count!=0U) ++failures;
        for(i=0;i<(CAP+1U)/2U;++i) if(metadata[i]!=0U) ++failures;
    }
    if(failures) return 3;
    printf("PASS odd/even insertion/deletion: %u cycles, %u slots, zero stale metadata\n",round,CAP);
    printf("TABLE: spans %u words + metadata %u words = %u words (baseline %u)\n",CAP,(CAP+1U)/2U,CAP+(CAP+1U)/2U,2U*CAP);
    return 0;
}
