/*
 * v1450 experimental zero-bitmap codec, 36-bit PDP-6 assembly.
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
 * Encode: AC1=source, AC2=positive word count, AC3=destination.
 * Decode: AC1=source, AC3=destination, AC4=positive word count.
 * Both require nonzero word count; MM handles empty image extents.
 * Encoder leaves AC3 at the first free destination word, so the MM caller
 * obtains the exact packed size as (AC3 - saved_destination_base).
 * Decoder returns void. Neither operation needs a status return, because
 * neither can fail on the kernel-owned validated process representation.
 * AC6,AC7,AC10,AC11 scratch; AC1,AC2,AC3,AC4 as above.
 * No production runtime integration or reentrant ABI is claimed.
 */
        .text
        .globl bitmap_encode_v1450
        .globl bitmap_decode_v1450

bitmap_encode_v1450:
bitmap_enc_group:
        move    10,3
        setzm   (3)                     ; initialize the bitmap in place
        aoj     3,
        movsi   6,0400000              ; bit 35 without a literal-pool word
bitmap_enc_word:
        move    11,(1)
        aoj     1,
        jumpe   11,bitmap_enc_advance
        movem   11,(3)
        aoj     3,
        iorm    6,(10)                  ; publish the present-bit directly
bitmap_enc_advance:
        soje    2,bitmap_enc_finish
        lsh     6,-1
        jumpn   6,bitmap_enc_word
bitmap_enc_finish:
        jumpn   2,bitmap_enc_group
bitmap_enc_done:
        popj    17,

bitmap_decode_v1450:
bitmap_dec_group:
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
