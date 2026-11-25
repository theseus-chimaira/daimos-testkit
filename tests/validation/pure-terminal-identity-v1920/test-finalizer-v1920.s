; Native integrated terminal recovery. The v1681 builder supplies setup,
; original finalizer, MM and remaining fixture. The test-only mm_free
; gateway executes the real deletion and injects one foreign claim.
        movei   1,2
        movei   2,012345
        pushj   17,proc_finish_slot
        camn    1,[-1]
        jrst    first_v1920
        jrst    fail_2_v1681
first_v1920:
        move    1,__uarea+067
        came    1,[0560242,,012345]    ; FINALIZE+PREVM+ARMED+TERM+sector
        jrst    fail_5_v1681
        move    1,__ptable+7
        came    1,[02000,,0]
        jrst    fail_4_v1681
        move    1,mm_extent_count
        caie    1,1
        jrst    fail_9_v1681
        move    1,mm_extents
        came    1,[0200,,050600]
        jrst    fail_10_v1681
        move    1,mm_extents+1
        came    1,[2,,3]
        jrst    fail_10_v1681
        pushj   17,proc_finish_service_v881
        jumpn   1,fail_13_v1681
        move    1,__uarea+067
        came    1,[0560242,,012345]
        jrst    fail_6_v1681
        ; Replace the injected foreign range with an equally sized,
        ; correctly aligned same-slot RAW extent at a DIFFERENT base.
        move    1,[01400,,060400]
        movem   1,mm_extents
        move    1,[4,,2]
        movem   1,mm_extents+1
        pushj   17,proc_finish_service_v881
        jumpn   1,fail_13_v1681
        move    1,__uarea+067
        came    1,[0560242,,012345]
        jrst    fail_7_v1681
        move    1,mm_extents
        came    1,[01400,,060400]
        jrst    fail_14_v1681
        move    1,__free_calls_v1920
        caie    1,1
        jrst    fail_12_v1681
        ; Remove ONLY the test-created replacement. The original native
        ; free already committed; no second deletion is authorized.
        setzm   mm_extent_count
        pushj   17,proc_finish_service_v881
        jumpn   1,fail_18_v1681
        move    1,__ptable+7
        camn    1,[-1]
        jrst    vm_done_v1920
        jrst    fail_19_v1681
vm_done_v1920:
        skipn   __records_v1681+2
        skipn   __modes_v1681
        jrst    check_both_v1920
        jrst    fail_21_v1681
check_both_v1920:
        skipn   __records_v1681+2
        jrst    check_mode_v1920
        jrst    fail_21_v1681
check_mode_v1920:
        skipn   __modes_v1681
        jrst    finish_v1920
        jrst    fail_22_v1681
finish_v1920:
        move    1,__uarea+067
        tlne    1,023777
        jrst    fail_23_v1681
        pushj   17,proc_finish_service_v881
        jumpn   1,fail_24_v1681
        pushj   17,proc_finish_service_v881
        caie    1,1
        jrst    fail_25_v1681
        move    1,__free_calls_v1920
        caie    1,1
        jrst    fail_28_v1681
        move    1,__hup_calls
        caie    1,1
        jrst    fail_26_v1681
        setz    1,
        jrst    done_v1681
