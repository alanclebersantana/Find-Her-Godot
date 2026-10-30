#!/usr/bin/env python3
"""Episódio 2: o Morcego-Rei vai para o FIM das profundezas (logo antes da porta do cofre), como os
outros chefes no fim dos seus trechos. Onde era a caverna dele entram desafios (tábuas podres sobre
um poço, morcegos pendurados, espinhos), e depois do carrinho há um caminho com espinhos até a caverna.
Rodar uma vez sobre o level2.json atual (tem trava: não roda de novo)."""
import json, os
P = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'data', 'level2.json')
L = json.load(open(P))
if L.get('_batEnd'):
    print('já aplicado')
    raise SystemExit
L['_batEnd'] = 1
GY = 500
D0 = 24526
E0 = 28126
S = L['solids']


def find(**kw):
    for s in S:
        if all(s.get(k) == v for k, v in kw.items()):
            return s
    raise KeyError(kw)


# ---------------------------------------------------------------- a caverna antiga vira caminho
cav = find(t='rockw', x=D0 + 760, y=-620)
cav['h'] = 740                       # teto baixo de mina, como o resto
for px in (25440, 25826, 26190):
    S.remove(find(t='plat', x=px))
L['specials'] = [sp for sp in L['specials'] if sp['c'] != 'roxo']
L['hints'] = [h for h in L['hints'] if 'algo grande dorme' not in h['t']]
L['coins'] = [c for c in L['coins'] if not (25300 < c[0] < 26480)]
gnd = find(t='ground', x=24508)
# poço com tábuas podres
PIT0, PIT1 = 25420, 25760
g2 = dict(gnd)
gnd['w'] = PIT0 - gnd['x']
g2['x'] = PIT1
g2['w'] = 26826 - PIT1
S.append(g2)
L['pits'].append([PIT0, PIT1])
for i in range(4):
    S.append({'t': 'plat', 'x': PIT0 + 20 + i * 82, 'y': 470, 'w': 64, 'crumble': 1})
L['coins'] += [[PIT0 + 52 + i * 82, 430] for i in range(4)]
L['hints'].append({'a': 25160, 'b': 25420, 't': 'Tábuas podres sobre o poço: elas caem logo depois que você pisa. Não pare!'})
# morcegos pendurados no teto baixo
for bx, r in [(25960, [25840, 26100]), (26300, [26180, 26420])]:
    L['enemies'].append({'k': 'bat', 'x': bx, 'y': 280, 'cy': 280, 'r': r})
    S.append({'t': 'rockw', 'x': bx - 34, 'y': 110, 'w': 68, 'h': 156, 'ceil': 1})
L['traps'].append({'k': 'spikes', 'x': 26120, 'y': GY, 'w': 96, 'per': 150, 'ph': 0})
L['coins'] += [[x, 470] for x in range(25800, 26420, 60) if not 26100 < x < 26240]
L['oil'].append([26480, 468])

# ---------------------------------------------------------------- depois do carrinho: caminho e caverna
X0 = 28760                 # a caverna do Morcego-Rei
X1 = X0 + 1080
DOOR = X1 + 120
WALL = DOOR + 180
find(t='ground', x=E0 - 200)['w'] = WALL - (E0 - 200)
find(t='rockw', x=26486, y=-620)['w'] = E0 - 200 - 26486
ce = find(t='rockw', x=E0 - 200, y=-620)
ce['w'] = X0 - (E0 - 200)
S.append({'t': 'rockw', 'x': X0, 'y': -620, 'w': X1 - X0, 'h': 500, 'ceil': 1})        # a caverna alta
S.append({'t': 'rockw', 'x': X1, 'y': -620, 'w': WALL - X1, 'h': 720, 'ceil': 1})
mass = find(t='rockw', x=E0 + 900, y=-620)
mass['w'] = 30286 - WALL
mass['x'] = WALL
L['rails'] = [E0 - 200, E0 + 500]
L['coins'] = [c for c in L['coins'] if not (E0 < c[0] < E0 + 900)]
# o caminho: espinhos e um morcego antes da caverna
L['traps'].append({'k': 'spikes', 'x': 28360, 'y': GY, 'w': 96, 'per': 140, 'ph': 50})
L['enemies'].append({'k': 'bat', 'x': 28580, 'y': 260, 'cy': 260, 'r': [28470, 28700]})
S.append({'t': 'rockw', 'x': 28546, 'y': 90, 'w': 68, 'h': 156, 'ceil': 1})
L['coins'] += [[x, 470] for x in range(28200, 28700, 60) if not 28330 < x < 28480]
L['checks'] = [c for c in L['checks'] if c[0] not in (25286, 26506)]
L['checks'] += [[25300, GY], [26520, GY], [X0 - 60, GY]]
L['checks'].sort(key=lambda c: c[0])
# o Morcego-Rei (mesma arena, deslocada)
L['hawk'] = {'x0': X0, 'x1': X1, 'y': GY, 'trig': X0 + 140, 'hp': 4, 'skin': 'bat',
             'lamps': [[X0 + 159, 385], [X0 + 540, 400], [X0 + 909, 385]]}
for dx, w, y in [(94, 130, 385), (480, 120, 400), (844, 130, 385)]:
    S.append({'t': 'plat', 'x': X0 + dx, 'y': y, 'w': w, 'trestle': 1})
L['specials'].append({'x': X0 + 540, 'y': 360, 'c': 'roxo'})
L['coins'] += [[x, 470] for x in range(X0 + 80, X1 - 40, 60)]
L['hints'] = [h for h in L['hints'] if 'porta de ferro do Vargas' not in h['t']]
L['hints'].append({'a': X0 - 300, 'b': X0 + 120, 't': 'Uma caverna enorme e escura... algo grande dorme pendurado lá no alto. Ali tem lamparinas apagadas.'})
L['hints'].append({'a': X1, 'b': DOOR + 60, 't': 'A porta de ferro do Vargas... Pegue a pista e vá até a porta.'})
for c in L['clues']:
    if c['id'] == 12:
        c['x'] = X1 + 40
L['door']['x'] = DOOR
json.dump(L, open(P, 'w'), ensure_ascii=False, indent=1)
print('ok: morcego em', X0, X1, 'porta', DOOR)
