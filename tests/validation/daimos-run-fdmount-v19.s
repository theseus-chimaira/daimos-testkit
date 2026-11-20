; Source-linked PDP-6 RUN fd-map: current v417 FILE encoding embeds the
; complete six-bit mount directly in the descriptor's canonical vnode.
; Inherit TSFS mount 63 from parent fd7 to child fd5, including offset.
        .text
        .globl main
main:
        movei   5,7                    ; TSFS provider
        lsh     5,036
        movei   6,077                  ; highest legal six-bit mount
        lsh     6,030
        ior     5,6
        movei   6,1                    ; local kind
        lsh     6,022
        ior     5,6
        iori    5,01234               ; local inode/index
        tlo     5,400000              ; readable FILE
        movem   5,parent_fd_table+016 ; parent fd7 word 0
        movei   5,012345
        movem   5,parent_fd_table+017 ; full source word offset
        movei   014,child_uarea
        movei   015,fdmap
        movei   3,1
        setz    4,
        pushj   17,proc_run_map_loop
        jumpn   1,check_copy_fail      ; loop returns zero on success
        move    5,parent_fd_table+016
        came    5,child_uarea+040     ; 026 + 2*5 = 040 octal
        jrst    check_copy_fail
        move    5,parent_fd_table+017
        came    5,child_uarea+041
        jrst    check_copy_fail
        ; Old extension u-area word 067 must remain untouched. This word
        ; is now owned by process finalization/FILE error diagnostics.
        skipn   child_uarea+067
        jrst    check_copy_ok
        jrst    check_copy_fail
check_copy_ok:
        setz    1,
        popj    17,
check_copy_fail:
        movei   1,1
        popj    17,

        .data
        .globl file_table
file_table: .word parent_fd_table
fdmap:       .word 5,,7

        .bss
parent_fd_table: .block 042
child_uarea:    .block 070
        .globl __test_exit
__test_exit:     .block 1
