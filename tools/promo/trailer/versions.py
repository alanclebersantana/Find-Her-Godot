"""Três versões do trailer (90 s cada), com o mesmo enredo, quadrinhos e perguntas.
  v1 Mistério   — a história em ordem, cenas de ação por fase
  v2 Ação       — cortes rápidos, mais mecânicas, cartelas mais curtas
  v3 Trilha     — abre com ação, depois a história; montagem agrupada por mecânica
Uso: python3 versions.py [v1 v2 v3]   -> /tmp/vid/encontre-a_trailer_<v>.mp4
Os trechos de jogo são cortados uma vez e reaproveitados entre as versões (cache pelo nome)."""
import os, sys, subprocess, hashlib
import build
from build import clip, SEG, A

# ('g', seg, início, duração, zoom0, zoom1, legenda, gama, opções)
def G(seg, st, du, z0=1.35, z1=None, cap=None, gm=None, **op):
    return ('g', seg, st, du, z0, z1 or z0, cap, gm, op)

def C(name):
    return ('c', name)

# ---- trechos de ação (iguais nas três versões quando o corte é o mesmo) ----
INI_CASA = G('a_inicio', 0.2, 2.0, 1.3, 1.5, 'trilha')
INI_RASTEJA = G('a_inicio', 2.3, 2.0, 1.5, 1.5, 'inicio')
INI_PEDRAS = G('a_inicio', 4.5, 2.2, 1.45, 1.45, None)
ESTACA = G('a_estaca', 0.3, 3.6, 1.45, 1.35, 'estaca')
ESCADA = G('a_escada', 7.0, 2.6, 1.5, 1.5, 'escada')
GALHO = G('a_galho', 0.2, 2.6, 1.35, 1.35, 'galho')
CIPO1 = G('a_galho', 3.4, 2.2, 1.35, 1.35, None)
CHAO = G('a_chao', 0.6, 3.4, 1.45, 1.45, 'chao')
FLOR = G('flor', 0.6, 2.2, 1.5, 1.5, 'flor')
COPAS = G('copas', 3.0, 2.2, 1.35, 1.35, 'copas')
PLANAR = G('a_planar', 1.0, 3.2, 1.3, 1.3, 'planar')
REGIAS = G('a_regias', 0.3, 3.0, 1.35, 1.35, 'regias')
COLMEIA = G('a_colmeia', 0.0, 3.0, 1.6, 1.6, 'colmeia2')
TUNEL = G('a_colmeia', 3.4, 2.6, 1.4, 1.4, 'tunel', bias=(0, 0))
REGIAS2 = G('regias', 2.0, 2.2, 1.3, 1.3, None)
CIPOS = G('regias', 7.6, 3.0, 1.35, 1.35, 'cipos2')
CORDA = G('corda', 1.4, 2.8, 1.35, 1.35, 'corda')
JANGADA = G('jangada', 1.5, 2.4, 1.3, 1.3, 'jangada')
JAVALI = G('javali', 1.8, 1.6, 1.2, 1.2, None)
GAVIAO = G('gaviao', 1.6, 1.6, 1.15, 1.15, None)
BOLANEVE = G('bolaneve', 1.5, 2.2, 1.35, 1.35, 'bolaneve')
CAVALO = G('cavalo', 2.2, 2.2, 1.15, 1.15, 'cavalo', fixed=(.55, .62))
PONTE = G('ponte', 1.0, 2.2, 1.3, 1.3, 'ponte')
URSO = G('urso', 0.8, 1.6, 1.15, 1.15, None)
VENTO = G('vento', 3.0, 2.0, 1.3, 1.3, 'vento')
VOO = G('voo', 19.0, 2.4, 1.15, 1.15, 'voo', fixed=(.45, .5))
MACHADO = G('a_noite', 0.2, 2.2, 1.35, 1.35, 'machado', 1.25)
SALTA1 = G('a_noite', 4.4, 3.4, 1.25, 1.25, 'saltador', 1.25)
SALTA2 = G('a_noite', 8.0, 3.0, 1.2, 1.2, None, 1.25)
TABUAS = G('a_tabuas', 0.3, 2.8, 1.35, 1.35, 'tabuas', 1.45)
PEDRA = G('pedra', 26.0, 1.7, 1.25, 1.25, 'pedra', 1.5, bias=(-.12, .05))
PEDRA2 = G('pedra', 33.4, 2.2, 1.25, 1.25, 'pedra2', 1.5, bias=(-.06, .05))


def short(g, du, cap=False):
    """mesma cena, mais curta (e sem legenda, se cap=False)"""
    _, seg, st, _, z0, z1, c, gm, op = g
    return ('g', seg, st, du, z0, z1, c if cap else None, gm, op)


V = {
    'v1': [
        C('abertura'), C('sumiu'), INI_CASA, C('titulo'), C('pista'),
        INI_RASTEJA, ESTACA, ESCADA, C('q_cipo'), GALHO, CHAO,
        C('p_quem'), FLOR, PLANAR, REGIAS, COLMEIA, C('q_toxico'), TUNEL, CIPOS, CORDA,
        C('reis'), JAVALI, GAVIAO, C('p_onde'), C('q_neve'), BOLANEVE, CAVALO, C('q_pipoca'), PONTE, URSO,
        C('q_aviao'), VOO, C('p_porque'), MACHADO, SALTA1, C('q_mina'), TABUAS, PEDRA, PEDRA2, C('final'),
    ],
    'v2': [
        C('abertura'), C('sumiu'), short(INI_CASA, 1.8, True), C('titulo'), C('pista'),
        short(INI_RASTEJA, 1.5, True), short(INI_PEDRAS, 1.5), short(ESTACA, 2.6, True), short(ESCADA, 1.8),
        C('q_cipo'), short(GALHO, 1.6), short(CIPO1, 1.6), short(CHAO, 2.2, True), short(COPAS, 1.5),
        C('p_quem'), short(PLANAR, 2.0, True), short(REGIAS, 2.0, True), short(COLMEIA, 2.2, True),
        short(TUNEL, 1.5), C('q_toxico'), short(CIPOS, 2.0, True), short(CORDA, 1.6), short(JANGADA, 1.6),
        C('reis'), short(JAVALI, 1.2), short(GAVIAO, 1.2), short(URSO, 1.2),
        C('p_onde'), short(BOLANEVE, 1.5), short(CAVALO, 1.6, True), short(PONTE, 1.5), short(VENTO, 1.4),
        C('q_aviao'), short(VOO, 1.6), C('p_porque'), short(MACHADO, 1.8, True), short(SALTA1, 2.4, True),
        short(SALTA2, 1.6), C('q_mina'), short(TABUAS, 1.6), short(PEDRA, 1.4), short(PEDRA2, 1.6, True), C('final'),
    ],
    'v3': [
        short(SALTA1, 1.4), short(CHAO, 1.4), short(CIPOS, 1.4), short(PEDRA, 1.2),
        C('abertura'), C('sumiu'), INI_CASA, C('titulo'), C('pista'),
        # mergulhos e pulos
        ESTACA, CHAO, C('q_cipo'),
        # pelo alto
        GALHO, PLANAR, short(COPAS, 1.6),
        C('p_quem'),
        # água e pântano
        REGIAS, COLMEIA, TUNEL, C('q_toxico'), CIPOS, short(JANGADA, 1.8),
        C('reis'), short(JAVALI, 1.4), short(URSO, 1.4),
        C('p_onde'), C('q_pipoca'), short(CAVALO, 1.8, True), short(PONTE, 1.8, True), short(VOO, 1.8, True),
        C('p_porque'), MACHADO, SALTA1, C('q_mina'), short(TABUAS, 1.8, True), PEDRA2, C('final'),
    ],
}

# na v2 as cartelas de quadrinho ficam mais curtas (cortadas no fim)
BASE_TRIM = {'sumiu': 3.3, 'titulo': 3.8, 'pista': 3.2, 'q_cipo': 1.8, 'q_toxico': 1.9, 'q_neve': 1.8,
             'q_pipoca': 1.9, 'q_aviao': 1.8, 'q_mina': 2.0, 'p_quem': 1.5, 'p_onde': 1.5, 'p_porque': 1.5,
             'reis': 2.4}
CARD_TRIM = {'v1': BASE_TRIM, 'v3': BASE_TRIM,
             'v2': dict(BASE_TRIM, q_cipo=1.6, q_toxico=1.7, q_pipoca=1.7, q_aviao=1.5, q_mina=1.8,
                        p_quem=1.3, p_onde=1.3, p_porque=1.3, reis=2.2, pista=3.0, titulo=3.6)}
ALVO = 90.0


def dur(path):
    return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path],
                                capture_output=True, text=True).stdout)


def clip_file(e):
    _, seg, st, du, z0, z1, cap, gm, op = e
    key = repr((seg, st, du, z0, z1, cap, gm, sorted(op.items())))
    name = 'x_%s_%s' % (seg, hashlib.md5(key.encode()).hexdigest()[:8])
    if not os.path.exists(SEG + name + '.mp4'):
        clip(name, seg, st, du, z0, z1, cap, gm, **op)
    return SEG + name + '.mp4'


def card_file(ver, name):
    src = SEG + name + '.mp4'
    t = CARD_TRIM.get(ver, {}).get(name)
    if not t:
        return src
    out = SEG + 'trim_%s_%s.mp4' % (ver, name)
    if not os.path.exists(out):
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', src, '-t', str(t), '-vf',
                        'fade=t=out:st=%.2f:d=0.2' % (t - .2), '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
                        '-pix_fmt', 'yuv420p', '-r', '30', out], check=True)
    return out


def ajusta(ver):
    """encolhe os trechos de jogo por igual para o vídeo dar 90 s (mínimo 1,1 s por cena)"""
    cards = sum(dur(card_file(ver, e[1])) for e in V[ver] if e[0] == 'c')
    gs = [e for e in V[ver] if e[0] == 'g']
    alvo = ALVO - cards
    f = alvo / sum(e[3] for e in gs)
    for _ in range(6):
        ds = [max(1.1, e[3] * f) for e in gs]
        f *= alvo / sum(ds)
    out, i = [], 0
    for e in V[ver]:
        if e[0] == 'g':
            d = round(max(1.1, e[3] * f) * 30) / 30
            out.append(e[:3] + (d,) + e[4:])
        else:
            out.append(e)
    print(ver, 'cartelas %.1f s, jogo %.1f s (fator %.2f)' % (cards, alvo, f))
    return out


def montar(ver):
    files, marks, t = [], {}, 0.0
    for e in ajusta(ver):
        f = clip_file(e) if e[0] == 'g' else card_file(ver, e[1])
        d = dur(f)
        if e[0] == 'c':
            marks.setdefault(e[1], (t, t + d))
        files.append(f)
        t += d
    lst = '/tmp/vid/list_%s.txt' % ver
    open(lst, 'w').write(''.join("file '%s'\n" % f for f in files))
    mudo = '/tmp/vid/mudo_%s.mp4' % ver
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', lst, '-c', 'copy', mudo], check=True)
    D = dur(mudo)
    t_ab = marks['abertura'][0]
    t_tit = marks['titulo'][0]
    p_ini = marks['pista'][0] + 1.0
    t_fim = marks['final'][0]
    # pistas: (arquivo, entra, sai) com cruzamento suave
    parts = []
    if t_ab > 0.5:  # v3: abre com a perseguição
        parts.append(('mus_perseguicao.ogg', 0, t_ab + .8, .2, 1.0))
    parts += [('mus_noite.ogg', t_ab, t_tit + .6, 1.2, 1.0),
              ('mus_tema.ogg', t_tit, p_ini + 1.4, .5, 1.4),
              ('mus_perseguicao.ogg', p_ini, t_fim + 1.2, 1.0, 1.6),
              ('mus_noite.ogg', t_fim - .6, D, 1.2, 0)]
    ins, fc, labs = [], '', []
    for i, (f, a, b, fi, fo) in enumerate(parts):
        ins += ['-stream_loop', '4', '-i', A + f]
        L = b - a
        fc += ('[%d:a]atrim=0:%.3f,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=%.2f%s,adelay=%d|%d[p%d];'
               % (i, L, fi, (',afade=t=out:st=%.3f:d=%.2f' % (L - fo, fo)) if fo else '', int(a * 1000), int(a * 1000), i))
        labs.append('[p%d]' % i)
    fc += '%samix=inputs=%d:normalize=0,atrim=0:%.3f,afade=t=out:st=%.3f:d=2.5,volume=0.8,alimiter=limit=0.8:level=0[a]' % (
        ''.join(labs), len(labs), D, D - 2.5)
    trilha = '/tmp/vid/trilha_%s.m4a' % ver
    subprocess.run(['ffmpeg', '-v', 'error', '-y'] + ins + ['-filter_complex', fc, '-map', '[a]', '-c:a', 'aac',
                                                            '-b:a', '192k', trilha], check=True)
    out = '/tmp/vid/encontre-a_trailer_%s.mp4' % ver
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', mudo, '-i', trilha, '-c:v', 'copy', '-c:a', 'copy',
                    '-shortest', '-movflags', '+faststart', out], check=True)
    print(ver, 'duração %.1f' % D)
    return D


if __name__ == '__main__':
    for v in (sys.argv[1:] or ['v1', 'v2', 'v3']):
        montar(v)
