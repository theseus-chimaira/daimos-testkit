/* v048: even_half_copy: valid */
.text
.globl main
.globl d6v048_decode
main:
 move 0,[012345670123]
 movem 0,guard
 movei 1,stream
 movei 2,03
 movei 3,outbuf
 movei 4,04
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
 .word 022000000000
 .word 0403002000000
 .word 052
.bss
outbuf: .block 04
guard: .block 1
.globl __test_exit
__test_exit: .block 1
