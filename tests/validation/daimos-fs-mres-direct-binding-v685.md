# v685 — Instruction-embedded direct MRES operation bindings

This is a **table representation and linked-size prototype**, not a complete
direct-call dispatcher and not a native PDP-6 behavioral test.

The script extracts all 16 slots from the real D6FS, MEMFS, DTFS and TSFS
provider vectors, including unsupported (zero) slots. It emits and links
two equivalent placeholder-target representations for comparison:

* 4 × 8 packed `.word LH,,RH` records = **32 data words**;
* 4 × 16 `JRST target` instruction records = **64 data words**.

Both alternatives retain the same one-word placeholder code target. The
direct representation therefore costs 32 additional words across the four
providers. This can be offset by removing the shared operation decoder,
measured as **33 gross words** in the earlier v683 isolated comparison;
however, a real call path must still perform operation-range checks,
marshal C arguments, implement missing-operation rejection, and preserve
the outer provider lock. Therefore **no net saving is demonstrated**.

The first attempt deliberately retains all missing slots so it does not
silently change operation numbering or provider capability semantics. A
future fair A/B experiment must implement real provider entry and dispatch
code with the same ABI and tests, rather than compare tables alone.

Production DAIMOS is unchanged. Source tests belong in daimos-testkit.
