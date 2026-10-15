/* Verify actual low-core relocation and grouped decoding at 000060. */
.text
.globl main
.globl d6lz_image_start
.globl d6lz_image_end
main:
 movei 1,d6lz_image_start
 hrl 1,1
 hrri 1,000060
 blt 1,000060+(d6lz_image_end-d6lz_image_start)-1
 movei 1,stream
 movei 2,4
 movei 3,output
 movei 4,output+3
 movei 5,output
 pushj 17,000060
 jumpn 1,fail
 move 0,output
 came 0,[012345670123]
 jrst fail
 move 0,output+1
 came 0,[0670123670123]
 jrst fail
 move 0,output+2
 came 0,[0670123670123]
 jrst fail
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
.data
stream:
 .word 010000000000
 .word 012345670123
 .word 014000000000
 .word 0402001000000
.bss
output: .block 3
.globl __test_exit
__test_exit: .block 1
