; Production PDP-6 MM pin/free contract, exercised by p10run.
.text
.globl main
main:
        movei   010,1
        movei   1,1
        movem   1,mm_extent_count
        move    1,[02000,,04000]
        movem   1,mm_extents
        move    1,[01,,07]
        movem   1,mm_extents+1
        movei   1,04000
        pushj   17,mm_unpin
        came    1,[-4]
        jrst    failed
        movei   010,2
        movei   1,04000
        pushj   17,mm_pin
        jumpn   1,failed
        movei   010,3
        movei   1,04000
        pushj   17,mm_is_pinned
        caie    1,1
        jrst    failed
        movei   010,4
        movei   1,04000
        movei   2,1
        movei   3,7
        pushj   17,mm_free
        came    1,[-5]
        jrst    failed
        movei   010,5
        move    1,mm_extent_count
        caie    1,1
        jrst    failed
        movei   010,6
        ; Saturated pin field must reject increment without changing meta.
        move    1,[03771,,07]       ; 255 pins + type 1 + owner 7
        movem   1,mm_extents+1
        movei   1,04000
        pushj   17,mm_pin
        came    1,[-5]
        jrst    failed
        movei   010,7
        move    1,mm_extents+1
        tlne    1,03770
        jrst    saturated
        jrst    failed
saturated:
        movei   010,010
        ; Reduce to one pin, release, then allow exact owner/type free.
        move    1,[011,,07]         ; one pin + type 1 + owner 7
        movem   1,mm_extents+1
        movei   1,04000
        pushj   17,mm_unpin
        jumpn   1,failed
        movei   010,011
        movei   1,04000
        pushj   17,mm_is_pinned
        jumpn   1,failed
        movei   010,10
        movei   1,04000
        movei   2,1
        movei   3,6
        pushj   17,mm_free
        came    1,[-4]
        jrst    failed
        movei   010,11
        movei   1,04000
        movei   2,1
        movei   3,7
        pushj   17,mm_free
        jumpn   1,failed
        movei   010,12
        move    1,mm_extent_count
        jumpn   1,failed
        setz    1,
        popj    17,
failed:
        move    1,010
        popj    17,
.bss
.globl mm_extent_count
.globl mm_extents
mm_extent_count: .block 1
mm_extents: .block 4
.globl mm_extent_capacity
mm_extent_capacity: .word 2
.globl __test_exit
__test_exit: .block 1
