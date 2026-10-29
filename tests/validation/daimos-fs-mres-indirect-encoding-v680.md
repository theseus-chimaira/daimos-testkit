# MRES dispatcher indirect addressing — v680

This test assembles and links a small independent PDP-6/PDP-10 call sequence
using an indexed indirect `PUSHJ` through a KINIT-style `JRST` service slot.
The assembler produces LH octal `260767`, explicitly encoding `PUSHJ` with
the indirect bit and index register 7. The linked symbol starts at 000020.

This independently verifies that the v679 optimization is representable and
linkable; it does **not** establish that a live PDP-6 simulator follows a
patched service `JRST` to its target correctly, or that the filesystem lock
survives a blocking call. Those native tests are required before editing
production `fs_mres.s`.

The proposed dispatch simplification removes two instructions (one from the
MEMFS fast path, one from the serialized path). KCORE net-word savings and
dynamic direct-binding costs are not yet measured with matched whole-system
images. No production change was made.
