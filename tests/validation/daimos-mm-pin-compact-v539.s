; Real PDP-6 compact/find-fit/descriptor/VM/FS/runqueue in one transaction.
.text
.globl main
main:
        movei 1,4
        movem 1,mm_extent_capacity
        movei 1,3
        movem 1,mm_extent_count
        movei 1,1
        movem 1,mm_arena_count
        move 1,[012000,,010000]
        movem 1,mm_arenas
        move 1,[02000,,010000]
        movem 1,mm_extents
        move 1,[02,,0]
        movem 1,mm_extents+1
        move 1,[02000,,014000]
        movem 1,mm_extents+2
        move 1,[011,,01]  ; pin count 1, process type 1
        movem 1,mm_extents+3
        move 1,[02000,,016000]
        movem 1,mm_extents+4
        move 1,[02,,0]
        movem 1,mm_extents+5
        movei 1,proc_records
        movem 1,proc_table
        movei 1,7
        movem 1,proc_current_slot
        move 1,[026000,,0400000]
        movem 1,proc_records+3
        movei 1,014000
        movem 1,proc_records+4
        move 1,[0200000,,0]
        movem 1,proc_records+5
        setzm 026024
        movei 1,1
        movem 1,proc_runq_head
        movei 1,012345
        movem 1,014000
        movei 1,076543
        movem 1,015777
        movei 1,04000
        movei 2,02000
        pushj 17,mm_compact
        came 1,[-2]             ; fragmentation while process pinned
        jrst bad1
        move 1,proc_records+4
        caie 1,014000
        jrst bad1
        move 1,mm_extents+2
        came 1,[02000,,014000]
        jrst bad1
        ; Remove the pin and retry the exact same real compact path.
        move 1,[01,,01]
        movem 1,mm_extents+3
        movei 1,04000
        movei 2,02000
        pushj 17,mm_compact
        jumpn 1,bad1
        move 1,proc_records+4
        caie 1,020000
        jrst bad2
        move 1,020000
        caie 1,012345
        jrst bad3
        move 1,021777
        caie 1,076543
        jrst bad4
        move 1,proc_runq_head
        caie 1,1
        jrst bad5
        move 1,proc_records+5
        hlrz 2,1
        andi 2,0700000
        caie 2,0200000
        jrst bad6
        move 1,mm_extents+2
        came 1,[02000,,016000]
        jrst bad7
        move 1,mm_extents+4
        came 1,[02000,,020000]
        jrst bad8
        setz 1,
        popj 17,
bad1: movei 1,1
        popj 17,
bad2: movei 1,2
        popj 17,
bad3: movei 1,3
        popj 17,
bad4: movei 1,4
        popj 17,
bad5: movei 1,5
        popj 17,
bad6: movei 1,6
        popj 17,
bad7: movei 1,7
        popj 17,
bad8: movei 1,010
        popj 17,
.globl mach_pi_disable
mach_pi_disable:
        movei 1,0123
        popj 17,
.globl mach_pi_restore
mach_pi_restore:
        popj 17,
.bss
.globl mm_extent_count
.globl mm_extent_capacity
.globl mm_extents
.globl mm_arena_count
.globl mm_arenas
.globl proc_table
.globl proc_current_slot
.globl proc_runq_head
mm_extent_count: .block 1
mm_extent_capacity: .block 1
mm_extents: .block 010
mm_arena_count: .block 1
mm_arenas: .block 3
proc_table: .block 1
proc_records: .block 6
proc_current_slot: .block 1
proc_runq_head: .block 1
.globl __test_exit
__test_exit: .block 1
