; Source-map-linked guest fixture phase markers, all no-op functions.
; Their user virtual addresses MUST NOT be used as SIMH breakpoints:
; those addresses may overlap unrelated fixed KCORE instructions.
; Real physical snapshots are taken only at synchronized CTY holds.
        .text
        .globl v1672_before
        .globl v1672_pressure
        .globl v1672_reaped
v1672_before:
        popj 017,
v1672_pressure:
        popj 017,
v1672_reaped:
        popj 017,
