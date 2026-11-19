; Minimal test-only 36-bit user process. Real scheduler SLEEP + EXIT UUOs.
; No C runtime or large TSFS executable; all outputs are ASCII comments.
        .text
        .globl _start
_start:
        movei 02,027340         ; 12000 decimal 60-Hz ticks = 200 seconds
        movei 01,036            ; SYS_EXT_SLEEP selector
        uuo 077,0(1)
        movei 01,0              ; clean EXIT status
        uuo 040,0(1)
        halt .                  ; never reached if native EXIT succeeds
