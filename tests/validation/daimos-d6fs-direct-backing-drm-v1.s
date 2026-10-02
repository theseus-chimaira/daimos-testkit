        .text
        .globl  main
        .globl  fs_backing_direct_read
        .globl  fs_backing_direct_write
        .globl  fs_backing_direct_read_jump
        .globl  fs_backing_direct_write_jump
        .globl  fs_backing_direct_drm_read_jump
        .globl  fs_backing_direct_drm_write_jump
        .globl  __test_exit

main:
        ; The production DRM slots default to failure before MINIT patches them.
        move    1,[0400002,,0400]
        movei   2,7
        movei   3,buffer
        pushj   17,fs_backing_direct_read
        came    1,[-1]
        jrst    backing_fail

        ; Patch the same four jump words MINIT patches in a live kernel.
        movei   1,test_dsk_read
        hrrm    1,fs_backing_direct_read_jump
        movei   1,test_dsk_write
        hrrm    1,fs_backing_direct_write_jump
        movei   1,test_drm_read
        hrrm    1,fs_backing_direct_drm_read_jump
        movei   1,test_drm_write
        hrrm    1,fs_backing_direct_drm_write_jump

        ; Historical untagged opaque value remains DSK unit,,base.
        move    1,[2,,0400]
        movei   2,7
        movei   3,buffer
        pushj   17,fs_backing_direct_read
        caie    1,011
        jrst    backing_fail
        move    1,seen_kind
        caie    1,1
        jrst    backing_fail
        move    1,seen_unit
        caie    1,2
        jrst    backing_fail
        move    1,seen_block
        caie    1,0407
        jrst    backing_fail
        move    1,seen_buffer
        caie    1,buffer
        jrst    backing_fail

        ; Tagged opaque value selects DRM and strips the tag before dispatch.
        move    1,[0400003,,0100]
        movei   2,5
        movei   3,buffer
        pushj   17,fs_backing_direct_read
        caie    1,022
        jrst    backing_fail
        move    1,seen_kind
        caie    1,2
        jrst    backing_fail
        move    1,seen_unit
        caie    1,3
        jrst    backing_fail
        move    1,seen_block
        caie    1,0105
        jrst    backing_fail

        move    1,[1,,0200]
        movei   2,3
        movei   3,buffer
        pushj   17,fs_backing_direct_write
        caie    1,033
        jrst    backing_fail
        move    1,seen_kind
        caie    1,3
        jrst    backing_fail
        move    1,seen_unit
        caie    1,1
        jrst    backing_fail
        move    1,seen_block
        caie    1,0203
        jrst    backing_fail

        move    1,[0400000,,0600]
        movei   2,4
        movei   3,buffer
        pushj   17,fs_backing_direct_write
        caie    1,044
        jrst    backing_fail
        move    1,seen_kind
        caie    1,4
        jrst    backing_fail
        move    1,seen_unit
        jumpn   1,backing_fail
        move    1,seen_block
        caie    1,0604
        jrst    backing_fail

        ; Multi-DRM uses the same one-block equal-size INTERLEAVE policy as
        ; BLOCKSET.  Mask 0015 selects physical units 0, 2, and 3.
        move    1,[0600015,,0100]
        movei   2,1                     ; ordinal member 1 -> physical unit 2
        movei   3,buffer
        pushj   17,fs_backing_direct_read
        caie    1,022
        jrst    backing_fail
        move    1,seen_unit
        caie    1,2
        jrst    backing_fail
        move    1,seen_block
        caie    1,0100
        jrst    backing_fail

        move    1,[0600015,,0100]
        movei   2,010                   ; 010 / 3 = block 2, member 2 -> unit 3
        movei   3,buffer
        pushj   17,fs_backing_direct_write
        caie    1,044
        jrst    backing_fail
        move    1,seen_unit
        caie    1,3
        jrst    backing_fail
        move    1,seen_block
        caie    1,0102
        jrst    backing_fail

        ; A set tag without members is rejected before any leaf-driver call.
        move    1,[0600000,,0100]
        movei   2,1
        movei   3,buffer
        pushj   17,fs_backing_direct_read
        came    1,[-1]
        jrst    backing_fail

        setz    1,
        popj    17,

backing_fail:
        movei   1,1
        popj    17,

; Backend ABI after the direct adapter: AC1=unit, AC2=physical block,
; AC3=buffer.  Each stub records arguments and returns a distinct value.
test_dsk_read:
        movei   4,1
        movei   5,011
        jrst    backing_record

test_drm_read:
        movei   4,2
        movei   5,022
        jrst    backing_record

test_dsk_write:
        movei   4,3
        movei   5,033
        jrst    backing_record

test_drm_write:
        movei   4,4
        movei   5,044

backing_record:
        movem   4,seen_kind
        movem   1,seen_unit
        movem   2,seen_block
        movem   3,seen_buffer
        move    1,5
        popj    17,

        .bss
seen_kind:      .block  1
seen_unit:      .block  1
seen_block:     .block  1
seen_buffer:    .block  1
buffer:         .block  0200
__test_exit:    .block  1
