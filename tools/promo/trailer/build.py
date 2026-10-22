"""Monta o trailer de 1min30 de Encontre-a · Episódio 1.

1. gravar os trechos em 2560x1440 (window override temporário) com tests/capture.gd -> /tmp/vid/hi/<seg>.avi + .pos
2. python3 cards.py          (cartelas animadas e legendas)
3. python3 build.py          (cortes que acompanham o Tomé, ordem, trilha) -> /tmp/vid/encontre-a_trailer.mp4
"""
import json, subprocess, os
from PIL import Image, ImageEnhance

HI = '/tmp/vid/hi/'
SEG = '/tmp/vid/seg2/'
CARDS = '/tmp/vid/cards/'
A = '/home/claude/find-her-godot/assets/audio/'
W, H, FPS = 1280, 720, 30
SW, SH = 2560, 1440


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def load_pos(seg, n):
    p = HI + seg + '.pos'
    rows = [l.split() for l in open(p)] if os.path.exists(p) else []
    if not rows:
        return [(.5, .55)] * n
    last = int(rows[-1][0])
    off = last - (n - 1)
    m = {int(r[0]) - off: (float(r[1]), float(r[2])) for r in rows}
    out, cur = [], None
    for i in range(n):
        if i in m:
            cur = m[i]
        out.append(cur)
    first = next((c for c in out if c), (.5, .55))
    out = [c or first for c in out]
    # suaviza (média móvel de ida e volta) para a câmera não tremer
    for _ in range(2):
        sm, a = [], out[0]
        for c in out:
            a = (a[0] * .88 + c[0] * .12, a[1] * .9 + c[1] * .1)
            sm.append(a)
        out, sm2, a = sm, [], sm[-1]
        for c in reversed(sm):
            a = (a[0] * .88 + c[0] * .12, a[1] * .9 + c[1] * .1)
            sm2.append(a)
        out = list(reversed(sm2))
    return out


def nframes(avi):
    r = subprocess.run(['ffprobe', '-v', 'error', '-count_packets', '-select_streams', 'v:0', '-show_entries',
                        'stream=nb_read_packets', '-of', 'csv=p=0', avi], capture_output=True, text=True)
    return int(r.stdout.strip())


def clip(out, seg, start, dur, z0=1.25, z1=None, cap=None, gamma=None, fixed=None, bias=(0, -.05)):
    """z: aproximação (1 = quadro inteiro; 2 = tamanho real). fixed=(u,v) trava o centro."""
    z1 = z1 or z0
    avi = HI + seg + '.avi'
    n = nframes(avi)
    pos = load_pos(seg, n)
    s0 = int(start * FPS)
    cnt = int(round(dur * FPS))
    dec = subprocess.Popen(['ffmpeg', '-v', 'error', '-ss', str(start), '-i', avi, '-frames:v', str(cnt),
                            '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H),
                            '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
                            '-pix_fmt', 'yuv420p', SEG + out + '.mp4'], stdin=subprocess.PIPE)
    capim = Image.open(CARDS + 'cap_%s.png' % cap) if cap else None
    last = None
    for i in range(cnt):
        buf = dec.stdout.read(SW * SH * 3)
        if len(buf) < SW * SH * 3:
            im = last
        else:
            im = Image.frombytes('RGB', (SW, SH), buf)
        last = im
        t = i / max(1, cnt - 1)
        z = z0 + (z1 - z0) * ease(t)
        cw, ch = SW / z, SH / z
        u, v = fixed or pos[min(n - 1, s0 + i)]
        cx = u * SW + bias[0] * SW
        cy = v * SH + bias[1] * SH
        x = min(max(cx - cw / 2, 0), SW - cw)
        y = min(max(cy - ch / 2, 0), SH - ch)
        fr = im.crop((int(x), int(y), int(x + cw), int(y + ch))).resize((W, H), Image.LANCZOS)
        if gamma:
            fr = fr.point(lambda p: int(255 * (p / 255) ** (1 / gamma)))
        k = min(1.0, ease(i / 6), ease((cnt - 1 - i) / 6))
        if k < 1:
            fr = Image.blend(Image.new('RGB', (W, H)), fr, k)
        if capim:
            a = min(1.0, ease((i - 4) / 8), ease((cnt - 4 - i) / 8))
            if a > 0:
                c = capim.copy()
                c.putalpha(c.getchannel('A').point(lambda p: int(p * a)))
                fr = fr.convert('RGBA')
                fr.alpha_composite(c)
                fr = fr.convert('RGB')
        enc.stdin.write(fr.tobytes())
    dec.stdout.close()
    dec.wait()
    enc.stdin.close()
    enc.wait()
    print(out, seg, dur)


# ---------------- roteiro: (tipo, nome, ...) ----------------
# 'c' = cartela pronta em seg2; 'g' = trecho de jogo
ROTEIRO = [
    ('c', 'abertura'),
    ('c', 'sumiu'),
    ('g', 'g_manha', 'manha', 0.3, 3.6, 2.0, 1.7, 'trilha'),
    ('c', 'titulo'),
    ('c', 'pista'),
    ('g', 'g_flor', 'flor', 0.6, 2.6, 1.5, 1.5, 'flor'),
    ('g', 'g_copas', 'copas', 3.0, 2.8, 1.35, 1.35, 'copas'),
    ('c', 'q_cipo'),
    ('g', 'g_fenda', 'fenda', 1.0, 2.6, 1.9, 1.9, 'fenda'),
    ('g', 'g_colmeia', 'colmeia', 0.3, 2.4, 1.4, 1.4, 'colmeia'),
    ('c', 'p_quem'),
    ('g', 'g_regias', 'regias', 2.0, 2.8, 1.3, 1.3, 'regias'),
    ('g', 'g_cipos', 'cipos', 0.4, 2.4, 1.5, 1.5, 'cipos'),
    ('c', 'q_toxico'),
    ('g', 'g_mergulho', 'mergulho', 11.5, 2.6, 1.4, 1.4, 'mergulho'),
    ('g', 'g_jangada', 'jangada', 1.5, 2.6, 1.3, 1.3, 'jangada'),
    ('c', 'reis'),
    ('g', 'g_javali', 'javali', 1.8, 1.8, 1.2, 1.2, None),
    ('g', 'g_gaviao', 'gaviao', 1.6, 1.8, 1.15, 1.15, None),
    ('c', 'p_onde'),
    ('c', 'q_neve'),
    ('g', 'g_bolaneve', 'bolaneve', 1.5, 2.4, 1.35, 1.35, 'bolaneve'),
    ('g', 'g_gelo', 'gelo', 0.8, 2.0, 1.4, 1.4, 'gelo'),
    ('g', 'g_cavalo', 'cavalo', 2.2, 2.6, 1.15, 1.15, 'cavalo'),
    ('c', 'q_pipoca'),
    ('g', 'g_ponte', 'ponte', 1.0, 2.2, 1.3, 1.3, 'ponte'),
    ('g', 'g_urso', 'urso', 0.8, 1.8, 1.15, 1.15, None),
    ('g', 'g_vento', 'vento', 3.0, 2.0, 1.3, 1.3, 'vento'),
    ('c', 'q_aviao'),
    ('g', 'g_voo', 'voo', 1.0, 2.8, 1.15, 1.15, 'voo'),
    ('c', 'p_porque'),
    ('g', 'g_cogumelos', 'cogumelos', 2.0, 3.0, 1.5, 1.9, 'cogumelos', 1.35),
    ('c', 'q_mina'),
    ('g', 'g_pedra', 'pedra', 0.8, 2.4, 1.4, 1.4, 'pedra', 1.9),
    ('c', 'q_bola'),
    ('g', 'g_pedra2', 'pedra', 8.4, 2.0, 1.5, 1.5, 'pedra2', 1.9),
    ('c', 'final'),
]

OPTS = {  # ajustes por trecho
    'g_cavalo': dict(fixed=(.55, .62)),
    'g_voo': dict(fixed=(.5, .45)),
    'g_mergulho': dict(bias=(0, 0)),
}


def build(only=None):
    for r in ROTEIRO:
        if r[0] != 'g' or (only and r[1] not in only):
            continue
        _, out, seg, st, du, z0, z1, cap = r[:8]
        gm = r[8] if len(r) > 8 else None
        clip(out, seg, st, du, z0, z1, cap, gm, **OPTS.get(out, {}))


def montar():
    with open('/tmp/vid/list2.txt', 'w') as f:
        for r in ROTEIRO:
            f.write("file '%s%s.mp4'\n" % (SEG, r[1]))
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', '/tmp/vid/list2.txt',
                    '-c', 'copy', '/tmp/vid/trailer_mudo.mp4'], check=True)
    D = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0',
                              '/tmp/vid/trailer_mudo.mp4'], capture_output=True, text=True).stdout)
    # marcas de tempo: fim da introdução (título) e começo do final
    t = 0.0
    marks = {}
    for r in ROTEIRO:
        d = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0',
                                  SEG + r[1] + '.mp4'], capture_output=True, text=True).stdout)
        marks[r[1]] = (t, t + d)
        t += d
    t_tit = marks['titulo'][0]
    t_fim = marks['final'][0]
    # noite (mistério) na abertura -> tema no título -> perseguição na aventura -> noite no fim
    fc = (
        "[0:a]atrim=0:{a0},afade=t=in:st=0:d=1.5,afade=t=out:st={a0f}:d=1.2[n0];"
        "[1:a]atrim=0:{a1},adelay={d1}|{d1},afade=t=in:st={t_tit}:d=0.6,afade=t=out:st={a1f}:d=1.5[tm];"
        "[2:a]aloop=loop=3:size=2e6,atrim=0:{a2},adelay={d2}|{d2},afade=t=in:st={a2s}:d=1.2,afade=t=out:st={a2f}:d=1.5[pc];"
        "[3:a]atrim=0:{a3},adelay={d3}|{d3},afade=t=in:st={a3s}:d=1.2[nf];"
        "[n0][tm][pc][nf]amix=inputs=4:normalize=0,atrim=0:{D},afade=t=out:st={Df}:d=2.5,volume=0.9[a]"
    )
    p_ini = marks['pista'][0] + 1.0
    fc = fc.format(a0=t_tit + 1.0, a0f=t_tit - .2, a1=p_ini - t_tit + 1.6, d1=int(t_tit * 1000), t_tit=t_tit,
                   a1f=p_ini, a2=t_fim - p_ini + 1.6, d2=int(p_ini * 1000), a2s=p_ini, a2f=t_fim,
                   a3=D - t_fim + .5, d3=int((t_fim - .6) * 1000), a3s=t_fim - .6, D=D, Df=D - 2.5)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', A + 'mus_noite.ogg', '-i', A + 'mus_tema.ogg',
                    '-i', A + 'mus_perseguicao.ogg', '-i', A + 'mus_noite.ogg', '-filter_complex', fc,
                    '-map', '[a]', '-c:a', 'aac', '-b:a', '192k', '/tmp/vid/trilha2.m4a'], check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', '/tmp/vid/trailer_mudo.mp4', '-i', '/tmp/vid/trilha2.m4a',
                    '-c:v', 'copy', '-c:a', 'aac', '-shortest', '-movflags', '+faststart',
                    '/tmp/vid/encontre-a_trailer.mp4'], check=True)
    print('duração', D)
    for k, v in marks.items():
        print('%6.1f %s' % (v[0], k))


if __name__ == '__main__':
    import sys
    a = sys.argv[1:]
    if not a or a[0] == 'clips':
        build(a[1:] or None)
    if not a or a[0] == 'montar':
        montar()
