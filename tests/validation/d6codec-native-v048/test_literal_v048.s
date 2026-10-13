/* v048: literal: valid */
.text
.globl main
.globl d6v048_decode
main:
 move 0,[012345670123]
 movem 0,guard
 movei 1,stream
 movei 2,02
 movei 3,outbuf
 movei 4,01
 pushj 17,d6v048_decode
 jumpn 1,fail
 jrst check_guard
check_guard:
 move 0,guard
 came 0,[012345670123]
 jrst fail
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
.data
stream:
 .word 010000000000
 .word 052
.bss
outbuf: .block 01
guard: .block 1
.globl __test_exit
__test_exit: .block 1
