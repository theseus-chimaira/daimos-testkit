# Transient executable backing reservation, v1933

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-load-reservation-v1933

The native PDP-6 gate links the actual provider gateway, reservation
publication/release, file/mount owner scanners, quiescence guard and
exec_load_process. Controlled wait, lookup, STAT, payload, MM and
attachment boundaries exercise lease drain before reservation, exact
vnode protection, mount protection, overlapping reservations and
non-LIFO removal. Actual WRITE/TRUNCATE dispatch refuses a reserved
vnode but permits an unrelated file. Eight plain DXR1 loader cases
cover success and lookup, STAT, access, header, allocation, payload
and attachment refusal, with balanced stacks and an empty list on
return. Six unsafe variants fail native assertions (octal 1, 2, 2,
3, 4, 0100). Earlier owner/lease/mutation and FULL guard regressions
pass with an explicit empty reservation list in isolated fixtures.

This is controlled native validation, not whole-guest PI6 acceptance.
The native loader oracle does not execute real compressed or raw-XIP
payloads, or the complete EXEC old/new-image transaction. The latter
must preserve both live backing dependencies across startup, record
replacement and destruction. Private stack lifetime across fatal
process recovery and the lookup-to-reservation namespace boundary
need integrated testing. Some older source-extraction runners were
adjusted for the new symbol/leaf boundary but have not been rerun.
