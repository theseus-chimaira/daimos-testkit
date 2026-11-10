; Native testkit-only validation fixture, NEVER an independent executable
; loader. The final integration must fold this DXR2 header/payload handling
; into exec_load_process' shared executable load/decode engine so EXEC and
; inactive PURE restoration use one implementation and one format policy.
; Reconstruct ONLY omitted immutable PURE text from a validated, plain DXR2
; executable. Never write at/after the saved mutable suffix boundary.
;
; int proc_pure_prefix_plain_v1385(backing, APRbase, uarea, prefix_words)
; AC1=0 complete, -1 invalid/read failure, -2 compressed DXR (fallback).
; Input PROCESS remains nonresident; original suffix is owned by an MM
; PACKED_PROCESS full-span reservation. The caller retains TRANSITION.
;
; The existing backing unpacker supplies canonical provider/mount/node,
; including the extra fifth mount bit kept in the stable u-area.
        .text
        .globl proc_pure_prefix_plain_v1385
        .globl proc_swap_unpack_backing
        .globl vfs_read_words

        .equ PLAIN_DXR_MAGIC_V1385,0447062
        .equ PLAIN_DXR_TEXT_TAG_V1385,0647022
        .equ PLAIN_DXR_PURE_V1385,0200000
        .equ PLAIN_DXR_COMPRESSED_V1385,0100000
        .equ PLAIN_EXEC_ORIGIN_V1385,020

proc_pure_prefix_plain_v1385:
        push    17,010
        push    17,011
        push    17,012
        push    17,013
        push    17,014
        push    17,015
        push    17,016
        add     17,[03,,03]           ; scratch DXR2 header, three words
        move    010,1                 ; packed executable source
        move    011,2                 ; aligned physical APR base
        move    012,3                 ; stable u-area
        move    013,4                 ; exact released sector prefix
        jumpe   011,pprefix_bad_v1385
        caig    013,PLAIN_EXEC_ORIGIN_V1385
        jrst    pprefix_bad_v1385
        trne    013,0177
        jrst    pprefix_bad_v1385
        move    1,010
        move    2,012
        pushj   17,proc_swap_unpack_backing
        move    014,1                 ; guarded executable vnode
        move    015,2                 ; validated PURE text words
        jumpe   014,pprefix_bad_v1385
        jumpe   015,pprefix_bad_v1385
        move    5,015
        addi    5,PLAIN_EXEC_ORIGIN_V1385
        andi    5,0777600
        came    5,013                 ; same complete-sector prefix
        jrst    pprefix_bad_v1385

        ; Read all DXR2 header fields before modifying user memory.
        move    1,014
        setz    2,                    ; header file offset 0
        movei   3,-2(17)
        movei   4,3
        pushj   17,vfs_read_words
        caie    1,3
        jrst    pprefix_bad_v1385
        hlrz    5,-2(17)
        caie    5,PLAIN_DXR_MAGIC_V1385
        jrst    pprefix_bad_v1385
        hlrz    5,(17)                ; TX2 uncompressed text words
        came    5,015
        jrst    pprefix_bad_v1385
        hrrz    5,(17)
        caie    5,PLAIN_DXR_TEXT_TAG_V1385
        jrst    pprefix_bad_v1385
        hlrz    5,-1(17)             ; uncompressed initialized words
        camle   015,5
        jrst    pprefix_bad_v1385
        hrrz    5,-1(17)
        trnn    5,PLAIN_DXR_PURE_V1385
        jrst    pprefix_bad_v1385
        trne    5,PLAIN_DXR_COMPRESSED_V1385
        jrst    pprefix_unsupported_v1385

        ; Only the original complete omitted sectors minus user AC words
        ; are reconstructed. The retained mutable suffix is untouched.
        move    1,014
        movei   2,3                   ; plain DXR2 payload offset
        move    3,011
        addi    3,PLAIN_EXEC_ORIGIN_V1385
        move    4,013
        subi    4,PLAIN_EXEC_ORIGIN_V1385
        move    016,4                 ; exact read length across VFS
        pushj   17,vfs_read_words
        came    1,016
        jrst    pprefix_bad_v1385
        setz    1,
        jrst    pprefix_done_v1385
pprefix_unsupported_v1385:
        movni   1,2
        jrst    pprefix_done_v1385
pprefix_bad_v1385:
        seto    1,
pprefix_done_v1385:
        sub     17,[03,,03]
        pop     17,016
        pop     17,015
        pop     17,014
        pop     17,013
        pop     17,012
        pop     17,011
        pop     17,010
        popj    17,
