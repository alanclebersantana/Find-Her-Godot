"""Caixas de escudo: põe uma caixa de escudo (item armor) em chão firme perto de cada x pedido
(antes dos trechos perigosos e dos chefes). Usado pelos scripts de fase (ep1/ep2 por remendo, ep3 no gerador)."""

GROUND = ('ground', 'cliff', 'street', 'dirt', 'hill', 'stone')


def _ground(L, x):
    best = None
    for s in L['solids']:
        if s.get('deco') or s.get('ceil') or s.get('t') not in GROUND:
            continue
        if not all(k in s for k in ('x', 'y', 'w')):
            continue
        if s['x'] + 40 <= x <= s['x'] + s['w'] - 40 and 300 <= s['y'] <= 560:
            if best is None or s['y'] < best:
                best = s['y']
    return best


def _blocked(L, x, gy):
    for p in L.get('pits', []):
        if p[0] - 90 < x < p[1] + 90:
            return True
    for c in L.get('crates', []):
        if abs(c['x'] - x) < 120:
            return True
    for s in L['solids']:
        if s.get('deco') or s.get('ceil') or s.get('t') in GROUND:
            continue
        if not all(k in s for k in ('x', 'y', 'w')):
            continue
        h = s.get('h', 20)
        # algo sólido ocupando o lugar da caixa
        if s['x'] - 10 < x + 40 and s['x'] + s['w'] + 10 > x - 2 and s['y'] < gy and s['y'] + h > gy - 60:
            return True
    for t in L.get('traps', []):
        if abs(t.get('x', -9999) - x) < 160:
            return True
    for sw in L.get('swamp', []):
        if sw.get('x', 0) - 80 < x < sw.get('x', 0) + sw.get('w', 0) + 80:
            return True
    return False


def add(L, xs, reach=900):
    """devolve a lista de x usados"""
    L.setdefault('crates', [])
    used = []
    for x0 in xs:
        done = False
        for d in range(0, reach, 30):
            for x in (x0 - d, x0 + d):
                gy = _ground(L, x)
                if gy is None or _blocked(L, x, gy):
                    continue
                L['crates'].append({'t': 'break', 'x': int(x), 'y': int(gy - 38), 'item': 'armor'})
                used.append((int(x), int(gy)))
                done = True
                break
            if done:
                break
        if not done:
            used.append((x0, None))
    return used
