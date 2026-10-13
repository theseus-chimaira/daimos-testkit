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
        .globl d6v029_encode_literals

; Encode groups of <=30 literals, no match-search or scratch storage.
; AC5 points to start of destination for return-length calculation.
; AC6 holds group size; AC7 loops; AC10 is control header.
d6v029_encode_literals:
        move    5,3
        move    16,1                  ; input origin for backref bounds
        move    0,2
        jumpe   2,d6v029_enc_done

d6v029_enc_group:
        ; Fast-path a run of zero words beginning at this source address.
        move    0,0(1)
        jumpe   0,d6v029_zero_scan
        pushj   17,d6v029_word_probe
        caige   11,3
        jrst    d6v029_literal_group
        move    6,11
        jrst    d6v029_match_emit

; Distance-one word reference, at least 3 words, at most 127 words.
d6v029_word_probe:
        aos     d6v029_calls
        ; Search backward up to 128 existing source words. AC15 holds
        ; candidate distance; AC13 holds the longest match distance.
        move    15,1
        sub     15,16
        jumpe   15,d6v029_word_none
        caile   15,0200
        movei   15,0200
        setz    13,
        setz    11,                   ; best match length
 d6v029_word_candidate:
        aos     d6v029_candidates
        move    14,1
        sub     14,15
        move    0,0(14)
        came    0,0(1)
        jrst    d6v029_word_advance
        ; Reject a candidate that cannot beat the current best length.
        ; This checks the next unproven word *before* scanning the prefix.
        move    0,2
        caml    11,0
        jrst    d6v029_word_advance
        move    6,1
        add     6,11
        move    0,0(6)
        move    6,14
        add     6,11
        aos     d6v029_prechecks
        came    0,0(6)
        jrst    d6v029_word_advance
        movei   6,1
        movei   7,0177
        camle   7,2
        move    7,2
 d6v029_word_compare:
        camge   6,7
        jrst    d6v029_word_compare_next
        jrst    d6v029_word_consider
 d6v029_word_compare_next:
        aos     d6v029_comparisons
        move    14,1
        add     14,6
        move    0,0(14)
        sub     14,15
        came    0,0(14)
        jrst    d6v029_word_consider
        aoja    6,d6v029_word_compare
 d6v029_word_consider:
        camle   6,11
        jrst    d6v029_word_new_best
        jrst    d6v029_word_advance
 d6v029_word_new_best:
        move    11,6
        move    13,15
        caie    11,0177
        jrst    d6v029_word_advance
        jrst    d6v029_word_ready
 d6v029_word_advance:
        sojg    15,d6v029_word_candidate
 d6v029_word_ready:
        popj    17,
 d6v029_word_none:
        setz    11,
        popj    17,

d6v029_literal_group:
        ; Group consecutive literals until another zero run or a confirmed
        ; distance-one match of at least three words. No token staging RAM.
        movei   6,1
        move    7,2
        caile   7,036
        movei   7,036
 d6v029_lookahead:
        camge   6,7
        jrst    d6v029_probe_next
        jrst    d6v029_literal_emit
 d6v029_probe_next:
        move    14,1
        add     14,6
        skipn   0(14)
        jrst    d6v029_literal_emit
        ; Reuse the same bounded 128-word search on this future cursor.
        ; AC8/9 hold the real source cursor/remaining words; AC12 and
        ; AC10 save the literal scan's count and token limit.
        push    17,1
        push    17,2
        push    17,6
        push    17,7
        add     1,6
        sub     2,6
        pushj   17,d6v029_word_probe
        pop     17,7
        pop     17,6
        pop     17,2
        pop     17,1
        caige   11,3
        jrst    d6v029_add_literal
        jrst    d6v029_literal_emit
 d6v029_add_literal:
        aoja    6,d6v029_lookahead
 d6v029_literal_emit:
        move    7,6
        move    10,6
        lsh     10,036
        move    11,6
        aoj     11,
        camle   11,4
        jrst    d6v029_enc_error
        movem   10,0(3)
        aoj     3,

d6v029_enc_copy:
        move    10,0(1)
        movem   10,0(3)
        aoj     1,
        aoj     3,
        sojg    7,d6v029_enc_copy
        sub     2,6
        sub     4,11
        jumpn   2,d6v029_enc_group
        jrst    d6v029_enc_done

; A single match token in a control group encodes 1..128 zeros.
; This deliberately prioritizes a small encoder over optimal token packing.
d6v029_zero_scan:
        movei   6,1
        movei   7,0177                 ; 128 decimal words
        camle   7,2
        move    7,2
d6v029_zero_next:
        camge   6,7
        jrst    d6v029_zero_probe
        jrst    d6v029_zero_emit
d6v029_zero_probe:
        move    14,1
        add     14,6
        skipn   0(14)
        aoja    6,d6v029_zero_next
d6v029_zero_emit:
        movei   13,0200000         ; kind 1, zero distance
        ; Common direct descriptor emission, no temporary token staging.
d6v029_match_emit:
        caige   4,2
        jrst    d6v029_enc_error
        move    10,[014000000000]
        movem   10,0(3)
        aoj     3,
        move    10,6
        lsh     10,11
        ior     10,13
        lsh     10,022
        movem   10,0(3)
        aoj     3,
        add     1,6
        sub     2,6
        subi    4,2
        jumpn   2,d6v029_enc_group
        jrst    d6v029_enc_done

d6v029_enc_done:
        move    1,3
        sub     1,5
        popj    17,
d6v029_enc_error:
        seto    1,
        popj    17,



.bss
.globl d6v029_calls
d6v029_calls: .block 1
.globl d6v029_candidates
d6v029_candidates: .block 1
.globl d6v029_comparisons
d6v029_comparisons: .block 1
.globl d6v029_prechecks
d6v029_prechecks: .block 1
