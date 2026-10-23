#!/usr/bin/env python3
"""Tomé em peças, no visual do desenho aprovado (tools/art_src/rl_tome_design.jpg).
Fontes (Gemini, editando o desenho aprovado): rl_tome_body.jpg (corpo: gorro, rosto, barba, casaco, cachecol)
e rl_tome_limbs.jpg (braço pendurado com a mão, braço estendido com a lanterna, perna com bota).
Saída: assets/rig/tome2/<peça>.png + rig.json. Unidades do rig.json: pixels do desenho aprovado,
com a origem no chão embaixo do Tomé (y para baixo, então tudo acima do chão é negativo)."""
import os, subprocess, sys, tempfile, json
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'art_src')
OUT = os.path.join(ROOT, 'assets', 'rig', 'tome2')
os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):
    if f.endswith('.png') or f.endswith('.png.import'):
        os.remove(os.path.join(OUT, f))
PRE = .26            # resolução guardada (fração do desenho)
G = (780, 732)       # chão embaixo do Tomé, no desenho


def cut(name):
    tmp = tempfile.mkdtemp()
    out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(SRC, name),
                          os.path.join(tmp, 'p'), '238', '4'], check=True, capture_output=True, text=True).stdout
    res = []
    for l in out.strip().splitlines():
        k, x, y, w, h = map(int, l.split())
        res.append((k, x, y, w, h, os.path.join(tmp, 'p_%d.png' % k)))
    return res


def pick(pieces, cx, cy):
    for k, x, y, w, h, f in pieces:
        if x <= cx <= x + w and y <= cy <= y + h:
            return x, y, np.asarray(Image.open(f).convert('RGBA')).copy()
    raise SystemExit('peça não achada em %d,%d' % (cx, cy))


meta = {'pre': PRE, 'parts': {}}


def save(n, a, x, y, piv, dx=0, dy=0, dark=1.0):
    """a: imagem RGBA da peça, (x, y) onde ela fica no desenho (antes do ajuste dx, dy), piv: pivô no desenho."""
    ys, xs = np.nonzero(a[..., 3] > 8)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    a = a[y0:y1, x0:x1]
    if dark != 1.0:
        a[..., :3] = (a[..., :3] * dark).astype(np.uint8)
    im = Image.fromarray(a, 'RGBA')
    ox, oy = x + dx + x0, y + dy + y0       # canto da peça no desenho
    meta['parts'][n] = {'w': im.width, 'h': im.height, 'px': (piv[0] - ox) / im.width, 'py': (piv[1] - oy) / im.height,
                        'at': [piv[0] - G[0], piv[1] - G[1]]}
    im.resize((max(1, round(im.width * PRE)), max(1, round(im.height * PRE))), Image.LANCZOS).save(os.path.join(OUT, n + '.png'))


body = cut('rl_tome_body.jpg')
limbs = cut('rl_tome_limbs.jpg')
# corpo inteiro (cabeça, barba, casaco, cachecol): gira e respira em volta do quadril
k, bx, by, bw, bh, bf = max(body, key=lambda t: t[3] * t[4])
ba = np.asarray(Image.open(bf).convert('RGBA')).copy()
save('corpo', ba, bx, by, (775, 500))
# braço pendurado (o de perto, por cima do casaco): pivô no ombro
x, y, a = pick(limbs, 300, 350)
save('braco', a, x, y, (657, 305), 327, 74)
# braço estendido com a lanterna (atrás da barba): pivô no ombro; a lanterna vira peça própria (balança na mão)
x, y, a = pick(limbs, 950, 300)
lx, ly = 255, 92                    # corte entre a mão e a lanterna (na peça)
lan = a.copy()
yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
sel = (yy >= ly) & (xx >= 190)
bail = sel | ((yy >= 62) & (xx >= 228) & (xx <= 284))   # a alça entra na mão (fica atrás dos dedos)
lan[..., 3] = np.where(bail, a[..., 3], 0)
a[..., 3] = np.where(sel, 0, a[..., 3])
# a lanterna tem brilho branco que vira buraco no recorte: preenche com amarelo quente dentro do vidro
save('braco_lamp', a, x, y, (856, 279), -9, -1)
save('lanterna', lan, x, y, (x - 9 + 255, y - 1 + 78), -9, -1)
# perna (calça) e bota separadas: a bota fica rente ao chão enquanto a perna gira no quadril
x, y, a = pick(limbs, 470, 560)
ank = 232                            # tornozelo (na peça)
leg = a.copy()
boot = a.copy()
yy = np.arange(a.shape[0])[:, None]
leg[..., 3] = np.where(yy < ank - 6, a[..., 3], 0)
boot[..., 3] = np.where(yy >= ank - 22, a[..., 3], 0)
LX, LY = 636, 416                    # onde a perna fica no desenho
save('perna', leg, LX, LY, (LX + 88, LY + 45))
save('bota', boot, LX, LY, (LX + 86, LY + ank))
meta['leg'] = ank - 45                # quadril até o tornozelo
meta['foot'] = 312 - ank              # tornozelo até a sola
# encaixes no corpo (relativos ao pivô do corpo, no desenho)
P = meta['parts']['corpo']['at']
meta['joints'] = {
    'hip_b': [-40, -35], 'hip_f': [40, -35],
    'sh_n': [657 - 775, 305 - 500], 'sh_l': [856 - 775, 279 - 500],
    'head': [822 - 775, 222 - 500],
}
meta['height'] = G[1] - 65
json.dump(meta, open(os.path.join(OUT, 'rig.json'), 'w'), indent=1)
print('ok', json.dumps(meta['parts']))
