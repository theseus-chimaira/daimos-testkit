#!/usr/bin/env python3
"""Fixture-based MAKE storage accounting; no claim about peak RSS."""
from pathlib import Path
p=Path.home()/'tmp/daimos-make-phase-fresh-20261009-v1.5gDn1Z/large.txt'
lines=p.read_text().splitlines()
labels={line.split(':',1)[0] for line in lines if ':' in line and not line.startswith('.PHONY')}
deps=[word for line in lines if ':' in line and not line.startswith('.PHONY') for word in line.split(':',1)[1].split()]
def capacity(n,initial):
 c=initial
 while c<n:c*=2
 return c
r=capacity(len(labels),32);d=capacity(len(deps),64)
print('fixture_lhs_names',len(labels));print('dependency_links',len(deps))
print('rule_capacity_estimate',r,'rule_words',r*7)
print('dependency_capacity_estimate',d,'dependency_words',d*2)
print('rule_order_words_estimate',r)
print('one_word_per_rule_saving_capacity',r)
print('one_word_per_rule_saving_used',len(labels))
print('one_word_per_dep_saving_capacity',d)
print('character_storage_9bit_not_one_word_per_character','yes')
