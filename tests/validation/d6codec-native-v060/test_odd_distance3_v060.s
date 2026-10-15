/* v060: odd halfword distance three across two literal words. */
.text
.globl main
.globl d6codec_v059_decode
main:
 movei 1,stream
 movei 2,4
 movei 3,outbuf
 movei 4,3
 pushj 17,d6codec_v059_decode
 jumpn 1,fail
 move 0,outbuf+2
 came 0,[0670123076543]
 jrst fail
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
.data
stream:
 .word 0031000000000
 .word 0401003000000
 .word 0012345670123
 .word 0076543210765
.bss
outbuf: .block 3
.globl __test_exit
__test_exit: .block 1
