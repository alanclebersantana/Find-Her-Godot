#!/usr/bin/env python3
"""Terra lisa embaixo do chão: mantém só a faixa de cima (grama / trilho / calçamento) e troca o resto
por terra pintada simples, sem raízes, pedras ou cogumelos (pedido do Alan: nada de poluição visual).
A terra tem só variação suave de tom (pinceladas grandes), emenda nas laterais e escurece para baixo.
Uso como módulo: plain(im, keep_mask, base_rgb) -> imagem nova.
Uso direto: plain_dirt.py  (refaz chao_mina.png e chao_vila.png a partir das cópias antigas)"""
import os, shutil
import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def dirt(w, h, base, seed=7):
    rng = np.random.default_rng(seed)
    b = np.array(base, float)
    # pinceladas grandes e suaves (ruído desfocado que emenda nas laterais)
    n1 = nd.gaussian_filter(rng.standard_normal((h, w)), (5, 14), mode='wrap')
    n2 = nd.gaussian_filter(rng.standard_normal((h, w)), (2, 5), mode='wrap')
    n1 /= max(1e-6, np.abs(n1).max())
    n2 /= max(1e-6, np.abs(n2).max())
    v = 1 + n1 * .07 + n2 * .035
    a = np.ones((h, w, 3)) * b[None, None, :] * v[..., None]
    # um pouco mais quente perto da superfície
    ys = np.linspace(0, 1, h)[:, None, None]
    a *= (1.04 - .1 * ys)
    return a


def plain(im, keep, base, shade=22):
    """im: RGBA; keep: máscara (h, w) do que fica da arte original (grama, trilho...)."""
    a = np.asarray(im.convert('RGBA')).astype(float)
    h, w = keep.shape
    d = dirt(w, h, base)
    # sombra macia logo abaixo do que ficou por cima (a grama faz sombra na terra)
    k = keep.astype(float)
    below = np.zeros_like(k)
    cov = np.maximum.accumulate((a[..., 3] > 10).astype(float), axis=0)   # tudo abaixo do topo do chão
    dist = nd.distance_transform_edt(k < .5)
    sh = np.clip(1 - dist / shade, 0, 1) * cov
    d *= (1 - .45 * sh)[..., None]
    out = np.zeros_like(a)
    out[..., :3] = d
    out[..., 3] = 255 * cov                         # terra só onde já é chão (abaixo do topo)
    ka = (a[..., 3:4] / 255) * k[..., None]
    out[..., :3] = a[..., :3] * ka + out[..., :3] * (1 - ka)
    out[..., 3] = np.maximum(out[..., 3], a[..., 3] * k)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA')


def top_band(im, rows):
    a = np.asarray(im.convert('RGBA'))
    keep = np.zeros(a.shape[:2], bool)
    keep[:rows] = a[:rows, :, 3] > 10
    return keep


if __name__ == '__main__':
    src = os.path.join(ROOT, 'tools', 'art_src')
    for n, rows, base in (('chao_mina', 54, (78, 52, 34)), ('chao_vila', 80, (104, 66, 40))):
        p = os.path.join(ROOT, 'assets', 'sprites', n + '.png')
        old = os.path.join(src, n + '_antigo.png')
        if not os.path.exists(old):
            shutil.copy(p, old)
        im = Image.open(old)
        plain(im, top_band(im, rows), base).save(p)
        print(n, 'ok')
