# v701 — Cross-MRES clock call-site prototype

`daimos-mres-clock-direct-prototype-v701.py` generates baseline and
direct-patchable assembly for the four source files containing six explicit
`PUSHJ 17,wall_time36` instructions. Both variants assemble for PDP-6.

The candidate adds a globally exported short label at each existing PUSHJ.
No runtime instruction is added or deleted. These labels allow a future
KINIT consumer installer to patch the 18-bit destination directly, using a
clock address selected by the earlier PCLK or software-clock MINIT.

This experiment does **not** yet redirect those calls, install MRES exports,
or remove the KCORE wall-clock gateway. C compiler output and the packed
syscall table reference still require complete handling. Consequently there
is no claim of measured RAM or cycle savings yet; an actual direct-binding
implementation must resolve the installed provider, preserve the absent
calendar default, and test installation in both calendar configurations.

Run:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
python3 tests/validation/daimos-mres-clock-direct-prototype-v701.py \
  "$HOME/git/DAIMOS" "$TMPDIR/daimos-clock-prototype-v701" \
  --assembler "$HOME/cross/bin/das"
```
