#!/usr/bin/env python3
"""Retain the original native user test assertions, require native HALT."""
from pathlib import Path
import re
import sys
machine,mode,path=sys.argv[1:]
t=Path(path).read_text(errors="replace")
assert re.search(r"MACH\s+"+("KA10" if machine=="ka10" else "PDP6"),t),t
assert "INIT V1" not in t or "<" in t,t
assert "Address already in use" not in t and "device number conflict" not in t,t
assert "HALT instruction" in t,t
assert "<" in t,t
body=t.split("<",1)[1].split("HALT instruction",1)[0].replace("\n","").replace("\r","")
assert "!" not in body and "X" not in body,body
if mode=="protection":
    assert not body.strip(),body
elif mode=="lifecycle":
    assert "P" in body,body
elif mode=="events":
    assert "E" in body,body
elif mode=="childfault":
    assert body.strip()==("RWINP" if machine=="ka10" else "RWNP"),body
elif mode=="scheduler":
    assert not any(c in body for c in "NFX"),body
    for c in "abcdeAD12345":
        assert c in body,(c,body)
    assert all(body.index(c)<body.index("A") for c in "bcde"),body
    assert body.index("D")>body.index("b"),body
else:
    raise ValueError(mode)
print("PASS",machine,mode,repr(body),flush=True)
