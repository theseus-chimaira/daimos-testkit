; Minimal test-only child, event-blocked on inherited PIPE fd0.
; No C runtime or large TSFS executable; all outputs are ASCII comments.
        .text
        .globl _start
_start:
        ; This is the actual native 36-bit GETPID + BRK syscall path.
        ; On a 48K guest, PID2..PID6 grow from 02000 to 06000 APR words.
        ; Five enlarged and four ordinary children, plus a refused
        ; tenth RUN, force true MM pressure and RAW PURE reclamation.
        uuo 076,0              ; SYS_GETPID, return child PID in AC1
        ; Every child writes a PID-specific canary into its *writable*
        ; VM suffix before it sleeps. This word lies beyond the 0200
        ; octal PURE prefix and is checked after native PURE restoration.
        ; An EXIT(0) is impossible if evicted suffix data was corrupted.
        movei 03,012345
        xor 03,1
        movem 03,02500
        subi 01,6
        jumpg 01,__sleep
        movei 02,06000         ; 3072 logical words in the child APR
        movei 01,052           ; SYS_EXT_BRK selector
        uuo 077,0(1)
        jumpl 01,__bad_brk
__sleep:
        movei 01,0              ; inherited reader pipe, mapped as fd0
        uuo 061,0(1)            ; real SYS_READCHAR: blocks in PROC_SLEEP
        caie 01,0122            ; 'R': explicit PID1 release token
        jrst __bad_canary
        uuo 076,0               ; recover own PID, not pre-SLEEP AC state
        movei 03,012345
        xor 03,1
        came 03,02500          ; compare retained writable suffix
        jrst __bad_canary
        movei 01,0              ; clean EXIT status
        uuo 040,0(1)
        halt .                  ; never reached if native EXIT succeeds
__bad_brk:
        movei 01,17            ; BRK rejected: never silently continue
        uuo 040,0(1)
        halt .
__bad_canary:
        movei 01,16            ; retained RAW suffix was lost/corrupted
        uuo 040,0(1)
        halt .

; Retain the original fixed DXR2 text extent: eleven added canary
; instructions replace eleven original padding words.
; One full explicit DXR2 text sector, unreachable in normal execution.
; This gives the actual PURE loader an immutable prefix to release.
; Without sufficient TX2 text, the PDP-6 sector skip is zero, and
; no RAW eviction is legal. This is a source-backed test fixture.
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
