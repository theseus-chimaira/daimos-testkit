# v699 — Conditional wall-clock gateway binding

The installed wall-clock MRES is chosen once by KINIT. The current resident
`pclk_gateway.s` has two patched `JRST` instructions: `wall_time36` and
`wall_clock_set`, each with an appropriate default when no provider exists.

Unlike the LOGSTORE and MTC direct-call improvements, this provider has
multiple consumers **inside independently linked MRES packages**, not only
resident KCORE call sites. The syscall table also contains the packed
`native_sys_exec,,wall_time36` word. Replacing the gateway needs explicit
per-consumer call-site exports and a 18-bit table patch, together with the
PCLK versus software-calendar choice and unavailable-SETTIME semantics.

The source inventory script enumerates the assembly `PUSHJ` references
without pretending that a source count equals removable permanent words.
An actual implementation would additionally need to enumerate compiler-
generated `wall_time36()` calls and the loader's order constraints.

No production change is made: eliminating one JRST is plausible, but there
is not yet an integrated size/native-boot comparison or a complete consumer
relocation inventory. Keep the existing gateway until those are established.
