# Native PDP-6 codec v014: first exact counted-stream round trip

PASS in isolated PDP-6 `p10run` deposit mode: three nonzero source words
encoded by the assembler encoder to four words (one control plus three
literals), decoded by `decode_v014.s` back to the original three words.
The decoder checks exact source consumption, output bounds, control count,
and reserved/match flag bits. The native encoder has the corrected
literal-group termination from v013.

This is a **literal-only subset** of the v006 counted-group stream format.
It does not prove correct zero-run decoding or any paired 18-bit match
handling. The v009 encoder's zero-run path emits an incompatible descriptor
and is not used by this passing test. Keep it out of production.

Both routines currently use a research ABI, not the production D6LZ36
resumable AC state. They are standalone testkit sources and never built into
DAIMOS KCORE or Stage-1. Subsequent work must preserve the existing kernel
frontend ABI and fixed low-core constraints when implementing the complete
v006 decoder.
