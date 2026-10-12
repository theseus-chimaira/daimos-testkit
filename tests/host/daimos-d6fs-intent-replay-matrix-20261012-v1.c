/* C99 abstract D6FS create recovery decision matrix.
 * Deliberately refuses unsafe replay when commit metadata is incomplete.
 */
#include <stdio.h>

enum phase { EMPTY, PREPARE, COMMIT };
enum decision { NOOP, ROLLFORWARD, INVESTIGATE };
struct image {
        enum phase intent;
        int child_fcb;
        int child_data;
        int parent_extent;
        int dirent;
        int parent_size;
};
static enum decision decide(struct image s)
{
        /* A transaction cannot be forgotten while any unreferenced metadata
         * remains durable. No write return proves rollback safety. */
        if (s.intent == EMPTY)
                return s.child_fcb || s.dirent ? INVESTIGATE : NOOP;
        if (s.intent == PREPARE)
                return INVESTIGATE; /* must inspect FCB and directory identity */
        if (!s.child_fcb || !s.child_data || !s.parent_extent)
                return INVESTIGATE;
        if (!s.dirent || !s.parent_size)
                return INVESTIGATE;
        return ROLLFORWARD; /* only if identity matches the durable intent */
}
int main(void)
{
        unsigned state, mask, examined=0U, uncertain=0U, committed=0U;
        for (state=EMPTY;state<=COMMIT;++state)
                for (mask=0;mask<32U;++mask) {
                        struct image s;
                        enum decision d;
                        s.intent=(enum phase)state;
                        s.child_fcb=(mask&1U)!=0U;
                        s.child_data=(mask&2U)!=0U;
                        s.parent_extent=(mask&4U)!=0U;
                        s.dirent=(mask&8U)!=0U;
                        s.parent_size=(mask&16U)!=0U;
                        d=decide(s);
                        ++examined;
                        if (d==INVESTIGATE)++uncertain;
                        if (d==ROLLFORWARD) {
                                ++committed;
                                if (state!=COMMIT || mask!=31U)return 1;
                        }
                        if (d==NOOP && (state!=EMPTY || s.child_fcb || s.dirent))return 2;
                }
        if (examined!=96U || committed!=1U)return 3;
        printf("PASS: %u state/metadata cases; %u require investigation, %u safely committed\n",
               examined,uncertain,committed);
        return 0;
}
