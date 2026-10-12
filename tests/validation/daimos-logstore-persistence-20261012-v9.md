# LOGSTORE persistence regression reproducer (v9, OPEN)

Build a *fresh* PDP-6 disk image, then run
`probes/daimos-logstore-persistence-20261012-v9.txt` using
`tools/daimos-simh-harness-v6.sh`. Do not reuse a simulated disk image
after an earlier boot: this has independently triggered a `?RT`
root-mount failure during investigation.

As of 2026-10-12, the probe **fails**. `LOGD` reports `LOGSTORE READY`,
but `LOGDUMP` prints no retained record. A temporary diagnostic build
printed LOGSTORE next producer sequence `000000000004`, yet the three
expected slots returned all-zero records (`magic`, sequence, trailer).
Thus the in-memory producer cursor advanced without a readable block.
Both general APPEND using a static BSS record and APPEND using a
temporary user stack record exhibited the issue. Even the compact
four-word EVENT path has failed on subsequent fresh-image runs after
one earlier successful run. Do not claim record persistence on the
strength of SYS_LOGCTL return values or a working LOGIN/DSH boot.

Run this alongside the existing 115-probe DSH suite and the direct
INIT_READY check. Investigate the LOGSTORE write/read backend and
physical block mapping, fix the cause, and require repeated fresh-disk
passes before promoting single-block SUPERVISOR to production.
