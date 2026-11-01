.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Redirect the DPY file-close call site to the production STOP logic.
 movei 1,dpy_stop_shim
 hrrm 1,dpy_close_words_call
 ; The physical extent is pinned: MM refuses to free it.
 movei 1,__fd_active
 pushj 17,file_close_entry_v865
 camn 1,[-5]
 jrst pinned_failed
 jrst fail_1
pinned_failed:
 move 1,__fd_active
 camn 1,[020002000010]
 jrst pinned_retained
 jrst fail_2
pinned_retained:
 move 1,dpy_list_base
 caie 1,__raw_list
 jrst fail_3
 move 1,dpy_list_iowd
 camn 1,[-3,,__raw_list-1]
 jrst pinned_iowd
 jrst fail_4
pinned_iowd:
 move 1,mm_extent_count
 caie 1,1
 jrst fail_5
 skipn dpy_refresh_iowd
 jrst pinned_quiesced
 jrst fail_6
pinned_quiesced:
 ; Release the real MM pin; corrupt only the owner field to expose
 ; the invalid-owner rejection, without losing the FILE reference.
 movei 1,__raw_list
 pushj 17,mm_unpin
 jumpe 1,unpin_ok
 jrst fail_7
unpin_ok:
 move 1,[03000015]
 movem 1,mm_extents+1
 movei 1,__fd_active
 pushj 17,file_close_entry_v865
 camn 1,[-4]
 jrst wrong_owner_rejected
 jrst fail_8
wrong_owner_rejected:
 move 1,__fd_active
 camn 1,[020002000010]
 jrst wrong_owner_retained
 jrst fail_9
wrong_owner_retained:
 move 1,dpy_list_base
 caie 1,__raw_list
 jrst fail_10
 move 1,mm_extent_count
 caie 1,1
 jrst fail_11
 ; Restore the correct MM owner and retry the same descriptor.
 move 1,[03000014]
 movem 1,mm_extents+1
 movei 1,__fd_active
 pushj 17,file_close_entry_v865
 jumpe 1,freed
 jrst fail_12
freed:
 skipn __fd_active
 jrst freed_fd
 jrst fail_13
freed_fd:
 skipn dpy_list_base
 jrst freed_base
 jrst fail_14
freed_base:
 skipn dpy_list_iowd
 jrst freed_iowd
 jrst fail_15
freed_iowd:
 skipn mm_extent_count
 jrst freed_mm
 jrst fail_16
freed_mm:
 ; A later descriptor close with no raw list must not touch MM.
 movei 1,__fd_empty
 pushj 17,file_close_entry_v865
 jumpe 1,empty_closed
 jrst fail_17
empty_closed:
 skipn __fd_empty
 jrst pass
 jrst fail_18
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
done: movem 1,__test_exit
 jrst 4,0
; MINIT patches the existing FILE call site to the optional DPY MRES.
dpy_stop_shim:
 push 17,010
 push 17,011
 jrst dpy_list_stop
.globl file_node_from_fd
file_node_from_fd:
 move 1,(1)
 tlz 1,700070
 popj 17,
.globl pipe_close_ref
pipe_close_ref:
 seto 1,
 popj 17,
.globl vfs_sync
vfs_sync:
 seto 1,
 popj 17,
.globl kret_zero
kret_zero:
 setz 1,
 popj 17,
.data
__fd_active: .word 020002000010
__fd_empty: .word 020002000010
.globl dpy_list_base
dpy_list_base: .word __raw_list
.globl dpy_list_iowd
dpy_list_iowd: .word -3,,__raw_list-1
.globl dpy_refresh_iowd
dpy_refresh_iowd: .word 1
.globl dpy_pending
dpy_pending: .word 1
.globl dpy_refresh_divider
dpy_refresh_divider: .word 2
.globl mm_extents
mm_extents: .word 3,,__raw_list
            .word 013000014
.globl mm_extent_count
mm_extent_count: .word 1
.bss
__raw_list: .block 3
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
