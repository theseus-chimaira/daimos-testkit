# Test-only ambiguous FCB completion — 2026-10-12 v1

An isolated generated `fs_backing.s` variant calls the real backing-write
callback and, if it succeeded for an FCB-table logical block (442..486),
returns -1 to its caller instead. This models **reported failure after a
completed backing callback**. It does NOT establish hardware durability,
model a torn write, or interrupt power.

The test image pre-seeds `/CONFIG/FCBSEED` with one word. The PDP-6 C99
fixture appends a second word, requires a negative write return, then
reopens and observes two committed words, correctly distinguishing the
unknown commit outcome from a definitively rejected FCB update.

SIMH 2026-10-12: append/readback probe PASS; orderly HALT PASS. However,
`d6fsck -n 4` FAILED on a CLEAN-marked filesystem with two unreachable FCBs:
451 and 452 (each reference count 0). Hence **the end-to-end test FAILS**.
The injection applies to every FCB block in this range for the whole boot,
not only the target append. Unrelated operations (including directory/other
metadata updates) may be affected; causal attribution requires a narrower
selector or a write-hit trace. Do not infer that the staged growth helper
caused the two unreachable FCBs, and do not claim atomic record commits.

Next: isolate only the targeted FCB publication, trace each injected write,
check before/after disk images, and rerun `d6fsck`. Preserve the failing
image under `$TMPDIR` for diagnosis. Ensure an unclean power-cut test uses
cloned disks and post-reboot checks, not just synthetic completion status.
