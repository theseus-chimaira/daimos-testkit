# DSH pipeline regression investigation (2026-10-10, v1)

## Reproduction

Run `make test-daimos-dsh-pipeline` in daimos-testkit with a working PDP-6
compiler/tool prefix and a clean image. The three cases in
`probes/daimos-dsh-pipeline-regression-20261010-v1.txt` reproduce failures
in two- and three-stage concurrent pipelines and final-stage status.

On a clean isolated DAIMOS checkout based on bf963a4, all three cases failed
in SIMH. The probe file passes the host probe-format validation. A failing
probe is a regression report, not a successful acceptance result.

## Observations from temporary instrumentation

The initial pipeline stage launched successfully. The second RUN failed, and
the shell returned status 126. A diagnostic RUN/loader build identified a
failure in `exec_load_process()` while resolving the next executable pathname:
the pathname walker encountered a failed access/stat operation on its root
directory. No DXR header or payload had been read at that point.

Changing the second stage's process-group mode, delaying TTY handoff, or
waiting for the first child did not resolve the failure. Launches passed when
the first stage's standard output was not mapped to the pipe, suggesting the
failure involves the live inherited pipe descriptor and filesystem lookup.

Experiments using descriptor resets (`next_read = next_write = -1`) did not
actually transmit pipe FDs to children. These runs cannot support claims
about pipe correctness, `AOS`, P10FOLD, or provider serialization. Subsequent
corrected experiments failed with both `AOS` and an equivalent explicit
load/increment/store; excluding `pipe.dobj` from the fold plan also failed.
No assembler, CPU emulator, or P10FOLD defect has been established.

## Follow-up

Investigate file descriptor mapping and pipe state during `SYS_RUN`, focusing
on what changes before the second child executes `file_lookup_path()` and
`vfs_stat()` through the filesystem provider. Use a clean image and preserve
the provider's existing serialization semantics. Fix the root cause rather
than removing pipe references or sequentializing pipelines.

After the correction, run the isolated pipeline probes, the full 115-case DSH
conformance suite, and the real-DCS foreground/TTY restoration acceptance.
The earlier SOURCE and function-recursion failures also remain open.

## Follow-up isolation (2026-10-10)

A fresh-image instrumented run confirmed that the second RUN reaches
`exec_load_process()` but that `file_lookup_path()` returns an error from
`file_check_access()`: the underlying `vfs_stat()` call fails while checking
directory traversal. This is before DXR header validation. The instrumented
RUN failure classified the path as a filesystem-stat failure, not a failed
process-group join. These diagnostics are experimental, not public ABI changes.

The additional `TRUE ! TRUE` probe fails with the same second-RUN lookup
failure even without pipe payload output. The sequential control
`TRUE; TRUE` passes on the same clean image. This distinguishes concurrent
pipeline setup and inherited descriptors from actual data transfer.

Reusing a previously exercised SIMH disk for another test occasionally led to
the boot-time `?RT` HALT; results from those reboots are excluded. Each valid
comparison above used a freshly constructed image. The next investigation
should differentiate provider `vfs_stat` errors (invalid vnode, locked/busy
provider, corrupted request state) and explicitly test the pipe reader/writer
refcounts across first-child exit and parent descriptor closure.

All diagnostic source changes were discarded from the isolated DAIMOS
worktree. This report and the new probes belong to daimos-testkit; there is
no corresponding production DAIMOS code change in this investigation.

## Type 270 failure isolation (second pass, 2026-10-10)

Five target probes were run on fresh images: all four pipeline cases failed,
while the sequential two-RUN control passed. Temporary instrumented return
codes traced the second RUN through executable lookup, directory VFS STAT,
D6FS FCB retrieval, D6FS cache block fetch, and the filesystem backing read.
The backing read returned storage error 5. Type 270 driver instrumentation
identified a failed controller completion rather than a full pending queue.
The Type 270 CONI status on that error had low bits 020 (octal): DRL, data
request late. That pinpoints disk/DCT transfer timing but does not yet prove
whether the kernel driver's interrupt/completion ordering, PI masking, or
the simulator is responsible.

A tested queue-space wait/wakeup experiment did not fix any of the pipeline
failures and was discarded. Investigate the Type 136 DCT handoff and PI
servicing during live Type 270 transfers; verify timing before making a
production change. Do not add unconditional I/O retries or relax the
controller's error handling merely to pass these tests.

## DCT/PI timing review (third pass, 2026-10-10)

Inspected `DAIMOS/system/kernel/drivers/dsk_io.s`,
`DAIMOS/system/kernel/storage/storage_router.s`,
`DAIMOS/system/kernel/core/kcore_pi_pdp6.s`, and SIMH's
`PDP10/pdp6_dsk.c` and `PDP10/pdp6_dct.c`.

SIMH's disk transfer service sets DRL when `dct_write()` (disk read) or
`dct_read()` (disk write) reports its buffer unavailable. Its per-word disk
service reschedules at 100 simulated time units; DCT buffer handoffs use
service delays of 10 or 20 units. The Type 270 PI5 path starts the DCT via
CONO 0200 and the disk via CONO 0270. The Type 136 PI3 path uses the patched
BLKI/BLKO at location 000046, and handles sector-end/drain separately.

DAIMOS's `mach_pi_disable` globally gates PI and is called during some memory
movement/compaction and process teardown. An extended critical section while
a disk transfer is active could starve a DCT request, but no trace has yet
established that this occurs in the failing pipeline case. A concurrent RUN
may also expose a DCT handshake or simulator scheduling defect. Neither
explanation is proven merely by the DRL bit.

The DSK queue has a `dsk_enqueue_ok: JRST kret_zero` success return in the
current source. A clean target run with the current diagnostic variant still
failed four pipeline cases and passed sequential RUN. Queue return alone does
not resolve the DRL condition.

Next diagnostic should record, for the *first* DRL: DSK unit/sector, DCT
buffer status, current PI request/hold/enable bits, controller/DCT command
and status, current process/slot, and whether a PI-disabled critical section
spanned the requested word transfer. Correlate these events on the same
simulated instruction/time axis, using an isolated simulator build. Do not
alter DSK/DCT service delays as a production correction; a changed interval
would be an experiment only. Re-run the five isolated target cases with a
fresh disk image after each tested hypothesis.
