/* v081 exact compressed count; provider returns only two words each call. */
.text
.globl main
.globl vfs_read_words
.globl d6codec_vfs_v062
main:
 ; Valid single-literal group: two compressed words.
 movei 1,1
 movei 2,0
 movei 3,2
 move 4,[1,,outbuf]
 pushj 17,d6codec_vfs_v062
 jumpn 1,fail
 move 0,outbuf
 came 0,[012345670123]
 jrst fail
 ; An additional compressed word, not yet fetched, must be rejected.
 movei 1,1
 movei 2,0
 movei 3,3
 move 4,[1,,outbuf]
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
vfs_read_words:
 caie 1,1
 jrst vf_bad
 move 6,2
 add 6,4
 caile 6,3
 jrst vf_bad
 caile 4,2
 movei 4,2
 move 5,4
 movei 6,stream
 add 6,2
vf_loop:
 move 0,(6)
 movem 0,(3)
 aoj 6,
 aoj 3,
 sojg 5,vf_loop
 move 1,4
 popj 17,
vf_bad:
 seto 1,
 popj 17,
.data
stream:
 .word 010000000000
 .word 012345670123
 .word 0777777777777
.bss
outbuf: .block 1
.globl __test_exit
__test_exit: .block 1
