/* Native PDP-6 link and invocation test of v079 codec callback bindings.
 * Transaction stubs call the actual v078 codec; this is not an MM test.
 */
.text
.globl main
.globl proc_packed_evict_transaction_v077
.globl proc_packed_restore_transaction_v46
.globl vfs_read_words
main:
        movei 1,d6i67_image_start
        hrl 1,1
        hrri 1,000060
        blt 1,000060+(d6i67_image_end-d6i67_image_start)-1
        movei 1,1
        setz 2,
        pushj 17,proc_packed_inline_evict_v079
        jumpn 1,fail_evict
        movei 1,1
        movei 2,012345
        movei 3,dummy_reload
        pushj 17,proc_packed_inline_restore_v079
        jumpn 1,fail_restore
        movei 5,0
compare:
        move 6,source(5)
        came 6,decoded(5)
        jrst fail_compare
        aoj 5,
        caige 5,6
        jrst compare
        setz 1,
        popj 17,
fail_evict:
        movei 1,2
        popj 17,
fail_restore:
        movei 1,3
        popj 17,
fail_compare:
        movei 1,4
        popj 17,
fail:
        movei 1,1
        popj 17,
proc_packed_evict_transaction_v077:
        movem 4,encoder_ptr_v079
        movei 1,source
        movei 2,6
        pushj 17,0(3)                 ; invoke native size callback
        jumple 1,fail
        movem 1,encoded_size_v079
        movei 1,source
        movei 2,6
        movei 3,encoded
        move 4,encoded_size_v079
        move 5,encoder_ptr_v079
        pushj 17,0(5)                 ; invoke native encoder callback
        came 1,encoded_size_v079
        jrst fail_size
        move 6,encoded
        jumpe 6,fail_no_header
        setz 1,
        popj 17,
fail_no_header:
        movei 1,6
        popj 17,
fail_size:
        movei 1,5
        popj 17,
proc_packed_restore_transaction_v46:
        movem 3,decoder_ptr_v079
        movei 1,encoded
        move 2,encoded_size_v079
        movei 3,decoded
        movei 4,6
        move 5,decoder_ptr_v079
        pushj 17,0(5)                 ; invoke native decoder callback
        caie 1,6
        popj 17,
        setz 1,
        popj 17,
dummy_reload:
        setz 1,
        popj 17,
vfs_read_words:
        seto 1,
        popj 17,
.data
source:
        .word 012345023456
        .word 0
        .word 0
        .word 0
        .word 012345023456
        .word 012345023456
.bss
encoded: .block 32
decoded: .block 6
encoder_ptr_v079: .block 1
decoder_ptr_v079: .block 1
encoded_size_v079: .block 1
.globl __test_exit
__test_exit: .block 1
