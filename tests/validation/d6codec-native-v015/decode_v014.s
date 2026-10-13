/** Experimental decoder of v006 counted control groups, literal subset.
 * AC1 input pointer, AC2 compressed count, AC3 output pointer, AC4 output
 * count; AC17 stack. AC0..AC7 volatile. Returns AC1=0 or -1.
 * This experiment does not yet implement match descriptor tokens.
 */
        .text
        .globl d6v014_decode

d6v014_decode:
        jumpe   4,d6v014_finish
d6v014_group:
        jumpe   2,d6v014_bad
        move    6,0(1)
        aoj     1,
        soj     2,
        move    7,6
        lsh     7,-036                  ; token count
        jumpe   7,d6v014_bad
        caile   7,036
        jrst    d6v014_bad
        ; The control word contains only the token count in this subset.
        move    5,7
        lsh     5,036
        sub     6,5
        jumpn   6,d6v014_bad
        camle   7,4
        jrst    d6v014_bad
        camle   7,2
        jrst    d6v014_bad
        sub     2,7
        sub     4,7
d6v014_copy:
        move    6,0(1)
        movem   6,0(3)
        aoj     1,
        aoj     3,
        sojg    7,d6v014_copy
        jumpn   4,d6v014_group
d6v014_finish:
        jumpn   2,d6v014_bad
        setz    1,
        popj    17,
d6v014_bad:
        seto    1,
        popj    17,
