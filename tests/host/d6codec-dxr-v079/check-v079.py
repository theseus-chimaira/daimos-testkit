#!/usr/bin/env python3
import pathlib,struct,subprocess,sys
base=pathlib.Path(sys.argv[1]); exe=sys.argv[2]
pack=lambda x:struct.pack('<Q',x)
unpack=lambda b:list(struct.unpack('<'+'Q'*(len(b)//8),b))
image=[0 if i%11==0 else (i%5+0o12345) for i in range(80)]
reloc=[0,0,0]
original=[(0o447062<<18)|3,(80<<18)|7,(12<<18)|0o647022]+image+reloc
(base/'input.dxr').write_bytes(b''.join(map(pack,original)))
subprocess.run([exe,str(base/'input.dxr'),str(base/'grouped.dxr')],check=True)
output=unpack((base/'grouped.dxr').read_bytes())
assert output[0]==original[0]
assert output[1]==(original[1]|0o100000)
assert output[2]==((12<<18)|0o647047)
assert output[-3:]==reloc
(base/'payload.bin').write_bytes(b''.join(map(pack,output[3:-3])))
(base/'expected.bin').write_bytes(b''.join(map(pack,image)))
assert subprocess.run([exe,str(base/'grouped.dxr'),str(base/'duplicate.dxr')],capture_output=True).returncode!=0
print('PASS TXG DXR2 header, relocation preservation, compressed-input rejection')
