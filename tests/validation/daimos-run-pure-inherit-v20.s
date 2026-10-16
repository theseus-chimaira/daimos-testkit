; Native RUN credential-copy invariant: UID/GID/UMASK and their unused high
; bits survive, but a parent's fifth PURE backing mount-slot bit must NOT
; be inherited by a child which has no attached executable backing yet.
        .text
        .globl main
main:
        move    4,[001234567123]
        tlo     4,001000               ; parent PURE mount slot bit 4
        movem   4,parent_fdtable+040   ; credential 066 - file_table 026
        movei   7,parent_fdtable
        movei   014,child_uarea
        movei   013,child_proc
        pushj   17,proc_run_copy_cred
        move    4,parent_fdtable+040
        tlz     4,001000
        came    4,child_uarea+066
        jrst    test_fail
        move    4,parent_fdtable+040
        tlne    4,001000               ; parent's backing bit remains intact
        jrst    check_nonpure
        jrst    test_fail
check_nonpure:
        move    4,[000234567123]
        movem   4,parent_fdtable+040
        movei   4,1                   ; staging bit for new mount 26 PURE
        movem   4,child_proc+2
        pushj   17,proc_run_copy_cred
        move    4,parent_fdtable+040
        tlo     4,001000               ; child got OWN executable bit
        came    4,child_uarea+066
        jrst    test_fail
        move    4,parent_fdtable+040
        tlne    4,001000               ; parent remains untouched
        jrst    test_fail
        setzm   child_proc+2
        pushj   17,proc_run_copy_cred
        move    4,parent_fdtable+040
        came    4,child_uarea+066       ; child bit cleared for low mount
        jrst    test_fail
        setz    1,
        popj    17,
test_fail:
        movei   1,1
        popj    17,

        .bss
parent_fdtable: .block 042
child_uarea: .block 070
child_proc: .block 3
        .globl __test_exit
__test_exit: .block 1
