.text
.globl main
.globl d6codec_v061_decode
.globl v074_stream
.globl v074_input_count
.globl v074_expected
main:
 movei 1,v074_stream
 move 2,v074_input_count
 movei 3,v074_output
 movei 4,v074_output+0536
 movei 5,v074_output
 pushj 17,d6codec_v061_decode
 jumpn 1,v074_fail
 movei 6,0
v074_check:
 move 7,v074_output(6)
 came 7,v074_expected(6)
 jrst v074_fail
 aoj 6,
 caige 6,0536
 jrst v074_check
 setz 1,
 popj 17,
v074_fail:
 movei 1,1
 popj 17,
.bss
v074_output: .block 0536
.globl __test_exit
__test_exit: .block 1
