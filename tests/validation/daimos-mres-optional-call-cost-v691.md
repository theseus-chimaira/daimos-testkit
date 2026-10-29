# v691: Optional-service gateway fan-out

`sys_logstore_service_jump` and `sys_mtc_service_jump` are one-word
KINIT-patched `JRST` entry points. Their callers execute `PUSHJ` to the
resident entry; the entry then jumps to the installed MRES. An uninstalled
service defaults to `kret_neg1`.

Patching every existing `PUSHJ` to the MRES directly would remove one shared
trampoline word per service and one executed jump per call. However, it
requires patching **every** caller and assigning the same absent-service
target at all sites. The helper counts distinct source call instructions and
the additional KINIT patches needed relative to the single existing patch.

In the current system this is primarily a speed-versus-binding-complexity
tradeoff, not a demonstrated KCORE or total-resident RAM optimization.
KINIT patching code is transient, but runtime relocation/removal would have
to retarget all direct caller instructions rather than one stable trampoline.

The script is a source-level audit; no direct-call prototype is executed and
no change is made to production DAIMOS.
