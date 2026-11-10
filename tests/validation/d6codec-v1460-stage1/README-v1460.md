# v1460 PDP-6 DTC/MTC Stage-1 entry-register correction

The v1452 and v1459 DTC/MTC Stage-1 loaders retained the KINIT entry
address in AC5 across the shared block decoder. A match command
overwrites AC5 with its source address, causing the subsequent
`JRST 0(5)` to branch into an arbitrary position in the decoded
image. This failure occurred after the compressed payload was read
and decoded: it was not an unreadable tape or a stuck DCT channel.

The block-encoded image header specified entry octal `053537`; a
captured failed-boot snapshot after decoding had AC5=`120366`,
the most recent match source address. The v1460 Stage-1 loaders
instead retain the validated entry address in AC16, which the
fixed decoder does not modify. The raw/hybrid DTC path uses the
same entry register. No instruction, low-core data or fixed decoder
words are added.

`register-liveness-v1460.py` independently assembles original v1459
and v1460 device Stage-1 sources with identical includes and checks:

| Device | Physical read-in words | Changed instruction words | Growth |
|---|---:|---:|---:|
| DTC | 160 | 5 | 0 |
| MTC | 125 | 4 | 0 |

Both native control tests passed. Both fixed loaders also passed
fresh, isolated, full-profile PDP-6 SIMH cold boots: KINIT banner,
ROOT login, DSH startup and a guest ECHO command.

Run just the zero-growth assembler test:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    python3 -B tests/validation/d6codec-v1460-stage1/register-liveness-v1460.py \
        --daimos "$DAIMOS_REPO" --prefix "$HOME/cross" \
        --work "$TMPDIR/d6codec-v1460-stage1/native-regression"

Run the entire native and real cold-boot acceptance:

    export DAIMOS_REPO=/path/to/DAIMOS-v1460-worktree
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    sh tests/validation/d6codec-v1460-stage1/run-v1460.sh

`inspect-stage1-v1460.py` snapshots live Stage-1 registers via the
SIMH console when investigating boot issues. It does not patch guest
code, source, media or memory. Its isolated diagnostics are kept under
TMPDIR and are separate from the pass/fail acceptance runner.
