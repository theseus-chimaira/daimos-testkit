/*
 * v1445 experimental zero-bitmap codec, 36-bit PDP-6 assembly.
 *
 * A control word is followed by one literal for each set control bit.
 * The highest bit represents the first output word, progressing to
 * the least significant bit for the 36th word. A zero bit denotes a
 * zero output word. The final control can represent a short group;
 * the caller supplies exact decoded/encoded counts.
 *
 * Encoder and decoder each operate on caller-owned, disjoint buffers.
 * No static DATA/BSS, no heap, no lookbehind, and no VFS interface.
 * AC1=source, AC2=source length, AC3=destination,
 * AC4=destination capacity. Return encoded/decoded words in AC1
 * or -1 on error. Scratch AC5..AC12 are clobbered in this prototype.
 * No production runtime integration or reentrant ABI is claimed.
 */
        .text
        .globl bitmap_encode_v1445
        .globl bitmap_decode_v1445

bitmap_encode_v1445:
        move    5,3                    ; base of packed output for return size
bitmap_enc_group:
        jumpe   2,bitmap_enc_done
        sojl    4,bitmap_error          ; reserve one bitmap header word
        move    10,3
        aoj     3,
        movsi   6,0400000              ; bit 35 without a literal-pool word
        setz    7,
bitmap_enc_word:
        move    11,(1)
        aoj     1,
        jumpe   11,bitmap_enc_advance
        sojl    4,bitmap_error          ; reserve one nonzero literal word
        movem   11,(3)
        aoj     3,
        ior     7,6
bitmap_enc_advance:
        soje    2,bitmap_enc_finish
        lsh     6,-1
        jumpn   6,bitmap_enc_word
bitmap_enc_finish:
        movem   7,(10)
        jrst    bitmap_enc_group
bitmap_enc_done:
        move    1,3
        sub     1,5                    ; exact written words = end - base
        popj    17,

bitmap_decode_v1445:
        move    12,4
bitmap_dec_group:
        jumpe   4,bitmap_dec_done
        sojl    2,bitmap_error          ; consume header or fail on EOF
        move    6,(1)
        aoj     1,
        movsi   7,0400000              ; identical bit 35 mask
bitmap_dec_word:
        tdnn    6,7                     ; nonzero bit skips zero branch
        jrst    bitmap_dec_zero
        sojl    2,bitmap_error          ; consume literal or fail on EOF
        move    11,(1)
        aoj     1,
        movem   11,(3)
        jrst    bitmap_dec_advance
bitmap_dec_zero:
        setzm   (3)
bitmap_dec_advance:
        aoj     3,
        soje    4,bitmap_dec_done
        lsh     7,-1
        jumpn   7,bitmap_dec_word
        jrst    bitmap_dec_group
bitmap_dec_done:
        jumpn   2,bitmap_error
        move    1,12
        popj    17,

bitmap_error:
        seto    1,
        popj    17,
