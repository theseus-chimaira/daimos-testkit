.text
__start:
	movei 017,__kcc_test_stack-01
	hrli 017,-01000
	movei 01,01
	movem 01,__test_exit
	pushj 017,main
	movem 01,__test_exit
	jrst 04,0

.bss
__kcc_test_stack:
	.block 01000
