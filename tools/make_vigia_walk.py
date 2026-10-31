#!/usr/bin/env python3
"""Ciclo de andar do vigia em recorte (marionete): corpo do quadro parado (vigia.png, quadro 4) e as duas
pernas giradas no quadril. Os quadros da IA tinham o pé de trás sempre levantando e voltando (parecia mancar).
Gera assets/sprites/vigia_walk.png (8 quadros 220x200). O pé de apoio fica no chão, o corpo desce no passo."""
import math, os
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = os.path.join(ROOT, 'assets', 'sprites')
CW, CH = 220, 200
base = np.array(Image.open(os.path.join(S, 'vigia.png')).convert('RGBA'))[:, 4 * CW:5 * CW].copy()
H, W = base.shape[:2]
r, g, b, a = [base[:, :, i].astype(int) for i in range(4)]
lum = (r * 3 + g * 6 + b) / 10
GAP = 101            # entre as pernas
HIP = 138            # quadril (escondido pelo casaco)
# barra do casaco (contorno de baixo), medida no quadro parado: abas de x 58 a 140
def hem(x):
    if x <= 102:
        return 154 + (x - 58) * 7 / 44
    return 161 - (x - 102) * 5 / 38
legmask = np.zeros((H, W), bool)
for x in range(55, 155):
    legmask[int(hem(x)) + 2:, x] = a[int(hem(x)) + 2:, x] > 0
body = base.copy()
body[legmask, 3] = 0


def leg(x0, x1, dark):
    p = np.zeros((H, W, 4), np.uint8)
    m = legmask.copy()
    m[:, :x0] = False
    m[:, x1:] = False
    p[m] = base[m]
    # estende a calça para cima até o quadril (fica sob o casaco)
    ref = 167
    for y in range(HIP - 4, ref):
        row = p[ref, x0:x1].copy()
        p[y, x0:x1][row[:, 3] > 0] = row[row[:, 3] > 0]
    if dark:
        p[:, :, :3] = (p[:, :, :3] * dark).astype(np.uint8)
    return Image.fromarray(p)


back = leg(55, GAP, .82)
front = leg(GAP, 155, 1.0)
hipB = ((55 + GAP) / 2, HIP)
hipF = ((GAP + 150) / 2, HIP)
L = H - 3 - HIP
AMP = 22.0
LIFT = 6.0
out = Image.new('RGBA', (CW * 8, CH), (0, 0, 0, 0))
for i in range(8):
    ph = 2 * math.pi * i / 8
    aF = AMP * math.sin(ph)
    aB = -aF
    liftF = LIFT * max(0.0, math.cos(ph))
    liftB = LIFT * max(0.0, -math.cos(ph))
    drop = L * (1 - math.cos(math.radians(abs(aF))))
    fr = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    for img, hp, ang, lf in ((back, hipB, aB, liftB), (front, hipF, aF, liftF)):
        rot = img.rotate(ang, resample=Image.BICUBIC, center=hp)
        fr.alpha_composite(rot, (0, int(round(drop - lf))) if drop - lf >= 0 else (0, 0))
        if drop - lf < 0:
            pass
    fr.alpha_composite(Image.fromarray(body), (0, int(round(drop))))
    out.paste(fr, (i * CW, 0))
out.save(os.path.join(S, 'vigia_walk.png'), optimize=True)
print('ok', 'passada (px da folha):', round(2 * L * math.sin(math.radians(AMP)), 1))
