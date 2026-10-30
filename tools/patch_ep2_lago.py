#!/usr/bin/env python3
"""Episódio 2: o lago do Sapo-Rei fica raso (só a superfície das vitórias-régias):
sem fundo, sem capacete/arpão, sem corrente de bolhas; o lápis verde vai para o alto."""
import json, os
P = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'data', 'level2.json')
L = json.load(open(P))
LK0, LK1, WY = 14700, 16000, -130
DEPTH = 30
for w in L['water']:
    if w['x'] == LK0:
        w['h'] = DEPTH
L['caves'] = [c for c in L['caves'] if not (c.get('wet') and c['x'] == LK0)]
sol = []
for s in L['solids']:
    if s['t'] == 'dirt' and s['x'] in (14700, 14680, 14720) and s['y'] in (470, -10, 300):
        continue
    sol.append(s)
sol.append({'t': 'dirt', 'x': LK0, 'y': WY + DEPTH, 'w': LK1 - LK0, 'h': 640})
L['solids'] = sol
L['gear'] = []
L['vents'] = []
L['currents'] = []
for sp in L['specials']:
    if sp['c'] == 'verde':
        sp['x'], sp['y'] = 15196, -262
L['hints'] = [h for h in L['hints'] if 'Lago fundo' not in h.get('t', '')]
L['coins'] = [c for c in L['coins'] if not (LK0 < c[0] < LK1 and c[1] > WY + 10)]
json.dump(L, open(P, 'w'), ensure_ascii=False, indent=1)
print('ok', len(L['solids']))
# o quintal do Brutus: portão de saída alto (não dá para pular por cima sem lutar); sem corrente
L = json.load(open(P))
for s in L['solids']:
    if s.get('id') == 'plazaR':
        s['y'], s['h'] = -380, 880
L['boss'].pop('chain', None)
L['boss']['hp'] = 4
json.dump(L, open(P, 'w'), ensure_ascii=False, indent=1)
