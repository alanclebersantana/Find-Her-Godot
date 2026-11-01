#!/usr/bin/env python3
"""Episódio 1 — lote de 11 ajustes (rodar uma vez, depois de tools/shift_level.py 51745 2000 widen):
 - dica da neve sem o nome do Vargas (ele só é revelado no crachá)
 - sem a sanguessuga e sem a gangorra depois do avião (os lápis e o coração dela ficam no chão)
 - caixas de escudo antes dos trechos perigosos
 - perseguição do Urso-Rei 2000 px mais longa; os galhos de se abaixar viram passagens altas (não dá para pular)
 - bola de pedra mais rápida e com desabamentos de se abaixar no túnel
 - desenho da Isis dentro da casinha da árvore; o pavio no ninho em cima do cogumelo azul (só o cogumelo alcança)
 - mais frascos de óleo na noite (o óleo agora acaba)"""
import json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import shield_crates
P = os.path.join(ROOT, 'assets', 'data', 'level1.json')
L = json.load(open(P))
if L.get('_lote11'):
    print('já aplicado'); raise SystemExit
L['_lote11'] = 1
D = 2000
S = L['solids']

# ---- nome do Vargas
for h in L['hints']:
    if 'carrinho do Vargas' in h.get('t', ''):
        h['t'] = 'Marcas de rodas na neve: um carrinho passou por aqui, descendo para a mina!'
    if 'sanguessugas' in h.get('t', ''):
        h['t'] = 'Lamaçal fundo: não dá para atravessar planando. Vá de cipó em cipó!'

# ---- sanguessuga
L['enemies'] = [e for e in L['enemies'] if e['k'] != 'leech']

# ---- gangorra (os 5 lápis e o coração vão para o chão/caixa ali perto)
for sw in L['slam'].get('seesaw', []):
    tx = sw['target'][0]
    L['coins'] += [[tx - 60 + i * 30, 470] for i in range(sw.get('items', 5))]
    if sw.get('heart'):
        L['crates'].append({'t': 'break', 'x': int(sw['x'] + 60), 'y': 462, 'item': 'heart', 'lote': 1})
L['slam']['seesaw'] = []

# ---- Urso-Rei: a perseguição fica 2000 px mais longa (o fim — rugido, pingentes, rocha — já andou)
b = L['bear']
b['x1'] += D
b['rock']['x'] += D
b['roar'] += D
b['ici'] = [x + D for x in b['ici']]
GY = b['y']
TALL = 330          # passagem baixa: o galho fica embaixo de uma pilha de pedras de neve (não dá para pular)
def branch(x, w=110):
    return {'k': 'branch', 'x': x, 'y': GY - 26 - TALL, 'w': w, 'h': TALL}
b['obs'] = [branch(o['x'], o['w']) if o['k'] == 'branch' else o for o in b['obs']]
b['obs'] += [branch(51960), {'k': 'log', 'x': 52330, 'y': 462, 'w': 74, 'h': 38}, branch(52680),
             {'k': 'logs', 'x': 53000, 'y': 444, 'w': 66, 'h': 56}, branch(53330)]
b['obs'].sort(key=lambda o: o['x'])
L['coins'] = [c for c in L['coins'] if not (51745 < c[0] < 53745)]
L['coins'] += [[x, 470] for x in range(51800, 53700, 70) if all(abs(x - (o['x'] + o['w'] / 2)) > 90 for o in b['obs'])]

# ---- bola de pedra: mais rápida e com desabamentos (vigas caídas com pedras até o teto) para se abaixar
for t in L['traps']:
    if t['k'] == 'boulder':
        t['vmax'] = 5.0
        t['acc'] = .05
        for i, x in enumerate([76350, 78700]):
            sid = 'bo%d' % (8 + i)
            S.append({'t': 'bob', 'bob': 'collapse', 'id': sid, 'x': x, 'y': 500 - 26 - TALL, 'w': 64, 'h': TALL})
            t['smash'].append(sid)
        bo = t

# ---- casinha da árvore com o desenho; o pavio no ninho em cima do cogumelo azul
for s in S:
    if s.get('t') == 'plat' and s['x'] == 73360 and s['y'] == 120:
        S.remove(s); break
S.append({'t': 'treehouse', 'x': 72870, 'y': 40, 'w': 240, 'h': 110, 'deco': 1})
for d in L['drawings']:
    if 'lanterna do papai' in d['txt']:
        d['x'], d['y'] = 72990, 122
sp = [s for s in L['springs'] if s.get('k') == 'glow'][0]
# ninho bem no alto, em cima do cogumelo: o cogumelo fica mais forte (lança até ~y -250) e, com o pulo duplo lá
# em cima, o Tomé entra por baixo pelo piso de tábua. Da casinha da árvore o máximo é ~y -180: não alcança.
sp['pow'] = -30
NX = sp['x'] - 60
NY = -300
S.append({'t': 'plat', 'x': NX, 'y': NY, 'w': 120, 'nest': 1})
S.append({'t': 'trunk', 'x': NX + 128, 'y': NY + 10, 'w': 40, 'h': 500 - NY - 10, 'deco': 1})
for it in L['items']:
    if it['id'] == 'pavio':
        it['x'], it['y'] = NX + 60, NY - 24
L['coins'] = [c for c in L['coins'] if not (73350 < c[0] < 73520 and c[1] < 200)]
L['coins'] += [[sp['x'], y] for y in (300, 160, 20, -120)]
L['hints'].append({'a': sp['x'] - 500, 'b': sp['x'] + 200, 't': 'O pavio ficou no ninho lá no alto, em cima do cogumelo azul. Pule no cogumelo e, lá em cima, dê o pulo duplo!'})

# ---- óleo: agora acaba de verdade; mais frascos na noite
L['oil'] += [[74300, 468], [78750, 468]]
L['oil'] = [o for o in L['oil'] if o[0] <= L['villain']['trig'] - 100]   # na perseguição a luz é cheia
L['oil'].sort(key=lambda o: o[0])

# ---- caixas de escudo
print('escudos', shield_crates.add(L, [4500, 20350, 49600, 65720, 80400]))
json.dump(L, open(P, 'w'), ensure_ascii=False, indent=1)
print('ok')
