#!/usr/bin/env python3
"""A Isis do começo do jogo (lembranças, varanda, carrinho do Vargas) com a mesma arte da Isis da
fuga (isis2.png, do Gemini): refaz filha.png e as peças lia_draw / lia_scared do atlas2."""
import json, os
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(ROOT, 'assets', 'sprites')
isis = Image.open(os.path.join(SP, 'isis2.png')).convert('RGBA')
CW = 150


def cell(i):
    c = isis.crop((i * CW, 0, i * CW + CW, CW))
    return c


# filha.png: 0 parada, 1 acenando (braços erguidos), 2 pulando de alegria, 3 mãos à frente (correndo)
fr = [cell(4), cell(5), cell(5), cell(1)]
out = Image.new('RGBA', (CW * 4, CW), (0, 0, 0, 0))
for i, c in enumerate(fr):
    out.alpha_composite(c, (i * CW, 0))
out.save(os.path.join(SP, 'filha.png'))

# peças do atlas: lia_draw (ajoelhada, desenhando) e lia_scared (assustada, no carrinho)
A = json.load(open(os.path.join(ROOT, 'assets', 'data', 'atlas.json')))
fr2 = A['atlas2'].get('frames', A['atlas2'])


def put(name, src):
    r = fr2[name]
    x, y, w, h = r[0], r[1], r[2], r[3]
    src = src.crop(src.getbbox())
    k = min(w / src.width, h / src.height)
    src = src.resize((max(1, int(src.width * k)), max(1, int(src.height * k))), Image.LANCZOS)
    for fn in ['atlas2.png', 'atlas2_sil.png']:
        p = os.path.join(SP, fn)
        if not os.path.exists(p):
            continue
        at = Image.open(p).convert('RGBA')
        at.paste((0, 0, 0, 0), (x, y, x + w, y + h))
        piece = src
        if 'sil' in fn:
            a = np.asarray(src).copy()
            a[..., 0:3] = 0
            piece = Image.fromarray(a)
        at.alpha_composite(piece, (x + (w - src.width) // 2, y + h - src.height))
        at.save(p)


put('lia_draw', cell(7))
put('lia_scared', cell(9))
print('ok')
