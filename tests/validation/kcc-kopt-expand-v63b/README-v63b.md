# Fixed-register arithmetic and assembly template relocation

Use the v63a source as KCC_BASE_SOURCE and the v63b source as KCC_SOURCE.
Run run-v63b.py with Python 3 and the PDP-10 toolchain environment.
The same KIR2 files feed both backends. Compare assembly on PDP-6 and
KI10, optimized and unoptimized, and check signed/unsigned quotient
and remainder coverage. Five direct records cover templates difficult
to force through allocation. Malformed records and mixed KPCODE4/5
producer/consumer inputs must fail. Evidence stays in versioned TMPDIR
directories. These are hosted phase tests, not native compiler execution.
