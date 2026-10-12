# Lazy persistent function payload pool: test coverage

The existing `probes/daimos-dsh-conformance-v1.txt` suite exercised the
combined lazy-pool and variable-sized AST build and passed **115/115** on the PDP-6 console.
It covers function definitions, redefinition, SOURCE, and argument limits.

`probes/daimos-dsh-ast-lazy-20261012-v9.txt` extends the compact-AST
lifetime probes with a full 20-slot FOR AST and a function
redefined through two levels of SOURCE. The FOR case avoids the separate
kernel RUN argument cap; the function case reuses an existing function slot
rather than illegally requesting a fifth simultaneous function.
The extended regression passes **16/16** on a separate fresh CTY boot.
Both the full 20-slot FOR and nested SOURCE definition tests pass.
