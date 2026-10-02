; Minimal current filesystem helpers required by memfs_runtime.s.
; Keep these identical to the corresponding resident helpers in
; DAIMOS system/kernel/fs/fs_mres.s without pulling the unrelated
; BLOCKSET/device bridge into this focused MEMFS target test.

        .text
        .globl  vfs_name_words_equal
vfs_name_words_equal:
        jumpe   3,vfs_name_words_equal_yes
vfs_name_words_equal_loop:
        move    4,(1)
        came    4,(2)
        jrst    kret_zero
        aoj     1,
        aoj     2,
        sojg    3,vfs_name_words_equal_loop
vfs_name_words_equal_yes:
        jrst    kret_one

        .globl  fs_copy_words
fs_copy_words:
        jumpe   3,fs_copy_words_done
        move    4,2
        hrl     4,1
        add     2,3
        subi    2,1
        blt     4,(2)
fs_copy_words_done:
        popj    17,

        .globl  fs_zero_words
fs_zero_words:
        jumpe   2,fs_zero_words_done
        setzm   (1)
        subi    2,1
        jumpe   2,fs_zero_words_done
        move    3,1
        aoj     3,
        hrl     3,1
        add     1,2
        blt     3,(1)
fs_zero_words_done:
        popj    17,

        .globl  vfs_current_owner
vfs_current_owner:
        setz    1,                     ; focused fixture runs as root
        popj    17,

        .globl  pclk_time36
pclk_time36:
        setz    1,                     ; deterministic timestamp fixture
        popj    17,

        .globl  fs_mres_context_vector_dispatch
        .globl  kret_zero
        .globl  kret_one
        .globl  kret_neg1
fs_mres_context_vector_dispatch:
        jrst    kret_neg1
