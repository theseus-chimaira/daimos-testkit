#!/bin/sh
# v907: full PDP-6 HUP partial commit with real pinned u-area MM owner.
# Only an isolated kernel copy contains injection and observability.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
pipe_hup=${DAIMOS_V1104_PIPE_HUP:-0}
dpy_hup=${DAIMOS_V1105_DPY_HUP:-0}
swap_hup=${DAIMOS_V1107_SWAP_HUP:-0}
disk_pi6=${DAIMOS_V1154_PI6_DISK_SPIN:-0}
case "$disk_pi6" in
    0|1) ;;
    *) echo 'v1154: invalid DISK PI6 mode' >&2; exit 2 ;;
esac
if [ "$disk_pi6" = 1 ] && { [ "$swap_hup" != 1 ] ||
    [ "$pipe_hup" != 1 ] || [ "$dpy_hup" != 0 ]; }; then
    echo 'v1154: requires actual PIPE+DISK v1122 guest' >&2
    exit 2
fi
case "$pipe_hup:$dpy_hup:$swap_hup" in
    0:0:0|1:0:0|0:1:0|0:0:1|1:1:0|0:1:1|1:0:1) ;;
    *) echo 'v1119: unsupported physical HUP provider combination' >&2; exit 2 ;;
esac
if [ "$disk_pi6" = 1 ]; then
    work=$(mktemp -d "$TMPDIR/daimos-session-disk-pi6-v1154.XXXXXX")
elif [ "$pipe_hup" = 1 ] && [ "$swap_hup" = 1 ]; then
    work=$(mktemp -d "$TMPDIR/daimos-session-hup-pipe-swap-v1122.XXXXXX")
elif [ "$dpy_hup" = 1 ] && [ "$swap_hup" = 1 ]; then
    work=$(mktemp -d "$TMPDIR/daimos-session-hup-dpy-swap-v1121.XXXXXX")
elif [ "$pipe_hup" = 1 ] && [ "$dpy_hup" = 1 ]; then
    work=$(mktemp -d "$TMPDIR/daimos-session-hup-pipe-dpy-v1119.XXXXXX")
elif [ "$swap_hup" = 1 ]; then
    work=$(mktemp -d "$TMPDIR/daimos-session-hup-swap-v1107.XXXXXX")
elif [ "$dpy_hup" = 1 ]; then
    work=$(mktemp -d "$TMPDIR/daimos-session-hup-dpy-mm-v1105.XXXXXX")
elif [ "$pipe_hup" = 1 ]; then
    work=$(mktemp -d "$TMPDIR/daimos-session-hup-pipe-mm-v1104.XXXXXX")
else
    work=$(mktemp -d "$TMPDIR/daimos-session-hup-physical-v907.XXXXXX")
fi
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel/proc/proc_pdp6.s" \
    "${DAIMOS_V907_NEGATIVE:-0}" "$pipe_hup" "$dpy_hup" "$swap_hup" <<'PY'
from pathlib import Path
import sys
path=Path(sys.argv[1]); source=path.read_text()
def patch(old,new):
    global source
    if source.count(old)!=1:
        raise SystemExit('v907: injection anchor not unique: '+repr(old))
    source=source.replace(old,new)
# The first child to receive HUP is really pinned in the kernel MM table.
# The second child first rejects HUP (synthetic v907, physical PIPE MM
# refusal v1104, physical DPY MM refusal v1105, or disk-swap verifier
# refusal v1107). For v1107, slot 0 finishes the PREVM owner before
# leader retry, so no second delivery is expected for that child.
patch('''        move    1,011
        movei   2,2                    ; default-fatal HUP
        pushj   17,proc_event_apply
        jumpn   1,proc_session_teardown_fail''','''        skipn   daimos_test_first_v907
        jrst    daimos_test_pin_first_v907
        move    6,daimos_test_first_v907
        camn    6,011
        jrst    daimos_test_repeat_v907
        skipn   daimos_test_failures_v907
        jrst    daimos_test_fail_second_v907
        aos     daimos_test_second_v907
        jrst    daimos_test_deliver_v907
daimos_test_pin_first_v907:
        movem   011,daimos_test_first_v907
        movem   010,daimos_test_leader_v907
        hlrz    1,(012)               ; real first-member u-area base
        movem   1,daimos_test_base_v907
        pushj   17,mm_pin
        jumpe   1,daimos_test_pin_ok_v907
        aos     daimos_test_errors_v907
        jrst    daimos_test_deliver_v907
daimos_test_pin_ok_v907:
        aos     daimos_test_pins_v907
        jrst    daimos_test_deliver_v907
daimos_test_repeat_v907:
        aos     daimos_test_repeats_v907
        jrst    daimos_test_deliver_v907
daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        jrst    proc_session_teardown_fail
daimos_test_deliver_v907:
        move    1,011
        movei   2,2                    ; default-fatal HUP
        pushj   17,proc_event_apply
        jumpn   1,proc_session_teardown_fail''')
patch('''proc_session_teardown_commit_v875:
        ; No member can have an unclosed FD after successful HUP.''','''proc_session_teardown_commit_v875:
        skipn   daimos_test_first_v907
        jrst    daimos_test_commit_done_v907
        move    4,daimos_test_leader_v907
        came    4,010                  ; only the targeted session leader
        jrst    daimos_test_commit_done_v907
        ; At the actual final commit, prove the first HUP remains an
        ; irrevocably finalized, physically pinned MM owner.
        move    4,daimos_test_first_v907
        imuli   4,PROC_WORDS
        add     4,proc_table
        move    6,(4)
        trnn    6,PROC_TRANSITION_RH
        aos     daimos_test_errors_v907
        move    6,1(4)
        camn    6,[-1]
        jrst    daimos_test_vm_none_v907
        aos     daimos_test_errors_v907
daimos_test_vm_none_v907:
        hlrz    4,(4)
        move    6,PROC_FINALIZE_OFFSET(4)
        tlne    6,PROC_FINALIZE_MARK_LH
        jrst    daimos_test_pending_check_v907
        aos     daimos_test_errors_v907
daimos_test_pending_check_v907:
        aos     daimos_test_pending_v907
        move    1,daimos_test_base_v907
        pushj   17,mm_unpin
        jumpe   1,daimos_test_unpin_ok_v907
        aos     daimos_test_errors_v907
        jrst    daimos_test_commit_done_v907
daimos_test_unpin_ok_v907:
        aos     daimos_test_unpins_v907
daimos_test_commit_done_v907:
        ; No member can have an unclosed FD after successful HUP.''')
if sys.argv[3] == '1':
    # Do not synthesize the second HUP error: its real FILE close now
    # reaches a genuinely pinned private PIPE extent and fails -5.
    # Keep the v907 first-member pinned-uarea and committed-HUP checks.
    if sys.argv[5] == '1':
        # The first HUP recipient is a distinct, still-resident PIPE
        # owner. Arm its physical MM refusal BEFORE the first HUP.
        # The second recipient retains a real DISK swap record; its
        # bitmap failure is armed separately by the v1107 branch.
        patch('''daimos_test_pin_ok_v907:
        aos     daimos_test_pins_v907
        jrst    daimos_test_deliver_v907''',
              '''daimos_test_pin_ok_v907:
        aos     daimos_test_pins_v907
        setom   daimos_test_pipe_armed_v1104
        jrst    daimos_test_deliver_v907''')
    else:
        patch('''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        jrst    proc_session_teardown_fail''',
              '''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        setom   daimos_test_pipe_armed_v1104
        jrst    daimos_test_deliver_v907''')
if sys.argv[4] == '1':
    # Unlike v907's synthetic refusal, the second HUP really closes
    # the published Type-340 raw list. An MM pin will reject its first
    # release while the previously finalized first member remains held.
    if sys.argv[5] == '1':
        # The swap branch must first complete a genuine backing write,
        # then arm the DPY MM fault before delivering member HUP.
        # Keep the original second-member HUP injection for swap.
        pass
    elif sys.argv[3] == '1':
        # Both private MM owners are live at the same session-member HUP.
        # Arm the separate hooks before the original event dispatcher.
        patch('''        setom   daimos_test_pipe_armed_v1104
        jrst    daimos_test_deliver_v907''',
              '''        setom   daimos_test_pipe_armed_v1104
        setom   daimos_test_dpy_armed_v1105
        jrst    daimos_test_deliver_v907''')
    else:
        patch('''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        jrst    proc_session_teardown_fail''',
              '''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        setom   daimos_test_dpy_armed_v1105
        jrst    daimos_test_deliver_v907''')
if sys.argv[5] == '1':
    # The real second session member becomes nonresident through the
    # production swap-out transaction. Its DISK state and live bitmap
    # record are not synthesized. Only after success is the first HUP
    # allowed to enter the real checked swap-detach path.
    patch('''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        jrst    proc_session_teardown_fail''',
          '''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        move    4,proc_swap_blocks_used
        movem   4,daimos_test_swap_before_v1107
        setom   daimos_test_swap_select_v1107
        push    17,011
        movei   1,1                   ; one free word, valid alignment
        movei   2,1
        movei   3,1                   ; exclude parent INIT
        pushj   17,proc_swap_reclaim
        pop     17,011
        setzm   daimos_test_swap_select_v1107
        movem   1,daimos_test_swap_result_v1107
        jumpe   1,daimos_test_swap_success_v1107
        aos     daimos_test_swap_errors_v1107
        jrst    proc_session_teardown_fail
daimos_test_swap_success_v1107:
        aos     daimos_test_swap_outs_v1107
        move    4,proc_swap_records
        move    4,4(4)                ; actual slot-4 disk record
        movem   4,daimos_test_swap_record_v1107
        ; BACKSTORE block zero is a valid first allocation. Only the
        ; block count must be nonzero; the whole packed record must
        ; remain owned until the checked detach commits.
        hrrz    5,4
        jumpn   5,daimos_test_swap_arm_v1107
daimos_test_swap_record_bad_v1107:
        movei   7,1                   ; missing record/block count
        iorm    7,daimos_test_swap_errors_v1107
daimos_test_swap_arm_v1107:
        setom   daimos_test_swap_armed_v1107
        jrst    daimos_test_deliver_v907''')
    patch('''        aos     daimos_test_second_v907
        jrst    daimos_test_deliver_v907''',
          '''        aos     daimos_test_second_v907
        move    4,proc_finish_last_tick_v881
        movem   4,daimos_test_swap_tick_v1107
        move    4,proc_table
        move    4,014(4)               ; slot-4 descriptor
        movem   4,daimos_test_swap_slot_v1107
        hlrz    5,4
        jumpe   5,daimos_test_swap_slot_done_v1107
        move    5,PROC_FINALIZE_OFFSET(5)
        movem   5,daimos_test_swap_marker_v1107
daimos_test_swap_slot_done_v1107:
        move    4,proc_swap_records
        move    4,4(4)
        ; Slot 0 may have completed the PREVM retry before this later
        ; HUP scan. Ownership before repair is checked inside the
        ; actual bitmap verifier, not here after possible commit.
        jrst    daimos_test_deliver_v907''')
    if sys.argv[4] == '1':
        # The DPY owner is independent of the member's DISK record.
        # Both faults must be armed for the same actual member HUP,
        # but only AFTER swap-out has successfully published its record.
        patch('''        setom   daimos_test_swap_armed_v1107
        jrst    daimos_test_deliver_v907''',
              '''        setom   daimos_test_swap_armed_v1107
        setom   daimos_test_dpy_armed_v1105
        jrst    daimos_test_deliver_v907''')
    patch('''proc_session_teardown_commit_v875:
        skipn   daimos_test_first_v907''',
          '''proc_session_teardown_commit_v875:
        move    4,daimos_test_swap_outs_v1107
        jumpe   4,daimos_test_swap_commit_done_v1107
        move    4,daimos_test_leader_v907
        came    4,010
        jrst    daimos_test_swap_commit_done_v1107
        ; A session may reach this scan more than once while a member
        ; is being finalized. Keep the *last* targeted observation.
        ; The terminal record and block count must both be cleared.
        move    4,proc_swap_blocks_used
        movem   4,daimos_test_swap_commit_blocks_v1107
        ; Prove the exact slot-4 DISK record was retired, not merely
        ; that the allocator's total returned to its previous value.
        move    4,proc_swap_records
        move    4,4(4)
        movem   4,daimos_test_swap_commit_record_v1107
        aos     daimos_test_swap_commits_v1107
daimos_test_swap_commit_done_v1107:
        skipn   daimos_test_first_v907''')
    patch('''proc_finish_service_v881:
        push    17,10''',
          '''proc_finish_service_v881:
        aos     daimos_test_swap_reaper_v1107
        push    17,10''')
    patch('''proc_finish_mark_pending_v892:
        move    5,PROC_FINALIZE_OFFSET(3)''',
          '''proc_finish_mark_pending_v892:
        aos     daimos_test_swap_mark_v1107
        move    5,PROC_FINALIZE_OFFSET(3)''')
    # Use the installed SWAP MRES through the original KCORE gateway.
    # Force selection of job2 only in this isolated test; proc_swap_out
    # still enforces actual admission, writes backing and frees VM.
    patch('''proc_swap_victim:
        add     17,kconst_7_7''',
          '''proc_swap_victim:
        skipn   daimos_test_swap_select_v1107
        jrst    daimos_test_swap_select_normal_v1107
        aos     daimos_test_swap_select_calls_v1107
        movei   1,4
        popj    17,
daimos_test_swap_select_normal_v1107:
        add     17,kconst_7_7''')
# Negative control restores pre-v905 handling in this isolated image.
if sys.argv[2]=='1':
    old='''        ; A previous HUP may have committed its fatal exit but deferred
        ; u-area MM release.'''
    start=source.index(old)
    end=source.index('proc_session_teardown_deliver_v905:\n',start)
    source=source[:start]+source[end+len('proc_session_teardown_deliver_v905:\n'):]
source+='''
        .globl mm_pin
        .globl mm_unpin
        .bss
        .globl daimos_test_first_v907
daimos_test_first_v907: .block 1
        .globl daimos_test_leader_v907
daimos_test_leader_v907: .block 1
        .globl daimos_test_base_v907
daimos_test_base_v907: .block 1
        .globl daimos_test_pins_v907
daimos_test_pins_v907: .block 1
        .globl daimos_test_unpins_v907
daimos_test_unpins_v907: .block 1
        .globl daimos_test_failures_v907
daimos_test_failures_v907: .block 1
        .globl daimos_test_second_v907
daimos_test_second_v907: .block 1
        .globl daimos_test_repeats_v907
daimos_test_repeats_v907: .block 1
        .globl daimos_test_pending_v907
daimos_test_pending_v907: .block 1
        .globl daimos_test_errors_v907
daimos_test_errors_v907: .block 1
'''
if sys.argv[5] == '1':
    source += '''
        .globl proc_swap_reclaim
        .globl proc_swap_records
        .globl proc_swap_blocks_used
        .bss
        .globl daimos_test_swap_select_v1107
daimos_test_swap_select_v1107: .block 1
        .globl daimos_test_swap_armed_v1107
daimos_test_swap_armed_v1107: .block 1
        .globl daimos_test_swap_outs_v1107
daimos_test_swap_outs_v1107: .block 1
        .globl daimos_test_swap_record_v1107
daimos_test_swap_record_v1107: .block 1
        .globl daimos_test_swap_before_v1107
daimos_test_swap_before_v1107: .block 1
        .globl daimos_test_swap_commits_v1107
daimos_test_swap_commits_v1107: .block 1
        .globl daimos_test_swap_errors_v1107
daimos_test_swap_errors_v1107: .block 1
        .globl daimos_test_swap_verify_v1107
daimos_test_swap_verify_v1107: .block 1
        .globl daimos_test_swap_bitmap_addr_v1107
daimos_test_swap_bitmap_addr_v1107: .block 1
        .globl daimos_test_swap_bitmap_saved_v1107
daimos_test_swap_bitmap_saved_v1107: .block 1
        .globl daimos_test_swap_corrupt_v1107
daimos_test_swap_corrupt_v1107: .block 1
        .globl daimos_test_swap_restores_v1107
daimos_test_swap_restores_v1107: .block 1
        .globl daimos_test_swap_result_v1107
daimos_test_swap_result_v1107: .block 1
        .globl daimos_test_swap_select_calls_v1107
daimos_test_swap_select_calls_v1107: .block 1
        .globl daimos_test_swap_reaper_v1107
daimos_test_swap_reaper_v1107: .block 1
        .globl daimos_test_swap_mark_v1107
daimos_test_swap_mark_v1107: .block 1
        .globl daimos_test_swap_tick_v1107
daimos_test_swap_tick_v1107: .block 1
        .globl daimos_test_swap_slot_v1107
daimos_test_swap_slot_v1107: .block 1
        .globl daimos_test_swap_marker_v1107
daimos_test_swap_marker_v1107: .block 1
        .globl daimos_test_swap_free_calls_v1107
daimos_test_swap_free_calls_v1107: .block 1
        .globl daimos_test_swap_commit_blocks_v1107
daimos_test_swap_commit_blocks_v1107: .block 1
        .globl daimos_test_swap_commit_record_v1107
daimos_test_swap_commit_record_v1107: .block 1
'''
    if sys.argv[4] == '1':
        # The DPY owner can force a swapped process back into core to
        # execute its private FILE-close continuation. Count the real
        # SWAP MRES restore rather than infer it from bitmap activity.
        source += '''
        .bss
        .globl daimos_test_swap_in_calls_v1121
daimos_test_swap_in_calls_v1121: .block 1
        .globl daimos_test_swap_in_ok_v1121
daimos_test_swap_in_ok_v1121: .block 1
'''
path.write_text(source)
PY
if [ "$swap_hup" = 1 ] && [ "$dpy_hup" = 1 ]; then
    python3 - "$work/source/system/kernel/proc/proc_swap_pdp6.s" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
source = p.read_text()
def patch(old, new):
    global source
    if source.count(old) != 1:
        raise SystemExit('v1121: nonunique production SWAP anchor')
    source = source.replace(old, new, 1)

patch('''proc_swap_in:
        add     17,kconst_7_7''',
      '''proc_swap_in:
        caie    1,4                  ; exact second session member
        jrst    daimos_test_swap_in_other_v1121
        aos     daimos_test_swap_in_calls_v1121
daimos_test_swap_in_other_v1121:
        add     17,kconst_7_7''')
patch('''proc_swap_in_restore:
        movei   0,10''',
      '''proc_swap_in_restore:
        caie    10,4
        jrst    daimos_test_swap_in_return_v1121
        jumpn   1,daimos_test_swap_in_return_v1121
        aos     daimos_test_swap_in_ok_v1121
daimos_test_swap_in_return_v1121:
        movei   0,10''')
source = ('''        .globl daimos_test_swap_in_calls_v1121
        .globl daimos_test_swap_in_ok_v1121
''' + source)
p.write_text(source)
PY
fi
if [ "$swap_hup" = 1 ]; then
    python3 - "$work/source/system/kernel/storage/backstore.s" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = '''backstore_verify_allocated_v795:
        skipn   backstore_enabled'''
new = '''backstore_verify_allocated_v795:
        skipn   daimos_test_swap_armed_v1107
        jrst    backstore_verify_original_v1107
        move    4,proc_swap_records
        move    4,4(4)
        hlrz    5,4
        came    1,5
        jrst    backstore_verify_original_v1107
        hrrz    5,4
        came    2,5
        jrst    backstore_verify_original_v1107
        aos     daimos_test_swap_verify_v1107
        move    4,daimos_test_swap_verify_v1107
        caie    4,1
        jrst    daimos_test_swap_restore_v1107
        ; Clear precisely one actually allocated disk-bitmap bit.
        ; The real verifier will fail; no free or record clear may occur.
        move    4,1
        idivi   4,044
        add     4,backstore_bitmap
        movei   6,1
        lsh     6,0(5)
        tdne    6,(4)                  ; skip live branch if bit is clear
        jrst    daimos_test_swap_bit_live_v1107
        movei   7,2                   ; unexpectedly clear allocation bit
        iorm    7,daimos_test_swap_errors_v1107
daimos_test_swap_bit_live_v1107:
        movem   4,daimos_test_swap_bitmap_addr_v1107
        move    7,(4)
        movem   7,daimos_test_swap_bitmap_saved_v1107
        andcm   7,6
        movem   7,(4)
        aos     daimos_test_swap_corrupt_v1107
        jrst    backstore_verify_original_v1107
daimos_test_swap_restore_v1107:
        caie    4,2
        jrst    backstore_verify_original_v1107
        ; The first failed verification must not have consumed the
        ; original DISK record or reduced its block accounting.
        move    4,proc_swap_records
        move    4,4(4)
        came    4,daimos_test_swap_record_v1107
        jrst    daimos_test_swap_record_bad_retry_v1107
        jrst    daimos_test_swap_record_ok_v1107
daimos_test_swap_record_bad_retry_v1107:
        movei   7,4                   ; record changed across refusal
        iorm    7,daimos_test_swap_errors_v1107
daimos_test_swap_record_ok_v1107:
        move    4,proc_swap_blocks_used
        camg    4,daimos_test_swap_before_v1107
        jrst    daimos_test_swap_blocks_bad_v1107
        jrst    daimos_test_swap_blocks_ok_v1107
daimos_test_swap_blocks_bad_v1107:
        movei   7,010                 ; accounted blocks not retained
        iorm    7,daimos_test_swap_errors_v1107
daimos_test_swap_blocks_ok_v1107:
        move    4,daimos_test_swap_bitmap_addr_v1107
        move    5,daimos_test_swap_bitmap_saved_v1107
        movem   5,(4)
        aos     daimos_test_swap_restores_v1107
backstore_verify_original_v1107:
        skipn   backstore_enabled'''
if source.count(old) != 1:
    raise SystemExit('v1107: unique real bitmap-verifier anchor not found')
source = source.replace(old, new, 1)
old_free = '''backstore_free:
        jumpe   2,backstore_free_return'''
new_free = '''backstore_free:
        skipn   daimos_test_swap_armed_v1107
        jrst    daimos_test_swap_free_original_v1107
        push    17,4
        push    17,5
        move    4,daimos_test_swap_record_v1107
        hlrz    5,4
        came    1,5
        jrst    daimos_test_swap_free_other_v1107
        hrrz    5,4
        came    2,5
        jrst    daimos_test_swap_free_other_v1107
        aos     daimos_test_swap_free_calls_v1107
daimos_test_swap_free_other_v1107:
        pop     17,5
        pop     17,4
daimos_test_swap_free_original_v1107:
        jumpe   2,backstore_free_return'''
if source.count(old_free) != 1:
    raise SystemExit('v1107: unique physical backing-free anchor not found')
source = source.replace(old_free, new_free, 1)
source = source.replace('''        .text
''', '''        .text
        .globl proc_swap_records
        .globl daimos_test_swap_armed_v1107
        .globl daimos_test_swap_errors_v1107
        .globl daimos_test_swap_verify_v1107
        .globl daimos_test_swap_bitmap_addr_v1107
        .globl daimos_test_swap_bitmap_saved_v1107
        .globl daimos_test_swap_corrupt_v1107
        .globl daimos_test_swap_restores_v1107
        .globl daimos_test_swap_record_v1107
        .globl daimos_test_swap_free_calls_v1107
''', 1)
path.write_text(source)
PY
fi
if [ "$pipe_hup" = 1 ]; then
    python3 - "$work/source/system/kernel/mm/mm_pdp6.s" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
def patch(before, after):
    global source
    assert source.count(before) == 1, 'v1104: MM hook anchor drift: '+repr(before)
    source = source.replace(before, after, 1)

# Only the second session member's final private PIPE close is armed.
# Pin the *actual* physical MM extent on its first free. The second
# attempt unpins and lets production MM ownership validation free it.
# The same first owner/address and original 0,,1 writer reference must
# survive the refusal; a second attempt may not free a different PIPE.
patch('''mm_free:
        move    5,1
        move    6,2
        move    7,3''', '''mm_free:
        caie    2,3                    ; MM_TYPE_KERNEL_DYNAMIC
        jrst    mm_free_original_v1104
        caie    3,5                    ; PIPE_MM_OWNER
        jrst    mm_free_original_v1104
        skipn   daimos_test_pipe_armed_v1104
        jrst    mm_free_original_v1104
        skipn   daimos_test_pipe_target_v1104
        movem   1,daimos_test_pipe_target_v1104
        move    4,daimos_test_pipe_target_v1104
        came    1,4
        jrst    mm_free_original_v1104
        move    4,3(1)                 ; last writer still owns reference
        caie    4,1
        aos     daimos_test_pipe_errors_v1104
        aos     daimos_test_pipe_calls_v1104
        move    4,daimos_test_pipe_calls_v1104
        caie    4,1
        jrst    daimos_test_pipe_unpin_v1104
        push    17,1
        push    17,2
        push    17,3
        pushj   17,mm_pin
        jumpe   1,daimos_test_pipe_pin_ok_v1104
        aos     daimos_test_pipe_errors_v1104
        jrst    daimos_test_pipe_restore_v1104
daimos_test_pipe_pin_ok_v1104:
        aos     daimos_test_pipe_pins_v1104
        jrst    daimos_test_pipe_restore_v1104
daimos_test_pipe_unpin_v1104:
        push    17,1
        push    17,2
        push    17,3
        pushj   17,mm_unpin
        jumpe   1,daimos_test_pipe_unpin_ok_v1104
        aos     daimos_test_pipe_errors_v1104
        jrst    daimos_test_pipe_restore_v1104
daimos_test_pipe_unpin_ok_v1104:
        aos     daimos_test_pipe_unpins_v1104
daimos_test_pipe_restore_v1104:
        pop     17,3
        pop     17,2
        pop     17,1
mm_free_original_v1104:
        move    5,1
        move    6,2
        move    7,3''')
patch('''mm_free_busy:
        movni   1,5''', '''mm_free_busy:
        move    4,daimos_test_pipe_target_v1104
        camn    4,5
        aos     daimos_test_pipe_busy_v1104
        movni   1,5''')
patch('''        pushj   17,mm_delete
        setz    1,
        popj    17,
mm_free_inval:''', '''        move    4,daimos_test_pipe_target_v1104
        camn    4,5
        aos     daimos_test_pipe_frees_v1104
        pushj   17,mm_delete
        setz    1,
        popj    17,
mm_free_inval:''')
source += '''
        .bss
        .globl daimos_test_pipe_armed_v1104
daimos_test_pipe_armed_v1104: .block 1
        .globl daimos_test_pipe_target_v1104
daimos_test_pipe_target_v1104: .block 1
        .globl daimos_test_pipe_calls_v1104
daimos_test_pipe_calls_v1104: .block 1
        .globl daimos_test_pipe_pins_v1104
daimos_test_pipe_pins_v1104: .block 1
        .globl daimos_test_pipe_unpins_v1104
daimos_test_pipe_unpins_v1104: .block 1
        .globl daimos_test_pipe_busy_v1104
daimos_test_pipe_busy_v1104: .block 1
        .globl daimos_test_pipe_frees_v1104
daimos_test_pipe_frees_v1104: .block 1
        .globl daimos_test_pipe_errors_v1104
daimos_test_pipe_errors_v1104: .block 1
'''
path.write_text(source)
PY
fi
if [ "$dpy_hup" = 1 ]; then
    python3 - "$work/source/system/kernel/mm/mm_pdp6.s" \
        "$work/source/system/kernel/drivers/dpy_io.s" "$pipe_hup" <<'PY'
from pathlib import Path
import sys

mm = Path(sys.argv[1])
dp = Path(sys.argv[2])
source = mm.read_text()
entry_label = ('mm_free_original_v1104:' if sys.argv[3] == '1'
               else 'mm_free:')

def patch(old, new):
    global source
    if source.count(old) != 1:
        raise SystemExit('v1105: nonunique MM anchor: ' + repr(old))
    source = source.replace(old, new, 1)

patch(entry_label + '''
        move    5,1
        move    6,2
        move    7,3''', entry_label + '''
        caie    2,3                    ; MM_TYPE_KERNEL_DYNAMIC
        jrst    mm_free_original_v1105
        caie    3,014                  ; DPY raw-list MM owner
        jrst    mm_free_original_v1105
        skipn   daimos_test_dpy_armed_v1105
        jrst    mm_free_original_v1105
        skipn   daimos_test_dpy_target_v1105
        movem   1,daimos_test_dpy_target_v1105
        move    4,daimos_test_dpy_target_v1105
        came    1,4
        jrst    mm_free_original_v1105
        aos     daimos_test_dpy_calls_v1105
        move    4,daimos_test_dpy_calls_v1105
        caie    4,1
        jrst    daimos_test_dpy_unpin_v1105
        push    17,1
        push    17,2
        push    17,3
        pushj   17,mm_pin
        jumpe   1,daimos_test_dpy_pin_ok_v1105
        aos     daimos_test_dpy_errors_v1105
        jrst    daimos_test_dpy_restore_v1105
daimos_test_dpy_pin_ok_v1105:
        aos     daimos_test_dpy_pins_v1105
        jrst    daimos_test_dpy_restore_v1105
daimos_test_dpy_unpin_v1105:
        push    17,1
        push    17,2
        push    17,3
        pushj   17,mm_unpin
        jumpe   1,daimos_test_dpy_unpin_ok_v1105
        aos     daimos_test_dpy_errors_v1105
        jrst    daimos_test_dpy_restore_v1105
daimos_test_dpy_unpin_ok_v1105:
        aos     daimos_test_dpy_unpins_v1105
daimos_test_dpy_restore_v1105:
        pop     17,3
        pop     17,2
        pop     17,1
mm_free_original_v1105:
        move    5,1
        move    6,2
        move    7,3''')
busy_next = ('        move    4,daimos_test_pipe_target_v1104'
             if sys.argv[3] == '1' else '        movni   1,5')
patch('mm_free_busy:\n' + busy_next, '''mm_free_busy:
        move    4,daimos_test_dpy_target_v1105
        camn    4,5
        aos     daimos_test_dpy_busy_v1105
''' + busy_next)
free_next = ('''        move    4,daimos_test_pipe_target_v1104
        camn    4,5
        aos     daimos_test_pipe_frees_v1104
        pushj   17,mm_delete''' if sys.argv[3] == '1'
             else '        pushj   17,mm_delete')
patch(free_next + '''
        setz    1,
        popj    17,
mm_free_inval:''', '''        move    4,daimos_test_dpy_target_v1105
        camn    4,5
        aos     daimos_test_dpy_frees_v1105
''' + free_next + '''
        setz    1,
        popj    17,
mm_free_inval:''')
source += '''
        .bss
        .globl daimos_test_dpy_armed_v1105
daimos_test_dpy_armed_v1105: .block 1
        .globl daimos_test_dpy_target_v1105
daimos_test_dpy_target_v1105: .block 1
        .globl daimos_test_dpy_calls_v1105
daimos_test_dpy_calls_v1105: .block 1
        .globl daimos_test_dpy_pins_v1105
daimos_test_dpy_pins_v1105: .block 1
        .globl daimos_test_dpy_unpins_v1105
daimos_test_dpy_unpins_v1105: .block 1
        .globl daimos_test_dpy_busy_v1105
daimos_test_dpy_busy_v1105: .block 1
        .globl daimos_test_dpy_frees_v1105
daimos_test_dpy_frees_v1105: .block 1
        .globl daimos_test_dpy_errors_v1105
daimos_test_dpy_errors_v1105: .block 1
        .globl daimos_test_dpy_refresh_v1105
daimos_test_dpy_refresh_v1105: .block 1
        .globl daimos_test_dpy_after_busy_v1105
daimos_test_dpy_after_busy_v1105: .block 1
'''
mm.write_text(source)

source = dp.read_text()
old = '''        skipn dpy_list_base
        jrst dpy_refresh_retained
        move 1,dpy_list_iowd'''
new = '''        skipn dpy_list_base
        jrst dpy_refresh_retained
        aos daimos_test_dpy_refresh_v1105
        skipn daimos_test_dpy_busy_v1105
        jrst daimos_test_dpy_refresh_next_v1105
        skipe daimos_test_dpy_unpins_v1105
        jrst daimos_test_dpy_refresh_next_v1105
        aos daimos_test_dpy_after_busy_v1105
daimos_test_dpy_refresh_next_v1105:
        move 1,dpy_list_iowd'''
if source.count(old) != 1:
    raise SystemExit('v1105: nonunique DPY PI6 refresh anchor')
dp.write_text(source.replace(old, new, 1))
PY
fi
if [ "$disk_pi6" = 1 ]; then
    python3 "$self/daimos-oom-disk-pi6-v1154.py" \
        "$work/source/system/kernel"
fi
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
incs=""
for d in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
if [ "$pipe_hup" = 1 ]; then
    cflags='-DDAIMOS_V1104_PIPE_HUP=1'
    if [ "$dpy_hup" = 1 ]; then
        cflags="$cflags -DDAIMOS_V1105_DPY_HUP=1"
    fi
    if [ "$swap_hup" = 1 ]; then
        cflags="$cflags -DDAIMOS_V1107_SWAP_HUP=1 -DDAIMOS_V1122_PIPE_SWAP=1"
    fi
elif [ "$dpy_hup" = 1 ]; then
    cflags='-DDAIMOS_V1105_DPY_HUP=1'
    if [ "$swap_hup" = 1 ]; then
        cflags="$cflags -DDAIMOS_V1107_SWAP_HUP=1"
    fi
elif [ "$swap_hup" = 1 ]; then
    cflags='-DDAIMOS_V1107_SWAP_HUP=1'
else
    cflags=''
fi
if [ "$disk_pi6" = 1 ]; then
    cflags="$cflags -DDAIMOS_V1154_PI6_DISK_SPIN=1"
fi
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $cflags $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-session-hup-physical-v907.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"

build="$work/build/system/boot/pdp6"
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    >"$work/build.log" 2>&1 || {
        tail -80 "$work/build.log" >&2
        echo 'v907: isolated image build failed' >&2
        exit 1
    }
for name in first leader base pins unpins failures second repeats pending errors; do
    sym="daimos_test_${name}_v907"
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v907: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
if [ "$pipe_hup" = 1 ]; then
    for name in armed target calls pins unpins busy frees errors; do
        sym="daimos_test_pipe_${name}_v1104"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1104: missing $sym" >&2; exit 1; }
        printf 'pipe_%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$dpy_hup" = 1 ]; then
    for name in armed target calls pins unpins busy frees errors refresh after_busy; do
        sym="daimos_test_dpy_${name}_v1105"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1105: missing $sym" >&2; exit 1; }
        printf 'dpy_%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$swap_hup" = 1 ]; then
    for name in select armed outs record before commits errors verify bitmap_addr bitmap_saved corrupt restores result select_calls reaper mark tick slot marker free_calls commit_blocks commit_record; do
        sym="daimos_test_swap_${name}_v1107"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1107: missing $sym" >&2; exit 1; }
        printf 'swap_%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$swap_hup" = 1 ] && [ "$dpy_hup" = 1 ]; then
    for name in calls ok; do
        sym="daimos_test_swap_in_${name}_v1121"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1121: missing $sym" >&2; exit 1; }
        printf 'swap_in_%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$disk_pi6" = 1 ]; then
    for name in swap_first swap_last user_sleeps user_first user_last; do
        sym="daimos_pi6_${name}_v1154"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1154: missing $sym" >&2; exit 1; }
        printf 'pi6_%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
boot="$build/boot.ini"
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' "$boot"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$boot"
done < "$work/addresses"
printf 'exit\n' >> "$boot"
set +e
(cd "$build"; TERM=dumb timeout -k 2s 80s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -85 "$work/simh.out" >&2
    echo "v907: simulator exited $rc" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" "$pipe_hup" "$dpy_hup" "$swap_hup" "$disk_pi6" <<'PY'
from pathlib import Path
import re
import sys
output=Path(sys.argv[2]).read_text(errors='replace')
seen={}
for line in Path(sys.argv[1]).read_text().splitlines():
    name,addr=line.split()
    values=re.findall(r'(?im)^\s*0*'+re.escape(addr.lstrip('0'))+
                      r'\s*:\s*([0-7]+)\b',output)
    if not values:
        raise SystemExit('v907: missing sample '+name+'\n'+output[-1500:])
    seen[name]=int(values[-1],8)
expected=dict(pins=1,unpins=1,failures=1,
              second=(0 if sys.argv[5] == '1' and sys.argv[4] != '1'
                      else 1),
              repeats=1 if sys.argv[3] == '1' and sys.argv[5] == '1' else 0,
              pending=1,errors=0)
for name,value in expected.items():
    if seen[name]!=value:
        raise SystemExit('v907: '+name+'='+str(seen[name])+
                         ' expected '+str(value)+'\n'+output[-1800:])
if sys.argv[3] == '1':
    for name, value in dict(pipe_armed=(1 << 36)-1,
                            pipe_calls=2,pipe_pins=1,pipe_unpins=1,
                            pipe_busy=1,pipe_frees=1,pipe_errors=0).items():
        if seen[name] != value:
            raise SystemExit('v1104: '+name+'='+str(seen[name])+
                             ' expected '+str(value)+'\n'+output[-1800:])
    if not seen['pipe_target']:
        raise SystemExit('v1104: no private PIPE owner recorded')
if sys.argv[4] == '1':
    for name, value in dict(dpy_armed=(1 << 36)-1,
                            dpy_calls=2,dpy_pins=1,dpy_unpins=1,
                            dpy_busy=1,dpy_frees=1,dpy_errors=0).items():
        if seen[name] != value:
            raise SystemExit('v1105: '+name+'='+str(seen[name])+
                             ' expected '+str(value)+'\n'+output[-1800:])
    if not seen['dpy_target'] or seen['dpy_refresh'] < 3 or \
            seen['dpy_after_busy'] < 1:
        raise SystemExit('v1105: DPY raw PI6 replay/owner failed: '+
                         str(seen)+'\n'+output[-1800:])
if sys.argv[5] == '1':
    mixed_restore = sys.argv[4] == '1'
    # In v1107 alone, the terminal DISK owner is finalized by slot 0.
    # With an earlier physical DPY FILE-close refusal, its owning
    # process instead runs a real swap-in before finishing private
    # FILE close. The DISK bitmap verifier may not be injected on that
    # path, so require actual SWAP MRES restoration counters instead.
    required=dict(swap_select=0, swap_result=0,
                  swap_select_calls=1, swap_armed=(1 << 36)-1,
                  swap_outs=1,swap_free_calls=1,swap_errors=0)
    if mixed_restore:
        required.update(swap_in_calls=1,swap_in_ok=1,
                        swap_verify=0,swap_corrupt=0,swap_restores=0,
                        swap_bitmap_addr=0,swap_bitmap_saved=0)
    else:
        required.update(swap_verify=2,swap_corrupt=1,swap_restores=1)
    for name, value in required.items():
        if seen[name] != value:
            raise SystemExit('v1121/v1107: '+name+'='+str(seen[name])+
                             ' expected '+str(value)+'\n'+output[-2300:])
    if not seen['swap_record'] or (
            not mixed_restore and not seen['swap_bitmap_addr']):
        raise SystemExit('v1107: no real disk backing owner')
    if seen['swap_commits'] < 1 or seen['swap_reaper'] < 1 or \
            seen['swap_mark'] < 1:
        raise SystemExit('v1107: missing deferred finalizer/reaper/commit: '+
                         str(seen))
    if seen['swap_commit_blocks'] != seen['swap_before'] or \
            seen['swap_commit_record'] != 0:
        raise SystemExit('v1107: terminal DISK owner/bitmap leaked: '+
                         str(seen)+'\n'+output[-2300:])
if sys.argv[6] == '1':
    ticks = (seen['pi6_swap_last'] - seen['pi6_swap_first']) & 0o377777
    work = seen['pi6_user_last'] - seen['pi6_user_first']
    if seen['pi6_swap_first'] == 0 or ticks < 2 or work < 1 or \
            seen['pi6_user_sleeps'] < work:
        raise SystemExit('v1154: missing real PI6/independent spinner '
                         'progress between actual DISK verifications: '
                         + repr((ticks, work, seen)))
    print('v1154: real PI6 DISK retry ticks', ticks,
          'and unrelated user sleep progress', work, 'PASS')
if seen['first']<=2 or seen['leader']<=1 or not seen['base'] or \
        '<' not in output or \
        'H' not in output or 'HALT' not in output or '!' in output:
    raise SystemExit('v907: guest failed\n'+output[-2000:])
if sys.argv[5] == '1':
    if sys.argv[3] == '1':
        print('v1122: real first-member PIPE MM_BUSY followed by '
              'second-member DISK bitmap refusal and exact retries '
              'with final WAIT/TTY ownership PASS:', seen)
    elif sys.argv[4] == '1':
        print('v1121: real physical DPY MM_BUSY with genuine DISK '
              'swap-out/swap-in, exact backing release, retained PI6 '
              'list and WAIT/TTY ownership PASS:', seen)
    else:
        print('v1107: real swap-out, physical bitmap verifier refusal, '
              'record/WAIT retention and exact repair/free HUP PASS:',seen)
elif sys.argv[3] == '1' and sys.argv[4] == '1':
    print('v1119: combined physical PIPE/DPY HUP MM release retry, '
          'display PI6 and final WAIT/TTY ownership PASS:',seen)
elif sys.argv[4] == '1':
    print('v1105: booted physical HUP + pinned DPY PI6 replay/real '
          'MM_BUSY retry + deferred u-area/WAIT PASS:',seen)
elif sys.argv[3] == '1':
    print('v1104: booted physical HUP plus PIPE MM_BUSY and pinned '
          'member u-area, exact retries/TTY handoff PASS:',seen)
else:
    print('v907: PDP-6 real MM pin/partial HUP/retry/unpin/TTY handoff PASS:',seen)
PY
