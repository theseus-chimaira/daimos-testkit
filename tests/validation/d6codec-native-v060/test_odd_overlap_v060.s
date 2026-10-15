/* v060: literal followed by two odd halfword distance-one copies. */
.text
.globl main
.globl d6codec_v059_decode
main:
 movei 1,stream
 movei 2,3
 movei 3,outbuf
 movei 4,3
 pushj 17,d6codec_v059_decode
 jumpn 1,fail_decode
 move 0,outbuf
 came 0,[012345670123]
 jrst fail_literal
 move 0,outbuf+1
 came 0,[670123670123]
 jrst fail_first
 move 0,outbuf+2
 came 0,[670123670123]
 jrst fail_second
 setz 1,
 popj 17,
fail_decode:
 movei 1,1
 popj 17,
fail_literal:
 movei 1,2
 popj 17,
fail_first:
 movei 1,3
 popj 17,
fail_second:
 movei 1,4
 popj 17,
.data
stream:
 .word 022000000000
 .word 0402001000000
 .word 012345670123
.bss
.globl outbuf
outbuf: .block 1
.globl out1
out1: .block 1
.globl out2
out2: .block 1
.globl __test_exit
__test_exit: .block 1
