/*
 * v1432 experimental zero-bitmap codec, 36-bit PDP-6 assembly.
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
        .globl bitmap_encode_v1432
        .globl bitmap_decode_v1432

bitmap_encode_v1432:
        setz    5,
bitmap_enc_group:
        jumpe   2,bitmap_enc_done
        jumpe   4,bitmap_error
        move    10,3
        aoj     3,
        soj     4,
        aoj     5,
        move    6,[0400000000000]
        setz    7,
bitmap_enc_word:
        move    11,(1)
        aoj     1,
        jumpe   11,bitmap_enc_advance
        jumpe   4,bitmap_error
        movem   11,(3)
        aoj     3,
        soj     4,
        aoj     5,
        ior     7,6
bitmap_enc_advance:
        soj     2,
        jumpe   2,bitmap_enc_finish
        lsh     6,-1
        jumpn   6,bitmap_enc_word
bitmap_enc_finish:
        movem   7,(10)
        jrst    bitmap_enc_group
bitmap_enc_done:
        move    1,5
        popj    17,

bitmap_decode_v1432:
        move    12,4
bitmap_dec_group:
        jumpe   4,bitmap_dec_done
        jumpe   2,bitmap_error
        move    6,(1)
        aoj     1,
        soj     2,
        move    7,[0400000000000]
bitmap_dec_word:
        move    11,6
        and     11,7
        jumpe   11,bitmap_dec_zero
        jumpe   2,bitmap_error
        move    11,(1)
        aoj     1,
        soj     2,
        movem   11,(3)
        jrst    bitmap_dec_advance
bitmap_dec_zero:
        setzm   (3)
bitmap_dec_advance:
        aoj     3,
        soj     4,
        jumpe   4,bitmap_dec_done
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
