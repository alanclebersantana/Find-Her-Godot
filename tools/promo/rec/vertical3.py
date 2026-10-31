#!/usr/bin/env python3
"""Vídeo vertical (1080x1920) de gameplay dos 3 episódios, a partir das gravações de tests/rec
(/tmp/vid3/<nome>.avi + .pos). Jogo num quadro grande no meio (recorte 4:3 que segue o Tomé), fundo
desfocado do próprio jogo, título do episódio em cima, legenda e o selo "melhor com controle" embaixo.
Uso: python3 vertical3.py  ->  /tmp/vid3/encontre-a_gameplay_vertical.mp4
Um vídeo curto por episódio: python3 vertical3.py [1 2 3]. Roteiro em /tmp/vid3/roteiro.json:
{"1": [["intro", s], [gravação, quadro inicial, segundos, episódio, legenda], ..., ["pad", s], ["fim", s]], ...}.
O aviso do controle aparece uma vez só (cartela "pad")."""
import json, math, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

R = '/home/claude/find-her-godot/'
V = '/tmp/vid3/'
F = '/tmp/vid/fonts/'
W, H, FPS = 1080, 1920, 30
GW, GH = 1080, 810            # quadro do jogo
GY = 560
CREAM = (241, 229, 201)
GOLD = (242, 195, 91)
NIGHT = (17, 18, 28)
URL = 'alanclebersantana.github.io/Find-Her-Godot'

EPS = {1: ('EPISÓDIO 1', 'O Bosque'), 2: ('EPISÓDIO 2', 'As Profundezas da Mina'), 3: ('EPISÓDIO 3', 'A Fortaleza na Serra')}
ROT = json.load(open(V + 'roteiro.json'))   # {"1": [...trechos], "2": ..., "3": ...}
ART = {1: 'assets/ui/cena1.jpg', 2: 'assets/ui/cut_ep2_a.jpg', 3: 'assets/ui/cut_ep3_fort.jpg'}
TAG = {1: 'A Isis sumiu. Siga a trilha de lápis!', 2: 'A trilha desce para dentro da mina', 3: 'A trilha sobe até a fortaleza'}
MUS = {1: 'mus_tema', 2: 'mus_tunel', 3: 'mus_perseguicao'}

_fc = {}


def font(n, s):
    if (n, s) not in _fc:
        _fc[(n, s)] = ImageFont.truetype(F + n + '.ttf', s)
    return _fc[(n, s)]


def ctext(d, y, t, f, fill, stroke=0, sc=(0, 0, 0)):
    d.text((W / 2, y), t, font=f, fill=fill, anchor='mm', stroke_width=stroke, stroke_fill=sc)


def gamepad(d, cx, cy, s, body=(40, 42, 60), line=(0, 0, 0)):
    """controle desenhado (sem emoji): corpo com duas alças, cruz e 4 botões"""
    w, h = 2.2 * s, 1.15 * s
    lw = max(3, int(s * .07))
    for dx in (-1, 1):
        d.ellipse([cx + dx * w * .32 - s * .55, cy - h * .25, cx + dx * w * .32 + s * .55, cy + h * .75], fill=body, outline=line, width=lw)
    d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h * .25], radius=int(s * .45), fill=body, outline=line, width=lw)
    d.rectangle([cx - w * .3, cy - h * .5 + lw, cx + w * .3, cy + h * .25 - lw], fill=body)
    # cruz
    a, b = s * .13, s * .38
    x0 = cx - w * .27
    d.rectangle([x0 - b, cy - a, x0 + b, cy + a], fill=(230, 230, 236), outline=line, width=max(2, lw // 2))
    d.rectangle([x0 - a, cy - b, x0 + a, cy + b], fill=(230, 230, 236), outline=line, width=max(2, lw // 2))
    d.rectangle([x0 - a + 2, cy - a + 2, x0 + a - 2, cy + a - 2], fill=(230, 230, 236))
    # botões
    x1 = cx + w * .27
    r = s * .12
    for (bx, by), col in zip([(0, -1), (1, 0), (0, 1), (-1, 0)], [(242, 195, 91), (224, 80, 70), (90, 170, 90), (80, 140, 220)]):
        px, py = x1 + bx * s * .28, cy + by * s * .28
        d.ellipse([px - r, py - r, px + r, py + r], fill=col, outline=line, width=max(2, lw // 2))


def badge_layer():
    L = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    y = 1745
    f = font('Lora-Bold', 40)
    t = 'Melhor com controle (gamepad)'
    tw = d.textlength(t, font=f)
    bw = tw + 150
    d.rounded_rectangle([W / 2 - bw / 2, y - 52, W / 2 + bw / 2, y + 52], radius=52, fill=(242, 195, 91, 245), outline=(0, 0, 0), width=5)
    gamepad(d, W / 2 - bw / 2 + 62, y + 2, 32, body=(36, 30, 20))
    d.text((W / 2 - bw / 2 + 120, y), t, font=f, fill=(36, 23, 10), anchor='lm')
    return L


def top_layer(ep):
    L = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    ctext(d, 150, 'ENCONTRE-A', font('Cinzel-Bold', 92), CREAM, 5)
    ctext(d, 232, 'jogo de plataforma retrô · Android', font('Lora-Italic', 38), CREAM, 3)
    if ep:
        a, b = EPS[ep]
        ctext(d, 375, a, font('Cinzel-Bold', 46), GOLD, 4)
        ctext(d, 440, b, font('Lora-Bold', 50), CREAM, 4)
    return L


def caption_layer(t):
    L = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    if not t:
        return L
    d = ImageDraw.Draw(L)
    f = font('Lora-Italic', 50)
    tw = d.textlength(t, font=f)
    y = 1525
    d.rounded_rectangle([W / 2 - tw / 2 - 44, y - 50, W / 2 + tw / 2 + 44, y + 50], radius=16, fill=(255, 243, 207, 250), outline=(0, 0, 0), width=5)
    ctext(d, y, t, f, (40, 26, 12))
    return L




def load_pos(src):
    rows = [l.split() for l in open(V + src + '.pos')]
    return [(float(r[2]), float(r[3]), int(r[4])) for r in rows if len(r) >= 5]


def track(us):
    """centro do recorte (px no quadro 1280) suavizado para não tremer"""
    c = [min(max(u * 1280, 480), 800) for u in us]
    for _ in range(2):
        a = c[0]
        out = []
        for v in c:
            a = a * .9 + v * .1
            out.append(a)
        a = out[-1]
        back = []
        for v in reversed(out):
            a = a * .9 + v * .1
            back.append(a)
        c = list(reversed(back))
    return c


def frames(src, start, n):
    p = subprocess.Popen(['ffmpeg', '-v', 'error', '-ss', '%.4f' % (start / FPS), '-i', V + src + '.avi', '-frames:v', str(n),
                          '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
    sz = 1280 * 720 * 3
    while True:
        b = p.stdout.read(sz)
        if len(b) < sz:
            break
        yield Image.frombuffer('RGB', (1280, 720), b, 'raw', 'RGB', 0, 1)
    p.wait()


def bg_from(im):
    small = im.resize((128, 72), Image.BILINEAR)
    s = H / 72
    big = small.resize((int(128 * s), H), Image.BILINEAR)
    x = (big.width - W) // 2
    big = big.crop((x, 0, x + W, H)).filter(ImageFilter.GaussianBlur(18))
    return Image.blend(big, Image.new('RGB', (W, H), NIGHT), .55)


def compose_game(im, cx, top, cap, fade, gain=1.0):
    bg = bg_from(im)
    x0 = int(round(cx - 480))
    g = im.crop((x0, 0, x0 + 960, 720)).resize((GW, GH), Image.LANCZOS)
    if gain != 1.0:   # trechos muito escuros (noite, caverna): clareia um pouco
        g = ImageEnhance.Brightness(g).enhance(gain)
    out = bg
    d = ImageDraw.Draw(out)
    d.rectangle([0, GY - 6, W, GY + GH + 5], fill=(0, 0, 0))
    out.paste(g, (0, GY))
    out = out.convert('RGBA')
    out.alpha_composite(top)
    out.alpha_composite(cap)
    out = out.convert('RGB')
    if fade < 1:
        out = Image.blend(Image.new('RGB', (W, H), (0, 0, 0)), out, max(0.0, fade))
    return out


def cover(path, w, h):
    im = Image.open(path).convert('RGB')
    s = max(w / im.width, h / im.height)
    im = im.resize((math.ceil(im.width * s), math.ceil(im.height * s)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def card(kind, ep=1):
    """cartelas paradas (o movimento é um zoom lento aplicado na hora)"""
    base = cover(R + ART[ep], W, H).filter(ImageFilter.GaussianBlur(14))
    base = Image.blend(base, Image.new('RGB', (W, H), NIGHT), .6).convert('RGBA')
    d = ImageDraw.Draw(base)
    if kind == 'intro':
        art = cover(R + ART[ep], GW, GH)
        d.rectangle([0, GY - 6, W, GY + GH + 5], fill=(0, 0, 0))
        base.paste(art, (0, GY))
        base.alpha_composite(top_layer(ep))
        base.alpha_composite(caption_layer(TAG[ep]))
    elif kind == 'pad':
        ctext(d, 150, 'ENCONTRE-A', font('Cinzel-Bold', 92), CREAM, 5)
        ctext(d, 520, 'JOGUE COM', font('Cinzel-Bold', 80), GOLD, 5)
        ctext(d, 620, 'CONTROLE', font('Cinzel-Bold', 110), GOLD, 6)
        gamepad(d, W / 2, 960, 210, body=(52, 48, 70))
        f = font('Lora-Bold', 52)
        ctext(d, 1290, 'É muito melhor com gamepad', f, CREAM, 4)
        f2 = font('Lora-Italic', 44)
        ctext(d, 1375, 'Bluetooth ou USB, é só ligar e jogar', f2, CREAM, 3)
        ctext(d, 1440, '(também dá para jogar na tela)', font('Lora-Italic', 36), (200, 190, 170), 3)
    elif kind == 'fim':
        icon = Image.open(R + 'icon.png').convert('RGBA').resize((300, 300), Image.LANCZOS)
        ctext(d, 260, 'ENCONTRE-A', font('Cinzel-Bold', 110), CREAM, 6)
        ctext(d, 360, 'jogo de plataforma retrô · Android', font('Lora-Italic', 42), CREAM, 3)
        m = Image.new('L', (300, 300), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, 299, 299], 64, fill=255)
        d.rounded_rectangle([W / 2 - 156, 480 - 6, W / 2 + 156, 480 + 306], 70, fill=(0, 0, 0))
        base.paste(icon, (W // 2 - 150, 480), m)
        ctext(d, 940, 'BAIXE GRÁTIS', font('Cinzel-Bold', 96), GOLD, 6)
        ctext(d, 1040, 'Instalação passo a passo em:', font('Lora-Italic', 44), CREAM, 3)
        f = font('Lora-Bold', 46)
        tw = d.textlength(URL, font=f)
        d.rounded_rectangle([W / 2 - tw / 2 - 30, 1095, W / 2 + tw / 2 + 30, 1185], 18, fill=(255, 243, 207), outline=(0, 0, 0), width=5)
        ctext(d, 1140, URL, f, (40, 26, 12))
    return base.convert('RGB')


def card_frames(kind, secs, ep):
    im = card(kind, ep)
    n = int(secs * FPS)
    for i in range(n):
        z = 1 + .03 * i / n
        w2, h2 = int(W * z), int(H * z)
        f = im.resize((w2, h2), Image.BILINEAR).crop(((w2 - W) // 2, (h2 - H) // 2, (w2 - W) // 2 + W, (h2 - H) // 2 + H))
        fade = min(1.0, i / 8, (n - 1 - i) / 8)
        if fade < 1:
            f = Image.blend(Image.new('RGB', (W, H), (0, 0, 0)), f, max(0.0, fade))
        yield f


def main(ep):
    SEGS = ROT[str(ep)]
    out = V + 'encontre-a_ep%d_vertical.mp4' % ep
    tmp = V + 'v_noaudio_%d.mp4' % ep
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H), '-r', str(FPS),
                            '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p', tmp], stdin=subprocess.PIPE)
    total = 0
    tops = {e: top_layer(e) for e in (1, 2, 3)}
    for sg in SEGS:
        if sg[0] in ('intro', 'pad', 'fim'):
            for f in card_frames(sg[0], sg[1], ep):
                enc.stdin.write(f.tobytes())
                total += 1
            continue
        src, start, secs, ep, cap = sg[:5]
        gain = sg[5] if len(sg) > 5 else 1.0
        n = int(secs * FPS)
        pos = load_pos(src)
        us = [pos[min(start + i, len(pos) - 1)][0] for i in range(n)]
        cs = track(us)
        capL = caption_layer(cap)
        for i, im in enumerate(frames(src, start, n)):
            fade = min(1.0, (i + 1) / 6, (n - i) / 6)
            enc.stdin.write(compose_game(im, cs[i], tops[ep], capL, fade, gain).tobytes())
            total += 1
        print('seg', src, start, secs, file=sys.stderr)
    enc.stdin.close()
    enc.wait()
    dur = total / FPS
    music = R + 'assets/audio/%s.ogg' % MUS[ep]
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-stream_loop', '-1', '-i', music, '-filter_complex',
                    '[1:a]atrim=0:%.2f,afade=t=in:st=0:d=0.8,afade=t=out:st=%.2f:d=2.5,volume=0.9[a]' % (dur, max(0, dur - 2.5)),
                    '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', '-shortest', out], check=True)
    print('ok', out, '%.1fs' % dur)


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'cards':
        for e in (1, 2, 3):
            card('intro', e).save(V + 'card_intro%d.jpg' % e, quality=85)
        for k in ('pad', 'fim'):
            card(k).save(V + 'card_%s.jpg' % k, quality=85)
    else:
        for e in (sys.argv[1:] or ['1', '2', '3']):
            main(int(e))
