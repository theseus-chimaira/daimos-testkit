; v1674: test-only PURE child with deterministic pipe read + EXIT.
; Its standard SYS_READ_WORDS blocks on inherited FD0 until PID1 releases
; the nine children after the physical MM B checkpoint. No timer expiry.
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
        ; PID2 is the STOP/foreign-TERM target. It must own a saved
        ; user-mode PC, never an inherited private READ continuation.
        uuo 076,0               ; real GETPID, one target per guest
        caie 01,2
        jrst __pipe_wait_v1682
__user_spin_v1682:
        jrst __user_spin_v1682
__pipe_wait_v1682:
        movei 01,0              ; inherited pipe read end in child FD0
        movei 02,02501          ; one writable suffix word, no APR pin while blocked
        movei 03,1              ; request exactly one 36-bit word
        uuo 055,0(1)             ; native SYS_READ_WORDS, blocks as PROC_SLEEP
        caie 01,1              ; exactly one release token expected
        jrst __bad_pipe
        move 04,02501           ; verify the unique parent release value
        came 04,[01234567]
        jrst __bad_pipe
        uuo 076,0               ; recover own PID, not pre-pipe AC state
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
__bad_pipe:
        movei 01,15            ; invalid/missing pipe release
        uuo 040,0(1)
        halt .
__bad_canary:
        movei 01,16            ; retained RAW suffix was lost/corrupted
        uuo 040,0(1)
        halt .

; Retain the original fixed DXR2 text extent: the v1674 blocking
; read, token verification and error path replace six padding words.
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
