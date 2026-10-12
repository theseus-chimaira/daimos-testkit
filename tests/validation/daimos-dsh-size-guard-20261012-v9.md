# DSH v9 lazy-function-pool size guard

Use `DSH_DXR=... DSH_MAP=... KCORE_MAP=... sh tests/validation/daimos-dsh-size-guard-20261012-v9.sh`.

Measured PDP-6 image **035671**, static BSS **005013** octal words.
With 02020 origin/stack reservation the process needs **044724** words,
rounded to **046000** octal. The guard rejects image/BSS/VM regressions,
and ensures the unused libc helper symbols remain unlinked.

The combined v9 image passed **115/115** full DSH conformance probes over CTY
and **16/16** focused function/AST probes on independent clean boots. DCS0 lost terminal
characters on long HELP/MAN output in this experiment; treat that as a
transport-specific observation, not proof of a DSH output bug.

Separate 32K LOWMEM boot acceptance remains open; a smaller static
process allocation is not a successful 32K boot by itself.
