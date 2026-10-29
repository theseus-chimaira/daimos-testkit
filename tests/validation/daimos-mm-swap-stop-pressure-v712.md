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
