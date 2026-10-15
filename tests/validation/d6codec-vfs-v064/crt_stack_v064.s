/* Versioned PDP-6 CRT: fill stack guard region, then inspect it after main. */
.text
__start:
 movei 010,0
 movei 011,01777
stack_fill:
 move 012,[012345670123]
 movem 012,__v064_stack(010)
 aoj 010,
 caige 010,01000
 jrst stack_fill
 movei 017,__v064_stack-01
 hrli 017,-01000
 movei 01,01
 movem 01,__test_exit
 pushj 017,main
 movem 01,__test_exit
 movei 010,0777
stack_scan:
 move 012,__v064_stack(010)
 came 012,[012345670123]
 jrst stack_used
 sojge 010,stack_scan
 setz 010,
 jrst stack_store
stack_used:
 aoj 010,
stack_store:
 movem 010,__v064_first_changed
 jrst 04,0
.bss
.globl __v064_first_changed
__v064_first_changed: .block 1
__v064_stack: .block 01000
