# v702 — Direct clock binding from KINIT into MRES consumers

Six existing PUSHJ instructions have new linkable labels, two in MEMFS and
four in D6FS. Both MRES export tables include the sites after their earlier
exports, retaining all existing export indices. During installation, KINIT
reads the RH18 of the already-patched wall-time gateway and writes that
destination directly into each consumer PUSHJ. The gateway itself is kept
for existing syscall-table/C callers; its uninstalled default target is the
zero-returning `wall_time36_unset` routine.

No instruction is added at a consumer call site and no permanent binding
table is introduced. MRES package export metadata grows, but is separate
from the installed module image. A full-profile MEMFS target and a lowmem
D6FS image both link the exports. This does not yet remove the resident
wall-time gateway, nor prove a runtime speedup in a full guest boot.

The existing early-module order guarantees that the selected calendar
provider is installed first. Both PCLK and software-clock pathways still
patch the same resident gateway before MRES consumers are installed.
