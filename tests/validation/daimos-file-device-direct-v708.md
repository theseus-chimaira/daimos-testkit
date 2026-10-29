# v708 — Seven optional file-device calls

Seven single-caller service gateways (TTY read/write, LPT word write,
WCNSLS read/write and TTYDPY char read/write) are replaced by direct
KINIT-patched PUSHJ instructions with the original `kret_neg1` default.
The two-caller DPY word-output trampoline remains unchanged. The five
associated deferred-module mover entries now refer to direct call sites.

No new permanent patch table or runtime instructions are introduced.
The full lowmem image and source regression test verify the integration;
separate native execution and linked-map comparison establish behavior
and exact resident word savings.
