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
        .globl d6v008_encode_literals
        .globl d6v008_decode_literals

; Encode groups of <=30 literals, no match-search or scratch storage.
; AC5 points to start of destination for return-length calculation.
; AC6 holds group size; AC7 loops; AC10 is control header.
d6v008_encode_literals:
        move    5,3
        move    0,2
        jumpe   2,d6v008_enc_done

d6v008_enc_group:
        movei   6,036                  ; 30 decimal = 036 octal
        camle   6,2
        move    6,2
        move    7,6
        move    10,6
        lsh     10,036                 ; control group count in bits 35..30
        move    11,6
        aoj     11,                    ; count + control word
        camle   11,4
        jrst    d6v008_enc_error
        movem   10,0(3)
        aoj     3,

d6v008_enc_copy:
        move    10,0(1)
        movem   10,0(3)
        aoj     1,
        aoj     3,
        sojg    7,d6v008_enc_copy
        sub     2,6
        sub     4,11
        jumpn   2,d6v008_enc_group

d6v008_enc_done:
        move    1,3
        sub     1,5
        popj    17,
d6v008_enc_error:
        seto    1,
        popj    17,

; Decode literal-only packets emitted above. Other descriptor kinds rejected.
; AC1 encoded source, AC2 available encoded words, AC3 destination,
; AC4 expected decoded words. Return AC1=0 on exact completion, -1 on error.
d6v008_decode_literals:
        jumpe   4,d6v008_dec_done

d6v008_dec_group:
        jumpe   2,d6v008_dec_error
        move    10,0(1)
        aoj     1,
        soj     2,
        move    6,10
        lsh     6,-036
        jumpe   6,d6v008_dec_error
        caile   6,036
        jrst    d6v008_dec_error
        move    7,10
        lsh     7,6
        jumpn   7,d6v008_dec_error    ; reject any nonzero match flag
        camle   6,4
        jrst    d6v008_dec_error
        camle   6,2
        jrst    d6v008_dec_error
        move    7,6

d6v008_dec_copy:
        move    10,0(1)
        movem   10,0(3)
        aoj     1,
        aoj     3,
        sojg    7,d6v008_dec_copy
        sub     4,6
        sub     2,6
        jumpn   4,d6v008_dec_group
        jumpn   2,d6v008_dec_error

d6v008_dec_done:
        setz    1,
        popj    17,
d6v008_dec_error:
        seto    1,
        popj    17,
