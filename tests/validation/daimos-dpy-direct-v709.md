# v709 — DPY shared-gateway elimination

DPY had two fixed callers, one submitting a zero-word stop during CLOSE
and one performing WRITE_WORDS. Both now use individual KINIT-patched
`PUSHJ` instructions. The write call defaults to `kret_neg1` when no display MRES
is installed. As of v871, CLOSE defaults to `kret_zero`: no loaded DPY
means no raw list needs releasing. An installed DPY reports release
errors directly to FILE instead of masking them with a device VFS sync.
The single intermediate JRST is removed. The deferred
module-runtime fixed-binding list now references both patch sites.

The expected KCORE saving is one 36-bit instruction word. Confirm this
with the linked map comparison and native PDP-6 tests before claiming it.
