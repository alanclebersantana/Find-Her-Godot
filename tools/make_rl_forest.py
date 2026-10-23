#!/usr/bin/env python3
"""Floresta da manhã no estilo novo (Gemini, tools/art_src/rl_*.jpg):
assets/bg/bosque/1_ceu.jpg (céu e floresta distante), 2_longe.png (árvores ao longe: menores, azuladas e
desfocadas), 3_meio.png (árvores grandes recortadas) e assets/sprites/chao.png (chão emendável)."""
import os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as nd
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, 'tools', 'art_src')
OUT = os.path.join(ROOT, 'assets', 'bg', 'bosque')
os.makedirs(OUT, exist_ok=True)

def seamless(im, band):
    """emenda as bordas: a faixa da direita se funde com a da esquerda (pode repetir sem costura)"""
    a = np.asarray(im).astype(float)
    w = a.shape[1]
    left = a[:, :band].copy()
    right = a[:, w - band:].copy()
    t = np.linspace(0, 1, band)[None, :, None]
    a[:, :band] = right * (1 - t) + left * t
    return Image.fromarray(np.clip(a[:, :w - band], 0, 255).astype(np.uint8), im.mode)

def key_white(im, thr=232):
    a = np.asarray(im.convert('RGB')).astype(int)
    white = a.min(axis=2) >= thr
    lab, n = nd.label(white)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    # buracos brancos entre galhos e folhas (céu aparecendo por dentro da copa) também são fundo
    sizes = nd.sum(white, lab, index=np.arange(n + 1))
    bg |= white & (sizes[lab] > 40)
    fg = ~bg
    dist = nd.distance_transform_edt(fg)
    alpha = np.clip(dist / 2.0, 0, 1) * 255
    # tira o halo branco da borda escurecendo a cor perto do fundo
    rgb = a.astype(float)
    edge = (dist < 3) & fg
    rgb[edge] *= .85
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), alpha.astype(np.uint8)]), 'RGBA')

# 1: céu e floresta distante (opaco)
far = Image.open(os.path.join(A, 'rl_bg_far.jpg')).convert('RGB')
seamless(far, 160).save(os.path.join(OUT, '1_ceu.jpg'), quality=90)
# 3: árvores grandes do meio
trees = key_white(Image.open(os.path.join(A, 'rl_bg_trees.jpg')))
trees.save(os.path.join(OUT, '3_meio.png'))
# 2: as mesmas árvores bem longe: menores, mais claras/azuladas (névoa) e desfocadas
t2 = trees.resize((trees.width // 2, trees.height // 2), Image.LANCZOS)
a = np.asarray(t2).astype(float)
fog = np.array([170, 205, 225], float)
a[..., :3] = a[..., :3] * .45 + fog * .55
t2 = Image.fromarray(a.astype(np.uint8), 'RGBA').filter(ImageFilter.GaussianBlur(1.6))
canvas = Image.new('RGBA', (trees.width, trees.height), (0, 0, 0, 0))
for i in range(2):
    canvas.alpha_composite(t2, (i * t2.width, trees.height - t2.height - 40))
canvas.save(os.path.join(OUT, '2_longe.png'))
# chão: faixa de grama e terra (borda da grama a 32 px do topo, como a textura antiga)
g = Image.open(os.path.join(A, 'rl_ground.jpg')).convert('RGB')
gk = key_white(g)
K = .42
top = 250
crop = gk.crop((0, top, gk.width, gk.height))
crop = crop.resize((int(crop.width * K), int(crop.height * K)), Image.LANCZOS)
crop = seamless(crop, 60)
# a pintura escurece no pé (sombra do recorte): corta essa faixa e iguala o brilho da terra,
# para a terra repetir para baixo sem listras escuras
crop = crop.crop((0, 0, crop.width, 140))
ca = np.asarray(crop).astype(float)
ref = ca[96:104, :, :3].mean()
for y in range(100, 140):
    m = ca[y, :, :3].mean()
    ca[y, :, :3] *= min(1.6, ref / max(m, 1.0)) ** min(1.0, (y - 100) / 12.0)
crop = Image.fromarray(np.clip(ca, 0, 255).astype(np.uint8), 'RGBA')
old = Image.open(os.path.join(ROOT, 'assets', 'sprites', 'chao.png'))
if not os.path.exists(os.path.join(A, 'chao_antigo.png')):
    old.save(os.path.join(A, 'chao_antigo.png'))
crop.save(os.path.join(ROOT, 'assets', 'sprites', 'chao.png'))

# chão de floresta embaixo das árvores do fundo (sem isso as árvores ficam flutuando):
# a própria faixa de grama e terra, repetida, escurecida para baixo e com a névoa da camada
def floor_strip(width, hgt, fogk, fogc, dark):
    t = crop.resize((round(crop.width * hgt / crop.height), hgt), Image.LANCZOS)
    st = Image.new('RGBA', (width, hgt), (0, 0, 0, 0))
    x = 0
    while x < width:
        st.alpha_composite(t, (x, 0))
        x += t.width - 2
    a = np.asarray(st).astype(float)
    ys = np.linspace(0, 1, hgt)[:, None, None]
    a[..., :3] *= (1 - dark * ys)
    a[..., :3] = a[..., :3] * (1 - fogk) + np.array(fogc, float) * fogk
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')

meio = Image.open(os.path.join(OUT, '3_meio.png')).convert('RGBA')
st = floor_strip(meio.width, 120, .18, [60, 80, 60], .55)
meio.alpha_composite(st, (0, meio.height - 96))
meio.save(os.path.join(OUT, '3_meio.png'))
longe = Image.open(os.path.join(OUT, '2_longe.png')).convert('RGBA')
st = floor_strip(longe.width, 90, .55, [170, 205, 225], .25)
st = st.filter(ImageFilter.GaussianBlur(1.6))
longe.alpha_composite(st, (0, longe.height - 74))
longe.save(os.path.join(OUT, '2_longe.png'))
print('ok', crop.size)
