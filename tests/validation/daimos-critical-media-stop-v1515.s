; v1515 native PDP-6 test: exercise fixed-KCORE no-return fatal leaf.
; Test-specific input controls the authoritative reason. Never simulate a
; driver error or claim that a watchdog establishes media disappearance.
        .text
        .globl  main
        .globl  kcore_critical_device_lost_v1515
        .globl  __test_exit
main:
        move    1,test_reason_v1515
        pushj   17,kcore_critical_device_lost_v1515
        ; No critical-media failure may return here and resume user work.
        movei   1,7
        movem   1,__test_exit
        popj    17,
        .data
test_reason_v1515:
        .word 1
        .bss
__test_exit:
        .block 1
