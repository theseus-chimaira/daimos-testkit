/* v048: empty_missing: reject */
.text
.globl main
.globl d6v048_decode
main:
 move 0,[012345670123]
 movem 0,guard
 movei 1,stream
 movei 2,00
 movei 3,outbuf
 movei 4,01
 pushj 17,d6v048_decode
 camn 1,[-1]
 jrst check_guard
 jrst fail
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
 .word 0
.bss
outbuf: .block 01
guard: .block 1
.globl __test_exit
__test_exit: .block 1
