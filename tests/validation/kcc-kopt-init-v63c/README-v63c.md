# Static initializer emission relocation

Use v63b1 (9d0beeb) as KCC_BASE_SOURCE and v63c as KCC_SOURCE.
Run run-v63c.py with Python 3 and the PDP-10 toolchain environment.
The same KIR2 files feed both backend pairs. Compare complete output
and total KPCODE size in both optimization modes on PDP-6 and KI10.
Cover all byte prefix states, word values, zero fills and symbolic
label differences; reject invalid records and incompatible streams.
The previously unsupported GNU flexible-array initializer is checked
as an expected parser rejection, not counted as backend identity.
The packed string fix is separately tested by kcc-packed-string-v63b1.
