/**
 * @file codec_v008.s
 * @brief Initial PDP-6 native v006-stream codec experiments.
 *
 * Research-only assembler. C ABI is not established. Do not link to KCORE.
 * AC1 input cursor, AC2 number of source words, AC3 output cursor,
 * AC4 capacity in 36-bit words. AC17 pushdown pointer.
 * Return AC1 = number of encoded words; -1 on insufficient output space.
 * Clobbers AC0..AC16. The encoder currently emits literal-only token groups,
 * which are valid in the universal v006 stream format. Additional match
 * searches will be added once the native decoder is tested in simulation.
 *
 * The format permits a count (1..30) in control bits 35..30, 30 flags,
 * followed by ceil(match_count/2) descriptor words and then literal words.
 */
        .text
        .globl d6v022_encode_literals

; Encode groups of <=30 literals, no match-search or scratch storage.
; AC5 points to start of destination for return-length calculation.
; AC6 holds group size; AC7 loops; AC10 is control header.
d6v022_encode_literals:
        move    5,3
        move    16,1                  ; input origin for backref bounds
        move    0,2
        jumpe   2,d6v022_enc_done

d6v022_enc_group:
        ; Fast-path a run of zero words beginning at this source address.
        move    0,0(1)
        jumpe   0,d6v022_zero_scan
        jrst    d6v022_word_probe

; Distance-one word reference, at least 3 words, at most 127 words.
d6v022_word_probe:
        camn    1,16
        jrst    d6v022_literal_group
        move    14,1
        soj     14,
        move    0,0(14)
        came    0,0(1)
        jrst    d6v022_literal_group
        movei   6,1
        movei   7,0177
        camle   7,2
        move    7,2
d6v022_word_next:
        camge   6,7
        jrst    d6v022_word_cmp
        jrst    d6v022_word_end
d6v022_word_cmp:
        move    14,1
        add     14,6
        move    0,0(14)
        came    0,-1(14)
        jrst    d6v022_word_end
        aoja    6,d6v022_word_next
d6v022_word_end:
        caige   6,3
        jrst    d6v022_literal_group
        caige   4,2
        jrst    d6v022_enc_error
        move    10,[014000000000]
        movem   10,0(3)
        aoj     3,
        move    10,6
        lsh     10,11
        iori    10,1
        lsh     10,022
        movem   10,0(3)
        aoj     3,
        add     1,6
        sub     2,6
        subi    4,2
        jumpn   2,d6v022_enc_group
        jrst    d6v022_enc_done

d6v022_literal_group:
        ; A singleton group is required for the following token to be
        ; reconsidered for a match. The optimization objective here is
        ; functional proof, not final compression or speed.
        movei   6,1
        move    7,6
        move    10,6
        lsh     10,036
        movei   11,2
        camle   11,4
        jrst    d6v022_enc_error
        movem   10,0(3)
        aoj     3,

d6v022_enc_copy:
        move    10,0(1)
        movem   10,0(3)
        aoj     1,
        aoj     3,
        sojg    7,d6v022_enc_copy
        sub     2,6
        sub     4,11
        jumpn   2,d6v022_enc_group
        jrst    d6v022_enc_done

; A single match token in a control group encodes 1..128 zeros.
; This deliberately prioritizes a small encoder over optimal token packing.
d6v022_zero_scan:
        movei   6,1
        movei   7,0177                 ; 128 decimal words
        camle   7,2
        move    7,2
d6v022_zero_next:
        camge   6,7
        jrst    d6v022_zero_probe
        jrst    d6v022_zero_emit
d6v022_zero_probe:
        move    14,1
        add     14,6
        skipn   0(14)
        aoja    6,d6v022_zero_next
d6v022_zero_emit:
        caige   4,2
        jrst    d6v022_enc_error
        move    10,[014000000000]      ; one match token in 30-bit bitmap
        movem   10,0(3)
        aoj     3,
        move    10,6
        lsh     10,11                ; length in 18-bit descriptor bits 9..15
        iori    10,0200000          ; kind 1 zero run
        lsh     10,022              ; first descriptor occupies left half
        movem   10,0(3)
        aoj     3,
        add     1,6
        sub     2,6
        subi    4,2
        jumpn   2,d6v022_enc_group
        jrst    d6v022_enc_done

d6v022_enc_done:
        move    1,3
        sub     1,5
        popj    17,
d6v022_enc_error:
        seto    1,
        popj    17,


