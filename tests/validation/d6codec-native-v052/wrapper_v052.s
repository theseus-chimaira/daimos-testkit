/* v052: candidate assembly ABI wrapper; AC10..AC15 callee saved.
 * Production linkage intentionally deferred until boot-format atomic switch.
 */
.text
.globl d6v052_kernel_encode
.globl d6v052_kernel_decode
.globl d6v052_encode_literals
.globl d6v052_decode
d6v052_kernel_encode:
 push 17,10
 push 17,11
 push 17,12
 push 17,13
 push 17,14
 push 17,15
 pushj 17,d6v052_encode_literals
 jrst d6v052_restore
d6v052_kernel_decode:
 push 17,10
 push 17,11
 push 17,12
 push 17,13
 push 17,14
 push 17,15
 pushj 17,d6v052_decode
d6v052_restore:
 pop 17,15
 pop 17,14
 pop 17,13
 pop 17,12
 pop 17,11
 pop 17,10
 popj 17,
