#!/usr/bin/env python3
"""rl3_cut.py <grade.jpg> <cols> <rows> <folha:idx,idx> ...

Recorta uma grade convertida pelo Gemini (fundo branco) e devolve cada quadro
para o lugar dele nas folhas originais de assets/sprites/tome/*.png,
mantendo o tamanho e o ponto de apoio (pés) do quadro original.
Os quadros são lidos da grade da esquerda para a direita, de cima para baixo.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

TOME = 'assets/sprites/tome/'


def alpha_from_white(rgb):
    a = rgb.astype(np.int32)
    mn = a.min(axis=2)
    sat = a.max(axis=2) - mn
    bgish = (mn > 196) & (sat < 75)
    lab, _ = ndimage.label(bgish)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    fg = ~bg
    # remove pequenos fragmentos soltos
    lab2, n = ndimage.label(fg)
    if n:
        sizes = ndimage.sum(fg, lab2, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sizes > 60
        fg = keep[lab2]
    alpha = fg.astype(np.float32)
    # borda suave: na faixa externa, alfa pela distância do branco
    edge = fg & ~ndimage.binary_erosion(fg, iterations=2)
    soft = np.clip((765 - a.sum(axis=2)) / 120.0, 0, 1)
    alpha[edge] = np.maximum(soft[edge], 0.0)
    alpha = ndimage.gaussian_filter(alpha, 0.6) * fg
    # descontamina o branco das bordas
    out = a.astype(np.float32)
    m = (alpha > 0.02) & (alpha < 0.98)
    for c in range(3):
        ch = out[..., c]
        ch[m] = np.clip((ch[m] - 255 * (1 - alpha[m])) / alpha[m], 0, 255)
    return np.dstack([out, alpha * 255]).astype(np.uint8)


def main():
    src, cols, rows = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    targets = []
    for spec in sys.argv[4:]:
        f, ids = spec.split(':')
        for i in ids.split(','):
            targets.append((f, int(i)))
    im = Image.open(src).convert('RGB')
    rgba = alpha_from_white(np.array(im))
    H, W = rgba.shape[:2]
    cw, ch = W / cols, H / rows
    pieces = []
    for k in range(len(targets)):
        cx, cy = k % cols, k // cols
        cell = rgba[int(cy * ch):int((cy + 1) * ch), int(cx * cw):int((cx + 1) * cw)]
        ys, xs = np.nonzero(cell[..., 3] > 20)
        pieces.append(Image.fromarray(cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1]))
    sheets = {}
    origb = []
    for f, i in targets:
        if f not in sheets:
            sheets[f] = Image.open(TOME + f + '.png').convert('RGBA')
        origb.append(sheets[f].crop((i * 256, 0, i * 256 + 256, 256)).getbbox())
    scale = float(np.median([(b[3] - b[1]) / p.height for b, p in zip(origb, pieces)]))
    new = {f: Image.new('RGBA', s.size, (0, 0, 0, 0)) for f, s in sheets.items()}
    for (f, i), b, p in zip(targets, origb, pieces):
        q = p.resize((max(1, round(p.width * scale)), max(1, round(p.height * scale))), Image.LANCZOS)
        cxo = (b[0] + b[2]) / 2
        x = round(i * 256 + cxo - q.width / 2)
        y = b[3] - q.height
        x = min(max(x, i * 256), i * 256 + 256 - q.width)
        y = max(y, 0)
        frame = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
        frame.alpha_composite(q, (x - i * 256, y))
        new[f].alpha_composite(frame, (i * 256, 0))
    for f, s in new.items():
        s.save(TOME + f + '.png')
        print(f, s.size, 'escala %.3f' % scale)


if __name__ == '__main__':
    main()
