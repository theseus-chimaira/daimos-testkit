# Supervisor-only syscall veneer linkage (v6)

The resident PID 1 supervisor uses exactly eight syscall veneers copied
without ABI changes from libc/syscall.s: EXIT, WRITECHAR, RUN, WAIT,
GETPID, GETTIME, LOGCTL and TTYCTL. The generic syscall object and
unneeded syscall-helper object are no longer linked into SUPERVISOR.

Target size checks (octal 36-bit words):

| | v5 | v6 |
| --- | ---: | ---: |
| Image | 001442 | **001236** |
| BSS | 000261 | 000261 |
| Default initial VM | 004000 | 004000 |

Run `daimos-init-supervisor-size-20261012-v6.sh` with the three matching
INIT_DXR, SUPERVISOR_DXR and DSH_DXR environment paths. A missing
syscall veneer is a link failure and must not be suppressed.

The complete boot/conformance suite establishes the functional target
baseline; it does not alone cover eight concurrent configured services,
TTY 20, every RESPawn error path, or the 32K boot constraint.

The 02000-octal process allocation unit is determined by PDP-6 APR
relocation/protection, not by a minimum size in the generic MM allocator.
