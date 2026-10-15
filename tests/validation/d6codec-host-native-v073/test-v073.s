.text
.globl main
.globl d6codec_v061_decode
.globl v073_stream
.globl v073_input_count
.globl v073_expected
main:
 movei 1,v073_stream
 move 2,v073_input_count
 movei 3,v073_output
 movei 4,v073_output+0536
 movei 5,v073_output
 pushj 17,d6codec_v061_decode
 jumpn 1,v073_fail
 movei 6,0
v073_check:
 move 7,v073_output(6)
 came 7,v073_expected(6)
 jrst v073_fail
 aoj 6,
 caige 6,0536
 jrst v073_check
 setz 1,
 popj 17,
v073_fail:
 movei 1,1
 popj 17,
.bss
v073_output: .block 0536
.globl __test_exit
__test_exit: .block 1
