# v700 — Clock cross-MRES binding feasibility

KINIT's module install table selects PCLK or software clock **before** either
MEMFS or D6FS installation. Therefore cross-MRES direct binding could be
performed by the consumer's MINIT after its package has been installed.

The explicit assembly source contains six `PUSHJ 17,wall_time36` calls
within MEMFS and D6FS. D6FS also calls the clock from C, so a complete
patch-site inventory requires inspection of generated PDP-6 assembly before
new exports can be assigned. The syscall dispatch includes a packed
`native_sys_exec,,wall_time36` reference; SETTIME uses a tail JRST through
the clock gateway. Neither can simply be reinterpreted as a PUSHJ.

The existing resident two-word gateway is the only common interface for
both calendar providers. Removing it would require exposing all MRES-local
call sites as exports, adding direct binding patch operations to two MINITs,
retargeting the packed syscall halfword, and providing retained no-clock
failure defaults. Without those changes, deleting the gateway would leave
unresolved calls in independently linked module images.

The source audit passes and proves provider ordering, but it does not yet
establish net installed-RAM savings or native equivalence. Do not change
production until the compiler-generated calls and cross-module link sites
are audited and measured.
