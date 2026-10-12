/* C99: exhaustive word-prefix cuts for two-slot intent transitions.
 * Model only: neither barriers nor physical crash recovery are implemented.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define WORDS 128U
#define MASK UINT64_C(0777777777777)
#define MAGIC UINT64_C(064651164217)
#define EMPTY 0U
#define PREPARE 1U
#define COMMIT 2U
static uint64_t slots[2][WORDS], interrupted[WORDS], candidate[WORDS];
static uint64_t checksum(const uint64_t *p)
{
        uint64_t v=UINT64_C(061545612345);
        unsigned i;
        for (i=0;i<11U;i++) {v=((v<<7)|(v>>29))&MASK;v^=p[i];}
        return v&MASK;
}
static void encode(uint64_t *p,unsigned seq,unsigned state)
{
        memset(p,0,WORDS*sizeof(*p));
        p[0]=MAGIC;p[1]=1U;p[2]=seq;p[3]=state;
        p[4]=297U;p[5]=0U;p[6]=42U;p[7]=6U;
        p[8]=UINT64_C(012345670123);p[9]=UINT64_C(076543210765);
        p[11]=checksum(p);
}
static int valid(const uint64_t *p)
{
        unsigned i;
        if(p[0]!=MAGIC||p[1]!=1U||p[2]==0U||p[3]>COMMIT||p[11]!=checksum(p))return 0;
        for(i=0;i<WORDS;i++)if((p[i]&~MASK)!=0U)return 0;
        for(i=12U;i<WORDS;i++)if(p[i]!=0U)return 0;
        return 1;
}
static int selected(const uint64_t *a,const uint64_t *b)
{
        const int va=valid(a),vb=valid(b);
        if(!va&&!vb)return -1;
        if(!va)return 1;
        if(!vb)return 0;
        if(a[2]==b[2])return memcmp(a,b,WORDS*sizeof(*a))?-1:0;
        return a[2]>b[2]?0:1;
}
static int transition(unsigned step,unsigned state)
{
        unsigned cut, target=(step+1U)%2U;
        int winner;
        encode(candidate,step+2U,state);
        for(cut=0U;cut<=WORDS;cut++) {
                memcpy(interrupted,slots[target],sizeof(interrupted));
                memcpy(interrupted,candidate,cut*sizeof(uint64_t));
                winner=target==0U?selected(interrupted,slots[1]):selected(slots[0],interrupted);
                if(winner<0) {
                        fprintf(stderr,"invalid selection step=%u cut=%u\n",step,cut);
                        return 1;
                }
                if(valid(interrupted)&&memcmp(interrupted,slots[target],sizeof(interrupted))!=0&&
                   memcmp(interrupted,candidate,sizeof(interrupted))!=0) {
                        fprintf(stderr,"mixed valid state step=%u cut=%u\n",step,cut);
                        return 2;
                }
        }
        memcpy(slots[target],candidate,sizeof(candidate));
        winner=selected(slots[0],slots[1]);
        if(winner!=(int)target)return 3;
        return 0;
}
int main(void)
{
        unsigned i;
        const unsigned states[]={PREPARE,COMMIT,EMPTY,PREPARE,COMMIT,EMPTY};
        encode(slots[0],1U,EMPTY);
        memset(slots[1],0,sizeof(slots[1]));
        for(i=0;i<sizeof(states)/sizeof(states[0]);i++)
                if(transition(i,states[i])!=0)return 1;
        /* This selector cannot prove that underlying metadata was published;
         * a valid COMMIT record by itself is not sufficient for replay. */
        printf("PASS: six alternating intent transitions, 774 prefix cuts\n");
        return 0;
}
