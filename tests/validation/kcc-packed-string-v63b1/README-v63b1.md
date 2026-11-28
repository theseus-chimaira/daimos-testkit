# Packed character array string initializer regression

Use v63b (635ed29) as KCC_BASE_SOURCE and v63b1 or later as KCC_SOURCE.
Run run-v63b1.py with Python 3 and PDP10_PREFIX set. The old KGEN must
reject the valid initializer; the candidate must produce assembly that
runs successfully on PDP-6 in both optimization modes. Test ordinary
and unsigned char arrays, strings of exact array length, NUL padding
and neighboring packed fields and array elements.
