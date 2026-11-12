# KCORE v1517: simulated DECtape selection status is not a loss event

Date: 2026-11-12. Evidence from real PDP-6 SIMH I/O instructions,
not a claim of original Type-551 hardware equivalence.

`daimos-dtc-select-status-v1517.sh` executes a five-instruction
PDP-6 program containing a legal `MOVEI`, `CONO 0210` search/select,
`CONI 0214`, `MOVEM`, and an actual HALT. It runs that program in
current PDP-6 SIMH without a filesystem or synthetic status stubs.

| Physical selection | Controller status (octal) | Expected behavior |
| --- | --- | --- |
| DTC0 not attached | `000004` | `DTB_ILL` select/illegal error |
| DTC0 attached | `001000` | `DTB_REQ`, no select error |
| DTC0 detached after attachment | `000004` | `DTB_ILL` |
| DTC7 not attached, unrelated to selected root | `000004` | same `DTB_ILL` |

All four actual simulator HALTs occur at PC `001004`; the script
checks actual stored PDP-6 CONI words, not host metadata or a
mock function. All simulator cases PASS with the current SIMH.

SIMH `pdp6_dtc.c` sets `DTB_ILL` when selecting a unit without
`UNIT_ATT`. The same raw bit is named an *illegal/select* error,
not a dedicated removable-medium event: a command/selector fault
can be reported in the same category. The contemporary TU55/TU56
maintenance descriptions explain that transport OFF/LOCAL inhibits
remote control, and that the select-echo mechanism used on later
control systems is not used with the Type-550/551/552 family.
The Type-551 source-level hardware semantics require closer
validation before assuming a specific absence signal is always
produced by a physically removed tape. A running transport with a
missing reel or unreadable mark track can simply stop producing
the requested block marks, eventually reaching the existing bounded
search timeout instead of returning a distinct media change bit.

**Policy:** `DTB_ILL`, an individual negative Type-136 I/O result,
or a DTC search/data watchdog expiration is not automatically
evidence of *confirmed* root media removal. A selected physical
unit may belong to the TSFS root, an unrelated DTFS mount, or be
unmounted; the v1516 validated physical member mask is needed even
when an authoritative offline event is eventually established.

No KCORE, tape MRES, filesystem code, RAM, or ABI changes are made
by v1517. The v1515 no-return root/BACKSTORE fatal leaf and v1516
root-set ownership predicate remain available, but an authoritative
physical event producer and production caller are **OPEN**.
