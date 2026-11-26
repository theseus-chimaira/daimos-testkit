# v1974 full-kernel DCS-swapped reader on native KA10 RM10

Derive the v1955 six-child user fixture from its generated
user source/object directory (prepare-v1955.sh). Only
test user code changes: RUN adds child FD3 mapped to the
parent's native CTY input endpoint. PID2 sets its own
session/foreground logical TTY1 in RAW mode and waits on
DCS0 READCHAR(3) for exact ASCII Z before its original
pipe/canary path. Other children unchanged. All six
grow to 8192 words. Production KCORE identical v1972.

    DAIMOS_REPO=$HOME/git/DAIMOS sh prepare-v1974.sh V1955_USER WORK
    V1973_DCS_PORT=34890 sh run-v1974.sh WORK/build RESULT

A/B/C strict native quiescence snapshots retain the
v1955 ownership oracle. Connect real TCP terminal at A.
At B, slot2 DISK (VM 020000,,0), scheduler sleeping on
the actual relocated DCS event, mailbox/event zero.
Use actual MINIT-linked RM10 entry to resolve native
DATAO; break on next instruction, send TCP Z after B
release. Slot0 begins native swap-in; inspect real DCS
mailbox 0133 (byte+1) and event -1, slot2 transition
with original committed backing run, active RM10 READ
descriptor and 64 used blocks. No guest state deposits,
no synthetic wake or fabricated hardware status.
Resume; original reader must consume Z then pass pipe
token, both canaries and exact WAIT status. C mailbox
empty; original complete strict MM and bitmap oracle.

PASS A/B/C MM9/20/8 free43747/1203/43761, bitmap0/64/0,
drum reads2/2/66 writes0/64/64 errors0. No new fixed or
per-process state. Private reserved drum region unchanged,
backing area written. This demonstrates the actual DCS
receive wake across native DISK restoration; separate
source-linked v1974 PI2 probes demonstrate simultaneous
hardware RX/DMA BUSY and both-pending cases. No claim
of arbitrary simultaneous independent DF10 channels.

Evidence $TMPDIR/k17-pi2-v1974.HMnc5A/active.
