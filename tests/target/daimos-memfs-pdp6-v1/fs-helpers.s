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
	move    1,[012345670123]       ; deterministic nonzero timestamp fixture
	popj    17,

        .globl  fs_mres_context_vector_dispatch
        .globl  kret_zero
        .globl  kret_one
        .globl  kret_neg1

; Keep the focused fixture identical to the production vector target and
; context dispatcher.  This catches register-ABI regressions without relying
; on temporary diagnostics in the provider itself.
fs_mres_vector_target:
        jumple  6,fs_mres_vector_target_none
        caile   6,020
        jrst    fs_mres_vector_target_none
        subi    6,1
        trne    6,1
        jrst    fs_mres_vector_target_odd
        lsh     6,-1
        add     7,6
        hlrz    7,(7)
        popj    17,
fs_mres_vector_target_odd:
        lsh     6,-1
        add     7,6
        hrrz    7,(7)
        popj    17,
fs_mres_vector_target_none:
        setz    7,
        popj    17,

fs_mres_context_vector_dispatch:
        pushj   17,fs_mres_vector_target
        jumpe   7,kret_neg1
        add     17,[2,,2]
        movem   4,(17)
        movem   5,-1(17)
        move    4,3
        move    3,2
        move    2,1
        move    1,0
        pushj   17,(7)
        sub     17,[2,,2]
        popj    17,

        .globl  test_memfs_dispatch_stat
        .globl  memfs_mres_dispatch
test_memfs_dispatch_stat:
        movei   6,3                    ; FS_MRES_OP_STAT
        jrst    memfs_mres_dispatch

        .globl  test_memfs_dispatch_readdir
test_memfs_dispatch_readdir:
        movei   6,2                    ; FS_MRES_OP_READDIR
        jrst    memfs_mres_dispatch

; Exercise the same register contract as vfs_stat() -> fs_provider_reg_call
; -> MEMFS dispatch.  This deliberately tail-calls through a patchable JRST
; word so the focused test also covers the fixed service-jump convention.
        .globl  test_vfs_memfs_stat
test_vfs_memfs_stat:
        setzm   4(2)
        setzm   5(2)
        setzm   6(2)
        movei   7,4                    ; MEMFS provider
        movei   6,3                    ; FS_MRES_OP_STAT
        jrst    test_fs_provider_reg_call

test_fs_provider_reg_call:
        subi    7,4
        hrrz    7,test_memfs_service_jump(7)
        jrst    (7)

test_memfs_service_jump:
        jrst    memfs_mres_dispatch
