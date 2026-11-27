/* Host arithmetic oracle for the original source-extracted escrow
 * helpers. No MM or physical-memory authority is simulated here. */
#include <stdio.h>
#include "proc_pure_full_escrow_v1989.h"

static kword_t area[0410];
struct pbr_identity_v1980 {
        kword_t uarea, brk, escrow;
};
#define PRAM_PTR(x) (area)
#define MM_HALF_MASK 0777777UL
#include "layout-v1989.inc"

int main(void)
{
        struct pbr_identity_v1980 id;
        kword_t count, index, phase, src, floor, current, words, brk, field;
        unsigned long cases = 0;
        /* All length/target/phase combinations; cycle independently
         * through every physical source sector and legal heap shape.
         * Includes the 15th length bit and both address endpoints. */
        for(count=1;count<=040000UL;++count)
                for(index=0;index<=0377UL;++index)
                        for(phase=1;phase<=4;++phase) {
                                src=0200UL*(1UL+(cases%03777UL));
                                floor=02000UL*(1UL+(cases%0377UL));
                                words=floor<0776000UL?floor+02000UL:floor;
                                current=words==floor?floor:floor+1UL+(count%02000UL);
                                brk=(floor<<18U)|current;
                                if(!pbr_heap_ok_v1989(brk,words)) return 1;
                                id.brk=brk; id.escrow=0UL;
                                pbr_save_v1989(&id,src,count,index<<10U,(unsigned int)phase);
                                field=(area[PROC_BRK_OFFSET]>>18U)&01777UL;
                                if(field!=(01000UL|index) ||
                                    (area[PROC_FINALIZE_OFFSET]&077777UL)!=count ||
                                    ((area[PROC_FINALIZE_OFFSET]>>15U)&7UL)!=phase ||
                                    ((area[PROC_FINALIZE_OFFSET]>>18U)&03777UL)!=(src>>7U) ||
                                    (area[PROC_FINALIZE_OFFSET]>>29U)!=013UL ||
                                    (area[PROC_BRK_OFFSET]&0777777UL)!=current ||
                                    PBR_TARGET_BASE_V1989(id.brk)!=(index<<10U) ||
                                    PBR_HEAP_V1989(id.brk)!=brk) return 2;
                                pbr_phase_v1989(&id,PBR_HOLD_V1989);
                                if(((id.escrow>>15U)&7UL)!=1UL ||
                                    (id.escrow&077777UL)!=count ||
                                    id.brk!=area[PROC_BRK_OFFSET]) return 3;
                                pbr_clear_v1989(&id);
                                if(area[PROC_BRK_OFFSET]!=brk || area[PROC_FINALIZE_OFFSET]) return 4;
                                ++cases;
                        }
        id.brk=(02000UL<<18U)|02001UL;
        pbr_save_v1989(&id,0200UL,040000UL,1UL,PBR_HOLD_V1989);
        if(PBR_HEAP_FIELD_V1989(id.brk)!=01400UL) return 5;
        pbr_save_v1989(&id,0200UL,040000UL,01000000UL,PBR_HOLD_V1989);
        if(PBR_HEAP_FIELD_V1989(id.brk)!=01400UL) return 6;
        if(pbr_heap_ok_v1989(0UL,02000UL) ||
            pbr_heap_ok_v1989((02001UL<<18U)|02001UL,04000UL) ||
            pbr_heap_ok_v1989((04000UL<<18U)|02001UL,04000UL) ||
            pbr_heap_ok_v1989((02000UL<<18U)|02000UL,04000UL) ||
            pbr_heap_ok_v1989((02000UL<<18U)|04001UL,04000UL) ||
            pbr_heap_ok_v1989((02000UL<<18U)|02001UL,02001UL) ||
            pbr_heap_ok_v1989((02000UL<<18U)|02001UL,01000000UL)) return 7;
        printf("PASS v1989 layout: %lu exact round trips, invalid heap/target rejected\n",cases);
        return 0;
}
