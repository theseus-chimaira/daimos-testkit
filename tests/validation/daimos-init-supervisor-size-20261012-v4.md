# SUPERVISOR V4: reuse reserved stack for LOGSTORE scratch

PDP-6 production INIT/SUPERVISOR build, octal 36-bit words:

| | v3 | v4 |
| --- | ---: | ---: |
| SUPERVISOR image | 001447 | **001442** |
| SUPERVISOR static BSS | 000461 | **000261** |
| Stack reservation | 002000 | 002000 |
| Rounded VM allocation | 006000 | **004000** |

Only the SUPERVISOR build places the existing 0200-octal-word LOGSTORE
record on the C call stack while an event is being emitted; every other
program retains the existing static buffer. This exchanges BSS storage
for transient stack use without modifying the per-executable stack ABI.
The save in actual resident core is 02000 octal / 1024 decimal words.

`tests/validation/daimos-init-supervisor-size-20261012-v4.sh` checks
the strict image and rounded VM bounds. A production PDP-6 disk image
build passes; the 115-probe DSH conformance and repeated error/respawn
stress testing are distinct acceptance requirements. Full 32K LOGIN/DSH
boot must be measured separately and is not implied by these figures.
