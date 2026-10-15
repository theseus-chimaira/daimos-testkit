/* v061: output completion with trailing input is an error. */
.text
.globl main
.globl d6codec_v061_decode
main:
 movei 1,stream
 movei 2,3
 movei 3,outbuf
 movei 4,outbuf+1
 movei 5,outbuf
 pushj 17,d6codec_v061_decode
 camn 1,[-1]
 jrst pass
 movei 1,1
 popj 17,
pass:
 setz 1,
 popj 17,
.data
stream:
 .word 010000000000
 .word 012345670123
 .word 010000000000
.bss
outbuf: .block 1
.globl __test_exit
__test_exit: .block 1
