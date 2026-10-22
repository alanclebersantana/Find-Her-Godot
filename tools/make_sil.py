#!/usr/bin/env python3
"""Silhuetas brancas (mesmo alfa) das folhas usadas no contorno de luz e no contorno vermelho dos inimigos.
Gera <nome>_sil.png ao lado de cada folha (o jogo usa se existir, em vez de calcular no celular)."""
import os, sys
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = os.path.join(ROOT, 'assets', 'sprites')
names = ['atlas1', 'atlas2', 'extra', 'en_boar', 'en_frog2', 'en_crow2', 'javali', 'esquilo', 'pai', 'pai2']
names += [f[:-4] for f in os.listdir(S) if f.startswith('paint') and f.endswith('.png') and not f.endswith('_sil.png')]
for n in names:
    p = os.path.join(S, n + '.png')
    if not os.path.exists(p):
        continue
    im = Image.open(p).convert('RGBA')
    a = im.getchannel('A')
    w = Image.new('RGBA', im.size, (255, 255, 255, 0))
    w.putalpha(a)
    w.save(os.path.join(S, n + '_sil.png'), optimize=True)
    print('sil', n)
