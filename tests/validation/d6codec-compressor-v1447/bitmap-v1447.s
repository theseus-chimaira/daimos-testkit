/*
 * v1447 experimental zero-bitmap codec, 36-bit PDP-6 assembly.
 *
 * A control word is followed by one literal for each set control bit.
 * The highest bit represents the first output word, progressing to
 * the least significant bit for the 36th word. A zero bit denotes a
 * zero output word. The final control can represent a short group;
 * the caller supplies exact decoded/encoded counts.
 *
 * Encoder and decoder each operate on caller-owned, disjoint buffers.
 * No static DATA/BSS, no heap, no lookbehind, and no VFS interface.
 * Trusted MM only: all compressed words were produced by this encoder,
 * and both caller-owned extents and their exact sizes are guaranteed.
 * No in-code validation of untrusted compressed input or capacity.
 * Encode: AC1=source, AC2=word count, AC3=destination (AC4 unused).
 * Decode: AC1=source, AC2=unused, AC3=destination, AC4=word count.
 * Encoder returns packed word count in AC1. Decoder returns void;
 * the caller already owns the original count and cannot fail on a
 * kernel-owned valid stream. AC5..AC11 scratch.
 * No production runtime integration or reentrant ABI is claimed.
 */
        .text
        .globl bitmap_encode_v1447
        .globl bitmap_decode_v1447

bitmap_encode_v1447:
        move    5,3                    ; base of packed output for return size
bitmap_enc_group:
        jumpe   2,bitmap_enc_done
        move    10,3
        aoj     3,
        movsi   6,0400000              ; bit 35 without a literal-pool word
        setz    7,
bitmap_enc_word:
        move    11,(1)
        aoj     1,
        jumpe   11,bitmap_enc_advance
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

bitmap_decode_v1447:
bitmap_dec_group:
        jumpe   4,bitmap_dec_done
        move    6,(1)
        aoj     1,
        movsi   7,0400000              ; identical bit 35 mask
bitmap_dec_word:
        setzm   (3)                     ; zero by default; overwrite literal
        tdnn    6,7                     ; nonzero bit skips following branch
        jrst    bitmap_dec_advance
        move    11,(1)
        aoj     1,
        movem   11,(3)
bitmap_dec_advance:
        aoj     3,
        soje    4,bitmap_dec_done
        lsh     7,-1
        jumpn   7,bitmap_dec_word
        jrst    bitmap_dec_group
bitmap_dec_done:
        popj    17,
