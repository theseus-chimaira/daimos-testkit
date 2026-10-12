/* C99 host-only intent identity validation. Never guesses a conflicting write. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define W36 UINT64_C(0777777777777)
enum state { ABSENT, MATCH, CONFLICT };
enum verdict { SAFE_EMPTY, ALREADY_PUBLISHED, NEED_INSPECTION };
struct identity {
        uint32_t child, parent, slot;
        uint64_t name[4];
        uint32_t type;
};
static int equal(const struct identity *a, const struct identity *b)
{
        unsigned i;
        if (a->child!=b->child || a->parent!=b->parent ||
            a->slot!=b->slot || a->type!=b->type)return 0;
        for(i=0;i<4U;i++)
                if ((a->name[i]&W36)!=(b->name[i]&W36))return 0;
        return 1;
}
static enum verdict decide(enum state fcb, enum state entry,
                           int parent_visible)
{
        if (fcb==CONFLICT || entry==CONFLICT)return NEED_INSPECTION;
        if (fcb==ABSENT && entry==ABSENT)return SAFE_EMPTY;
        if (fcb==MATCH && entry==MATCH && parent_visible)
                return ALREADY_PUBLISHED;
        return NEED_INSPECTION;
}
int main(void)
{
        struct identity a={297U,0U,42U,{1U,2U,3U,4U},1U};
        struct identity b=a;
        unsigned f,d,p,checked=0U,unknown=0U;
        if(!equal(&a,&b))return 1;
        b.name[3]^=1U;
        if(equal(&a,&b))return 2;
        b=a;b.parent++;
        if(equal(&a,&b))return 3;
        for(f=0;f<3U;f++)for(d=0;d<3U;d++)for(p=0;p<2U;p++) {
                enum verdict v=decide((enum state)f,(enum state)d,(int)p);
                ++checked;
                if(v==NEED_INSPECTION)++unknown;
                if(v==SAFE_EMPTY && (f!=0U || d!=0U))return 4;
                if(v==ALREADY_PUBLISHED && (f!=1U || d!=1U || p!=1U))return 5;
        }
        if(checked!=18U || unknown!=15U)return 6;
        puts("PASS: 18 identity-state cases, 15 conservative unresolved; name/parent mismatches rejected");
        return 0;
}
