/* Native PDP-6 grouped stream: control/literal/descriptor split windows. */
        .text
        .globl main
        .globl d6codec_stream_v1361
main:
        ; Two-word literal stream, one input word per invocation.
        movei   1,state
        setzm   0(1)
        movei   0,outbuf
        movem   0,1(1)
        movem   0,3(1)
        aoj     0,
        movem   0,2(1)
        movei   0,2
        movem   0,4(1)
        movei   2,literal_stream
        movei   3,1
        pushj   17,d6codec_stream_v1361
        caie    0,1
        jrst    fail1
        movei   3,1
        pushj   17,d6codec_stream_v1361
        jumpn   0,fail2
        move    0,outbuf
        came    0,[052]
        jrst    fail3
        ; A one-token zero run requires two compressed words.
        ; Split between control and the descriptor word.
        movei   1,state
        setzm   0(1)
        movei   0,outbuf
        movem   0,1(1)
        movem   0,3(1)
        aoj     0,
        movem   0,2(1)
        movei   0,2
        movem   0,4(1)
        move    0,[012345670123]
        movem   0,outbuf
        movei   2,zero_stream
        movei   3,1
        pushj   17,d6codec_stream_v1361
        caie    0,1
        jrst    fail4
        movei   3,1
        pushj   17,d6codec_stream_v1361
        jumpn   0,fail5
        skipn   outbuf
        jrst    test_max_descriptors
        jrst    fail6
test_max_descriptors:
        ; 30 zero-run tokens, 15 packed descriptor words, 16 refills.
        movei   1,state
        setzm   0(1)
        movei   0,long_output
        movem   0,1(1)
        movem   0,3(1)
        addi    0,036
        movem   0,2(1)
        movei   0,020
        movem   0,4(1)
        movei   2,allzero_stream
max_feed:
        movei   3,1
        pushj   17,d6codec_stream_v1361
        skipn   4(1)
        jrst    max_done
        caie    0,1
        jrst    fail7
        jrst    max_feed
max_done:
        jumpn   0,fail8
        movei   5,0
max_verify:
        skipn   long_output(5)
        jrst    max_next
        jrst    fail9
max_next:
        aoj     5,
        caige   5,036
        jrst    max_verify
        ; Invalid group count must fail without altering output.
        movei   1,state
        setzm   0(1)
        movei   0,outbuf
        movem   0,1(1)
        movem   0,3(1)
        aoj     0,
        movem   0,2(1)
        movei   0,1
        movem   0,4(1)
        move    0,[012345670123]
        movem   0,outbuf
        movei   2,bad_control
        movei   3,1
        pushj   17,d6codec_stream_v1361
        camn    0,[-1]
        jrst    verify_invalid_guard
        jrst    fail10
verify_invalid_guard:
        move    0,outbuf
        came    0,[012345670123]
        jrst    fail10
        ; Invalid exclusive output endpoint must be rejected early.
        movei   1,state
        move    0,[01000001]
        movem   0,2(1)
        movei   2,bad_control
        movei   3,1
        pushj   17,d6codec_stream_v1361
        camn    0,[-1]
        jrst    success
        jrst    fail11
success:
        setz    1,
        popj    17,
fail1:  movei 1,1
        popj 17,
fail2:  movei 1,2
        popj 17,
fail3:  movei 1,3
        popj 17,
fail4:  movei 1,4
        popj 17,
fail5:  movei 1,5
        popj 17,
fail6:  movei 1,6
        popj 17,
fail7:  movei 1,7
        popj 17,
fail8:  movei 1,010
        popj 17,
fail9:  movei 1,011
        popj 17,
fail10: movei 1,012
        popj 17,
fail11: movei 1,013
        popj 17,
        .data
literal_stream:
        .word 010000000000
        .word 052
zero_stream:
        .word 014000000000
        .word 0201000000000
allzero_stream:
        .word 0367777777777
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
        .word 0201000201000
bad_control:
        .word 0
        .bss
state: .block 032
outbuf: .block 1
long_output: .block 036
        .globl __test_exit
__test_exit: .block 1
