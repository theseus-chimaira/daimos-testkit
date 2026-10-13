#!/usr/bin/env python3
"""PDP-6 decoder rejection tests with output guard words."""
from pathlib import Path
r=Path(__file__).resolve().parent
# case: stream words, available input, expected output words, success flag
match=lambda k,n,d: (((k<<16)|(n<<9)|d)<<18)
cases={
 'empty':([],0,0,True),
 'empty_missing':([],0,1,False),
 'zero_count':([0],1,1,False),
 'count31':([31<<30,17],2,1,False),
 'missing_literal':([1<<30],1,1,False),
 'truncated_descriptor':([(1<<30)|(1<<29)],1,1,False),
 'missing_two_literals':([2<<30,14],2,2,False),
 'invalid_kind':([(1<<30)|(1<<29),match(3,1,0)],2,1,False),
 'zero_length':([(1<<30)|(1<<29),match(1,0,0)],2,1,False),
 'zero_nonzero_distance':([(1<<30)|(1<<29),match(1,1,1)],2,1,False),
 'copy_distance_zero':([(1<<30)|(1<<29),match(0,1,0)],2,1,False),
 'copy_before_origin':([(1<<30)|(1<<29),match(0,1,1)],2,1,False),
 'even_half_before_origin':([(1<<30)|(1<<29),match(2,1,2)],2,1,False),
 'odd_half':([(1<<30)|(1<<29),match(2,1,1)],2,1,False),
 'output_overrun_literal':([2<<30,13,14],3,1,False),
 'output_overrun_match':([(1<<30)|(1<<29),match(1,2,0)],2,1,False),
 'trailing_word':([1<<30,42,99],3,1,False),
 'literal':([1<<30,42],2,1,True),
 'zero_one':([(1<<30)|(1<<29),match(1,1,0)],2,1,True),
 'zero_127':([(1<<30)|(1<<29),match(1,127,0)],2,127,True),
 'copy_overlap':([(2<<30)|(1<<28),match(0,3,1),42],3,4,True),
 'even_half_copy':([(2<<30)|(1<<28),match(2,3,2),42],3,4,True),
}
for name,(arr,nin,nout,success) in cases.items():
 cap=max(1,nout);words=''.join(f' .word 0{w:o}\n' for w in arr) or ' .word 0\n'
 # The decoder is permitted to partially change intended output on failure,
 # but must never overwrite the guard after the advertised output span.
 s=f'''/* v048: {name}: {'valid' if success else 'reject'} */
.text
.globl main
.globl d6v048_decode
main:
 movei 1,stream
 movei 2,0{nin:o}
 movei 3,outbuf
 movei 4,0{nout:o}
 pushj 17,d6v048_decode
 {'jumpn 1,fail' if success else 'camn 1,[-1]'}
 {'jrst check_guard' if success else 'jrst check_guard'}
 {'jrst fail' if not success else ''}
check_guard:
 move 0,guard
 came 0,[012345670123]
 jrst fail
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
.data
stream:
{words}.bss
outbuf: .block 0{cap:o}
guard: .block 1
.globl __test_exit
__test_exit: .block 1
'''
 # memory .bss starts zero; must initialize guard explicitly.
 s=s.replace('main:\n movei 1,stream','main:\n move 0,[012345670123]\n movem 0,guard\n movei 1,stream')
 if not success:s=s.replace(' caie 1,-1\n jrst fail\n jrst check_guard',' camn 1,[-1]\n jrst check_guard\n jrst fail')
 else:s=s.replace(' jumpn 1,fail\n jrst check_guard\n \n',' jumpn 1,fail\n jrst check_guard\n')
 (r/f'test_{name}_v048.s').write_text(s)
print('generated',len(cases),'cases')
