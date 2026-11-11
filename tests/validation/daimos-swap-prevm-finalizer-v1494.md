# v1494: retained PREVM owner after a refused swap-related VM destroy

The production `proc_finish_slot` and `proc_finish_service_v881`
assembly is extracted unchanged into a native PDP-6 instruction test.
The test-controlled `vm_space_destroy` refuses its first release and
accepts its second. The real finalizer must register FINALIZE+PREVM,
retain the same VM/u-area owner and exit status, and arrange the idle
retry without allowing the slot to run.

On idle retry the VM is released. The existing independent u-area MM
fixture rejects the first two u-area releases before accepting the
third. The real finalizer must skip sleeping HUP on every retry, must
not destroy the VM twice after its committed release, and must publish
the final zombie only after the u-area is actually relinquished.

An executable negative mutation skips the real post-`vm_space_destroy`
failure branch. The test must reject that premature commit.

Run:

```
DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross \
    sh tests/validation/daimos-swap-prevm-finalizer-v1494.sh
```

Result on 2026-11-11: PASS, including the negative mutation. The
preexisting v1081 refused-TTY PREVM test and v1086 PI6-masked idle
finalizer no-repeat-HUP regression also PASSed.

**Scope limitation:** the finalizer is production code, but
`vm_space_destroy` is deliberately test-controlled in this new test.
v1493 independently source-links the actual swap-in BACKSTORE bitmap
refusal through the real slot-0 swap service, while v1405 runs the
actual checked BACKSTORE free and bitmap. None of these independently
accepted tests proves the entire unbroken runtime sequence under a
physical 256K full guest. In particular, an injected bitmap refusal
during real swap-in, subsequent real TERM delivery, retained PREVM
owner, full finalizer retry and exact physical backing accounting
remain an **OPEN full-guest integration gate**. Do not mark it complete.
