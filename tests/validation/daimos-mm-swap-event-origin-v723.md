# v722-v723 — Slot-1 event-channel origin

The v722 native PDP-6 dump inspects octal `034737-034754` at the
idle breakpoint. Event word `034745` is zero. The slot-1 descriptor's
u-area base is `034521`; with `PROC_UAREA_WORDS=0410` (octal), the
wait channel lies inside the slot's stable private u-area rather than
the separately declared filesystem-provider readiness word.

The v723 sequential trace breaks at `proc_wait_event` (linked PC `013235`)
and then `proc_idle_loop` (`014102`), confirming the actual wait-entry
argument AC1 is `034745`. The subsequent slot-1 scheduler descriptor is
`320024034745`: state SLEEP, wait class EVENT, and identical channel.
This rules out interpreting the channel as an unrelated stale descriptor
value; it is the address used by the native wait operation.

It does **not** identify the caller or demonstrate a failed producer.
Next capture the return address and user/kernel stack at wait entry,
then find the matching event producer, including any stack-local event
whose lifetime extends across an executive sleep. Do not alter the
scheduler or wakeup policy without that evidence.

All media are copied from a CLEAN fixture; no production code changed.
