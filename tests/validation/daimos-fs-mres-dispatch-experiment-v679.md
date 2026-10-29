# Filesystem MRES dispatch experiment v679

Production source and its KINIT patching remain unchanged.

The experiment generates two copies of `fs_mres.s`: an untouched baseline
and an indirect-addressing candidate. KINIT already writes `JRST target`
instructions into four contiguous provider service slots. PDP-10 indirect
effective-address resolution can follow that patched instruction word.

The candidate replaces:

    HRRZ 7,fs_memfs_service_jump(7)
    JRST (7)

with a single indirect JRST, and likewise replaces target extraction plus
indirect PUSHJ inside the serialized provider path with a single indirect
PUSHJ. The shared lock, scheduler wait, register preservation, unlock and
service slots remain unmodified.

Result: two fewer candidate instructions, both variants accepted by DAS.
This is not a proven linked-KCORE word reduction or native runtime success.
Testing must verify the actual indirect effective address and patched JRST
word on PDP-6, including missing-service and sleep/wakeup cases.

Direct per-operation binding is a separate alternative: it would need more
KINIT patches, additional binding sites, and a strategy for lock ownership
and future relocation. No direct-per-operation variant is implemented yet.
