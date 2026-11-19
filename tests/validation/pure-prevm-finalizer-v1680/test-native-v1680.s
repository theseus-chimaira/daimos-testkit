; v1680: real PDP-6 proc_finish_slot and idle FINALIZE+PREVM retry.
; The VM leaf is a controlled model of a 2-pin MM refusal, NOT the
; original MM/terminal leaf. Terminal component is separately v1680.
.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 move 1,[010000,,0]
 movem 1,__uarea+020
 movei 1,2
 movem 1,__vm_pins_v1680
 movei 1,2
 movei 2,012345
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst v1680_refused
 jrst v1680_fail_1
v1680_refused:
 move 1,__vm_calls
 caie 1,1
 jrst v1680_fail_2
 move 1,__ptable+6
 trnn 1,0200000            ; TRANSITION
 jrst v1680_fail_3
 move 1,__ptable+7
 came 1,[04000,,020000]   ; original VM still owned
 jrst v1680_fail_4
 move 1,__uarea+067
 tlnn 1,0400000            ; FINALIZE
 jrst v1680_fail_5
 tlnn 1,0100000            ; PREVM
 jrst v1680_fail_6
 hrrz 1,1
 caie 1,012345
 jrst v1680_fail_7
 move 1,proc_finish_last_tick_v881
 tlnn 1,0400000            ; pending retry bit
 jrst v1680_fail_8
 move 1,__hup_calls
 caie 1,1
 jrst v1680_fail_9
 move 1,__tty_calls
 caie 1,1
 jrst v1680_fail_10
 ; Repeated real idle-stack finalize scans must retain owner, marker
 ; and the original single pending bit without repeated HUP.
 movei 16,3
v1680_retry:
 pushj 17,proc_finish_service_v881
 jumpe 1,v1680_retry_check
 jrst v1680_fail_11
v1680_retry_check:
 move 1,__ptable+7
 came 1,[04000,,020000]
 jrst v1680_fail_12
 move 1,__uarea+067
 tlnn 1,0100000
 jrst v1680_fail_13
 move 1,proc_finish_last_tick_v881
 tlnn 1,0400000
 jrst v1680_fail_14
 move 1,__hup_calls
 caie 1,1
 jrst v1680_fail_15
 skipn __release_calls
 jrst v1680_retry_next
 jrst v1680_fail_16
v1680_retry_next:
 sojg 16,v1680_retry
 move 1,__vm_calls
 caie 1,4                 ; initial plus 3 real idle retries
 jrst v1680_fail_17
 move 1,__vm_pins_v1680
 caie 1,2
 jrst v1680_fail_18
 ; Model eventual MM unpin by changing test-only pin state.
 ; The next real idle retry can now commit VM destruction.
 setzm __vm_pins_v1680
 pushj 17,proc_finish_service_v881
 jumpe 1,v1680_vm_done
 jrst v1680_fail_19
v1680_vm_done:
 move 1,__vm_calls
 caie 1,5
 jrst v1680_fail_20
 move 1,__ptable+7
 camn 1,[-1]
 jrst v1680_vm_none
 jrst v1680_fail_21
v1680_vm_none:
 move 1,__uarea+067
 tlne 1,0100000            ; PREVM must be removed after success
 jrst v1680_fail_22
 move 1,__release_calls
 caie 1,1                 ; original uarea fixture refuses 1st
 jrst v1680_fail_23
 move 1,__hup_calls
 caie 1,1
 jrst v1680_fail_24
 pushj 17,proc_finish_service_v881
 jumpe 1,v1680_second_uarea
 jrst v1680_fail_25
v1680_second_uarea:
 move 1,__release_calls
 caie 1,2
 jrst v1680_fail_26
 pushj 17,proc_finish_service_v881
 caie 1,1
 jrst v1680_fail_27
 move 1,__release_calls
 caie 1,3
 jrst v1680_fail_28
 move 1,__vm_calls
 caie 1,5
 jrst v1680_fail_29
 move 1,__ptable+010
 lsh 1,-041
 caie 1,4
 jrst v1680_fail_30
 pushj 17,proc_finish_service_v881
 jumpe 1,v1680_pass
 jrst v1680_fail_31
v1680_pass:
 setz 1,
 jrst v1680_done
v1680_fail_1: movei 1,1
 jrst v1680_done
v1680_fail_2: movei 1,2
 jrst v1680_done
v1680_fail_3: movei 1,3
 jrst v1680_done
v1680_fail_4: movei 1,4
 jrst v1680_done
v1680_fail_5: movei 1,5
 jrst v1680_done
v1680_fail_6: movei 1,6
 jrst v1680_done
v1680_fail_7: movei 1,7
 jrst v1680_done
v1680_fail_8: movei 1,010
 jrst v1680_done
v1680_fail_9: movei 1,011
 jrst v1680_done
v1680_fail_10: movei 1,012
 jrst v1680_done
v1680_fail_11: movei 1,013
 jrst v1680_done
v1680_fail_12: movei 1,014
 jrst v1680_done
v1680_fail_13: movei 1,015
 jrst v1680_done
v1680_fail_14: movei 1,016
 jrst v1680_done
v1680_fail_15: movei 1,017
 jrst v1680_done
v1680_fail_16: movei 1,020
 jrst v1680_done
v1680_fail_17: movei 1,021
 jrst v1680_done
v1680_fail_18: movei 1,022
 jrst v1680_done
v1680_fail_19: movei 1,023
 jrst v1680_done
v1680_fail_20: movei 1,024
 jrst v1680_done
v1680_fail_21: movei 1,025
 jrst v1680_done
v1680_fail_22: movei 1,026
 jrst v1680_done
v1680_fail_23: movei 1,027
 jrst v1680_done
v1680_fail_24: movei 1,030
 jrst v1680_done
v1680_fail_25: movei 1,031
 jrst v1680_done
v1680_fail_26: movei 1,032
 jrst v1680_done
v1680_fail_27: movei 1,033
 jrst v1680_done
v1680_fail_28: movei 1,034
 jrst v1680_done
v1680_fail_29: movei 1,035
 jrst v1680_done
v1680_fail_30: movei 1,036
 jrst v1680_done
v1680_fail_31: movei 1,037
v1680_done:
 movem 1,__test_exit
 jrst 4,0
