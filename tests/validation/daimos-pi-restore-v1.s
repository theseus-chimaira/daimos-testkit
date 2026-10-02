        .text
        .globl  _start
        .globl  __test_exit
        .globl  mach_pi_disable
        .globl  mach_pi_restore

_start:
        move    17,[0777700,,stack-1]
        setzm   __test_exit

        ; A disabled saved state must remain disabled after restore.
        cono    0004,000400
        pushj   17,mach_pi_disable
        pushj   17,mach_pi_restore
        coni    0004,2
        trne    2,000200
        jrst    pi_fail_clear

        ; An enabled saved state must be re-enabled after disable/restore.
        cono    0004,000200
        pushj   17,mach_pi_disable
        move    2,1
        trnn    2,000200
        jrst    pi_fail_saved
        pushj   17,mach_pi_restore
        coni    0004,2
        trnn    2,000200
        jrst    pi_fail_restored
        jrst    pi_pass

pi_fail_clear:
        movei   1,1
        jrst    pi_fail
pi_fail_saved:
        movei   1,2
        jrst    pi_fail
pi_fail_restored:
        movei   1,3
pi_fail:
        movem   1,__test_exit
        halt    .
pi_pass:
        halt    .

        .bss
stack:          .block 0100
__test_exit:    .block 1
