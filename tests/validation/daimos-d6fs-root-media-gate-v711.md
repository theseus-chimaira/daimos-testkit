# v711 — Root-mount `?RT` media-state isolation

The retained v298 swap/scheduler boot fixture contains D6FS superblock 713,
sequence 2, DIRTY. The clean 256K v710 image contains a distinct clean D6FS
generation. The existing v670 stage trace reaches `d6fs_super_select` and
then the KINIT error path before VFS mount on the retained DIRTY fixture.

Production `d6fs_super_select()` rejects the newest structurally valid
generation unless `state == D6FS_STATE_CLEAN`. This makes DIRTY-media reuse
a sufficient reason for normal RW mount rejection, but does **not** prove
the original v669 fresh-media failure had the same cause.

`daimos-d6fs-root-media-gate-v711.sh` classifies an existing boot fixture
with the native `d6fsck` checker. It deliberately does not repair, format or
otherwise modify disk images. Use it before attaching a fixture to any
swap-pressure acceptance test; use the v670 stage trace only to classify
the KINIT phase, not to claim workload completion. Next: fresh full-profile
swap fixture, isolated copy, then targeted post-superblock trace.
