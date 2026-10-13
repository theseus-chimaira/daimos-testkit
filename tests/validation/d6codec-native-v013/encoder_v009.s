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
        .globl d6v009_encode_literals

; Encode groups of <=30 literals, no match-search or scratch storage.
; AC5 points to start of destination for return-length calculation.
; AC6 holds group size; AC7 loops; AC10 is control header.
d6v009_encode_literals:
        move    5,3
        move    0,2
        jumpe   2,d6v009_enc_done

d6v009_enc_group:
        ; Fast-path a run of zero words beginning at this source address.
        move    0,0(1)
        jumpn   0,d6v009_literal_group
        jrst    d6v009_zero_scan

d6v009_literal_group:
        move    6,2
        caile   6,036
        movei   6,036
        move    7,6
        move    10,6
        lsh     10,036                 ; control group count in bits 35..30
        move    11,6
        aoj     11,                    ; count + control word
        camle   11,4
        jrst    d6v009_enc_error
        movem   10,0(3)
        aoj     3,

d6v009_enc_copy:
        move    10,0(1)
        movem   10,0(3)
        aoj     1,
        aoj     3,
        sojg    7,d6v009_enc_copy
        sub     2,6
        sub     4,11
        jumpn   2,d6v009_enc_group
        jrst    d6v009_enc_done

; A single match token in a control group encodes 1..128 zeros.
; This deliberately prioritizes a small encoder over optimal token packing.
d6v009_zero_scan:
        movei   6,1
        movei   7,0200                 ; 128 decimal words
        camle   7,2
        move    7,2
d6v009_zero_next:
        camge   6,7
        jrst    d6v009_zero_probe
        jrst    d6v009_zero_emit
d6v009_zero_probe:
        move    14,1
        add     14,6
        skipn   0(14)
        aoja    6,d6v009_zero_next
d6v009_zero_emit:
        caige   4,2
        jrst    d6v009_enc_error
        move    10,[400000000000]
        movem   10,0(3)
        aoj     3,
        move    10,6
        soj     10,
        iori    10,0100000
        movem   10,0(3)
        aoj     3,
        add     1,6
        sub     2,6
        subi    4,2
        jumpn   2,d6v009_enc_group

d6v009_enc_done:
        move    1,3
        sub     1,5
        popj    17,
d6v009_enc_error:
        seto    1,
        popj    17,


