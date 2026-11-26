/* Independent canonical directory construction and per-word read ledger.
 * Run against actual 36-bit native codec, check entire physical arena.
 */
#include "proc_pure_bitmap_directory_v1977.h"
#define BASE 020000UL
#define ARENA 0600UL
#define SRC (BASE + 0140UL)
#define LIMIT 109U
#define GUARD 0123456701234UL

kword_t __test_exit;
kword_t diag_raw_v1977, diag_pattern_v1977, diag_delta_v1977;
kword_t diag_direction_v1977, diag_rc_v1977, diag_expected_v1977;
kword_t diag_cases_v1977, diag_good_v1977, diag_refused_v1977;
kword_t diag_nogain_v1977, diag_reverse_only_v1977;
kword_t diag_reverse_encode_v1977, diag_both_unsafe_v1977;
static kword_t before[ARENA], expected[LIMIT], packed[LIMIT+4U];
static unsigned int unread[LIMIT+4U], ranks[LIMIT];
static kword_t *const arena = (kword_t *)BASE;
static kword_t *const source = (kword_t *)SRC;

static kword_t
sample(unsigned int i, unsigned int n, unsigned int p)
{
        if (p == 0U || (p == 1U && i % 5U) ||
            (p == 2U && i >= n/2U) || (p == 3U && i < n/2U) ||
            (p == 4U && i != 0U && i != 35U && i != 36U) ||
            (p == 6U && i % 36U == 35U) ||
            (p == 7U && i % 36U != 0U))
                return 0UL;
        return ((kword_t)1UL << 35U) | (i+1U);
}

static unsigned int
reference(unsigned int n, unsigned int p)
{
        unsigned int i, g = (n+35U)/36U, l = g;
        for (i=0U; i<g; ++i) packed[i]=0UL;
        for (i=0U; i<n; ++i) {
                expected[i]=sample(i,n,p);
                ranks[i]=l;
                if (expected[i]) {
                        packed[i/36U] |= (kword_t)1UL << (35U-i%36U);
                        packed[l++]=expected[i];
                }
        }
        return l;
}

static void
reset(const kword_t *data, unsigned int count)
{
        unsigned int i;
        for (i=0U; i<ARENA; ++i) arena[i]=GUARD;
        for (i=0U; i<count; ++i) source[i]=data[i];
        for (i=0U; i<ARENA; ++i) before[i]=arena[i];
}

static int
check(kword_t target, unsigned int count, const kword_t *data)
{
        unsigned int i;
        for (i=0U; i<ARENA; ++i) {
                kword_t a=BASE+i;
                if (arena[i] != ((a>=target && a<target+count) ?
                    data[a-target] : before[i])) return 0;
        }
        return 1;
}

/* The oracle does not use cursor interval arithmetic. Mark each actual
 * input word consumed, then ask if each store targets a still-live word.
 * Literal ranks are computed independently from the original RAW data.
 */
static int
live(kword_t address, unsigned int count)
{
        return address >= SRC && address < SRC+count && unread[address-SRC];
}

static int
safe(unsigned int n, unsigned int c, kword_t target,
    unsigned int rev, unsigned int decode)
{
        unsigned int i,k,rank,srcn=decode?c:n;
        unsigned int index, group, lastgroup=~0U;
        int ok=1;
        for (i=0U;i<srcn;++i) unread[i]=1U;
        for (k=0U;k<n;++k) {
                index=rev?n-1U-k:k;
                group=index/36U;
                if (decode && lastgroup!=group) unread[group]=0U;
                rank=ranks[index];
                if (decode) {
                        if (expected[index]) unread[rank]=0U;
                        if (live(target+index,srcn)) ok=0;
                } else {
                        unread[index]=0U;
                        if (expected[index] && live(target+rank,srcn)) ok=0;
                        if (k+1U==n || (rev?index%36U==0U:index%36U==35U))
                                if (live(target+group,srcn)) ok=0;
                }
                lastgroup=group;
        }
        return ok;
}

int
main(void)
{
        static const unsigned int lengths[]={1U,2U,35U,36U,37U,71U,72U,73U,109U};
        static const int shifts[]={-80,-37,-2,-1,0,1,2,18,37,80,110};
        unsigned int i,p,d,rev,n,c,side;
        kword_t target,count,plan;
        int rc,want,prc;
        for(i=0U;i<sizeof(lengths)/sizeof(lengths[0]);++i) {
                n=lengths[i]; diag_raw_v1977=n;
                for(p=0U;p<8U;++p) {
                        diag_pattern_v1977=p; c=reference(n,p);
                        for(d=0U;d<=sizeof(shifts)/sizeof(shifts[0]);++d) {
                                for(rev=0U;rev<2U;++rev) {
                                        /* The final geometry aligns both span ends. */
                                        target=d<sizeof(shifts)/sizeof(shifts[0]) ?
                                            SRC+shifts[d] : SRC+(long)n-(long)c;
                                        diag_delta_v1977=target-SRC;
                                        diag_direction_v1977=rev;
                                        reset(expected,n); count=plan=GUARD;
                                        want=c>=n?PBM_NO_GAIN_V1975:
                                            (safe(n,c,target,rev,0U)?MM_OK:PBM_OVERLAP_V1975);
                                        prc=pbmd_plan_encode_v1977(SRC,n,target,c,rev,&plan);
                                        if(prc!=want || plan!=(want==MM_OK?c:GUARD) ||
                                            !check(0UL,0U,packed)) return 1;
                                        rc=pbmd_encode_v1977(SRC,n,target,c,rev,&count);
                                        diag_rc_v1977=rc; diag_expected_v1977=want;
                                        ++diag_cases_v1977;
                                        if(rc!=want || count!=plan ||
                                            !check(target,rc==MM_OK?c:0U,packed)) return 2;
                                        if(rc==PBM_NO_GAIN_V1975) { ++diag_nogain_v1977; continue; }
                                        if(rc==MM_OK) {
                                                ++diag_good_v1977;
                                                if(rev && !safe(n,c,target,0U,0U)) ++diag_reverse_encode_v1977;
                                        } else {
                                                ++diag_refused_v1977;
                                                if(rev && !safe(n,c,target,0U,0U)) ++diag_both_unsafe_v1977;
                                        }
                                        reset(packed,c);
                                        target=d<sizeof(shifts)/sizeof(shifts[0]) ?
                                            SRC+shifts[d] : SRC+(long)c-(long)n;
                                        diag_delta_v1977=target-SRC;
                                        want=safe(n,c,target,rev,1U)?MM_OK:PBM_OVERLAP_V1975;
                                        rc=pbmd_decode_v1977(SRC,c,target,n,rev);
                                        diag_rc_v1977=rc; diag_expected_v1977=want;
                                        ++diag_cases_v1977;
                                        if(rc!=want || !check(target,rc==MM_OK?n:0U,expected)) return 3;
                                        if(rc==MM_OK) {
                                                ++diag_good_v1977;
                                                if(rev && !safe(n,c,target,0U,1U)) ++diag_reverse_only_v1977;
                                        } else {
                                                ++diag_refused_v1977;
                                                if(rev && !safe(n,c,target,0U,1U)) ++diag_both_unsafe_v1977;
                                        }
                                }
                        }
                }
        }
        /* Independent invalid geometry, exact capacity and canonical cases. */
        c=reference(37U,4U);
        for(rev=0U;rev<2U;++rev) {
                c=reference(37U,4U);
                reset(expected,37U); count=GUARD;
                if(pbmd_encode_v1977(SRC,37UL,SRC+110UL,c-1U,rev,&count)!=MM_ERR_NOMEM ||
                    count!=GUARD || !check(0UL,0U,expected)) return 4;
                for(side=0U;side<4U;++side) {
                        c=reference(37U,4U);
                        if(side==0U) packed[1]|=1UL; /* unused partial-mask bit */
                        if(side==1U) packed[2]=0UL; /* zero literal */
                        if(side==2U) --c; /* truncated stream */
                        if(side==3U) packed[c++]=1UL; /* extra literal */
                        reset(packed,c);
                        if(pbmd_decode_v1977(SRC,c,SRC,37UL,rev)!=MM_ERR_INVAL ||
                            !check(0UL,0U,expected)) return 5;
                }
                if(pbmd_decode_v1977(SRC,1UL,SRC,37UL,rev)!=MM_ERR_INVAL ||
                    pbmd_decode_v1977(0777777UL,2UL,SRC,37UL,rev)!=MM_ERR_INVAL ||
                    pbmd_encode_v1977(SRC,37UL,0777777UL,2UL,rev,&count)!=MM_ERR_INVAL ||
                    pbmd_plan_encode_v1977(SRC,37UL,SRC,37UL,rev,0)!=MM_ERR_INVAL ||
                    pbmd_decode_v1977(017UL,2UL,SRC,37UL,rev)!=MM_ERR_INVAL ||
                    pbmd_encode_v1977(SRC,37UL,017UL,37UL,rev,&count)!=MM_ERR_INVAL) return 6;
        }
        if(pbmd_decode_v1977(SRC,2UL,SRC,37UL,2U)!=MM_ERR_INVAL ||
            pbmd_encode_v1977(SRC,37UL,SRC,37UL,2U,&count)!=MM_ERR_INVAL ||
            !diag_reverse_only_v1977 || !diag_reverse_encode_v1977 ||
            !diag_both_unsafe_v1977 || !diag_good_v1977 || !diag_refused_v1977) return 7;
        /* Large zero-filled image: 146 directory words, not just 1..4.
         * Exact in-place forward compression and reverse expansion. */
        {
                kword_t *large = (kword_t *)040000UL;
                kword_t *other = (kword_t *)060000UL;
                unsigned int k;
                for (k=0U;k<5248U;++k) large[k]=0UL;
                large[5248]=GUARD;
                count=GUARD;
                if (pbmd_encode_v1977(040000UL,5248UL,040000UL,5248UL,0U,&count)!=MM_OK ||
                    count!=146UL || large[5248]!=GUARD) return 010;
                if (pbmd_decode_v1977(040000UL,count,040000UL,5248UL,0U)!=PBM_OVERLAP_V1975 ||
                    pbmd_decode_v1977(040000UL,count,040000UL,5248UL,1U)!=MM_OK) return 011;
                for (k=0U;k<5248U;++k) if (large[k]) return 012;
                if (large[5248]!=GUARD) return 013;
                /* Large sparse stream, reverse encoder -> forward decoder;
                 * verify exact mask and literal order independently. */
                for (k=0U;k<5248U;++k) {
                        large[k]=k%36U==0U?(kword_t)k+1UL:0UL;
                        other[k]=GUARD;
                }
                other[5248]=GUARD;
                if (pbmd_encode_v1977(040000UL,5248UL,060000UL,5248UL,1U,&count)!=MM_OK ||
                    count!=292UL) return 014;
                for (k=0U;k<146U;++k)
                        if (other[k]!=0400000000000UL || other[146U+k]!=(kword_t)k*36UL+1UL)
                                return 015;
                for (k=292U;k<=5248U;++k) if (other[k]!=GUARD) return 016;
                if (pbmd_decode_v1977(060000UL,count,040000UL,5248UL,0U)!=MM_OK) return 017;
                for (k=0U;k<5248U;++k)
                        if (large[k]!=(k%36U==0U?(kword_t)k+1UL:0UL)) return 020;
                if (large[5248]!=GUARD || other[5248]!=GUARD) return 021;
        }
        return 0;
}
