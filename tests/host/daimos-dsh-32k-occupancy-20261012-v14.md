# DSH 32K memory pressure — reproducible occupancy check

Captured with a **temporary, subsequently reverted** LOGIN-side
`SYS_MEMINFO` and `SYS_PROCINFO` trace. No diagnostic code belongs in
production LOGIN. The fixture records the 32K state just before ROOT
calls DSH EXEC. Run:

`sh tests/host/daimos-dsh-32k-occupancy-20261012-v14.sh`.

Total core: 0100000 octal words. Kernel/modules: 031152.
Occupied process memory: 025020, including an 012000-word INIT image,
an 012000-word LOGIN image and 01020 words of stable process overhead.
After releasing LOGIN, the maximum unfragmented free space is only
033606 octal. The largest 02000-aligned user extent that could possibly
fit is **032000**, whereas DSH currently requests **044000**.
No claim of actual contiguous availability is made.

This proves the *combined* current residency cannot fit even after
destructive low-memory EXEC. INIT swap eligibility, executable backing,
pinning and victim choice must be audited, or DSH would have to shrink
by another 012000 octal **allocated** words (5120 decimal) to fit
alongside INIT. Overlays may be explored only after computing their net
loader/window/IO cost; they are not yet implemented.
