/* PDP-6 v006 counted bitmap, paired 18-bit word/zero descriptors.
 * Experiment only, not yet resumable or kernel ABI.  AC1 input,
 * AC2 compressed words, AC3 output, AC4 output words, AC17 stack.
 * AC10..AC16 are volatile INTERNAL to this test entry; caller is assembler.
 */
        .text
        .globl d6v020_decode
d6v020_decode:
        move    5,3                     ; output origin
        add     4,3                     ; output end pointer
        jumpe   2,d6v020_empty
d6v020_group:
        move    6,0(1)                  ; control
        aoj     1,
        soj     2,
        move    7,6
        lsh     7,-036                  ; token count
        jumpe   7,d6v020_bad
        caile   7,036
        jrst    d6v020_bad
        move    10,6
        lsh     10,6                    ; flags at high bits
        move    11,10
        move    12,7
        setz    13,                    ; match count
 d6v020_popcount:
        skipge  11
        aoj     13,
        lsh     11,1
        sojg    12,d6v020_popcount
        move    11,13
        aoj     11,
        lsh     11,-1                  ; descriptor words
        move    12,7
        sub     12,13                  ; literal words
        add     12,11                  ; entire group payload
        camle   12,2
        jrst    d6v020_bad
        sub     2,12
        move    14,1                   ; descriptor cursor
        move    15,1
        add     15,11                  ; literal cursor
        add     1,12                   ; next group
        setz    11,                    ; descriptor half toggle
 d6v020_token:
        jumpl   10,d6v020_match
        camge   3,4
        jrst    d6v020_lit_ok
        jrst    d6v020_bad
 d6v020_lit_ok:
        move    0,0(15)
        movem   0,0(3)
        aoj     15,
        aoj     3,
        jrst    d6v020_next
 d6v020_match:
        move    0,0(14)
        jumpe   11,d6v020_left
        hrrz    0,0
        aoj     14,
        setz    11,
        jrst    d6v020_desc
 d6v020_left:
        hlrz    0,0
        movei   11,1
 d6v020_desc:
        move    12,0
        lsh     12,-11                 ; length = bits 9..15
        andi    12,0177
        jumpe   12,d6v020_bad
        move    16,3
        add     16,12
        camle   16,4
        jrst    d6v020_bad
        move    13,0
        andi    13,0777                ; distance
        move    16,0
        lsh     16,-020                ; 2-bit kind
        jumpe   16,d6v020_copy
        caie    16,1
        jrst    d6v020_half
        jumpn   13,d6v020_bad
 d6v020_zero:
        setzm   0(3)
        aoj     3,
        sojg    12,d6v020_zero
        jrst    d6v020_next
; Kind 2: 18-bit halfword match distance. For even distance,
; the two halves align with entire output words, so ordinary overlapping
; word copy is correct. Odd distance needs separate halfword handling.
 d6v020_half:
        caie    16,2
        jrst    d6v020_bad
        jumpe   13,d6v020_bad
        trne    13,1
        jrst    d6v020_bad
        lsh     13,-1            ; even halfword distance -> words
        jrst    d6v020_copy
; Odd halfword offset: source begins in the low half of a word.
; First write the high half to the destination before reading the low
; half from source+1. This makes distance-one overlapping copies valid.
 d6v020_copy:
        jumpe   13,d6v020_bad
        move    16,3
        sub     16,13
        camge   16,5
        jrst    d6v020_bad
 d6v020_copy_loop:
        move    0,0(16)
        movem   0,0(3)
        aoj     16,
        aoj     3,
        sojg    12,d6v020_copy_loop
 d6v020_next:
        lsh     10,1
        sojg    7,d6v020_token
        camn    3,4
        jrst    d6v020_finish
        jumpn   2,d6v020_group
 d6v020_bad:
        seto    1,
        popj    17,
 d6v020_empty:
        came    3,4
        jrst    d6v020_bad
        jrst    d6v020_finish
 d6v020_finish:
        jumpn   2,d6v020_bad
        setz    1,
        popj    17,
