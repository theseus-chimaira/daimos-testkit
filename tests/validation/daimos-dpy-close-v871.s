.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; When DPY MRES is absent, no list is owned; close succeeds.
 movei 1,__fd_missing
 pushj 17,file_close_entry_v865
 jumpe 1,missing_closed
 jrst fail_1
missing_closed:
 skipn __fd_missing
 jrst patch_provider
 jrst fail_2
patch_provider:
 movei 1,dpy_stop_shim
 hrrm 1,dpy_close_words_call
 ; First stop is rejected by MM, and must preserve list ownership.
 movei 1,__fd_active
 pushj 17,file_close_entry_v865
 camn 1,[-5]
 jrst release_failed
 jrst fail_3
release_failed:
 move 1,__fd_active
 camn 1,[020002000010]
 jrst fd_retained
 jrst fail_4
fd_retained:
 move 1,dpy_list_base
 caie 1,__raw_list
 jrst fail_5
 move 1,dpy_list_iowd
 camn 1,[-2,,__raw_list-1]
 jrst iowd_retained
 jrst fail_6
iowd_retained:
 skipn dpy_refresh_iowd
 jrst refresh_stopped
 jrst fail_7
refresh_stopped:
 move 1,dpy_refresh_divider
 caie 1,1
 jrst fail_8
 move 1,__mm_calls
 caie 1,1
 jrst fail_9
 ; Retry after unpin/free failure clears: same extent is finally released.
 setzm __fail_free
 movei 1,__fd_active
 pushj 17,file_close_entry_v865
 jumpe 1,released
 jrst fail_10
released:
 skipn __fd_active
 jrst check_list
 jrst fail_11
check_list:
 skipn dpy_list_base
 jrst check_iowd
 jrst fail_12
check_iowd:
 skipn dpy_list_iowd
 jrst check_mm
 jrst fail_13
check_mm:
 move 1,__mm_calls
 caie 1,2
 jrst fail_14
 ; With no raw list, a subsequent device close needs no MM operation.
 movei 1,__fd_empty
 pushj 17,file_close_entry_v865
 jumpe 1,empty_closed
 jrst fail_15
empty_closed:
 skipn __fd_empty
 jrst check_final
 jrst fail_16
check_final:
 move 1,__mm_calls
 caie 1,2
 jrst fail_17
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
done: movem 1,__test_exit
 jrst 4,0
; dpy_write_words installs this trampoline in the production MRES.
dpy_stop_shim:
 push 17,010
 push 17,011
 jrst dpy_list_stop
.globl mm_free
mm_free:
 aos __mm_calls
 move 4,1
 caie 2,3
 jrst mm_bad
 caie 3,014
 jrst mm_bad
 move 1,__fail_free
 jumpe 1,mm_ok
 movni 1,5
 popj 17,
mm_ok:
 setz 1,
 popj 17,
mm_bad:
 seto 1,
 popj 17,
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
 ; This must never override the actual DPY close result.
 seto 1,
 popj 17,
.globl kret_zero
kret_zero:
 setz 1,
 popj 17,
.data
__fd_missing: .word 020002000010
__fd_active: .word 020002000010
__fd_empty: .word 020002000010
.globl dpy_list_base
dpy_list_base: .word __raw_list
.globl dpy_list_iowd
dpy_list_iowd: .word -2,,__raw_list-1
.globl dpy_refresh_iowd
dpy_refresh_iowd: .word 1
.globl dpy_pending
dpy_pending: .word 1
.globl dpy_refresh_divider
dpy_refresh_divider: .word 2
__raw_list: .block 3
__fail_free: .word 1
__mm_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
