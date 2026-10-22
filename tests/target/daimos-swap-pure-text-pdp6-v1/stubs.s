        .text
        .globl  proc_swap_victim
proc_swap_victim:
        seto    1,
        popj    17,

        .globl  proc_event_apply
proc_event_apply:
        seto    1,
        popj    17,

        .globl  mm_compact
mm_compact:
        seto    1,
        popj    17,

; V72 startup snapshots are an independent subsystem.  This fixture
; concentrates on swap backing/mode transactions, so model a successful
; pinned snapshot acquisition and a no-op release.  Real snapshots are
; exercised by their own targeted test; do not mask swap-mode errors here.
        .globl  proc_snap_take_v72
proc_snap_take_v72:
        setz    1,
        popj    17,

        .globl  proc_snap_drop_v72
proc_snap_drop_v72:
        popj    17,
