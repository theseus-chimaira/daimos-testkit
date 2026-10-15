/* v061: two complete groups; NEED_INPUT only between groups. */
.text
.globl main
.globl d6codec_v061_decode
main:
 movei 1,first_group
 movei 2,2
 movei 3,outbuf
 movei 4,outbuf+3
 movei 5,outbuf
 pushj 17,d6codec_v061_decode
 caie 1,1
 jrst fail
 caie 3,outbuf+1
 jrst fail
 movei 1,second_group
 movei 2,2
 pushj 17,d6codec_v061_decode
 jumpn 1,fail
 caie 3,outbuf+3
 jrst fail
 move 0,outbuf
 came 0,[0012345670123]
 jrst fail
 move 0,outbuf+1
 came 0,[0670123670123]
 jrst fail
 move 0,outbuf+2
 came 0,[0670123670123]
 jrst fail
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
.data
first_group:
 .word 0010000000000
 .word 0012345670123
second_group:
 .word 0014000000000
 .word 0402001000000
.bss
outbuf: .block 3
.globl __test_exit
__test_exit: .block 1
