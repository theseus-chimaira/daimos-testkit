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
