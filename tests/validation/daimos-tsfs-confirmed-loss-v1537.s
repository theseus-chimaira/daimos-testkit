; Native PDP-6 test of the real KCORE TSFS loss-owner dispatch.
; A trusted event is explicitly supplied here. No controller error or
; watchdog is treated as positive physical evidence by this fixture.
        .text
        .globl  main
        .globl  tsfs_confirmed_root_member_loss_v1537
        .globl  __test_exit
        .globl  vfs_namespace_root
        .globl  vfs_mount_limit
        .globl  tsfs_file_shape_base

main:
        move    4,test_mask_v1537
        lsh     4,030
        movem   4,tsfs_shape_v1537+3
        move    1,test_unit_v1537
        pushj   17,tsfs_confirmed_root_member_loss_v1537
        camn    1,test_expected_v1537
        jrst    pass_v1537
        movei   1,7
        popj    17,
pass_v1537:
        setz    1,
        popj    17,

        .data
test_unit_v1537: .word 0
test_mask_v1537: .word 041
test_expected_v1537: .word 0
vfs_namespace_root: .word 070401000000
vfs_mount_limit: .word 6
tsfs_file_shape_base: .word tsfs_shape_v1537
tsfs_shape_v1537: .block 010

        .bss
__test_exit: .block 1
