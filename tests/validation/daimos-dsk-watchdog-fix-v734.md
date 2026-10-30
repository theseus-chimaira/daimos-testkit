# v730–v734: DSK watchdog memory update regression

The original Type 270 watchdog wrote `sub dsk_active_request,[1,,0]`.
On native PDP-6 it assembled to `SUB 0,26431`, an accumulator-only
instruction. The active request at `026432` therefore did not decrement.
An instruction-level v731 trace confirmed it remained `000454035024`
across the executed SUB instruction. This is a production bug, not a
failure to install or invoke the watchdog.

Changing the operation to `SUBM` would also be incorrect: PDP-10 SUBM
stores AC minus memory, not memory minus AC. The production correction is
`MOVSI 1,-1; ADDM 1,dsk_active_request`, subtracting one LH tick in place
without modifying the 18-bit RH request descriptor pointer.

Native corrected lowmem/256K image v734 built successfully and booted
clean D6FS media. The emitted instructions at `026217` and `026220` are
`MOVSI 1,777777` and `ADDM 1,26432`. The v734 regression breaks before
and after the memory update and verifies the actual request values:

```
before: 000454035024
after:  000453035024
```

The same request lost exactly one countdown tick with no pointer change.
This verifies the watchdog bug fix, **not** a completed five-second
timeout or the full-system scheduler-pressure workload. Further I/O
completion and failure-path acceptance remains open.
