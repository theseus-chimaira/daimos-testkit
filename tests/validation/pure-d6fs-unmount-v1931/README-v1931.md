# D6FS integrated unmount and selected-header publication, v1931

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-d6fs-unmount-v1931

The extended native v1927 gate links actual VFS unmount, owner-admission
and quiescence leaves, D6FS dispatch, physical identity proof, A/B
state publication and reader retirement. Controlled physical callbacks,
provider vector/lease boundary and MM/owner fixtures exercise initial
owner refusal, foreign identity, late owner admission and injected
owner presence, refused MM free, failed CLEAN and successful CLEAN
followed by late owner refusal. The root and reader stay published on
refusal. A successful retirement blocks admission until the VFS root
is unpublished. Four additional unsafe variants are rejected (17 total
in the extended gate). The writable CLEAN path uses the selected
verified header, not a fresh read of the opposite copy.

The extended v1562 gate tests D6FS acquisition and abort, packed FILE
admission and poison retention alongside the original DTFS cases;
eight unsafe variants are rejected. The v1563 native/host attachment
checks exercise both providers. Earlier v1514, v1523, v1562 complete
unmount, v1566 seal and D6FS RW/RO publication regressions pass.
The older isolated remount oracle uses a controlled selected proof
and raw write; the integrated native gate exercises real proof and
CLEAN publication with controlled physical completion.

No full-guest controller, physical exchange or PI6 acceptance claim.
Poisoned D6FS administrative retirement and general write repair are
not provided by ordinary unmount. Executable mutation/admission and
full mount-lifetime race audit remain K07 work.
