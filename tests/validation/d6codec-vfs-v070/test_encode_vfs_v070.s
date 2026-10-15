/* v070: native encoder -> vnode read callback -> grouped VFS decoder. */
.text
.globl main
.globl d6codec_v053_encode_literals
.globl d6codec_vfs_v062
.globl vfs_read_words
main:
 movei 1,source
 movei 2,0132
 movei 3,encoded
 movei 4,200
 pushj 17,d6codec_v053_encode_literals
 jumpl 1,fail
 movem 1,compressed_words
 move 3,1
 movei 1,1
 movei 2,0
 move 4,[0132,,decoded]
 pushj 17,d6codec_vfs_v062
 jumpn 1,fail
 movei 5,0
check:
 move 6,decoded(5)
 came 6,source(5)
 jrst fail
 aoj 5,
 caige 5,0132
 jrst check
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
/* Synthetic vnode read: seven compressed words maximum per call. */
vfs_read_words:
 caie 1,1
 jrst read_bad
 move 6,compressed_words
 sub 6,2
 camle 4,6
 move 4,6
 caile 4,7
 movei 4,7
 jumple 4,read_bad
 move 5,4
 movei 6,encoded
 add 6,2
read_loop:
 move 0,(6)
 movem 0,(3)
 aoj 6,
 aoj 3,
 sojg 5,read_loop
 move 1,4
 popj 17,
read_bad:
 seto 1,
 popj 17,
.data
source:
 .word 0000007654321
 .word 0000007666666
 .word 0000007701233
 .word 0000007713600
 .word 0000007726145
 .word 0000007740512
 .word 0000007753057
 .word 0000007765424
 .word 0000007777771
 .word 0000010012336
 .word 0000010024703
 .word 0000010037250
 .word 0000010051615
 .word 0000010064162
 .word 0000010076527
 .word 0000010111074
 .word 0000010123441
 .word 0000010136006
 .word 0000010150353
 .word 0000010162720
 .word 0000010175265
 .word 0000010207632
 .word 0000010222177
 .word 0000010234544
 .word 0000010247111
 .word 0000010261456
 .word 0000010274023
 .word 0000010306370
 .word 0000010320735
 .word 0000010333302
 .word 0000010345647
 .word 0000010360214
 .word 0000010372561
 .word 0000010405126
 .word 0000010417473
 .word 0000010432040
 .word 0000010444405
 .word 0000010456752
 .word 0000010471317
 .word 0000010503664
 .word 0000010516231
 .word 0000010530576
 .word 0000010543143
 .word 0000010555510
 .word 0000010570055
 .word 0000010602422
 .word 0000010614767
 .word 0000010627334
 .word 0000010641701
 .word 0000010654246
 .word 0000010666613
 .word 0000010701160
 .word 0000010713525
 .word 0000010726072
 .word 0000010740437
 .word 0000010753004
 .word 0000010765351
 .word 0000010777716
 .word 0000011012263
 .word 0000011024630
 .word 0000011037175
 .word 0000011051542
 .word 0000011064107
 .word 0000011076454
 .word 0000011111021
 .word 0000011123366
 .word 0000011135733
 .word 0000011150300
 .word 0000011162645
 .word 0000011175212
 .word 0000011207557
 .word 0000011222124
 .word 0000011234471
 .word 0000011247036
 .word 0000011261403
 .word 0000011273750
 .word 0000011306315
 .word 0000011320662
 .word 0000011333227
 .word 0000011345574
 .word 0000011360141
 .word 0000011372506
 .word 0000011405053
 .word 0000011417420
 .word 0000011431765
 .word 0000011444332
 .word 0000011456677
 .word 0000011471244
 .word 0000011503611
 .word 0000011516156
.bss
compressed_words: .block 1
encoded: .block 200
decoded: .block 0132
.globl __test_exit
__test_exit: .block 1
