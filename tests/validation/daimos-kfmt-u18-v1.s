        .text
        .globl  _start
        .globl  __test_exit
        .globl  kfmt_u18_sixbit

_start:
        move    17,[0777700,,stack-1]
        setzm   __test_exit

        setz    1,
        pushj   17,kfmt_u18_sixbit
        camn    1,[0200000000000]
        caie    2,1
        jrst    kfmt_fail_1

        movei   1,012
        pushj   17,kfmt_u18_sixbit
        camn    1,[0212000000000]
        caie    2,2
        jrst    kfmt_fail_2

        movei   1,0144
        pushj   17,kfmt_u18_sixbit
        camn    1,[0212020000000]
        caie    2,3
        jrst    kfmt_fail_3

        movei   1,01750
        pushj   17,kfmt_u18_sixbit
        camn    1,[0212020200000]
        caie    2,4
        jrst    kfmt_fail_4

        movei   1,023420
        pushj   17,kfmt_u18_sixbit
        camn    1,[0212020202000]
        caie    2,5
        jrst    kfmt_fail_5

        movei   1,0303240
        pushj   17,kfmt_u18_sixbit
        camn    1,[0212020202020]
        caie    2,6
        jrst    kfmt_fail_6

        movei   1,0777777
        pushj   17,kfmt_u18_sixbit
        camn    1,[0222622212423]
        caie    2,6
        jrst    kfmt_fail_7
        halt    .

kfmt_fail_1:   movei 1,1
               jrst kfmt_fail
kfmt_fail_2:   movei 1,2
               jrst kfmt_fail
kfmt_fail_3:   movei 1,3
               jrst kfmt_fail
kfmt_fail_4:   movei 1,4
               jrst kfmt_fail
kfmt_fail_5:   movei 1,5
               jrst kfmt_fail
kfmt_fail_6:   movei 1,6
               jrst kfmt_fail
kfmt_fail_7:   movei 1,7
kfmt_fail:
        movem   1,__test_exit
        halt    .

        .bss
stack:          .block 0100
__test_exit:    .block 1
