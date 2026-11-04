.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Two MM providers reject a replacement and rollback free. The MRES
 ; must retain the unpublished extent and remain runnable, not HALT.
 movei 1,1
 movem 1,__fail_new
 movei 1,__input
 movei 2,3
 pushj 17,dpy_write_words
 camn 1,[-5]
 jrst v912_double_refused
 jrst fail_26
v912_double_refused:
 move 1,dpy_list_orphan_v912
 caie 1,__newlist
 jrst fail_27
 move 1,dpy_list_base
 caie 1,__oldlist
 jrst fail_28
 move 1,dpy_refresh_divider
 caie 1,1
 jrst fail_29
 move 1,__alloc_calls
 caie 1,1
 jrst fail_30
 ; Repeated refusal cannot allocate yet another unpublished extent.
 movei 1,__input
 movei 2,3
 pushj 17,dpy_write_words
 camn 1,[-5]
 jrst v912_still_owned
 jrst fail_31
v912_still_owned:
 move 1,__alloc_calls
 caie 1,1
 jrst fail_32
 move 1,dpy_list_orphan_v912
 caie 1,__newlist
 jrst fail_33
 ; Once rollback MM recovers, drain orphan BEFORE the next allocation.
 setzm __fail_new
 movei 1,__input
 movei 2,3
 pushj 17,dpy_write_words
 ; Orphan cleanup succeeds; the still-pinned old list returns MM_BUSY.
 ; The release path preserves the real -5 rather than collapsing to -1.
 camn 1,[-5]
 jrst v912_orphan_drained
 jrst fail_34
v912_orphan_drained:
 skipn dpy_list_orphan_v912
 jrst v912_clean
 jrst fail_35
v912_clean:
 move 1,__alloc_calls
 caie 1,2
 jrst fail_36
 move 1,__freed_new
 caie 1,2
 jrst fail_37
 ; Reset only accounting witnesses; the real original list remains.
 setzm __freed_new
 ; The old extent is pinned: replacement must fail and roll back new.
 movei 1,__input
 movei 2,3
 pushj 17,dpy_write_words
 ; With only the old list pinned, rollback succeeds and returns -5.
 camn 1,[-5]
 jrst rollback_result
 jrst fail_1
rollback_result:
 move 1,dpy_list_base
 caie 1,__oldlist
 jrst fail_2
 move 1,dpy_list_iowd
 camn 1,[-2,,__oldlist-1]
 jrst rollback_iowd
 jrst fail_3
rollback_iowd:
 move 1,__freed_new
 caie 1,1
 jrst fail_4
 skipn __freed_old
 jrst rollback_count
 jrst fail_5
rollback_count:
 skipn mfsdev_io_out+010
 jrst rollback_refresh
 jrst fail_6
rollback_refresh:
 skipn dpy_refresh_iowd
 jrst rollback_divider
 jrst fail_7
rollback_divider:
 move 1,dpy_refresh_divider
 caie 1,1
 jrst fail_8
 move 1,__newlist
 camn 1,__input
 jrst retry_replacement
 jrst fail_9
retry_replacement:
 ; Release succeeds on retry and the new immutable IOWD is published.
 setzm __fail_old
 movei 1,__input
 movei 2,3
 pushj 17,dpy_write_words
 caie 1,3
 jrst fail_10
 move 1,dpy_list_base
 caie 1,__newlist
 jrst fail_11
 move 1,dpy_list_iowd
 camn 1,[-3,,__newlist-1]
 jrst check_retry_counts
 jrst fail_12
check_retry_counts:
 move 1,__freed_old
 caie 1,1
 jrst fail_13
 move 1,mfsdev_io_out+010
 caie 1,1
 jrst fail_14
 ; Allocation failure cannot alter an installed list or its IOWD.
 movei 1,1
 movem 1,__fail_alloc
 movei 1,__input
 movei 2,3
 pushj 17,dpy_write_words
 camn 1,[-1]
 jrst check_alloc_failure
 jrst fail_15
check_alloc_failure:
 move 1,dpy_list_base
 caie 1,__newlist
 jrst fail_16
 move 1,dpy_list_iowd
 camn 1,[-3,,__newlist-1]
 jrst stop_replacement
 jrst fail_17
stop_replacement:
 ; STOP must still release the published new extent normally.
 setzm __fail_alloc
 setz 1,
 setz 2,
 pushj 17,dpy_write_words
 jumpe 1,stop_ok
 jrst fail_18
stop_ok:
 skipn dpy_list_base
 jrst stop_iowd
 jrst fail_19
stop_iowd:
 skipn dpy_list_iowd
 jrst stop_count
 jrst fail_20
stop_count:
 move 1,__freed_new
 caie 1,2
 jrst fail_21
 move 1,mfsdev_io_out+010
 caie 1,1
 jrst fail_22
 ; Installation when no old list exists needs no old free.
 movei 1,__input
 movei 2,3
 pushj 17,dpy_write_words
 caie 1,3
 jrst fail_23
 move 1,dpy_list_base
 caie 1,__newlist
 jrst fail_24
 move 1,mfsdev_io_out+010
 caie 1,2
 jrst fail_25
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
 jrst done
fail_14: movei 1,016
 jrst done
fail_15: movei 1,017
 jrst done
fail_16: movei 1,020
 jrst done
fail_17: movei 1,021
 jrst done
fail_18: movei 1,022
 jrst done
fail_19: movei 1,023
 jrst done
fail_20: movei 1,024
 jrst done
fail_21: movei 1,025
 jrst done
fail_22: movei 1,026
 jrst done
fail_23: movei 1,027
 jrst done
fail_24: movei 1,030
 jrst done
fail_25: movei 1,031
fail_26: movei 1,32
 jrst done
fail_27: movei 1,33
 jrst done
fail_28: movei 1,34
 jrst done
fail_29: movei 1,35
 jrst done
fail_30: movei 1,36
 jrst done
fail_31: movei 1,37
 jrst done
fail_32: movei 1,40
 jrst done
fail_33: movei 1,41
 jrst done
fail_34: movei 1,42
 jrst done
fail_35: movei 1,43
 jrst done
fail_36: movei 1,44
 jrst done
fail_37: movei 1,45
 jrst done
done: movem 1,__test_exit
 jrst 4,0

.globl mm_alloc
mm_alloc:
 aos __alloc_calls
 skipn __fail_alloc
 jrst alloc_ok
 seto 1,
 popj 17,
alloc_ok:
 move 6,__new_base
 movem 6,(5)
 setz 1,
 popj 17,
.globl mm_free
mm_free:
 caie 2,3
 jrst mm_invalid
 caie 3,014
 jrst mm_invalid
 caie 1,__oldlist
 jrst free_new
 skipn __fail_old
 jrst free_old_ok
 movni 1,5
 popj 17,
free_old_ok:
 aos __freed_old
 setz 1,
 popj 17,
free_new:
 caie 1,__newlist
 jrst mm_invalid
 skipn __fail_new
 jrst v912_free_new_ok
 movni 1,5
 popj 17,
v912_free_new_ok:
 aos __freed_new
 setz 1,
 popj 17,
mm_invalid:
 seto 1,
 popj 17,
.data
.globl kconst_1_1
kconst_1_1: .word 1,,1
.globl dpy_list_base
dpy_list_base: .word __oldlist
.globl dpy_list_iowd
dpy_list_iowd: .word -2,,__oldlist-1
.globl dpy_refresh_iowd
dpy_refresh_iowd: .word 1
.globl dpy_pending
dpy_pending: .word 1
.globl dpy_refresh_divider
dpy_refresh_divider: .word 2
.globl mfsdev_io_out
mfsdev_io_out: .block 011
__input: .word 01234567
 .word 04567123
 .word 07654321
__oldlist: .word 1
 .word 2
 .word 3
__new_base: .word __newlist
__newlist: .block 3
__fail_old: .word 1
__fail_new: .word 0
.globl dpy_list_orphan_v912
dpy_list_orphan_v912: .word 0
__fail_alloc: .word 0
__alloc_calls: .word 0
__freed_new: .word 0
__freed_old: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
