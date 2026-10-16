; Native PDP-6 test of compact UID9/GID9/UMASK9 credential packing.
; Former UMASK word 067 must stay unchanged for future FILE mount-ID bits.
        .text
        .globl main
        .globl kret_neg1
        .globl kret_zero
main:
        movei   4,subject
        movei   5,uarea
        hrlm    5,(4)
        movei   5,0400000             ; PROC_F_UAREA
        hrli    5,uarea
        movem   5,proc_table_data+3
        movei   5,1
        movem   5,proc_current_slot

        ; UID starts as root, but the unused high bits are deliberately set.
        movei   5,0760000
        hrlm    5,uarea+066
        movei   5,044
        hrrm    5,uarea+066
        movei   5,027
        dpb     5,[POINT 9,uarea+066,26] ; umask above GID9 in RH
        pushj   17,file_check_root
        jumpn   1,test_fail

        ; Root may set GID and UID without losing the extra credential bits.
        movei   1,012                 ; SETGID
        movei   2,0312
        movei   4,subject
        pushj   17,proc_control_setcred
        caie    1,0312
        jrst    test_fail
        movei   1,07                  ; SETUID
        movei   2,0157
        movei   4,subject
        pushj   17,proc_control_setcred
        caie    1,0157
        jrst    test_fail
        hlrz    5,uarea+066
        andi    5,0777000             ; unused high nine bits of UID half
        caie    5,0760000
        jrst    test_fail
        ldb     5,[POINT 9,uarea+066,26]
        caie    5,027                  ; SETGID and SETUID preserved umask
        jrst    test_fail

        movei   1,06                  ; GETUID
        setz    2,
        movei   4,subject
        pushj   17,proc_control_getuid
        caie    1,0157
        jrst    test_fail
        movei   1,07                  ; GETGID
        setz    2,
        movei   4,subject
        pushj   17,proc_control_getgid
        caie    1,0312
        jrst    test_fail
        pushj   17,file_check_root
        jumpe   1,test_fail           ; UID is no longer root

        ; Non-root may set its existing GID despite nonzero packed UMASK9.
        movei   1,012
        movei   2,0312
        movei   4,subject
        pushj   17,proc_control_setcred
        caie    1,0312
        jrst    test_fail
        movei   1,012
        movei   2,0313
        movei   4,subject
        pushj   17,proc_control_setcred
        camn    1,[-1]
        jrst    v18_foreign_gid_rejected
        jrst    test_fail
v18_foreign_gid_rejected:

        ; UMASK must change only nine credential bits and never touch the
        ; dedicated 36-bit mount-extension word (offset 067).
        move    5,[012345670027]
        movem   5,uarea+067
        movei   2,077
        movei   4,subject
        pushj   17,proc_control_umask
        caie    1,027                 ; prior nine-bit mask
        jrst    test_fail
        ldb     5,[POINT 9,uarea+066,26]
        caie    5,077
        jrst    test_fail
        move    5,[012345670027]
        came    5,uarea+067           ; mount bitmap untouched
        jrst    test_fail

        setz    1,
        popj    17,
test_fail:
        movei   1,1
        popj    17,
kret_neg1:
        seto    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,

        .data
        .globl proc_table
proc_table:     .word proc_table_data
        .globl proc_current_slot
proc_current_slot: .word 0

        .bss
subject:       .block 1
proc_table_data: .block 6
uarea:         .block 070
        .globl __test_exit
__test_exit:   .block 1
