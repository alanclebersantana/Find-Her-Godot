#!/usr/bin/env python3
"""Recorta as folhas de arte nova (tools/art_src/rl2/<folha>.jpg, fundo branco) e dá nome a cada peça
pela ordem pedida ao Gemini (fileiras de cima para baixo, da esquerda para a direita).

Manifesto: tools/art_src/rl2/manifest.json
  {"folha": {"rows": [5, 5], "names": ["grass0", ...], "dest": {"nome": "paint|atlas|skip"}}}
- paint: vira art_src/paint/<nome>.png (atlas pintado, tools/pack_paint.py)
- atlas: vira art_src/atlas_over/<nome>.png (substitui a peça antiga do atlas1/atlas2, mesma proporção)
- skip / nome começando com "_": não usa
Uso: rl2_cut.py [folha ...]   (sem argumentos: todas)"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'art_src', 'rl2')
PAINT = os.path.join(ROOT, 'art_src', 'paint')
OVER = os.path.join(ROOT, 'art_src', 'atlas_over')
PIECES = os.path.join(ROOT, 'art_src', 'rl2_pieces')
PREV = '/tmp/claude-0/sc'
os.makedirs(OVER, exist_ok=True)
os.makedirs(PIECES, exist_ok=True)
ATL = json.load(open(os.path.join(ROOT, 'assets', 'data', 'atlas.json')))
ATLAS_NAMES = set(ATL['atlas1']) | set(ATL['atlas2'])


def cut(path, n_exp, thr=236, dil=7, holes=0, notext=False):
    im = Image.open(path).convert('RGB')
    a = np.asarray(im).astype(np.int16)
    white = a.min(axis=2) >= thr
    lab, n = nd.label(white)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = ~np.isin(lab, list(border))
    if holes:
        # buracos brancos fechados (entre degraus, grades, redes): viram transparentes
        for i in range(1, n + 1):
            if i in border:
                continue
            reg = lab == i
            ar = int(reg.sum())
            if ar >= holes and a[reg].mean() >= 246:
                fg[reg] = False
    fg = nd.binary_opening(fg, iterations=1)
    if notext:
        # letras que o Gemini às vezes escreve embaixo: pedacinhos escuros, baixos e soltos
        lb, nl = nd.label(fg)
        for i, sl in enumerate(nd.find_objects(lb)):
            hgt = sl[0].stop - sl[0].start
            reg = lb[sl] == i + 1
            ar = int(reg.sum())
            if hgt < 36 and ar < 2500 and a[sl][reg].mean() < 160:
                fg[sl][reg] = False
    dist = nd.distance_transform_edt(fg)
    alpha = np.clip(dist / 1.6, 0, 1)
    grp, m = nd.label(nd.binary_dilation(fg, iterations=dil))
    comps = []
    for i, sl in enumerate(nd.find_objects(grp)):
        area = int((fg[sl] & (grp[sl] == i + 1)).sum())
        if area < 150:
            continue
        comps.append({'ids': [i + 1], 'y0': sl[0].start, 'x0': sl[1].start, 'y1': sl[0].stop, 'x1': sl[1].stop, 'area': area})
    # junta as menores na vizinha mais próxima até sobrar o número pedido
    while len(comps) > n_exp:
        comps.sort(key=lambda c: c['area'])
        s = comps.pop(0)
        cx, cy = (s['x0'] + s['x1']) / 2, (s['y0'] + s['y1']) / 2
        def gap(c):
            dx = max(c['x0'] - s['x1'], s['x0'] - c['x1'], 0)
            dy = max(c['y0'] - s['y1'], s['y0'] - c['y1'], 0)
            return dx * dx + dy * dy
        t = min(comps, key=gap)
        t['ids'] += s['ids']
        t['area'] += s['area']
        for k, f in (('x0', min), ('y0', min), ('x1', max), ('y1', max)):
            t[k] = f(t[k], s[k])
    rgba = np.dstack([a.astype(np.uint8), (alpha * 255 * fg).astype(np.uint8)])
    return comps, rgba, grp, fg


def order(comps, rows):
    comps = sorted(comps, key=lambda c: (c['y0'] + c['y1']) / 2)
    out = []
    i = 0
    for n in rows:
        r = comps[i:i + n]
        i += n
        out += sorted(r, key=lambda c: (c['x0'] + c['x1']) / 2)
    return out


def fit_old(name, im):
    """peça do atlas antigo: mesma proporção da antiga (completa com transparente, base no centro)"""
    r = ATL['atlas1'].get(name) or ATL['atlas2'].get(name)
    ow, oh = r[2], r[3]
    w, h = im.size
    tgt = ow / oh
    if w / h > tgt:
        nh = round(w / tgt)
        c = Image.new('RGBA', (w, nh), (0, 0, 0, 0))
        c.paste(im, (0, nh - h))
    else:
        nw = round(h * tgt)
        c = Image.new('RGBA', (nw, h), (0, 0, 0, 0))
        c.paste(im, ((nw - w) // 2, 0))
    return c


def run(sheet, spec):
    path = os.path.join(SRC, sheet + '.jpg')
    names = spec['names']
    comps, rgba, grp, fg = cut(path, len(names), spec.get('thr', 236), spec.get('dil', 7), spec.get('holes', 0), spec.get('notext', False))
    if len(comps) != len(names):
        print('ATENÇÃO %s: %d peças, esperava %d' % (sheet, len(comps), len(names)))
    comps = order(comps, spec['rows'])
    prev = Image.open(path).convert('RGB')
    d = ImageDraw.Draw(prev)
    for c, n in zip(comps, names):
        sl = (slice(c['y0'], c['y1']), slice(c['x0'], c['x1']))
        mask = np.isin(grp[sl], c['ids']) & fg[sl]
        piece = rgba[sl].copy()
        piece[..., 3] = piece[..., 3] * mask
        im = Image.fromarray(piece, 'RGBA')
        bb = im.getbbox()
        im = im.crop(bb)
        d.rectangle([c['x0'], c['y0'], c['x1'], c['y1']], outline=(255, 0, 0), width=2)
        d.text((c['x0'] + 3, c['y0'] + 3), n, fill=(255, 0, 0))
        if n.startswith('_'):
            continue
        im.save(os.path.join(PIECES, n + '.png'))
        dest = spec.get('dest', {}).get(n) or ('atlas' if n in ATLAS_NAMES and not os.path.exists(os.path.join(PAINT, n + '.png')) else 'paint')
        if dest == 'paint':
            im.save(os.path.join(PAINT, n + '.png'))
        elif dest == 'atlas':
            fit_old(n, im).save(os.path.join(OVER, n + '.png'))
    prev.thumbnail((1200, 1200))
    prev.save(os.path.join(PREV, 'cut_%s.jpg' % sheet))
    print(sheet, 'ok', len(comps))


man = json.load(open(os.path.join(SRC, 'manifest.json')))
for s in (sys.argv[1:] or man.keys()):
    run(s, man[s])
