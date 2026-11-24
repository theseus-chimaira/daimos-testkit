# KCC automatic initializer call-boundary regression (v1917)

Separate caller and callee translation units exercise the original
PDP-6 ABI. An automatic initializer invokes a function before a later
call consumes incoming parameters. The caller must retain the original
slot, pointer and mode, and update only the pointed-to flags word.
Additional cases cover a single parameter read, C99 declarations after
statements, and a constant initializer preceding a bare call.

Run `sh run-v1917.sh` with the installed KCC, or set `KCC` to a staged
compiler. Both optimized and unoptimized native PDP-6 runs must pass.
The v37d compiler fails the optimized guest with exit 1; the repaired
compiler passes both modes. The existing v1612 PURE service regression
also passes with the repair, including its unsafe READY control.
