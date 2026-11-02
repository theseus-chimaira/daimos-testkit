.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Multi-pin u-area: physical pin count 3 is diagnostic, not a
 ; license to free even one pin or mutate the extent on failed free.
 move 4,[033,,01001]
 movem 4,mm_extents+1
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 caie 1,016
 jrst fail_1
 move 4,mm_extents+1
 camn 4,[033,,01001]
 jrst v955_pins_stable
 jrst fail_1
v955_pins_stable:
 movei 1,__uarea
 movei 2,3
 movei 3,01001
 pushj 17,mm_free
 camn 1,[-5]
 jrst v955_busy_stable
 jrst fail_1
v955_busy_stable:
 move 4,mm_extents+1
 camn 4,[033,,01001]
 jrst v955_restore_one_pin
 jrst fail_1
v955_restore_one_pin:
 move 4,[023,,01001]
 movem 4,mm_extents+1
 ; A pinned u-area returns MM_ERR_BUSY, without losing its extent.
 movei 1,__uarea
 movei 2,3
 movei 3,01001
 pushj 17,mm_free
 camn 1,[-5]
 jrst test_busy_snapshot
 jrst fail_1
test_busy_snapshot:
 move 1,mm_extent_count
 caie 1,1
 jrst fail_2
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 caie 1,012
 jrst fail_3
 ; Exact allocated type or owner mismatch returns MM_ERR_INVAL,
 ; not a retryable pin error. The allocated extent is preserved.
 movei 1,__uarea
 movei 2,2
 movei 3,01001
 pushj 17,mm_free
 camn 1,[-4]
 jrst check_wrong_type
 jrst fail_4
check_wrong_type:
 move 4,mm_extents+1
 camn 4,[023,,01001]
 jrst v955_wrong_type_stable
 jrst fail_4
v955_wrong_type_stable:
 move 4,[022,,01001]
 movem 4,mm_extents+1
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 caie 1,02006
 jrst fail_5
 move 4,[023,,01002]
 movem 4,mm_extents+1
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 caie 1,02012
 jrst fail_6
 movei 1,__uarea
 movei 2,3
 movei 3,01001
 pushj 17,mm_free
 camn 1,[-4]
 jrst test_unpin
 jrst fail_7
test_unpin:
 move 4,mm_extents+1
 camn 4,[023,,01002]
 jrst v955_owner_stable
 jrst fail_7
v955_owner_stable:
 ; Reset exact metadata with one pin, then release the pin.
 move 4,[013,,01001]
 movem 4,mm_extents+1
 movei 1,__uarea
 pushj 17,mm_unpin
 jumpn 1,fail_8
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 caie 1,2
 jrst fail_9
 movei 1,__uarea
 movei 2,3
 movei 3,01001
 pushj 17,mm_free
 jumpn 1,fail_10
 skipn mm_extent_count
 jrst test_missing
 jrst fail_11
test_missing:
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 caie 1,02002
 jrst fail_12
 movei 1,__uarea
 movei 2,3
 movei 3,01001
 pushj 17,mm_free
 camn 1,[-4]
 jrst v956_recreate
 jrst fail_13
v956_recreate:
 ; Rebuild one exact u-area extent, initially with the wrong owner.
 movei 1,1
 movem 1,mm_extent_count
 move 1,[0410,,__uarea]
 movem 1,mm_extents
 move 1,[03,,01002]
 movem 1,mm_extents+1
 move 1,__ptable+3
 movem 1,__owner_before
 movei 1,1
 movei 2,__ptable+3
 pushj 17,proc_uarea_release
 camn 1,[-1]
 jrst v956_wrong_owner
 jrst fail_13
v956_wrong_owner:
 move 1,__ptable+3
 came 1,__owner_before
 jrst fail_13
 move 1,mm_extents+1
 camn 1,[03,,01002]
 jrst v956_wrong_type
 jrst fail_13
v956_wrong_type:
 move 1,[02,,01001]
 movem 1,mm_extents+1
 movei 1,1
 movei 2,__ptable+3
 pushj 17,proc_uarea_release
 camn 1,[-1]
 jrst v956_type_preserved
 jrst fail_13
v956_type_preserved:
 move 1,__ptable+3
 came 1,__owner_before
 jrst fail_13
 move 1,[013,,01001]
 movem 1,mm_extents+1
 movei 1,1
 movei 2,__ptable+3
 pushj 17,proc_uarea_release
 camn 1,[-1]
 jrst v956_pin_preserved
 jrst fail_13
v956_pin_preserved:
 move 1,__ptable+3
 came 1,__owner_before
 jrst fail_13
 move 1,mm_extent_count
 caie 1,1
 jrst fail_13
 move 1,[03,,01001]
 movem 1,mm_extents+1
 movei 1,1
 movei 2,__ptable+3
 pushj 17,proc_uarea_release
 jumpn 1,fail_13
 skipn mm_extent_count
 jrst v956_owner_clear
 jrst fail_13
v956_owner_clear:
 move 1,__ptable+3
 camn 1,[0200000]
 jrst v956_repeat
 jrst fail_13
v956_repeat:
 movei 1,1
 movei 2,__ptable+3
 pushj 17,proc_uarea_release
 jumpn 1,fail_13
 skipn mm_extent_count
 jrst pass
 jrst fail_13
pass: setz 1,
 jrst done
fail_1: movei 1,1
 jrst done
fail_2: movei 1,2
 jrst done
fail_3: movei 1,3
 jrst done
fail_4: movei 1,4
 jrst done
fail_5: movei 1,5
 jrst done
fail_6: movei 1,6
 jrst done
fail_7: movei 1,7
 jrst done
fail_8: movei 1,010
 jrst done
fail_9: movei 1,011
 jrst done
fail_10: movei 1,012
 jrst done
fail_11: movei 1,013
 jrst done
fail_12: movei 1,014
 jrst done
fail_13: movei 1,015
done: movem 1,__test_exit
 jrst 4,0
.globl kret_neg1
kret_neg1: seto 1,
 popj 17,
.globl kret_zero
kret_zero: setz 1,
 popj 17,
.globl kret_one
kret_one: movei 1,1
 popj 17,
.data
.globl mm_extent_count
mm_extent_count: .word 1
.globl mm_extents
mm_extents:
 .word 0410,,__uarea
 .word 023,,01001
.globl proc_table
proc_table: .word __ptable
.globl proc_high_slot
proc_high_slot: .word 2
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0400020,,01234
__ptable:
 .block 3
 .word __uarea,,0600000
 .word -1
 .word 0300000,,0
__uarea: .block 067
 .word 0400000,,012345
 .block 0410-070
.bss
__owner_before: .block 1
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
