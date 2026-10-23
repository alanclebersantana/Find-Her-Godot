"""Versões verticais CALMAS (1080x1920) para status: poucas tomadas, longas, câmera deslizando devagar
pelo cenário, sons de ambiente de cada fase e frases sobre o capricho e o clássico de plataforma.
  cA  Paisagens  — 60 s, tela cheia, uma tomada longa por fase
  cB  Janela     — 60 s, gameplay numa janela 4:5 (mostra mais cenário), trilha das fases
  cC  Clássico   — 30 s, "O clássico de plataforma ainda vive"
Mesma história (Isis, a sombra, o sumiço) e o final com a pergunta. Ninguém revela quem levou a Isis.
Uso: python3 calmo.py [cA cB cC] -> /tmp/vid/encontre-a_calmo_<v>.mp4"""
import os, sys, math, subprocess, hashlib
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import vertical as V
from vertical import (font, ease, ramp, cover, text_layer, over, paste_a, writer, render, framed_panel,
                      W, H, FPS, SW, SH, GOLD, CREAM, YEL, INK, FASES, FASE_COR, R, A)
from build import load_pos, nframes, HI

OUT = '/tmp/vid/cseg/'
FASES1, COR1 = list(FASES), list(FASE_COR)
FASES2 = ['MINA', 'MOINHO', 'VILA', 'PROFUNDEZAS', 'A FUGA DA ISIS']
COR2 = [(210, 170, 110), (240, 190, 90), (150, 160, 240), (200, 140, 90), (240, 150, 170)]
AMB2 = {0: ('amb_caverna.ogg', .5), 1: ('amb_passaros.ogg', .5), 2: ('amb_grilos.ogg', .5),
        3: ('amb_caverna.ogg', .55), 4: ('amb_caverna.ogg', .45)}
MUS2 = {0: 'tunel', 1: 'tarde', 2: 'noite', 3: 'tunel', 4: 'noite'}
AMB = {0: ('amb_passaros.ogg', .55), 1: ('amb_passaros.ogg', .45), 2: ('amb_sapos.ogg', .6),
       3: ('amb_vento.ogg', .45), 4: ('amb_grilos.ogg', .45), 5: ('amb_caverna.ogg', .5)}


def soft_band(y0, y1, a=150):
    b = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    for yy in range(y0, y1):
        k = min(1, (yy - y0) / ((y1 - y0) * .35), (y1 - yy) / ((y1 - y0) * .35))
        d.line([(0, yy), (W, yy)], fill=(0, 0, 0, int(a * max(0, k))))
    return b


# ---------------------------------------------------------------- cartelas novas
def c_classico(dur):
    base = cover(R + 'assets/bg/bosque.jpg', int(W * 1.06), int(H * 1.03), 8, .55)
    L1 = text_layer([('Lembra dos jogos de plataforma', font('Lora-Italic', 58), CREAM, 800, 3, 980),
                     ('de antigamente?', font('Lora-Italic', 58), CREAM, 875, 3, 980)])
    L2 = text_layer([('O CLÁSSICO', font('Cinzel-Bold', 96), YEL, 1040, 6),
                     ('AINDA VIVE.', font('Cinzel-Bold', 96), YEL, 1150, 6)])

    def fr(t):
        ox = int(W * .05 * t / dur)
        im = over(base.crop((ox, 20, ox + W, 20 + H)), V.VIG, 1)
        im = over(im, L1, ramp(t, .3, dur - .1, .5))
        im = over(im, L2, ramp(t, dur * .42, dur - .1, .5))
        return im
    return fr


def c_final_calmo(dur):
    base = cover(R + 'assets/bg/noite.jpg', int(W * 1.06), int(H * 1.03), 6, .58)
    B = text_layer([('QUEM LEVOU A ISIS?', font('Cinzel-Bold', 100), YEL, 920, 6, 960)])
    C = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 124), GOLD, 700, 6),
                    ('EPISÓDIO 1 · O BOSQUE', font('Cinzel-Bold', 50), (232, 201, 138), 815, 4)])
    D = text_layer([('Um clássico de plataforma,', font('Lora-Italic', 50), CREAM, 1010, 2),
                    ('feito com capricho, detalhe por detalhe.', font('Lora-Italic', 50), CREAM, 1075, 2, 1000),
                    ('A seguir: Episódio 2 · As Profundezas da Mina', font('Lora-Bold', 36), (255, 214, 120), 1230, 2, 1000),
                    ('Para Android', font('Lora-Italic', 40), (225, 215, 195), 1330, 0)])
    a1 = dur * .32

    def fr(t):
        ox = int(W * .05 * t / dur)
        im = over(base.crop((ox, 20, ox + W, 20 + H)), V.VIG, 1)
        im = over(im, B, ramp(t, .2, a1, .45))
        im = over(im, C, ease((t - a1 - .2) / .7))
        im = over(im, D, ease((t - a1 - .9) / .8))
        return im
    return fr


def c_final_destaque(dur):
    base = cover(R + 'assets/bg/noite.jpg', int(W * 1.06), int(H * 1.03), 6, .6)
    B = text_layer([('QUEM LEVOU A ISIS?', font('Cinzel-Bold', 100), YEL, 920, 6, 960)])
    C = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 124), GOLD, 620, 6),
                    ('EPISÓDIO 1 · O BOSQUE', font('Cinzel-Bold', 50), (232, 201, 138), 735, 4)])
    D1 = text_layer([('O CLÁSSICO GÊNERO', font('Cinzel-Bold', 70), YEL, 930, 5),
                     ('DE PLATAFORMA', font('Cinzel-Bold', 70), YEL, 1015, 5)])
    D2 = text_layer([('O BÁSICO BEM FEITO.', font('Cinzel-Bold', 70), YEL, 1150, 5)])
    E = text_layer([('A seguir: Episódio 2 · As Profundezas da Mina', font('Lora-Bold', 36), (255, 214, 120), 1320, 2, 1000),
                    ('Para Android', font('Lora-Italic', 40), (225, 215, 195), 1410, 0)])
    a1 = dur * .26

    def fr(t):
        ox = int(W * .05 * t / dur)
        im = over(base.crop((ox, 20, ox + W, 20 + H)), V.VIG, 1)
        im = over(im, B, ramp(t, .2, a1, .45))
        im = over(im, C, ease((t - a1 - .2) / .7))
        im = over(im, D1, ease((t - a1 - .9) / .6))
        im = over(im, D2, ease((t - a1 - 1.8) / .6))
        im = over(im, E, ease((t - a1 - 2.6) / .6))
        return im
    return fr


def c_final_simples(dur):
    base = cover(R + 'assets/bg/noite.jpg', int(W * 1.06), int(H * 1.03), 6, .6)
    B = text_layer([('QUEM LEVOU A ISIS?', font('Cinzel-Bold', 100), YEL, 920, 6, 960)])
    C = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 124), GOLD, 820, 6),
                    ('EPISÓDIO 1 · O BOSQUE', font('Cinzel-Bold', 50), (232, 201, 138), 935, 4)])
    E = text_layer([('A seguir: Episódio 2 · As Profundezas da Mina', font('Lora-Bold', 36), (255, 214, 120), 1110, 2, 1000),
                    ('Para Android', font('Lora-Italic', 40), (225, 215, 195), 1200, 0)])
    a1 = dur * .36

    def fr(t):
        ox = int(W * .05 * t / dur)
        im = over(base.crop((ox, 20, ox + W, 20 + H)), V.VIG, 1)
        im = over(im, B, ramp(t, .2, a1, .45))
        im = over(im, C, ease((t - a1 - .2) / .7))
        im = over(im, E, ease((t - a1 - 1.0) / .7))
        return im
    return fr


V.CARDS['final_simples'] = c_final_simples
def c_final_simples(dur):
    base = cover(R + 'assets/bg/noite.jpg', int(W * 1.06), int(H * 1.03), 6, .6)
    B = text_layer([('QUEM LEVOU A ISIS?', font('Cinzel-Bold', 100), YEL, 920, 6, 960)])
    C = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 124), GOLD, 820, 6),
                    ('EPISÓDIO 1 · O BOSQUE', font('Cinzel-Bold', 50), (232, 201, 138), 935, 4)])
    E = text_layer([('A seguir: Episódio 2 · As Profundezas da Mina', font('Lora-Bold', 36), (255, 214, 120), 1110, 2, 1000),
                    ('Para Android', font('Lora-Italic', 40), (225, 215, 195), 1200, 0)])
    a1 = dur * .36

    def fr(t):
        ox = int(W * .05 * t / dur)
        im = over(base.crop((ox, 20, ox + W, 20 + H)), V.VIG, 1)
        im = over(im, B, ramp(t, .2, a1, .45))
        im = over(im, C, ease((t - a1 - .2) / .7))
        im = over(im, E, ease((t - a1 - 1.0) / .7))
        return im
    return fr


V.CARDS['final_simples'] = c_final_simples
def _pan2(imgs, textos, dur, band_y=(1100, 1700)):
    """pan vertical por uma ou duas ilustrações (fundindo uma na outra), com textos em sequência"""
    srcs = [Image.open(R + 'assets/ui/%s.jpg' % n).convert('RGB') for n in imgs]
    lays = [text_layer([(t_, font('Lora-Italic', 56), CREAM, 1380, 3, 940)]) for t_ in textos]
    band = soft_band(band_y[0], band_y[1], 170)
    n = len(srcs)

    def view(src, k, xa, xb):
        ch = 760 - 90 * k
        cw = ch * W / H
        x = xa + (min(xb, src.width - cw - 10) - xa) * ease(k)
        y = 4 + 60 * k
        return src.crop((int(x), int(y), int(x + cw), int(y + ch))).resize((W, H), Image.LANCZOS)

    def fr(t):
        seg_d = dur / n
        j = min(n - 1, int(t / seg_d))
        k = (t - j * seg_d) / seg_d
        im = view(srcs[j], k, *PAN2[imgs[j]])
        if j + 1 < n and k > .82:  # fusão para a próxima
            nx = view(srcs[j + 1], 0, *PAN2[imgs[j + 1]])
            im = Image.blend(im, nx, ease((k - .82) / .18))
        im = over(im, V.VIG, 1)
        im = over(im, band, 1)
        tl = dur / len(lays)
        for q, L in enumerate(lays):
            im = over(im, L, ramp(t, q * tl + .4, (q + 1) * tl - .1, .45))
        return im
    return fr


PAN2 = {'cut_ep2_a': (250, 620), 'cut_ep2_b': (600, 300), 'cut_isis_a': (180, 520), 'cut_isis_b': (380, 700)}


def c_ep2_abertura(dur):
    return _pan2(['cut_ep2_a', 'cut_ep2_b'], ['A trilha de lápis entra mina adentro...',
                                              'E o Tomé desce atrás dela, com a lanterna acesa.'], dur)


def c_ep2_isis(dur):
    return _pan2(['cut_isis_a', 'cut_isis_b'], ['Lá no fundo, a Isis não desiste.',
                                                'Cada lápis no chão é um recado para o pai.'], dur)


def c_ep2_titulo(dur):
    base = cover(R + 'assets/bg/mina.jpg', int(W * 1.08), int(H * 1.04), 7, .5)
    L = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 128), GOLD, 820, 6)])
    L2 = text_layer([('EPISÓDIO 2', font('Cinzel-Bold', 58), (232, 201, 138), 950, 4),
                     ('AS PROFUNDEZAS DA MINA', font('Cinzel-Bold', 52), (232, 201, 138), 1025, 4, 1000)])

    def fr(t):
        ox = int(W * .08 * ease(t / dur))
        im = over(base.crop((ox, 30, ox + W, 30 + H)), V.VIG, 1)
        im = over(im, L, ease((t - .1) / .6))
        im = over(im, L2, ease((t - .6) / .6))
        return im
    return fr


def c_ep2_final(dur):
    base = cover(R + 'assets/bg/esconderijo.jpg', int(W * 1.06), int(H * 1.03), 6, .62)
    B = text_layer([('Ela está cada vez mais perto.', font('Lora-Italic', 66), CREAM, 920, 3, 960)])
    C = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 124), GOLD, 800, 6),
                    ('EPISÓDIO 2', font('Cinzel-Bold', 54), (232, 201, 138), 915, 4),
                    ('AS PROFUNDEZAS DA MINA', font('Cinzel-Bold', 48), (232, 201, 138), 985, 4, 1000)])
    E = text_layer([('Para Android', font('Lora-Italic', 42), (225, 215, 195), 1150, 0)])
    a1 = dur * .36

    def fr(t):
        ox = int(W * .05 * t / dur)
        im = over(base.crop((ox, 20, ox + W, 20 + H)), V.VIG, 1)
        im = over(im, B, ramp(t, .2, a1, .45))
        im = over(im, C, ease((t - a1 - .2) / .7))
        im = over(im, E, ease((t - a1 - 1.0) / .7))
        return im
    return fr


V.CARDS.update({'ep2_abertura': c_ep2_abertura, 'ep2_isis': c_ep2_isis, 'ep2_titulo': c_ep2_titulo,
                'ep2_final': c_ep2_final})
V.CARDS['q_mergulho'] = V.c_quadro('mergulho', 'assets/bg/pantano.jpg', 'Lá no fundo tem alguma coisa brilhando...')
V.CARDS['q_jangada'] = V.c_quadro('jangada', 'assets/bg/pantano.jpg', 'Segura firme... que correnteza!')
V.CARDS['classico'] = c_classico
V.CARDS['final_destaque'] = c_final_destaque
V.CARDS['final_calmo'] = c_final_calmo


def card(name, dur):
    path = OUT + 'c_%s_%.2f.mp4' % (name, dur)
    fi = .6 if name in ('abertura', 'classico') else .35
    fo = 1.0 if name.startswith('final') else .45
    return render(path, dur, V.CARDS[name](dur), fi, fo)


# ---------------------------------------------------------------- tomadas longas
def calm_path(seg, st, cnt, n, cw_n):
    """caminho da câmera: deslize reto (com aceleração suave) entre o começo e o fim da tomada;
    se o Tomé fugir do quadro, usa um acompanhamento bem amortecido"""
    pos = load_pos(seg, n)
    s0 = int(st * FPS)
    win = [pos[min(n - 1, s0 + i)] for i in range(cnt)]
    k = max(3, cnt // 6)
    a = (sum(p[0] for p in win[:k]) / k, sum(p[1] for p in win[:k]) / k)
    b = (sum(p[0] for p in win[-k:]) / k, sum(p[1] for p in win[-k:]) / k)
    lin = [(a[0] + (b[0] - a[0]) * ease(i / max(1, cnt - 1)), a[1] + (b[1] - a[1]) * ease(i / max(1, cnt - 1)))
           for i in range(cnt)]
    dev = max(abs(w[0] - l[0]) for w, l in zip(win, lin))
    if dev < cw_n * .36:
        return lin
    sm, c = [], win[0]
    for p in win:
        c = (c[0] * .955 + p[0] * .045, c[1] * .955 + p[1] * .045)
        sm.append(c)
    out, c = [], sm[-1]
    for p in reversed(sm):
        c = (c[0] * .955 + p[0] * .045, c[1] * .955 + p[1] * .045)
        out.append(c)
    return list(reversed(out))


def tomada(seg, st, du, fase, layout, frase=None, z0=1.0, z1=1.08, gm=None, fixed=None, bias=(0, .02), trilha=False):
    key = repr((seg, st, du, fase, layout, frase, z0, z1, gm, fixed, bias, trilha, 'leg4' if layout != 'cheia' else ''))
    path = OUT + 't_%s_%s.mp4' % (seg, hashlib.md5(key.encode()).hexdigest()[:8])
    if os.path.exists(path):
        return path
    avi = HI + seg + '.avi'
    n = nframes(avi)
    cnt = int(round(du * FPS))
    aspect = (W / H) if layout == 'cheia' else (4 / 5)
    path_c = [fixed] * cnt if fixed else calm_path(seg, st, cnt, n, (SH / z0) * aspect / SW)
    dec = subprocess.Popen(['ffmpeg', '-v', 'error', '-ss', str(st), '-i', avi, '-frames:v', str(cnt),
                            '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
    enc = writer(path)
    fcol = FASE_COR[fase]
    tag = V.pill('%d · %s' % (fase + 1, FASES[fase]), 36, (14, 10, 6, 150), fcol, 'Cinzel-Bold')
    fl = text_layer([(frase, font('Lora-Italic', 60), CREAM, 1520, 3, 960)]) if (frase and layout == 'cheia' and isinstance(frase, str)) else None
    band = soft_band(1330, 1750, 150) if layout == 'cheia' else None
    jl = jd = emo = None
    if frase and layout != 'cheia':
        if isinstance(frase, tuple):  # (frase pequena, DESTAQUE[, emoji])
            peq, big = frase[:2]
            if len(frase) > 2:
                ef = ImageFont.truetype('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf', 109)
                ei = Image.new('RGBA', (160, 160), (0, 0, 0, 0))
                ImageDraw.Draw(ei).text((10, 10), frase[2], font=ef, embedded_color=True)
                ei = ei.crop(ei.getbbox())
                emo = ei.resize((int(ei.width * 1.5), int(ei.height * 1.5)), Image.LANCZOS)
            bl = big.split('|')  # '|' marca a quebra de linha do destaque
            nb = len(bl)
            y0 = 1640 - (nb - 1) * 76
            jl = text_layer([(peq, font('Lora-Italic', 46), CREAM, y0 - 72, 3, 1000)])
            jd = text_layer([(ln, font('Cinzel-Bold', 62), YEL, y0 + k * 76, 5, 1060) for k, ln in enumerate(bl)])
        else:
            jl = text_layer([(frase, font('Lora-Italic', 50), CREAM, 1640, 3, 1000)])
    jband = soft_band(1330, 1830, 175)
    logo = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 60), GOLD, 215, 4)])
    last = None
    for i in range(cnt):
        buf = dec.stdout.read(SW * SH * 3)
        im = Image.frombytes('RGB', (SW, SH), buf) if len(buf) == SW * SH * 3 else last
        last = im
        tt = i / max(1, cnt - 1)
        z = z0 + (z1 - z0) * tt
        u, v = path_c[i]
        ch = SH / z
        cw = ch * aspect
        cx = u * SW + bias[0] * SW
        cy = v * SH + bias[1] * SH
        x = min(max(cx - cw / 2, 0), SW - cw)
        y = min(max(cy - ch / 2, 0), SH - ch)
        if layout == 'cheia':
            fr = im.crop((int(x), int(y), int(x + cw), int(y + ch))).resize((W, H), Image.LANCZOS)
            if gm:
                fr = fr.point(lambda p: int(255 * (p / 255) ** (1 / gm)))
            fr = fr.convert('RGBA')
            paste_a(fr, tag, (W // 2 - tag.width // 2, 270), ramp(i / FPS, .2, du - .2, .6))
            if fl:
                a = ramp(i / FPS, .7, du - .35, .7)
                fr.alpha_composite(band) if a > 0 else None
                fr = over(fr.convert('RGB'), fl, a).convert('RGBA') if a > 0 else fr
        else:  # janela 4:5 de 1080x1350, fundo desfocado
            win = im.crop((int(x), int(y), int(x + cw), int(y + ch))).resize((W, 1350), Image.LANCZOS)
            if gm:
                win = win.point(lambda p: int(255 * (p / 255) ** (1 / gm)))
            sm = im.resize((SW // 8, SH // 8))
            bw = int(SH // 8 * W / H)
            bg = sm.crop((SW // 16 - bw // 2, 0, SW // 16 + bw // 2, SH // 8)).filter(ImageFilter.GaussianBlur(5))
            bg = Image.blend(bg.resize((W, H), Image.BILINEAR), Image.new('RGB', (W, H)), .6)
            fr = bg.convert('RGBA')
            fr.alpha_composite(logo)
            paste_a(fr, tag, (W // 2 - tag.width // 2, 280))
            fr.paste(win, (0, 370))
            d = ImageDraw.Draw(fr)
            d.line([(0, 370), (W, 370)], fill=fcol + (230,), width=3)
            d.line([(0, 1719), (W, 1719)], fill=fcol + (230,), width=3)
            if jl:
                ta = ramp(i / FPS, .5, du - .3, .6)
                if ta > 0:
                    sub = jband.crop((0, 370, W, 1720))
                    sub.putalpha(sub.getchannel('A').point(lambda v: int(v * ta)))
                    fr.alpha_composite(sub, (0, 370))
                fr = over(fr.convert('RGB'), jl, ta).convert('RGBA')
                if jd:
                    fr = over(fr.convert('RGB'), jd, ramp(i / FPS, 1.0, du - .3, .5)).convert('RGBA')
                if emo is not None:
                    ea = ramp(i / FPS, 1.0, du - .3, .4)
                    if ea > 0:
                        sc = .8 + .2 * ease((i / FPS - 1.0) / .35)
                        e2 = emo.resize((int(emo.width * sc), int(emo.height * sc)), Image.LANCZOS)
                        paste_a(fr, e2, (W // 2 - e2.width // 2, 1340 - e2.height // 2), ea)
                d = ImageDraw.Draw(fr)
            if trilha:
                nf_ = len(FASES)
                sp_ = 800 / (nf_ - 1)
                xs = [140 + k * sp_ for k in range(nf_)]
                yy = 1785
                for k in range(nf_ - 1):
                    d.line([(xs[k] + 16, yy), (xs[k + 1] - 16, yy)], fill=(230, 220, 200, 170) if k < fase else (60, 58, 55, 170), width=4)
                for k, xk in enumerate(xs):
                    r = 15 if k == fase else 10
                    c = FASE_COR[k] if k <= fase else (70, 66, 62)
                    d.ellipse([xk - r, yy - r, xk + r, yy + r], fill=c + (240,), outline=(20, 12, 5, 240), width=2)
        fr = fr.convert('RGB')
        k = min(1.0, ease(i / 14), ease((cnt - 1 - i) / 14))  # fusão lenta pelo preto
        if k < 1:
            fr = Image.blend(Image.new('RGB', (W, H)), fr, k)
        enc.stdin.write(fr.tobytes())
    dec.stdout.close()
    dec.wait()
    enc.stdin.close()
    enc.wait()
    print('  ', seg, du, layout)
    return path


# ---------------------------------------------------------------- roteiros
def t(seg, st, du, fase, frase=None, **op):
    return ('t', seg, st, du, fase, frase, op)


def c(name, du):
    return ('c', name, du)


ROT = {
    'cA': ('cheia', [
        c('abertura', 6.4), c('sumiu', 3.0), c('titulo', 3.2),
        t('a_inicio', 0.0, 5.0, 0, 'Sem pressa. Siga a trilha de cores.'),
        t('a_escada', 2.6, 5.6, 0, 'Cada cenário desenhado com capricho.'),
        t('copas', 3.0, 4.6, 1, None),
        t('a_planar', 0.8, 5.2, 1, 'Pular, explorar, flutuar... como nos velhos tempos.'),
        t('regias', 6.8, 5.6, 2, 'Chuva no pântano, cipós e vaga-lumes.'),
        t('voo', 18.0, 5.4, 3, 'Paisagens que mudam a cada passo.', bias=(.04, .02), z1=1.0),
        t('cogumelos', 2.0, 6.0, 4, 'O clássico de plataforma ainda vive.', gm=1.2),
        t('a_tabuas', 0.2, 4.0, 5, None, gm=1.45),
        c('final_calmo', 6.0)]),
    'cB': ('janela', [
        c('abertura', 6.4), c('sumiu', 3.0), c('titulo', 3.0),
        t('manha', 0.0, 4.0, 0, 'A casa na árvore, as flores, as folhas no vento...', z0=1.1, z1=1.18, trilha=True),
        t('a_galho', 0.0, 5.4, 1, 'Um bosque de outono feito com capricho.', z0=1.1, z1=1.18, trilha=True),
        t('a_regias', 0.2, 5.4, 1, None, z0=1.1, z1=1.16, trilha=True),
        t('corda', 0.2, 4.2, 2, 'Chuva, sapos e cipós no pântano.', z0=1.1, z1=1.16, trilha=True),
        t('jangada', 1.0, 5.0, 2, None, z0=1.05, z1=1.12, trilha=True),
        t('vento', 2.0, 5.2, 3, 'Neve caindo sobre a montanha.', z0=1.1, z1=1.16, trilha=True),
        t('a_noite', 0.0, 5.6, 4, 'O dia vira noite enquanto você joga.', z0=1.05, z1=1.12, gm=1.15, trilha=True),
        t('a_noite', 4.6, 4.8, 4, 'O clássico de plataforma ainda vive.', z0=1.1, z1=1.16, gm=1.2, trilha=True),
        c('final_calmo', 6.0)]),
    'cB2': ('janela', [
        c('abertura', 6.4), c('sumiu', 3.0), c('titulo', 3.0),
        t('manha', 0.0, 4.0, 0, 'A casa na árvore, as flores, as folhas no vento...', z0=1.1, z1=1.18, trilha=True),
        t('a_galho', 0.0, 5.4, 1, 'Um bosque de outono desenhado com capricho.', z0=1.1, z1=1.18, trilha=True),
        t('a_regias', 0.2, 5.6, 1, ('Ele está de volta:', 'O CLÁSSICO GÊNERO|DE PLATAFORMA'), z0=1.1, z1=1.16, trilha=True),
        t('corda', 0.2, 4.2, 2, 'Chuva, sapos e cipós no pântano.', z0=1.1, z1=1.16, trilha=True),
        t('jangada', 1.0, 5.0, 2, 'A correnteza leva a jangada rio abaixo.', z0=1.05, z1=1.12, trilha=True),
        t('vento', 2.0, 5.4, 3, ('Jogue no toque ou no controle:', '100% COMPATÍVEL|COM GAMEPAD', '🎮'), z0=1.1, z1=1.16, trilha=True),
        t('a_noite', 0.0, 5.6, 4, 'O dia vira noite enquanto você joga.', z0=1.05, z1=1.12, gm=1.15, trilha=True),
        t('a_noite', 4.6, 5.0, 4, ('Sem truques, só capricho:', 'O BÁSICO BEM FEITO.'), z0=1.1, z1=1.16, gm=1.2, trilha=True),
        c('final_simples', 6.2)]),
    'cB3': ('janela', [
        c('abertura', 6.4), c('sumiu', 3.0), c('titulo', 3.0),
        t('manha', 0.0, 4.0, 0, 'A casa na árvore, as flores, as folhas no vento...', z0=1.1, z1=1.18, trilha=True),
        t('a_galho', 0.0, 4.2, 1, 'Um bosque de outono desenhado com capricho.', z0=1.1, z1=1.18, trilha=True),
        t('a_regias', 0.2, 5.0, 1, ('Ele está de volta:', 'O CLÁSSICO GÊNERO|DE PLATAFORMA'), z0=1.1, z1=1.16, trilha=True),
        t('javali', 0.3, 3.9, 1, 'O Javali-Rei guarda a trilha do bosque.', fixed=(.55, .52), z0=1.0, z1=1.05, trilha=True),
        t('a_colmeia', 0.0, 3.6, 2, 'Abaixe devagar... para não acordar a colmeia.', z0=1.1, z1=1.16, trilha=True),
        t('mergulho', 11.0, 4.2, 2, 'Mergulhe nas águas do pântano.', z0=1.05, z1=1.12, bias=(0, 0), trilha=True),
        t('bagre', 0.6, 4.0, 2, 'Lá no fundo, o Bagre-Rei espera.', fixed=(.6, .55), z0=1.0, z1=1.04, trilha=True),
        t('corda', 0.2, 3.8, 2, 'Chuva, sapos e cipós no pântano.', z0=1.1, z1=1.16, trilha=True),
        t('jangada', 1.0, 4.0, 2, 'A correnteza leva a jangada rio abaixo.', z0=1.05, z1=1.12, trilha=True),
        t('bolaneve', 0.0, 4.4, 3, 'Neve: role bolas de neve gigantes.', z0=1.1, z1=1.16, trilha=True),
        t('cavalo', 0.6, 4.4, 3, 'Uma cavalgada pela trilha nevada.', fixed=(.36, .55), z0=1.0, z1=1.05, trilha=True),
        t('urso', 0.6, 4.4, 3, 'O Urso-Rei acorda na toca.', fixed=(.5, .55), z0=1.0, z1=1.05, trilha=True),
        t('vento', 2.0, 5.0, 3, ('Jogue no toque ou no controle:', '100% COMPATÍVEL|COM GAMEPAD', '🎮'), z0=1.1, z1=1.16, trilha=True),
        t('voo', 18.0, 4.6, 3, 'De biplano, por cima das montanhas.', bias=(.05, .02), z0=1.0, z1=1.05, trilha=True),
        t('a_noite', 0.0, 4.6, 4, 'O dia vira noite enquanto você joga.', z0=1.05, z1=1.12, gm=1.15, trilha=True),
        t('a_noite', 4.6, 4.6, 4, ('Sem truques, só capricho:', 'O BÁSICO BEM FEITO.'), z0=1.1, z1=1.16, gm=1.2, trilha=True),
        t('a_tabuas', 0.2, 3.6, 5, 'E a trilha de cores segue para dentro da mina...', z0=1.1, z1=1.16, gm=1.45, trilha=True),
        c('final_simples', 5.4)]),
    'cB4': ('janela', [
        c('abertura', 6.4), c('sumiu', 3.0), c('titulo', 3.0),
        t('manha', 0.0, 4.0, 0, 'A casa na árvore, as flores, as folhas no vento...', z0=1.1, z1=1.18, trilha=True),
        t('a_galho', 0.0, 4.2, 1, 'Um bosque de outono desenhado com capricho.', z0=1.1, z1=1.18, trilha=True),
        c('q_cipo', 2.6),
        t('a_regias', 0.2, 5.0, 1, ('Ele está de volta:', 'O CLÁSSICO GÊNERO|DE PLATAFORMA'), z0=1.1, z1=1.16, trilha=True),
        t('javali', 0.3, 3.9, 1, 'O Javali-Rei guarda a trilha do bosque.', fixed=(.55, .52), z0=1.0, z1=1.05, trilha=True),
        t('a_colmeia', 0.0, 3.6, 2, 'Abaixe devagar... para não acordar a colmeia.', z0=1.1, z1=1.16, trilha=True),
        c('q_mergulho', 2.6),
        t('mergulho', 11.0, 4.2, 2, 'Mergulhe nas águas do pântano.', z0=1.05, z1=1.12, bias=(0, 0), trilha=True),
        t('bagre', 0.6, 4.0, 2, 'Lá no fundo, o Bagre-Rei espera.', fixed=(.6, .55), z0=1.0, z1=1.04, trilha=True),
        t('corda', 0.2, 3.8, 2, 'Chuva, sapos e cipós no pântano.', z0=1.1, z1=1.16, trilha=True),
        c('q_jangada', 2.6),
        t('jangada', 1.0, 4.0, 2, 'A correnteza leva a jangada rio abaixo.', z0=1.05, z1=1.12, trilha=True),
        c('q_neve', 2.6),
        t('bolaneve', 0.0, 4.4, 3, 'Neve: role bolas de neve gigantes.', z0=1.1, z1=1.16, trilha=True),
        t('cavalo', 0.6, 4.4, 3, 'Uma cavalgada pela trilha nevada.', fixed=(.36, .55), z0=1.0, z1=1.05, trilha=True),
        t('urso', 0.6, 4.4, 3, 'O Urso-Rei acorda na toca.', fixed=(.5, .55), z0=1.0, z1=1.05, trilha=True),
        t('vento', 2.0, 5.0, 3, ('Jogue no toque ou no controle:', '100% COMPATÍVEL|COM GAMEPAD', '🎮'), z0=1.1, z1=1.16, trilha=True),
        c('q_aviao', 2.6),
        t('voo', 18.0, 4.6, 3, 'De biplano, por cima das montanhas.', bias=(.05, .02), z0=1.0, z1=1.05, trilha=True),
        t('a_noite', 0.0, 4.6, 4, 'O dia vira noite enquanto você joga.', z0=1.05, z1=1.12, gm=1.15, trilha=True),
        t('a_noite', 4.6, 4.6, 4, ('Sem truques, só capricho:', 'O BÁSICO BEM FEITO.'), z0=1.1, z1=1.16, gm=1.2, trilha=True),
        c('q_mina', 2.8),
        t('a_tabuas', 0.2, 3.6, 5, 'E a trilha de cores segue para dentro da mina...', z0=1.1, z1=1.16, gm=1.45, trilha=True),
        c('final_simples', 5.4)]),
    'e2': ('janela', [
        c('ep2_abertura', 7.0), c('ep2_titulo', 3.2),
        t('e2_boca', 0.5, 4.6, 0, 'A trilha de cores desce pelas galerias da mina.', z0=1.1, z1=1.16, gm=1.35, trilha=True),
        t('e2_boca', 4.4, 4.2, 0, ('Ele está de volta:', 'O CLÁSSICO GÊNERO|DE PLATAFORMA'), z0=1.1, z1=1.16, gm=1.35, trilha=True),
        t('e2_estaca', 0.3, 4.4, 0, 'Mergulhe na estaca e a ponte desce sobre o veneno.', z0=1.1, z1=1.16, gm=1.35, trilha=True),
        t('e2_elevador', 0.6, 4.2, 0, 'Um elevador velho range até as galerias de cima.', z0=1.05, z1=1.12, gm=1.35, trilha=True),
        t('e2_degraus', 0.4, 4.0, 0, 'Pedra por pedra, sem pressa.', z0=1.1, z1=1.16, gm=1.35, trilha=True),
        t('e2_flor', 0.4, 4.8, 1, 'Lá fora, o vale do moinho ao entardecer.', z0=1.05, z1=1.12, trilha=True),
        t('e2_pedras', 0.3, 5.0, 1, 'Trigo, pedras no riacho e o moinho no alto do morro.', z0=1.05, z1=1.12, trilha=True),
        t('e2_moinho', 3.0, 5.4, 1, 'As pás voltam a girar... e levam o Tomé lá para cima.', z0=1.0, z1=1.05, trilha=True),
        t('e2_celeiro', 0.5, 4.2, 1, ('Jogue no toque ou no controle:', '100% COMPATÍVEL|COM GAMEPAD', '🎮'), z0=1.05, z1=1.1, trilha=True),
        t('e2_telhados1', 0.3, 4.8, 2, 'À noite, pelos telhados da vila dos mineiros.', z0=1.05, z1=1.1, gm=1.15, trilha=True),
        t('e2_telhados2', 0.3, 5.0, 2, ('Chaminés, fumaça e lua cheia:', 'O BÁSICO BEM FEITO.'), z0=1.05, z1=1.1, gm=1.15, trilha=True),
        t('e2_fundo', 0.3, 3.8, 3, 'E a trilha desce ainda mais fundo...', z0=1.1, z1=1.16, gm=1.45, trilha=True),
        c('ep2_isis', 6.4),
        t('e2_isis_quarto', 0.5, 2.6, 4, 'Agora é a vez dela: jogue com a Isis.', z0=1.2, z1=1.25, gm=1.3, trilha=True),
        t('e2_isis_poco', 0.6, 3.6, 4, 'Pequena e leve, ela passa por onde o pai não passa.', z0=1.2, z1=1.25, gm=1.3, trilha=True),
        t('e2_isis_corda', 0.5, 3.6, 4, 'E vai deixando lápis pelo caminho.', z0=1.2, z1=1.25, gm=1.3, trilha=True),
        t('e2_isis_corda', 6.0, 3.8, 4, None, z0=1.2, z1=1.25, gm=1.3, trilha=True),
        c('ep2_final', 5.4)]),
    'cC': ('cheia', [
        c('classico', 4.2),
        c('abertura', 4.6), c('sumiu', 2.4),
        t('a_escada', 2.6, 5.0, 0, 'Cada cenário desenhado com capricho.'),
        t('a_planar', 0.8, 4.4, 1, None),
        t('cogumelos', 2.0, 4.4, 4, 'Calma, detalhes e bons pulos.', gm=1.2),
        c('final_calmo', 5.0)]),
}


def dur(p):
    return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', p],
                                capture_output=True, text=True).stdout)


def montar(ver):
    global FASES, FASE_COR
    FASES, FASE_COR = (FASES2, COR2) if ver.startswith('e2') else (FASES1, COR1)
    layout, items = ROT[ver]
    files, segs, tt = [], [], 0.0
    for e in items:
        if e[0] == 'c':
            p = card(e[1], e[2])
            segs.append(('c', e[1], tt, None))
        else:
            _, seg, st, du, fase, frase, op = e
            p = tomada(seg, st, du, fase, layout, frase, **op)
            segs.append(('t', seg, tt, fase))
        d = dur(p)
        files.append(p)
        tt += d
        segs[-1] = segs[-1] + (tt,)
    lst = '/tmp/vid/clist_%s.txt' % ver
    open(lst, 'w').write(''.join("file '%s'\n" % f for f in files))
    mudo = '/tmp/vid/cmudo_%s.mp4' % ver
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', lst, '-c', 'copy', mudo], check=True)
    D = dur(mudo)
    first_t = next(s[2] for s in segs if s[0] == 't')
    t_tit = next((s[2] for s in segs if s[1] in ('titulo', 'ep2_titulo')), first_t - 1.0)
    noite_t = next((s[2] for s in segs if s[0] == 't' and s[3] >= 4), D)
    t_fim = next(s[2] for s in segs if 'final' in s[1])
    # música calma: noite no mistério -> manhã nas fases de dia -> noite no fim
    parts = [('mus_noite.ogg', 0, t_tit + .8, 1.2, 1.2, 1.0),
             ('mus_tema.ogg', t_tit, first_t + 1.5, .6, 1.6, .9)] if t_tit > 0.5 else []
    if not parts:  # cC: abre com a frase
        parts = [('mus_tema.ogg', 0, first_t + 1.5, .8, 1.6, .9),
                 ('mus_noite.ogg', next(s[2] for s in segs if s[1] == 'abertura'), first_t + .8, 1.0, 1.2, .8)]
    if ver.startswith('e2'):
        # uma música por fase, cruzando devagar na troca
        blocos, cur = [], None
        for s_ in segs:
            if s_[0] != 't':
                continue
            m = MUS2[s_[3]]
            if cur and cur[0] == m:
                cur[2] = s_[4]
            else:
                cur = [m, s_[2], s_[4]]
                blocos.append(cur)
        blocos[-1][2] = D
        for k, (m, a0, a1) in enumerate(blocos):
            parts.append(('mus_%s.ogg' % m, max(0, a0 - .8), a1 + (1.6 if k + 1 < len(blocos) else 0), 1.6,
                          2.4 if k + 1 < len(blocos) else 0, .95))
    else:
        parts += [('mus_manha.ogg', first_t, noite_t + 2.0, 1.4, 2.4, 1.0),
                  ('mus_noite.ogg', noite_t - .4, D, 2.0, 0, 1.0)]
    # sons de ambiente de cada fase, baixinho, entrando e saindo com a tomada
    for s in segs:
        if s[0] == 't':
            f, g = (AMB2 if ver.startswith('e2') else AMB)[s[3]]
            parts.append((f, s[2], s[4], .8, .8, g * .55))
            if s[3] == 2 and not ver.startswith('e2'):
                parts.append(('rain.wav', s[2], s[4], .8, .8, .35))
    ins, fc, labs = [], '', []
    for i, (f, a, b, fi, fo, gain) in enumerate(parts):
        ins += ['-stream_loop', '-1', '-i', A + f]
        L = max(.5, b - a)
        fc += ('[%d:a]aformat=sample_rates=44100:channel_layouts=stereo,atrim=0:%.3f,asetpts=PTS-STARTPTS,volume=%.2f,'
               'afade=t=in:st=0:d=%.2f%s,adelay=%d|%d[p%d];'
               % (i, L, gain, fi, (',afade=t=out:st=%.3f:d=%.2f' % (L - fo, fo)) if fo else '',
                  int(a * 1000), int(a * 1000), i))
        labs.append('[p%d]' % i)
    fc += ('%samix=inputs=%d:normalize=0,atrim=0:%.3f,afade=t=out:st=%.3f:d=2.5,volume=0.7,'
           'alimiter=limit=0.7:level=0[a]' % (''.join(labs), len(labs), D, D - 2.5))
    trilha = '/tmp/vid/ctrilha_%s.m4a' % ver
    subprocess.run(['ffmpeg', '-v', 'error', '-y'] + ins + ['-filter_complex', fc, '-map', '[a]', '-t', '%.3f' % D,
                                                            '-c:a', 'aac', '-b:a', '192k', trilha], check=True)
    out = '/tmp/vid/encontre-a_calmo_%s.mp4' % ver
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', mudo, '-i', trilha, '-c:v', 'copy', '-c:a', 'copy',
                    '-shortest', '-movflags', '+faststart', out], check=True)
    if D > 60.5:
        corte = next((s[2] for s in segs if s[0] == 't' and s[3] == (2 if ver.startswith('e2') else 3)), D / 2)
        if corte > 60 or D - corte > 60:  # escolhe o começo de tomada mais perto do meio
            cands = [s[2] for s in segs if s[2] > 5]
            corte = min(cands, key=lambda c_: abs(c_ - D / 2))
        for k, (a0, a1) in enumerate([(0, corte), (corte, D)]):
            pp = '/tmp/vid/encontre-a_calmo_%s_parte%d.mp4' % (ver, k + 1)
            fade = 'afade=t=in:st=0:d=0.6,' if k else ''
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', '%.3f' % a0, '-to', '%.3f' % a1, '-i', out,
                            '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p',
                            '-af', fade + 'afade=t=out:st=%.3f:d=1.2' % (a1 - a0 - 1.2), '-c:a', 'aac', '-b:a', '192k',
                            '-movflags', '+faststart', pp], check=True)
            print('  parte %d: %.1f s' % (k + 1, a1 - a0))
    ntom = sum(1 for s in segs if s[0] == 't')
    print(ver, 'duração %.1f · %d tomadas de jogo' % (D, ntom))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    V.VIG = V.vignette()
    for v in (sys.argv[1:] or ['cA', 'cB', 'cC']):
        montar(v)
