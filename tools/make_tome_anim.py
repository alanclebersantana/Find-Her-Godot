#!/usr/bin/env python3
"""Folhas novas do Tomé (geradas no Gemini, tools/art_src/tome_mov.jpg, fundo branco) ->
assets/sprites/tome/run.png (8), jump.png, fall.png, land.png — quadros quadrados de 256 px,
pés na base, centralizados pelo centro de massa do desenho (sem tremer entre quadros)."""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp()
subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(ROOT, 'tools', 'art_src', 'tome_mov.jpg'),
                os.path.join(tmp, 'f'), '236', '8'], check=True, capture_output=True)
fr = []
k = 0
while os.path.exists(os.path.join(tmp, 'f_%d.png' % k)):
    fr.append(Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA'))
    k += 1
S = 256
C = .945            # escala comum (corrida ~64 px de altura na tela, como o Tomé parado)
def cell(im):
    im = im.crop(im.getbbox())
    im = im.resize((int(im.width * C), int(im.height * C)), Image.LANCZOS)
    a = np.asarray(im)[..., 3].astype(float)
    cx = (a.sum(axis=0) * np.arange(im.width)).sum() / a.sum()
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.alpha_composite(im, (int(round(S / 2 - cx)), S - 2 - im.height))
    return out
def save(name, idx):
    sh = Image.new('RGBA', (S * len(idx), S), (0, 0, 0, 0))
    for i, j in enumerate(idx):
        sh.alpha_composite(cell(fr[j]), (i * S, 0))
    os.makedirs(os.path.join(ROOT, 'assets', 'sprites', 'tome'), exist_ok=True)
    sh.save(os.path.join(ROOT, 'assets', 'sprites', 'tome', name + '.png'))
save('run', [0, 1, 2, 3, 4, 5, 6, 7])
save('jump', [13])
save('fall', [14])
save('land', [15])
print('ok', len(fr))
