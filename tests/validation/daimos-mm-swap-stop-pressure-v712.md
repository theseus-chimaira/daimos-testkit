# v712: Correct the stopped-job pressure test oracle

The v283 scheduler test called `target_is_swapped(target, pressure, count)`
with two scalar PIDs in the second and third argument positions. Its second
argument actually requires a pointer to an array of process IDs; GCC
diagnosed the integer-to-pointer conversion. The function subsequently
dereferences that pointer, making the old stopped-job acceptance result
invalid. Fix: pass an initialized two-element array and count `2U`, matching
the existing writer-pressure test's correct API usage.

A fresh, isolated clean D6FS boot advances past the previously reported
pre-VFS `?RT` stage and prints `INIT V1`. This is a boot-stage finding, not
proof of the scheduler workload. Run v670 with the corrected v283 C source
and a separately copied CLEAN disk image to validate the workload.

## Native rerun (v712)

The uncorrected test image reached `INIT V1` but timed out after 300 seconds
at octal PC `014102`. After fixing the invalid argument and recompiling,
the isolated CLEAN-media rerun likewise reached `INIT V1`, but timed out
after 300 seconds at octal PC `014103` (`TRNN 1,400`). Both PCs lie within
the linked `proc_swap_victim` region (starts at `013755` in the v710 map).
Neither run emitted the required post-INIT scheduler success marker.

**Accepted result:** CLEAN-media boot and INIT startup succeed; full-system
swap scheduler pressure does not yet pass. The remaining investigation
must trace victim selection, scheduler progress and test workload state;
do not attribute the post-INIT stall to the previous dirty-root `?RT`.
