"""Cartelas animadas do trailer de 1min30 (Encontre-a · Episódio 1).
Cada cartela vira um .mp4 1280x720 30fps em /tmp/vid/seg2/.
Uso: python3 cards.py [nome ...]   (sem nomes = todas)
Nada aqui mostra ou cita quem levou a Isis."""
import sys, subprocess, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

R = '/home/claude/find-her-godot/'
OUT = '/tmp/vid/seg2/'
F = '/tmp/vid/fonts/'
W, H, FPS = 1280, 720, 30
GOLD = (242, 210, 138)
CREAM = (240, 228, 200)
YEL = (255, 214, 77)
INK = (30, 15, 5)


def font(n, s):
    return ImageFont.truetype(F + n + '.ttf', s)


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def ramp(t, a, b, fade=.45):
    """opacidade 0..1: entra em a, sai em b"""
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


def text_layer(lines):
    """lines: [(texto, fonte, cor, y, contorno)] -> RGBA"""
    L = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    for t, f, c, y, st in lines:
        d.text((W / 2, y), t, font=f, fill=c, anchor='mm', stroke_width=st, stroke_fill=INK)
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


def vignette():
    v = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(v)
    d.ellipse([-W * .25, -H * .35, W * 1.25, H * 1.35], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(140))
    blk = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    blk.putalpha(v.point(lambda p: int((255 - p) * .8)))
    return blk


VIG = None
BAND = None


def writer(name, dur):
    p = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H),
                          '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
                          '-pix_fmt', 'yuv420p', '-r', str(FPS), OUT + name + '.mp4'], stdin=subprocess.PIPE)
    n = int(round(dur * FPS))
    return p, n


def render(name, dur, frame, fade_in=.3, fade_out=.3):
    p, n = writer(name, dur)
    for i in range(n):
        t = i / FPS
        im = frame(t)
        k = min(1.0, ease(t / fade_in) if fade_in else 1, ease((dur - t) / fade_out) if fade_out else 1)
        if k < 1:
            im = Image.blend(Image.new('RGB', (W, H)), im, k)
        p.stdin.write(im.tobytes())
    p.stdin.close()
    p.wait()
    print(name, dur)


def framed_panel(path, side, rot):
    p = Image.open(path).convert('RGB').resize((side, side), Image.LANCZOS)
    fr = Image.new('RGBA', (side + 20, side + 20), (250, 245, 230, 255))
    fr.paste(p, (10, 10))
    ImageDraw.Draw(fr).rectangle([10, 10, side + 9, side + 9], outline=(20, 15, 10), width=4)
    sh = Image.new('RGBA', fr.size, (0, 0, 0, 130))
    return fr.rotate(rot, expand=True, resample=Image.BICUBIC), sh.rotate(rot, expand=True)


def balloon(t):
    """caixa de legenda de quadrinho (RGBA do tamanho do texto)"""
    f = font('Lora-Italic', 30)
    tw = int(ImageDraw.Draw(Image.new('RGB', (1, 1))).textlength(t, font=f)) + 60
    b = Image.new('RGBA', (tw, 62), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    d.rounded_rectangle([0, 0, tw - 1, 61], 12, fill=(255, 243, 207), outline=(30, 20, 10), width=3)
    d.text((tw / 2, 31), t, font=f, fill=(40, 26, 12), anchor='mm')
    return b


# ---------------------------------------------------------------- cartelas
def abertura():
    """Isis desenhando na varanda; a câmera desliza até a sombra."""
    src = Image.open(R + 'assets/ui/cena1.jpg').convert('RGB')
    s = 820 / src.height
    big = src.resize((int(src.width * s), 820), Image.LANCZOS)  # 1469x820
    t1 = text_layer([('Toda tarde, a Isis desenhava na varanda...', font('Lora-Italic', 40), CREAM, 640, 3)])
    t2 = text_layer([('Até que, numa dessas tardes...', font('Lora-Italic', 40), CREAM, 640, 3)])
    dur = 8.0

    def fr(t):
        k = ease(t / dur)
        cw = 940 - 90 * k
        ch = cw * H / W
        # janela que vai da Isis (esquerda) para a sombra (direita)
        x0, x1 = 40, big.width - cw - 5
        x = x0 + (x1 - x0) * ease((t - 3.2) / 4.2)
        y = 150 + 120 * k
        im = big.crop((int(x), int(y), int(x + cw), int(y + ch))).resize((W, H), Image.LANCZOS)
        dk = .45 * ease((t - 6.0) / 2.0)
        if dk:
            im = Image.blend(im, Image.new('RGB', (W, H)), dk)
        im = over(im, VIG, 1)
        im = over(im, BAND, 1)
        im = over(im, t1, ramp(t, .6, 3.4))
        im = over(im, t2, ramp(t, 4.2, 7.6))
        return im
    render('abertura', dur, fr, .8, .25)


def sumiu():
    L = text_layer([('Quando o pai chegou, ela já não estava lá.', font('Lora-Italic', 46), CREAM, 330, 0)])
    L2 = text_layer([('Ninguém viu quem a levou.', font('Lora-Italic', 34), (190, 178, 160), 400, 0)])

    def fr(t):
        im = Image.new('RGB', (W, H), (6, 4, 3))
        im = over(im, L, ramp(t, .2, 3.6))
        im = over(im, L2, ramp(t, 1.4, 3.6))
        return im
    render('sumiu', 3.8, fr, 0, .2)


def titulo(name='titulo', bg='assets/bg/bosque.jpg', dur=4.2):
    base = cover(R + bg, int(W * 1.1), int(H * 1.1), 6, .5)
    L = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 128), GOLD, 300, 6)])
    L2 = text_layer([('EPISÓDIO 1 · O BOSQUE', font('Cinzel-Bold', 42), (232, 201, 138), 410, 3)])

    def fr(t):
        k = ease(t / dur)
        ox = int(W * .1 * k * .6)
        im = base.crop((ox, 30, ox + W, 30 + H))
        im = over(im, VIG, 1)
        im = over(im, L, ease((t - .2) / .9))
        im = over(im, L2, ease((t - 1.0) / .9))
        return im
    render(name, dur, fr, .35, .4)


def pergunta(name, txt, sub='', dur=2.0, bg=None):
    base = cover(R + bg, blur=10, dark=.82) if bg else Image.new('RGB', (W, H), (6, 4, 3))
    L = text_layer([(txt, font('Cinzel-Bold', 76), YEL, 340, 5)])
    L2 = text_layer([(sub, font('Lora-Italic', 34), CREAM, 430, 2)]) if sub else None

    def fr(t):
        s = 1 + .03 * t / dur
        lay = L.resize((int(W * s), int(H * s)), Image.LANCZOS).crop(
            (int(W * (s - 1) / 2), int(H * (s - 1) / 2), int(W * (s - 1) / 2) + W, int(H * (s - 1) / 2) + H))
        im = over(base, lay, ramp(t, .1, dur - .05, .35))
        if L2:
            im = over(im, L2, ramp(t, .5, dur - .05, .35))
        return im
    render(name, dur, fr, .2, .25)


def quadro(name, comic, bg, cap, dur=2.2, side=470, rot=-2):
    base = cover(R + bg, blur=9, dark=.6)
    fr_, sh = framed_panel(R + 'assets/comic/%s.jpg' % comic, side, rot)
    bl = balloon(cap) if cap else None

    def fr(t):
        im = base.convert('RGBA')
        im.alpha_composite(VIG)
        k = ease(t / .35)
        s = .86 + .14 * k + .03 * t / dur
        p = fr_.resize((int(fr_.width * s), int(fr_.height * s)), Image.LANCZOS)
        q = sh.resize(p.size)
        cx, cy = W // 2, 325 + int(20 * (1 - k))
        im.alpha_composite(q, (cx - p.width // 2 + 10, cy - p.height // 2 + 12))
        im.alpha_composite(p, (cx - p.width // 2, cy - p.height // 2))
        if bl:
            a = ease((t - .35) / .3)
            if a > 0:
                b = bl.copy()
                b.putalpha(b.getchannel('A').point(lambda v: int(v * a)))
                im.alpha_composite(b, (W // 2 - b.width // 2, 640 - 31))
        return im.convert('RGB')
    render(name, dur, fr, .15, .2)


def trio(name, comics, bg, title, cap, dur=2.8):
    """três quadrinhos entrando em sequência (chefes, rapidinho)"""
    base = cover(R + bg, blur=9, dark=.62)
    pans = [framed_panel(R + 'assets/comic/%s.jpg' % c, 330, r) for c, r in zip(comics, (4, -2, 3))]
    L = text_layer([(title, font('Cinzel-Bold', 54), YEL, 92, 5)])
    bl = balloon(cap)

    def fr(t):
        im = base.convert('RGBA')
        im.alpha_composite(VIG)
        for j, (p, sh) in enumerate(pans):
            k = ease((t - .25 * j) / .35)
            if k <= 0:
                continue
            s = .8 + .2 * k
            pp = p.resize((int(p.width * s), int(p.height * s)), Image.LANCZOS)
            cx, cy = W // 2 + (j - 1) * 390, 370 + int(30 * (1 - k))
            im.alpha_composite(sh.resize(pp.size), (cx - pp.width // 2 + 10, cy - pp.height // 2 + 12))
            im.alpha_composite(pp, (cx - pp.width // 2, cy - pp.height // 2))
        im = over(im.convert('RGB'), L, ease((t - .1) / .4)).convert('RGBA')
        a = ease((t - .9) / .3)
        if a > 0:
            b = bl.copy()
            b.putalpha(b.getchannel('A').point(lambda v: int(v * a)))
            im.alpha_composite(b, (W // 2 - b.width // 2, 655 - 31))
        return im.convert('RGB')
    render(name, dur, fr, .15, .25)


def pista():
    """trilha de lápis de cor atravessando a tela até um desenho da Isis"""
    base = cover(R + 'assets/bg/tarde.jpg', blur=8, dark=.62)
    at1 = Image.open(R + 'assets/sprites/atlas1.png').convert('RGBA')
    at2 = Image.open(R + 'assets/sprites/atlas2.png').convert('RGBA')
    draw = at1.crop((1652, 432, 1712, 496)).resize((210, 224), Image.LANCZOS)
    cols = [1108, 1128, 1148, 1167, 1187, 1206]
    pens = [at2.crop((x, 641, x + 18, 685)).resize((40, 98), Image.LANCZOS) for x in cols]
    pts = [(110 + i * 92, 300 + int(70 * math.sin(i * .9))) for i in range(9)]
    L = text_layer([('Cada lápis é uma pista.', font('Lora-Italic', 46), CREAM, 560, 3)])
    L2 = text_layer([('Cada desenho escondido, um pedaço da verdade.', font('Lora-Italic', 32), (225, 212, 185), 620, 2)])
    dur = 3.6

    def fr(t):
        im = base.convert('RGBA')
        im.alpha_composite(VIG)
        for j, (x, y) in enumerate(pts):
            k = ease((t - .12 * j) / .3)
            if k <= 0:
                continue
            p = pens[j % 6].rotate(-25 + 15 * math.sin(j * 1.7), expand=True, resample=Image.BICUBIC)
            yy = y - int(50 * (1 - k))
            p.putalpha(p.getchannel('A').point(lambda v: int(v * k)))
            im.alpha_composite(p, (x - p.width // 2, yy - p.height // 2))
        k = ease((t - 1.15) / .4)
        if k > 0:
            s = .7 + .3 * k
            d = draw.rotate(6, expand=True, resample=Image.BICUBIC)
            d = d.resize((int(d.width * s), int(d.height * s)), Image.LANCZOS)
            im.alpha_composite(d, (1080 - d.width // 2, 300 - d.height // 2))
        im = im.convert('RGB')
        im = over(im, L, ease((t - .7) / .4))
        im = over(im, L2, ease((t - 1.4) / .4))
        return im
    render('pista', dur, fr, .2, .25)


def final():
    base = cover(R + 'assets/bg/noite.jpg', int(W * 1.08), int(H * 1.08), 5, .58)
    A = text_layer([('Siga a trilha.', font('Lora-Italic', 52), CREAM, 330, 3)])
    B = text_layer([('QUEM LEVOU A ISIS?', font('Cinzel-Bold', 84), YEL, 350, 6)])
    C = text_layer([('ENCONTRE-A', font('Cinzel-Bold', 116), GOLD, 225, 6),
                    ('EPISÓDIO 1 · O BOSQUE', font('Cinzel-Bold', 44), (232, 201, 138), 325, 3)])
    D = text_layer([('Em breve: EPISÓDIO 2 · As Profundezas da Mina', font('Lora-Bold', 30), (255, 214, 120), 520, 2),
                    ('Para Android', font('Lora-Italic', 28), (220, 210, 190), 590, 0)])
    dur = 7.5

    def fr(t):
        k = t / dur
        ox = int(W * .08 * k)
        im = base.crop((ox, 25, ox + W, 25 + H))
        im = over(im, VIG, 1)
        im = over(im, A, ramp(t, .2, 1.8))
        im = over(im, B, ramp(t, 1.9, 3.8))
        im = over(im, C, ease((t - 4.0) / .7))
        im = over(im, D, ease((t - 4.7) / .7))
        return im
    render('final', dur, fr, .2, 1.0)


def caps():
    """faixas de legenda transparentes para os trechos de jogo"""
    import json
    for k, t in json.load(open(R + 'tools/promo/trailer/legendas.json')).items():
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        f = font('Lora-Italic', 30)
        w = d.textlength(t, font=f) + 56
        d.rounded_rectangle([W / 2 - w / 2, H - 92, W / 2 + w / 2, H - 38], 12, fill=(14, 10, 6, 200))
        d.text((W / 2, H - 65), t, font=f, fill=(245, 235, 210), anchor='mm')
        im.save('/tmp/vid/cards/cap_%s.png' % k)
    print('legendas ok')


JOBS = {
    'abertura': abertura,
    'sumiu': sumiu,
    'titulo': titulo,
    'pista': pista,
    'q_cipo': lambda: quadro('q_cipo', 'cipo', 'assets/bg/bosque.jpg', 'Um lápis lá no alto... ela passou por aqui!'),
    'p_quem': lambda: pergunta('p_quem', 'QUEM A LEVOU?', '', 1.8, 'assets/bg/tarde.jpg'),
    'q_colmeia': lambda: quadro('q_colmeia', 'colmeia_a', 'assets/bg/tarde.jpg', 'Abelhas! Corre, Tomé!', 2.0),
    'q_toxico': lambda: quadro('q_toxico', 'toxico', 'assets/bg/pantano.jpg', 'Essa água... alguém envenenou o brejo?', 2.2),
    'reis': lambda: trio('reis', ['javali_a', 'gaviao_a', 'urso_a'], 'assets/bg/tarde.jpg', 'OS REIS DO BOSQUE',
                         'Eles guardam o caminho... mas a mando de quem?'),
    'q_mergulho': lambda: quadro('q_mergulho', 'mergulho', 'assets/bg/pantano.jpg', 'Lá no fundo tem alguma coisa brilhando...', 2.2),
    'p_onde': lambda: pergunta('p_onde', 'PARA ONDE?', '', 1.8, 'assets/bg/pantano.jpg'),
    'q_jangada': lambda: quadro('q_jangada', 'jangada', 'assets/bg/pantano.jpg', 'Segura firme... que correnteza!', 2.0),
    'q_neve': lambda: quadro('q_neve', 'neve', 'assets/bg/neve.jpg', 'Brrr... aguenta firme, Isis!', 2.0),
    'q_pipoca': lambda: quadro('q_pipoca', 'pipoca', 'assets/bg/neve.jpg', 'Pipoca! Você sentiu o cheiro dela?', 2.2),
    'q_aviao': lambda: quadro('q_aviao', 'aviao_b', 'assets/bg/neve.jpg', 'Daqui de cima eu vejo a mina!', 2.0),
    'p_porque': lambda: pergunta('p_porque', 'E POR QUÊ?', '', 1.8, 'assets/bg/noite.jpg'),
    'q_mina': lambda: quadro('q_mina', 'mina', 'assets/bg/noite.jpg', 'Escuro demais... ainda bem que eu trouxe a lanterna.', 2.4),
    'q_bola': lambda: quadro('q_bola', 'bola_b', 'assets/bg/noite.jpg', 'Uma pedra gigante! Corre!', 1.8),
    'final': final,
    'caps': caps,
}

if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    os.makedirs('/tmp/vid/cards', exist_ok=True)
    VIG = vignette()
    BAND = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for yy in range(H - 200, H):
        ImageDraw.Draw(BAND).line([(0, yy), (W, yy)], fill=(0, 0, 0, int(170 * (yy - H + 200) / 200)))
    for k in (sys.argv[1:] or list(JOBS)):
        JOBS[k]()
