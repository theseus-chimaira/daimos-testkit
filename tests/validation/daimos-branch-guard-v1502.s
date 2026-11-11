; One branch counter must increment only while its event scope is active.
; The real injected two-instruction sequence replaces each marker.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        setzm   __active
; INSERT_GUARD_V1502
        skipn   __count
        jrst    enable_v1502
        jrst    fail_v1502
enable_v1502:
        setom   __active
; INSERT_GUARD_V1502
        move    1,__count
        caie    1,1
        jrst    fail_v1502
        setzm   __active
; INSERT_GUARD_V1502
        move    1,__count
        caie    1,1
        jrst    fail_v1502
        setz    1,
        jrst    done_v1502
fail_v1502:
        movei   1,1
done_v1502:
        movem   1,__test_exit
        jrst    4,0
        .data
__active: .word 0
__count: .word 0
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
