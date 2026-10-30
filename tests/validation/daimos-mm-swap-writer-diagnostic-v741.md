# v740–v741: first real pressure INIT writer-case failure

Fresh pressure-test INIT was installed using `SYSTEM_INIT_DXR` in an
isolated 256K PDP-6 D6FS image (corrected v734 DSK watchdog source).
Unlike earlier ordinary-INIT traces, the native workload ran and emitted
`<wd!W`: the writer-case verification returned an error. This is **not**
full swap-pressure acceptance. The combined v283 assertion conflated
initial pipe read, writer WAIT report, pipe drain and close.

Versioned v740 C diagnostic separates those checks. Its fresh native run
emitted `<we!W`: initial read of `A` succeeded, but the writer
`wait_report(writer, SYS_WAIT_EXITED, WRITER_STATUS)` failed. Pipe draining
was not reached. Therefore do not infer an MM-swap or DSK watchdog failure
solely from the writer-case marker.

Versioned v741 additionally prints the returned PID and the wait status
kind/value (and expected values) in six-digit octal, using only WRITECHAR;
the standalone PDP-6 GCC compilation succeeds. Fresh native pressure-INIT
execution then produced:

```
<wE000002/000002:000001/000001:400001/000050e!W
```

The returned PID and EXITED kind match. The child's reported status is
`0400001` rather than the expected `050`: by `SYS_WAIT_EVENT_FLAG` and
`SYS_EVENT_TERM` this denotes fatal TERM, not normal EXIT. Kernel source
has an explicit TERM-on-swap-in-failure path in
`proc_swap_mres_service_v481` and `vm_pdp6_swap.c`; the native run has
**not** yet proved that this path caused the TERM, because other TERM
delivery routes exist. Treat swap-in failure as a prioritized hypothesis,
not a verified cause. The earlier v283 `d` marker masked the same failure
behind a combined assertion; pipe draining was not reached.

To run v741, set `DAIMOS_SWAP_INIT_SOURCE_V738` to its absolute C path
when invoking `daimos-mm-swap-scheduler-v669.sh` without a reused boot
fixture. The latter must be rebuilt so the test INIT is actually installed.
