#!/usr/bin/env python3
"""Episódio 2: Morcego-Rei no molde do Gavião-Rei, com mais vida (5 golpes de picareta)."""
import json, os
P = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'data', 'level2.json')
L = json.load(open(P))
L['hawk']['hp'] = 5
for h in L['hints']:
    if 'algo grande dorme' in h['t']:
        h['t'] = ('Uma caverna enorme e escura... algo grande dorme pendurado lá no alto. Ali tem lamparinas: '
                  'acesas, elas mostram a sombra de quem mergulha.')
json.dump(L, open(P, 'w'), ensure_ascii=False, indent=1)
print('ok')
