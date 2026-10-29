# v704 — eliminate permanent clock dispatch trampolines

The wall-clock gateway contained two unconditional JRST instructions, one
for TIME36 and one for SETTIME. The known callers were converted to direct
bindings in v702–v703, and the old symbols now denote the unchanged fallback
routines (`TIME36` returns zero; `SETTIME` returns -1). No unconditional
trampoline remains resident. KINIT stores the chosen PCLK/SCLK address in a
temporary scalar instead of consulting a patched KCORE gateway instruction.

This deliberately preserves a direct fallback symbol for any unpatched
MRES reference, so independently linked consumers still resolve correctly.
The KINIT service selection belongs to transient code, not to resident
relocation tables. Full native boot of both calendar configurations remains
a distinct acceptance test; the source and linked map test must not be
reported as proof of full runtime boot.
