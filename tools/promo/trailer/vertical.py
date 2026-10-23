"""Versões verticais (1080x1920) do trailer, para status do WhatsApp.
  vA  Tela cheia  — 60 s, gameplay ocupando a tela, seguindo o Tomé, fase por fase
  vB  Moldura     — 60 s, gameplay num quadro grande com a trilha das 6 fases embaixo
  vC  Teaser      — 30 s, cortes rápidos, as 6 fases em sequência
Mesmo enredo: a Isis na varanda, a sombra, o sumiço, a trilha de lápis, quadrinhos e perguntas.
Ninguém revela quem levou a Isis.
Uso: python3 vertical.py [vA vB vC]  ->  /tmp/vid/encontre-a_vertical_<v>.mp4
Requer os trechos em /tmp/vid/hi (ver build.py)."""
import os, sys, math, subprocess, hashlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from build import load_pos, nframes, HI

R = '/home/claude/find-her-godot/'
OUT = '/tmp/vid/vseg/'
F = '/tmp/vid/fonts/'
A = R + 'assets/audio/'
W, H, FPS = 1080, 1920, 30
SW, SH = 2560, 1440
GOLD = (242, 210, 138)
CREAM = (240, 228, 200)
YEL = (255, 214, 77)
INK = (30, 15, 5)

FASES = ['MANHÃ', 'TARDE', 'PÂNTANO', 'NEVE', 'NOITE', 'MINA']
FASE_COR = [(150, 210, 120), (240, 160, 70), (110, 170, 140), (170, 210, 240), (150, 140, 230), (210, 170, 110)]
FASE_BG = ['assets/bg/bosque.jpg', 'assets/bg/tarde.jpg', 'assets/bg/pantano.jpg', 'assets/bg/neve.jpg',
           'assets/bg/noite.jpg', 'assets/bg/noite.jpg']

_fc = {}


def font(n, s):
    k = (n, s)
    if k not in _fc:
        _fc[k] = ImageFont.truetype(F + n + '.ttf', s)
    return _fc[k]


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def ramp(t, a, b, fade=.35):
    if t < a or t > b:
        return 0.0
    return min(ease((t - a) / fade), ease((b - t) / fade))


def cover(path, w=W, h=H, blur=0, dark=0.0):
    im = Image.open(path).convert('RGB')
    s = max(w / im.width, h / im.height)
    im = im.resize((math.ceil(im.width * s), math.ceil(im.height * s)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    im = im.crop((x, y, x + w, y + h))
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    if dark:
        im = Image.blend(im, Image.new('RGB', (w, h), (8, 6, 4)), dark)
    return im


def wrap(t, f, maxw):
    d = ImageDraw.Draw(Image.new('RGB', (1, 1)))
    out, cur = [], ''
    for w_ in t.split():
        n = (cur + ' ' + w_).strip()
        if d.textlength(n, font=f) > maxw and cur:
            out.append(cur)
            cur = w_
        else:
            cur = n
    if cur:
        out.append(cur)
    return out


def text_layer(items):
    """items: (texto, fonte, cor, y, contorno, largura_max) -> RGBA; quebra linhas centralizadas"""
    L = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    for it in items:
        t, f, c, y, st = it[:5]
        mw = it[5] if len(it) > 5 else 960
        lines = wrap(t, f, mw)
        lh = f.size * 1.22
        y0 = y - lh * (len(lines) - 1) / 2
        for i, ln in enumerate(lines):
            d.text((W / 2, y0 + i * lh), ln, font=f, fill=c, anchor='mm', stroke_width=st, stroke_fill=INK)
    return L


def over(base, layer, a):
    if a <= 0:
        return base
    if a < 1:
        layer = layer.copy()
        layer.putalpha(layer.getchannel('A').point(lambda v: int(v * a)))
    base = base.convert('RGBA')
    base.alpha_composite(layer)
    return base.convert('RGB')


def pill(t, size=40, fill=(14, 10, 6, 205), color=(245, 235, 210), fnt='Lora-Italic', maxw=920, pad=34):
    f = font(fnt, size)
    lines = wrap(t, f, maxw - 2 * pad)
    d0 = ImageDraw.Draw(Image.new('RGB', (1, 1)))
    tw = max(d0.textlength(l, font=f) for l in lines) + 2 * pad
    lh = int(size * 1.25)
    th = lh * len(lines) + 30
    im = Image.new('RGBA', (int(tw), th), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, tw - 1, th - 1], 22, fill=fill)
    for i, l in enumerate(lines):
        d.text((tw / 2, 15 + lh * i + lh / 2), l, font=f, fill=color, anchor='mm')
    return im


def paste_a(base, im, xy, a=1.0):
    if a <= 0:
        return
    if a < 1:
        im = im.copy()
        im.putalpha(im.getchannel('A').point(lambda v: int(v * a)))
    base.alpha_composite(im, (int(xy[0]), int(xy[1])))


def vignette():
    v = Image.new('L', (W, H), 0)
    ImageDraw.Draw(v).ellipse([-W * .45, -H * .2, W * 1.45, H * 1.2], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(160))
    blk = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    blk.putalpha(v.point(lambda p: int((255 - p) * .75)))
    return blk


VIG = None


def writer(path):
    return subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H),
                             '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '19',
                             '-pix_fmt', 'yuv420p', '-r', str(FPS), path], stdin=subprocess.PIPE)


def render(path, dur, frame, fi=.25, fo=.25):
    if os.path.exists(path):
        return path
    p = writer(path)
    n = int(round(dur * FPS))
    for i in range(n):
        t = i / FPS
        im = frame(t)
        k = min(1.0, ease(t / fi) if fi else 1, ease((dur - t) / fo) if fo else 1)
        if k < 1:
            im = Image.blend(Image.new('RGB', (W, H)), im, k)
        p.stdin.write(im.tobytes())
    p.stdin.close()
    p.wait()
    print('  ', os.path.basename(path), dur)
    return path


def framed_panel(path, side, rot):
    p = Image.open(path).convert('RGB').resize((side, side), Image.LANCZOS)
    fr = Image.new('RGBA', (side + 24, side + 24), (250, 245, 230, 255))
    fr.paste(p, (12, 12))
    ImageDraw.Draw(fr).rectangle([12, 12, side + 11, side + 11], outline=(20, 15, 10), width=5)
    sh = Image.new('RGBA', fr.size, (0, 0, 0, 130))
    return fr.rotate(rot, expand=True, resample=Image.BICUBIC), sh.rotate(rot, expand=True)


def balloon(t):
    return pill(t, 42, (255, 243, 207, 255), (40, 26, 12), 'Lora-Italic', 940)


# ======================================================== cartelas verticais
def c_abertura(dur):
    src = Image.open(R + 'assets/ui/cena1.jpg').convert('RGB')  # 1376x768
    t1 = text_layer([('Toda tarde, a Isis desenhava na varanda...', font('Lora-Italic', 56), CREAM, 1380, 3, 900)])
    t2 = text_layer([('Até que, numa dessas tardes...', font('Lora-Italic', 56), CREAM, 1380, 3, 900)])
    band = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)
    for yy in range(1100, 1700):
        a = int(170 * min(1, (yy - 1100) / 200) * min(1, (1700 - yy) / 200))
        bd.line([(0, yy), (W, yy)], fill=(0, 0, 0, a))
    split = dur * .45

    def fr(t):
        k = ease(t / dur)
        ch = 760 - 120 * k
        cw = ch * W / H
        x0, x1 = 300, 1376 - cw - 140
        x = x0 + (x1 - x0) * ease((t - split * .8) / (dur - split * .8 - .4))
        y = 8 + 70 * k
        im = src.crop((int(x), int(y), int(x + cw), int(y + ch))).resize((W, H), Image.LANCZOS)
        dk = .4 * ease((t - (dur - 1.6)) / 1.4)
        if dk:
            im = Image.blend(im, Image.new('RGB', (W, H)), dk)
        im = over(im, VIG, 1)
        im = over(im, band, 1)
        im = over(im, t1, ramp(t, .4, split))
        im = over(im, t2, ramp(t, split + .3, dur - .15))
        return im
    return fr


def c_sumiu(dur):
    L = text_layer([('Na manhã seguinte, ela tinha sumido.', font('Lora-Italic', 64), CREAM, 880, 0, 900)])
    L2 = text_layer([('Ninguém viu quem a levou.', font('Lora-Italic', 46), (190, 178, 160), 1060, 0, 900)])

    def fr(t):
        im = Image.new('RGB', (W, H), (6, 4, 3))
        im = over(im, L, ramp(t, .1, dur - .05))
        im = over(im, L2, ramp(t, dur * .35, dur - .05))
        return im
    return fr


def c_titulo(dur):
    base = cover(R + 'assets/bg/bosque.jpg', int(W * 1.08), int(H * 1.04), 7, .5)
    L = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 128), GOLD, 860, 6)])
    L2 = text_layer([('EPISÓDIO 1 · O BOSQUE', font('Cinzel-Bold', 54), (232, 201, 138), 990, 4)])

    def fr(t):
        ox = int(W * .08 * ease(t / dur))
        im = base.crop((ox, 30, ox + W, 30 + H))
        im = over(im, VIG, 1)
        im = over(im, L, ease((t - .1) / .6))
        im = over(im, L2, ease((t - .6) / .6))
        return im
    return fr


def c_pergunta(txt, bg):
    def mk(dur):
        base = cover(R + bg, blur=12, dark=.8)
        L = text_layer([(txt, font('Cinzel-Bold', 104), YEL, 920, 6, 940)])

        def fr(t):
            s = 1 + .04 * t / dur
            lay = L.resize((int(W * s), int(H * s)), Image.LANCZOS)
            ox, oy = (lay.width - W) // 2, (lay.height - H) // 2
            return over(base, lay.crop((ox, oy, ox + W, oy + H)), ramp(t, .05, dur - .02, .25))
        return fr
    return mk


def c_quadro(comic, bg, cap):
    def mk(dur):
        base = cover(R + bg, blur=11, dark=.6)
        fr_, sh = framed_panel(R + 'assets/comic/%s.jpg' % comic, 860, -2)
        bl = balloon(cap)

        def fr(t):
            im = base.convert('RGBA')
            im.alpha_composite(VIG)
            k = ease(t / .3)
            s = .86 + .14 * k + .03 * t / dur
            p = fr_.resize((int(fr_.width * s), int(fr_.height * s)), Image.LANCZOS)
            cx, cy = W // 2, 860 + int(30 * (1 - k))
            im.alpha_composite(sh.resize(p.size), (cx - p.width // 2 + 12, cy - p.height // 2 + 14))
            im.alpha_composite(p, (cx - p.width // 2, cy - p.height // 2))
            paste_a(im, bl, (W // 2 - bl.width // 2, 1390), ease((t - .3) / .25))
            return im.convert('RGB')
        return fr
    return mk


def c_pista(dur):
    base = cover(R + 'assets/bg/tarde.jpg', blur=9, dark=.62)
    at1 = Image.open(R + 'assets/sprites/atlas1.png').convert('RGBA')
    at2 = Image.open(R + 'assets/sprites/atlas2.png').convert('RGBA')
    draw = at1.crop((1652, 432, 1712, 496)).resize((330, 352), Image.LANCZOS)
    cols = [1108, 1128, 1148, 1167, 1187, 1206]
    pens = [at2.crop((x, 641, x + 18, 685)).resize((56, 137), Image.LANCZOS) for x in cols]
    pts = [(150 + int(330 * (.5 + .5 * math.sin(i * 1.1))) + 150 * (i % 2), 1300 - i * 95) for i in range(8)]
    L = text_layer([('Só ficou uma trilha de lápis de cor...', font('Lora-Italic', 52), CREAM, 1470, 3, 990)])
    L2 = text_layer([('Cada lápis é uma pista.', font('Lora-Italic', 46), (225, 212, 185), 1590, 2, 920)])

    def fr(t):
        im = base.convert('RGBA')
        im.alpha_composite(VIG)
        for j, (x, y) in enumerate(pts):
            k = ease((t - .1 * j) / .25)
            if k <= 0:
                continue
            p = pens[j % 6].rotate(-30 + 20 * math.sin(j * 1.7), expand=True, resample=Image.BICUBIC)
            paste_a(im, p, (x - p.width // 2, y - int(50 * (1 - k)) - p.height // 2), k)
        k = ease((t - .9) / .35)
        if k > 0:
            d = draw.rotate(6, expand=True, resample=Image.BICUBIC)
            s = .7 + .3 * k
            d = d.resize((int(d.width * s), int(d.height * s)), Image.LANCZOS)
            im.alpha_composite(d, (W // 2 - d.width // 2, 440 - d.height // 2))
        im = im.convert('RGB')
        im = over(im, L, ease((t - .3) / .35))
        im = over(im, L2, ease((t - .9) / .35))
        return im
    return fr


def c_fases(dur):
    """mapa da jornada: as 6 fases acendendo em sequência"""
    base = cover(R + 'assets/bg/neve.jpg', blur=12, dark=.72)
    L = text_layer([('A JORNADA', font('Cinzel-Bold', 70), YEL, 470, 4)])

    def fr(t):
        im = over(base, VIG, 1).convert('RGBA')
        im = over(im.convert('RGB'), L, ease(t / .4)).convert('RGBA')
        d = ImageDraw.Draw(im)
        for i, n in enumerate(FASES):
            k = ease((t - .25 - .22 * i) / .25)
            y = 640 + i * 150
            if i:
                d.line([(W // 2, y - 150 + 34), (W // 2, y - 34)], fill=(230, 220, 200, int(180 * k)), width=5)
            if k <= 0:
                continue
            c = FASE_COR[i]
            d.ellipse([W // 2 - 300 - 30, y - 30, W // 2 - 300 + 30, y + 30], fill=c + (int(255 * k),))
            d.text((W // 2 - 300, y), str(i + 1), font=font('Cinzel-Bold', 38), fill=(20, 12, 5, int(255 * k)), anchor='mm')
            d.text((W // 2 - 230, y), n, font=font('Cinzel-Bold', 64), fill=c + (int(255 * k),), anchor='lm',
                   stroke_width=3, stroke_fill=INK)
        return im.convert('RGB')
    return fr


def c_final(dur):
    base = cover(R + 'assets/bg/noite.jpg', int(W * 1.06), int(H * 1.03), 6, .58)
    A_ = text_layer([('Siga a trilha.', font('Lora-Italic', 70), CREAM, 880, 3)])
    B = text_layer([('QUEM LEVOU A ISIS?', font('Cinzel-Bold', 104), YEL, 920, 6, 960)])
    Cc = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 124), GOLD, 760, 6),
                     ('EPISÓDIO 1 · O BOSQUE', font('Cinzel-Bold', 54), (232, 201, 138), 880, 4)])
    D = text_layer([('A seguir: EPISÓDIO 2', font('Lora-Bold', 46), (255, 214, 120), 1120, 2),
                    ('As Profundezas da Mina', font('Lora-Bold', 46), (255, 214, 120), 1185, 2),
                    ('Para Android', font('Lora-Italic', 42), (225, 215, 195), 1320, 0)])
    a1, a2 = dur * .2, dur * .45

    def fr(t):
        ox = int(W * .06 * t / dur)
        im = base.crop((ox, 20, ox + W, 20 + H))
        im = over(im, VIG, 1)
        im = over(im, A_, ramp(t, .1, a1))
        im = over(im, B, ramp(t, a1 + .1, a2))
        im = over(im, Cc, ease((t - a2 - .15) / .5))
        im = over(im, D, ease((t - a2 - .6) / .5))
        return im
    return fr


CARDS = {
    'abertura': c_abertura, 'sumiu': c_sumiu, 'titulo': c_titulo, 'pista': c_pista, 'fases': c_fases,
    'final': c_final,
    'p_quem': c_pergunta('QUEM A LEVOU?', 'assets/bg/tarde.jpg'),
    'p_onde': c_pergunta('PARA ONDE?', 'assets/bg/pantano.jpg'),
    'p_porque': c_pergunta('E POR QUÊ?', 'assets/bg/noite.jpg'),
    'q_cipo': c_quadro('cipo', 'assets/bg/bosque.jpg', 'Um lápis lá no alto... ela passou por aqui!'),
    'q_toxico': c_quadro('toxico', 'assets/bg/pantano.jpg', 'Essa água... alguém envenenou o brejo?'),
    'q_neve': c_quadro('neve', 'assets/bg/neve.jpg', 'Brrr... aguenta firme, Isis!'),
    'q_pipoca': c_quadro('pipoca', 'assets/bg/neve.jpg', 'Pipoca! Você sentiu o cheiro dela?'),
    'q_aviao': c_quadro('aviao_b', 'assets/bg/neve.jpg', 'Daqui de cima eu vejo a mina!'),
    'q_mina': c_quadro('mina', 'assets/bg/noite.jpg', 'Escuro demais... ainda bem que eu trouxe a lanterna.'),
}


def card(name, dur):
    path = OUT + 'c_%s_%.2f.mp4' % (name, dur)
    fi = .5 if name == 'abertura' else .15
    fo = .8 if name == 'final' else .2
    return render(path, dur, CARDS[name](dur), fi, fo)


# ======================================================== trechos de jogo verticais
def vclip(seg, st, du, fase, layout, z=1.0, cap=None, gm=None, stamp=False, fixed=None, bias=(0, .03)):
    key = repr((seg, st, du, fase, layout, z, cap, gm, stamp, fixed, bias))
    path = OUT + 'g_%s_%s.mp4' % (seg, hashlib.md5(key.encode()).hexdigest()[:8])
    if os.path.exists(path):
        return path
    avi = HI + seg + '.avi'
    n = nframes(avi)
    pos = load_pos(seg, n)
    s0 = int(st * FPS)
    cnt = int(round(du * FPS))
    dec = subprocess.Popen(['ffmpeg', '-v', 'error', '-ss', str(st), '-i', avi, '-frames:v', str(cnt),
                            '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
    enc = writer(path)
    capim = pill(cap, 44) if cap else None
    fcol = FASE_COR[fase]
    tag = pill('%d · %s' % (fase + 1, FASES[fase]), 40, (14, 10, 6, 190), fcol, 'Cinzel-Bold')
    big = text_layer([(FASES[fase], font('Cinzel-Bold', 140), fcol, 960, 7)])
    logo = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 64), GOLD, 330, 4)])
    last = None
    for i in range(cnt):
        buf = dec.stdout.read(SW * SH * 3)
        im = Image.frombytes('RGB', (SW, SH), buf) if len(buf) == SW * SH * 3 else last
        last = im
        u, v = fixed or pos[min(n - 1, s0 + i)]
        cx = u * SW + bias[0] * SW
        cy = v * SH + bias[1] * SH
        if layout == 'cheia':
            ch = SH / z
            cw = ch * W / H
            x = min(max(cx - cw / 2, 0), SW - cw)
            y = min(max(cy - ch / 2, 0), SH - ch)
            fr = im.crop((int(x), int(y), int(x + cw), int(y + ch))).resize((W, H), Image.LANCZOS)
            if gm:
                fr = fr.point(lambda p: int(255 * (p / 255) ** (1 / gm)))
            fr = fr.convert('RGBA')
            paste_a(fr, tag, (W // 2 - tag.width // 2, 250))
        else:  # moldura: quadro 1080x1080 no meio, fundo desfocado, trilha das fases embaixo
            s = SH / z
            x = min(max(cx - s / 2, 0), SW - s)
            y = min(max(cy - s / 2, 0), SH - s)
            sq = im.crop((int(x), int(y), int(x + s), int(y + s))).resize((W, W), Image.LANCZOS)
            bgw = im.resize((SW // 8, SH // 8)).crop((SW // 16 - 50, 0, SW // 16 + 51, SH // 8))
            bg = bgw.filter(ImageFilter.GaussianBlur(6)).resize((W, H), Image.BILINEAR)
            bg = Image.blend(bg, Image.new('RGB', (W, H)), .55)
            if gm:
                sq = sq.point(lambda p: int(255 * (p / 255) ** (1 / gm)))
            fr = bg.convert('RGBA')
            fr.alpha_composite(logo)
            paste_a(fr, tag, (W // 2 - tag.width // 2, 400))
            fr.paste(sq, (0, 500))
            d = ImageDraw.Draw(fr)
            d.line([(0, 500), (W, 500)], fill=fcol + (255,), width=4)
            d.line([(0, 1579), (W, 1579)], fill=fcol + (255,), width=4)
            # trilha das fases
            xs = [110 + k * 172 for k in range(6)]
            yy = 1660
            for k in range(5):
                d.line([(xs[k] + 22, yy), (xs[k + 1] - 22, yy)], fill=(200, 190, 170, 200) if k < fase else (90, 85, 80, 200), width=5)
            for k, xk in enumerate(xs):
                on = k <= fase
                r = 26 if k == fase else 18
                c = FASE_COR[k] if on else (90, 85, 80)
                d.ellipse([xk - r, yy - r, xk + r, yy + r], fill=c + (255,), outline=(20, 12, 5, 255), width=3)
                d.text((xk, yy + 52), FASES[k], font=font('Cinzel-Bold', 30 if k == fase else 24),
                       fill=(c if on else (120, 115, 108)) + (255,), anchor='mm')
        if capim:
            a = min(1.0, ease((i - 3) / 6), ease((cnt - 3 - i) / 6))
            yc = 1420 if layout == 'cheia' else 1460
            if layout != 'cheia':
                yc = 1590 - capim.height - 26
            paste_a(fr, capim, (W // 2 - capim.width // 2, yc), a)
        if stamp:
            a = ramp(i / FPS, 0, 1.0, .2)
            if a > 0:
                fr = over(fr.convert('RGB'), big, a).convert('RGBA')
        fr = fr.convert('RGB')
        k = min(1.0, ease(i / 4), ease((cnt - 1 - i) / 4))
        if k < 1:
            fr = Image.blend(Image.new('RGB', (W, H)), fr, k)
        enc.stdin.write(fr.tobytes())
    dec.stdout.close()
    dec.wait()
    enc.stdin.close()
    enc.wait()
    print('  ', seg, du, layout)
    return path


# ======================================================== roteiros
# cenas: (seg, início, duração, fase, legenda, opções)
def g(seg, st, du, fase, cap=None, **op):
    return ('g', seg, st, du, fase, cap, op)


def c(name, du):
    return ('c', name, du)


MANHA = [g('a_inicio', 0.3, 2.0, 0, 'Só ficou uma trilha de lápis de cor...'),
         g('a_inicio', 2.4, 1.8, 0, 'Rasteje sob as toras'),
         g('a_inicio', 4.5, 1.8, 0, None),
         g('a_estaca', 0.3, 3.0, 0, 'Mergulhe na estaca e baixe a ponte'),
         g('a_escada', 7.0, 2.0, 0, 'Desça as escadas da casa na árvore')]
TARDE = [g('a_galho', 0.2, 2.0, 1, 'Pulo duplo até o galho alto'),
         g('a_galho', 3.4, 1.8, 1, 'Balance no cipó'),
         g('a_chao', 0.6, 3.0, 1, 'O mergulho racha o chão!'),
         g('flor', 0.6, 1.8, 1, 'Flores-catapulta'),
         g('a_planar', 1.0, 2.6, 1, 'Infle e flutue sobre o bosque'),
         g('a_regias', 0.3, 2.6, 1, 'Pule nas vitórias-régias')]
PANTANO = [g('a_colmeia', 0.0, 2.6, 2, 'Abaixe para não acordar a colmeia'),
           g('a_colmeia', 3.4, 2.0, 2, "Mergulhe pelos túneis d'água", bias=(0, 0)),
           g('regias', 7.6, 2.6, 2, 'De cipó em cipó sobre o lamaçal'),
           g('corda', 1.4, 2.0, 2, 'Pendurado na corda'),
           g('jangada', 1.5, 2.0, 2, 'Desça a correnteza de jangada')]
NEVE = [g('bolaneve', 1.5, 2.0, 3, 'Empurre bolas de neve gigantes'),
        g('cavalo', 2.2, 2.0, 3, 'Cavalgada pela trilha nevada', fixed=(.55, .6)),
        g('ponte', 1.0, 1.8, 3, 'A ponte está se soltando!'),
        g('urso', 0.8, 1.6, 3, None),
        g('voo', 19.0, 2.2, 3, 'Voe de biplano até a mina', fixed=(.45, .5))]
NOITE = [g('a_noite', 0.2, 2.0, 4, 'Passe pelo machado na hora certa', gm=1.2),
         g('a_noite', 4.4, 3.0, 4, 'Cogumelos saltadores!', gm=1.2),
         g('a_noite', 8.0, 2.6, 4, None, gm=1.2)]
MINA = [g('a_tabuas', 0.3, 2.4, 5, 'Tábuas podres sobre o abismo', gm=1.45),
        g('pedra', 26.0, 1.6, 5, 'Fuja da pedra gigante!', gm=1.5, bias=(-.08, .03)),
        g('pedra', 33.4, 2.0, 5, 'Abaixe no buraco... e deixe passar!', gm=1.5, bias=(-.04, .03))]


def pick(lst, idx, durs=None, caps=True):
    out = []
    for j, i in enumerate(idx):
        e = lst[i]
        d = durs[j] if durs else e[3]
        out.append(e[:3] + (d, e[4], e[5] if caps else None, e[6]))
    return out


def stamp_first(lst):
    """marca a primeira cena de cada fase com o nome grande da fase"""
    return [lst[0][:6] + (dict(lst[0][6], stamp=True),)] + lst[1:]


V = {
    'vA': ('cheia', 60.0,
           [c('abertura', 5.6), c('sumiu', 2.4), c('titulo', 2.4)]
           + stamp_first(pick(MANHA, [0, 1, 3, 4]))
           + [c('q_cipo', 1.6)]
           + stamp_first(pick(TARDE, [0, 2, 4, 5]))
           + [c('p_quem', 1.2)]
           + stamp_first(pick(PANTANO, [0, 1, 2]))
           + [c('q_toxico', 1.6)]
           + stamp_first(pick(NEVE, [0, 1, 2, 4]))
           + [c('p_onde', 1.2)]
           + stamp_first(pick(NOITE, [0, 1]))
           + [c('q_mina', 1.7)]
           + stamp_first(pick(MINA, [0, 1, 2]))
           + [c('p_porque', 1.2), c('final', 4.8)]),
    'vB': ('moldura', 60.0,
           [c('abertura', 5.6), c('sumiu', 2.4), c('titulo', 2.2), c('fases', 2.4)]
           + pick(MANHA, [0, 3, 4, 2]) + [c('q_cipo', 1.6)]
           + pick(TARDE, [0, 1, 2, 4]) + [c('p_quem', 1.2)]
           + pick(PANTANO, [0, 1, 2, 4]) + [c('q_pipoca', 1.6)]
           + pick(NEVE, [1, 2, 3, 4]) + [c('p_onde', 1.2)]
           + pick(NOITE, [0, 1, 2])
           + pick(MINA, [0, 1, 2]) + [c('p_porque', 1.2), c('final', 4.8)]),
    'vC': ('cheia', 30.0,
           [c('abertura', 3.6), c('sumiu', 1.7), c('titulo', 1.7)]
           + stamp_first(pick(MANHA, [3, 0], [1.6, 1.0]))
           + stamp_first(pick(TARDE, [2, 4], [1.5, 1.4]))
           + stamp_first(pick(PANTANO, [0, 2], [1.4, 1.3]))
           + [c('p_quem', 1.0)]
           + stamp_first(pick(NEVE, [1, 4], [1.3, 1.3]))
           + stamp_first(pick(NOITE, [1], [1.8]))
           + stamp_first(pick(MINA, [1, 2], [1.2, 1.3]))
           + [c('final', 3.6)]),
}


def dur(p):
    return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', p],
                                capture_output=True, text=True).stdout)


def fit(ver):
    layout, alvo, items = V[ver]
    cards = sum(e[2] for e in items if e[0] == 'c')
    gs = [e for e in items if e[0] == 'g']
    tg = alvo - cards
    f = tg / sum(e[3] for e in gs)
    out = []
    for e in items:
        if e[0] == 'g':
            out.append(e[:3] + (round(max(1.0, e[3] * f) * 30) / 30,) + e[4:])
        else:
            out.append(e)
    print(ver, layout, 'cartelas %.1f s · jogo %.1f s · fator %.2f · %d cenas' % (cards, tg, f, len(gs)))
    return layout, out


def montar(ver):
    layout, items = fit(ver)
    files, marks, t = [], {}, 0.0
    for e in items:
        if e[0] == 'c':
            p = card(e[1], e[2])
            marks.setdefault(e[1], t)
        else:
            _, seg, st, du, fase, cap, op = e
            p = vclip(seg, st, du, fase, layout, 1.0 if layout == 'cheia' else 1.25, cap,
                      op.get('gm'), op.get('stamp', False), op.get('fixed'), op.get('bias', (0, .03)))
        files.append(p)
        t += dur(p)
    lst = '/tmp/vid/vlist_%s.txt' % ver
    open(lst, 'w').write(''.join("file '%s'\n" % f for f in files))
    mudo = '/tmp/vid/vmudo_%s.mp4' % ver
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', lst, '-c', 'copy', mudo], check=True)
    D = dur(mudo)
    t_tit = marks['titulo']
    t_jogo = t_tit + 1.6
    t_fim = marks['final']
    parts = [('mus_noite.ogg', 0, t_tit + .5, 1.0, .9),
             ('mus_tema.ogg', t_tit, t_jogo + 1.0, .3, 1.0),
             ('mus_perseguicao.ogg', t_jogo, t_fim + 1.0, .8, 1.4),
             ('mus_noite.ogg', t_fim - .5, D, 1.0, 0)]
    ins, fc, labs = [], '', []
    for i, (f, a, b, fi, fo) in enumerate(parts):
        ins += ['-stream_loop', '4', '-i', A + f]
        L = b - a
        fc += ('[%d:a]atrim=0:%.3f,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=%.2f%s,adelay=%d|%d[p%d];'
               % (i, L, fi, (',afade=t=out:st=%.3f:d=%.2f' % (L - fo, fo)) if fo else '', int(a * 1000), int(a * 1000), i))
        labs.append('[p%d]' % i)
    fc += '%samix=inputs=%d:normalize=0,atrim=0:%.3f,afade=t=out:st=%.3f:d=2.0,volume=0.72,alimiter=limit=0.75:level=0[a]' % (
        ''.join(labs), len(labs), D, D - 2.0)
    trilha = '/tmp/vid/vtrilha_%s.m4a' % ver
    subprocess.run(['ffmpeg', '-v', 'error', '-y'] + ins + ['-filter_complex', fc, '-map', '[a]', '-c:a', 'aac',
                                                            '-b:a', '192k', trilha], check=True)
    out = '/tmp/vid/encontre-a_vertical_%s.mp4' % ver
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', mudo, '-i', trilha, '-c:v', 'copy', '-c:a', 'copy',
                    '-shortest', '-movflags', '+faststart', out], check=True)
    print(ver, 'duração %.1f' % D)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    VIG = vignette()
    a = sys.argv[1:]
    if a and a[0] == 'cards':
        for n in a[1:]:
            card(n, 3.0)
    else:
        for v in (a or ['vA', 'vB', 'vC']):
            montar(v)
