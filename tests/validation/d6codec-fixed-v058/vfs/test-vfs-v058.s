/* Mock VFS forces new-format group refill across a two-word read. */
.text
.globl main
.globl vfs_read_words
main:
        movei 1,d6codec_image_start
        hrl 1,1
        hrri 1,000060
        blt 1,000060+(d6codec_image_end-d6codec_image_start)-1
        movei 1,1
        setz 2,
        movei 3,3
        move 4,[3,,output]
        pushj 17,d6codec_decode_vfs_v058
        jumpn 1,fail
        movei 5,0
check:
        move 6,output(5)
        came 6,expected(5)
        jrst fail
        aoj 5,
        caige 5,3
        jrst check
        movei 1,2
        setz 2,
        movei 3,037
        move 4,[036,,output30]
        pushj 17,d6codec_decode_vfs_v058
        jumpn 1,fail
        movei 5,0
check30:
        move 6,output30(5)
        came 6,expected30(5)
        jrst fail
        aoj 5,
        caige 5,036
        jrst check30
        setz 1,
        popj 17,
fail:
        movei 1,1
        popj 17,
/* AC1 vnode, AC2 offset, AC3 destination, AC4 requested count. */
vfs_read_words:
        movei 5,3
        caie 1,1
        movei 5,037
        sub 5,2
        jumple 5,vfs_eof
        caile 5,2
        movei 5,2
        camle 5,4
        move 5,4
        movei 6,0
vfs_copy:
        caie 1,1
        jrst vfs_copy30
        move 7,stream(2)
        jrst vfs_store
vfs_copy30:
        move 7,stream30(2)
vfs_store:
        movem 7,0(3)
        aoj 2,
        aoj 3,
        aoj 6,
        caml 6,5
        jrst vfs_finished
        jrst vfs_copy
vfs_finished:
        move 1,5
        popj 17,
vfs_eof:
        setz 1,
        popj 17,

.data
stream:
        .word 022000000000
        .word 0402001000000
        .word 012345023456
expected:
        .word 012345023456
        .word 023456023456
        .word 023456023456
stream30:
        .word 0360000000000
        .word 000000000001
        .word 000000000002
        .word 000000000003
        .word 000000000004
        .word 000000000005
        .word 000000000006
        .word 000000000007
        .word 000000000010
        .word 000000000011
        .word 000000000012
        .word 000000000013
        .word 000000000014
        .word 000000000015
        .word 000000000016
        .word 000000000017
        .word 000000000020
        .word 000000000021
        .word 000000000022
        .word 000000000023
        .word 000000000024
        .word 000000000025
        .word 000000000026
        .word 000000000027
        .word 000000000030
        .word 000000000031
        .word 000000000032
        .word 000000000033
        .word 000000000034
        .word 000000000035
        .word 000000000036
expected30:
        .word 000000000001
        .word 000000000002
        .word 000000000003
        .word 000000000004
        .word 000000000005
        .word 000000000006
        .word 000000000007
        .word 000000000010
        .word 000000000011
        .word 000000000012
        .word 000000000013
        .word 000000000014
        .word 000000000015
        .word 000000000016
        .word 000000000017
        .word 000000000020
        .word 000000000021
        .word 000000000022
        .word 000000000023
        .word 000000000024
        .word 000000000025
        .word 000000000026
        .word 000000000027
        .word 000000000030
        .word 000000000031
        .word 000000000032
        .word 000000000033
        .word 000000000034
        .word 000000000035
        .word 000000000036
.bss
output30: .block 036
output: .block 3
.globl __test_exit
__test_exit: .block 1
