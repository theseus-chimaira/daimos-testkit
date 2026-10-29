# v727–v729: DSK270 watchdog binding and native execution

The 256K CLEAN v710 linked image patches `storage_clock_dsk_jump`
at octal `020135` to instruction `254000026215` (`JRST 026215`).
The relocated target is the DSK watchdog: `026215` contains
`SKIPN 0,26432`, identifying `dsk_active_request` at `026432`.

After a native PDP-6 idle-loop breakpoint, a second breakpoint at
`026215` fires, proving the watchdog is **executed** after idle.
The v729 test captures two watchdog entries and the active-request word:

```
first:  026432 000454035024
second: 026432 000454034700
```

Octal `0454` is 300 decimal ticks (five seconds at 60 Hz).
The RH request descriptor changed from `035024` to `034700` between
observations, so these readings must **not** be treated as successive
countdown samples for the same disk operation. Even the `step 6` diagnostic
did not retain one uninterrupted request: a PI interruption occurred.

Confirmed: MINIT installed the watchdog jump; the actual post-idle
watchdog instruction is reached; an active request exists. Still open:
same-request countdown, disk completion PI, timeout failure and event
wakeup. Full-system swap-pressure acceptance is not established.
