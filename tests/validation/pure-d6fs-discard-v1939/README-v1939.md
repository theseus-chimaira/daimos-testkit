# Poisoned D6FS administrative retirement, v1939

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-d6fs-discard-v1939

Extends the source-linked v1927 native PDP-6 gate with administrative
retirement through real VFS and D6FS dispatch/release leaves. Healthy,
read-suspect, unknown flags, selected root, critical owner, borrowed
barrier, absent barrier, wrong root/reader and early/late owner cases
refuse. MM free refusal retains the exact reader, identity and poison.
Successful retirement of a writable poisoned reader never invokes the
physical read/write callbacks. Real BCACHE reclaim invalidates both
clean tags even when its MM release refuses, retaining the cache slab
owner. Exact reader MM type/owner, root/target retirement and namespace
revision update are checked. Seven new unsafe variants fail native
assertions; all 17 preceding proof/unmount controls still fail as
expected. The v1531 native FILE/VFS oracle includes D6FS poison-only FD
abandonment and stale-provider refusal, retaining its four DTFS unsafe
controls. v1575 drain, v1562 unmount, context selector, multimount,
reader slab and remount regression gates pass.

The provider lease wait and owner injection, physical callbacks and
MM return are controlled. This is not complete-guest PI6 or physical
controller acceptance. Isolated older selector/remount fixtures refuse
unexpected administrative calls; the main gate executes the real code.
Other historical runners have not all been rerun.
