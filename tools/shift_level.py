#!/usr/bin/env python3
"""Abre espaço na fase: tudo que está em x >= X anda D pixels para a direita.
Uso: python3 tools/shift_level.py X D [widen|split]
 - widen: blocos que atravessam X ficam mais largos (o chão continua)
 - split: blocos que atravessam X são cortados em dois (abre um vão)
Também ajusta as posições x escritas nos testes (tests/*.gd)."""
import json, re, sys

P = 'assets/data/level1.json'

def sx(v, X, D):
    return v + D if v >= X else v

def shift(L, X, D, mode='widen'):
    f = lambda v: sx(v, X, D)
    L['spanX'] += D
    L['spawn']['x'] = f(L['spawn']['x'])
    L['lanternOutX'] = f(L['lanternOutX'])
    for k in ['sections', 'darkZones', 'lily', 'mud', 'climb', 'bushes', 'items', 'clues', 'specials',
              'drawings', 'springs', 'crates', 'water', 'mirrors', 'crystals', 'ghost', 'secrets',
              'chalk', 'tocas', 'plates', 'caves', 'swamp']:
        for e in L.get(k, []):
            if 'w' in e and e['x'] < X < e['x'] + e['w'] and k in ('caves', 'swamp', 'darkZones'):
                e['w'] += D
            else:
                e['x'] = f(e['x'])
    new = []
    for s in L['solids']:
        w = s.get('w', 0)
        if s['x'] < X < s['x'] + w:
            if mode == 'widen' or s['t'] not in ('ground', 'dirt', 'cliff'):
                s['w'] += D
            else:
                b = dict(s); b['x'] = X + D; b['w'] = s['x'] + w - X
                s['w'] = X - s['x']
                new.append(b)
        else:
            if 'ladder' in s and s['x'] >= X: s['ladder'][0] += D
            s['x'] = f(s['x'])
    L['solids'] += new
    for v in L.get('vines', []):
        v['x'] = f(v['x'])
        if 'aim' in v: v['aim'][0] = f(v['aim'][0])
    for e in L.get('enemies', []):
        moved = e['x'] >= X
        e['x'] = f(e['x'])
        if moved: e['r'] = [e['r'][0] + D, e['r'][1] + D]
    for k in ['coins', 'clocks', 'checks']:
        for c in L.get(k, []):
            c[0] = f(c[0])
    L['door']['x'] = f(L['door']['x'])
    v = L['villain']
    for k in ['trig', 'x0', 'gateX']: v[k] = f(v[k])
    for h in L.get('hints', []):
        if h['b'] >= X:
            h['a'] = f(h['a']) if h['a'] >= X else X + D
            h['b'] += D
    L['pits'] = [[f(a), f(b)] for a, b in L.get('pits', [])]
    b = L['boss']
    moved = b['x0'] >= X
    for k in ['x0', 'x1', 'trig', 'spawn']: b[k] = f(b[k])
    b['item'][0] = f(b['item'][0])
    for k in ['gold', 'dog', 'table']:
        if k in L: L[k]['x'] = f(L[k]['x'])
    bo = L.get('boat')
    if bo:
        bo['x'] = f(bo['x']); bo['post'][0] = f(bo['post'][0])
    for l in L.get('locks', []):
        moved = l['x'] >= X
        l['x'] = f(l['x'])
        if 'ring' in l: l['ring'][0] = f(l['ring'][0])
        if 'topX' in l: l['topX'] = f(l['topX'])
    for e in L.get('entrances', []):
        e['x'] = f(e['x'])
        e['to'][0] = f(e['to'][0])
    for t in L.get('traps', []):
        moved = t['x'] >= X
        t['x'] = f(t['x'])
        for k in ['trig', 'end', 'frame']:
            if k in t and moved: t[k] += D
        if 'post' in t and moved: t['post'][0] += D
        if isinstance(t.get('to'), list) and moved: t['to'][0] += D
    for k in ['cattails']:
        if k in L: L[k] = [f(x) for x in L[k]]
    if 'tunnel' in L: L['tunnel'] = [f(x) for x in L['tunnel']]
    return L

def shift_tests(X, D, files):
    for fn in files:
        s = open(fn).read()
        s2 = re.sub(r'(?<![\w.])(\d{4,5})(?!\w)', lambda m: str(sx(int(m.group(1)), X, D)), s)
        open(fn, 'w').write(s2)

if __name__ == '__main__':
    X, D = int(sys.argv[1]), int(sys.argv[2])
    mode = sys.argv[3] if len(sys.argv) > 3 else 'widen'
    L = json.load(open(P))
    shift(L, X, D, mode)
    open(P, 'w').write(json.dumps(L, ensure_ascii=False, indent=1))
    shift_tests(X, D, ['tests/route.gd', 'tests/trap_test.gd'])
