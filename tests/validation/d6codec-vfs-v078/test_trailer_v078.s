/* Native VFS stub forces short reads, tests a split grouped stream. */
.text
.globl main
.globl vfs_read_words
.globl d6codec_vfs_v062
main:
 movei 1,1
 movei 2,0
 movei 3,4
 move 4,[3,,outbuf]
 pushj 17,d6codec_vfs_v062
 jumpn 1,fail
 move 0,outbuf
 came 0,[012345670123]
 jrst fail
 move 0,outbuf+1
 came 0,[0670123670123]
 jrst fail
 move 0,outbuf+2
 came 0,[0670123670123]
 jrst fail
 ; Exact output with an unread declared trailer MUST fail.
 ; The provider does have five words; the fifth must not be ignored.
 movei 1,1
 movei 2,0
 movei 3,5
 move 4,[3,,outbuf]
 pushj 17,d6codec_vfs_v062
 camn 1,[-1]
 jrst check_short
 jrst fail
check_short:
 ; A truncated source must also fail, not report NEED_INPUT success.
 movei 1,1
 movei 2,0
 movei 3,3
 move 4,[3,,outbuf]
 pushj 17,d6codec_vfs_v062
 camn 1,[-1]
 jrst pass
 jrst fail
pass:
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
/* VFS: AC1 vnode, AC2 offset, AC3 destination, AC4 requested.
 * Returns a maximum of one word per read to force group fragmentation. */
vfs_read_words:
 caie 1,1
 jrst vf_bad
 caige 2,5
 jrst vf_ok
vf_bad:
 seto 1,
 popj 17,
vf_ok:
 move 0,stream(2)
 movem 0,(3)
 movei 1,1
 popj 17,
.data
stream:
 .word 010000000000
 .word 012345670123
 .word 014000000000
 .word 0402001000000
 .word 0777777777777
.bss
outbuf: .block 3
.globl __test_exit
__test_exit: .block 1
