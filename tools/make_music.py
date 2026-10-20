"""Compõe e grava as músicas, os ambientes e parte dos efeitos do Find Her com instrumentos reais
(amostras gravadas de piano, harpa, violoncelo, violino, flauta, clarinete, violão, xilofone,
contrabaixo, trompa e fagote — pacotes npm tonejs-instrument-*-mp3, licença MIT; amostras originais
do projeto nbrosowsky/tonejs-instruments, CC-BY 3.0).

Uso:
  mkdir -p /tmp/tj && cd /tmp/tj && for p in piano harp cello violin flute clarinet guitar-nylon \
     xylophone contrabass french-horn bassoon; do npm pack tonejs-instrument-$p-mp3; done
  for f in *.tgz; do mkdir -p ${f%.tgz}; tar xzf $f -C ${f%.tgz}; done
  python3 tools/make_music.py /tmp/tj
Saída: assets/audio/mus_*.ogg, amb_*.ogg e alguns efeitos .wav (requer numpy, scipy e ffmpeg).
"""
import glob, os, re, subprocess, sys
import numpy as np
from scipy.signal import fftconvolve

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
SRC = sys.argv[1] if len(sys.argv) > 1 else '/tmp/tj'
rng = np.random.default_rng(11)

# ----------------------------------------------------------------- amostras
NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}

def midi_of(name):
    m = re.match(r'^([A-G])(s|#|b)?(-?\d)$', name)
    if not m:
        return None
    n = NOTE[m.group(1)] + (1 if m.group(2) in ('s', '#') else -1 if m.group(2) == 'b' else 0)
    return n + 12 * (int(m.group(3)) + 1)

def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    pk = np.max(np.abs(x)) if len(x) else 1
    idx = np.argmax(np.abs(x) > pk * .02)          # corta o silêncio inicial
    x = x[max(0, idx - 40):]
    return x / (pk + 1e-9)

INST = {}
def inst(name):
    if name not in INST:
        d = {}
        for f in glob.glob(os.path.join(SRC, f'tonejs-instrument-{name}-mp3*', 'package', '*.mp3')):
            m = midi_of(os.path.basename(f)[:-4])
            if m is not None:
                d[m] = decode(f)
        if not d:
            raise SystemExit(f'amostras de {name} não encontradas em {SRC}')
        INST[name] = d
    return INST[name]

PAN = {'piano': 0, 'harp': -.35, 'cello': .3, 'violin': -.25, 'flute': .25, 'clarinet': .2, 'guitar-nylon': -.3,
       'xylophone': .35, 'contrabass': .1, 'french-horn': -.15, 'bassoon': .15}

class Track:
    def __init__(self, secs):
        self.n = int(secs * SR)
        self.buf = np.zeros((2, self.n + SR * 8))
        self.dry = np.zeros((2, self.n + SR * 8))

    def note(self, name, midi, t, dur, vel=.7, rel=.25, pan=None, dry=.0):
        d = inst(name)
        k = min(d, key=lambda m: abs(m - midi))
        s = d[k]
        ratio = 2 ** ((midi - k) / 12)
        ln = int((dur + rel) * SR)
        pos = np.arange(ln) * ratio
        pos = pos[pos < len(s) - 1]
        if len(pos) == 0:
            return
        y = np.interp(pos, np.arange(len(s)), s)
        e = np.ones(len(y))
        a = min(len(y), int(.004 * SR))
        e[:a] = np.linspace(0, 1, a)
        hold = int(dur * SR)
        if hold < len(y):
            r = len(y) - hold
            e[hold:] *= np.exp(-np.linspace(0, 6, r))
        y = y * e * vel
        p = PAN.get(name, 0) if pan is None else pan
        i = int(t * SR)
        end = min(i + len(y), self.buf.shape[1])
        y = y[:end - i]
        tgt = self.dry if dry else self.buf
        tgt[0, i:end] += y * np.sqrt((1 - p) / 2) * 1.41
        tgt[1, i:end] += y * np.sqrt((1 + p) / 2) * 1.41

    def raw(self, y, t, pan=0.0, dry=True):
        i = int(t * SR)
        end = min(i + len(y), self.buf.shape[1])
        y = y[:end - i]
        tgt = self.dry if dry else self.buf
        tgt[0, i:end] += y * np.sqrt((1 - pan) / 2) * 1.41
        tgt[1, i:end] += y * np.sqrt((1 + pan) / 2) * 1.41

    def render(self, wet=.32, room=2.2, loop=True):
        ir_n = int(room * SR)
        tt = np.arange(ir_n) / SR
        ir = np.stack([rng.standard_normal(ir_n), rng.standard_normal(ir_n)]) * np.exp(-tt * 6.9 / room)
        ir[:, :int(.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2, axis=1, keepdims=True))
        rev = np.stack([fftconvolve(self.buf[c], ir[c])[:self.buf.shape[1]] for c in range(2)])
        mix = self.buf + self.dry + rev * wet
        if loop:
            out = mix[:, :self.n].copy()
            tail = mix[:, self.n:]
            k = 0
            while k < tail.shape[1]:      # o rabo (reverberação) volta para o começo: emenda sem corte
                seg = tail[:, k:k + self.n]
                out[:, :seg.shape[1]] += seg
                k += self.n
        else:
            out = mix
            nz = np.where(np.max(np.abs(out), axis=0) > 1e-4)[0]
            out = out[:, :nz[-1] + SR // 4] if len(nz) else out
        pk = np.max(np.abs(out)) + 1e-9
        out = np.tanh(out / pk * 1.15) / np.tanh(1.15) * .89
        return out

def save_ogg(name, x, q=4):
    path = os.path.join(OUT, name + '.ogg')
    pcm = (np.clip(x.T, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-',
                    '-c:a', 'libvorbis', '-q:a', str(q), path], input=pcm, check=True)
    print('ok', name, f'{x.shape[1] / SR:.1f}s', os.path.getsize(path) // 1024, 'KB')

def save_wav(name, x):
    import wave
    m = x.mean(axis=0) if x.ndim == 2 else x
    m = m / (np.max(np.abs(m)) + 1e-9) * .9
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((m * 32767).astype('<i2').tobytes())
    print('ok', name + '.wav')

# ----------------------------------------------------------------- teoria
def P(s):
    """'E4' -> midi; aceita # e b"""
    return midi_of(s.replace('#', 's'))

def mel(s):
    """'E4:2 G4:1 r:1' -> [(beat, dur, midi|None)]"""
    out, b = [], 0.0
    for tok in s.split():
        n, d = tok.split(':')
        d = float(d)
        out.append((b, d, None if n == 'r' else P(n)))
        b += d
    return out

CH = {'': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10], 'sus': [0, 5, 7], 'dim': [0, 3, 6]}
def chord(sym, octave=3):
    m = re.match(r'^([A-G][#b]?)(.*)$', sym)
    root = P(m.group(1) + str(octave))
    return [root + i for i in CH[m.group(2)]]

def play_mel(T, name, notes, spb, t0=0, vel=.7, legato=1.0, octave=0, rel=.3, hum=0.0):
    for b, d, m in notes:
        if m is None:
            continue
        v = vel * (1 + rng.uniform(-.08, .08))
        T.note(name, m + 12 * octave, t0 + b * spb + rng.uniform(0, hum), d * spb * legato, v, rel)

# ----------------------------------------------------------------- tema da Lia (canção de ninar)
LIA = mel('E4:2 G4:1 A4:2 G4:1 E4:1 D4:1 C4:1 D4:3 '
          'E4:2 G4:1 A4:1 C5:1 B4:1 A4:1 G4:1 E4:1 G4:3 '
          'A4:2 C5:1 B4:2 G4:1 A4:1 G4:1 E4:1 D4:3 '
          'E4:2 G4:1 A4:1 G4:1 E4:1 D4:1 E4:1 D4:1 C4:3')
LIA_CH = 'C F C G C F Am G F Em Am G C F G C'.split()

def song_tema():
    bpm, bar = 80, 3
    spb = 60 / bpm
    T = Track(16 * bar * spb)
    play_mel(T, 'piano', LIA, spb, vel=.62, legato=1.0, rel=.8)
    for i, c in enumerate(LIA_CH):
        ch = chord(c, 3)
        t = i * bar * spb
        T.note('cello', ch[0] - 12, t, bar * spb * .98, .32, .6)
        for k, idx in enumerate([0, 1, 2, 1, 2, 0]):          # harpa em colcheias
            m = ch[idx] + (12 if k in (2, 4) else 0)
            T.note('harp', m, t + k * spb / 2, spb, .26 + (.08 if k == 0 else 0), 1.2)
        if i >= 8:
            T.note('violin', ch[2] + 12, t, bar * spb, .12, .8)
    return T.render(.34, 2.6)

def song_manha():
    bpm = 108
    spb = 60 / bpm
    chs = 'G D Em C G D C D Em C G D C D G G'.split()
    T = Track(16 * 4 * spb)
    for i, c in enumerate(chs):
        ch = chord(c, 3)
        t = i * 4 * spb
        tones = [ch[0], ch[2], ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[1] + 12, ch[0] + 12, ch[2]]
        for k, m in enumerate(tones):                          # violão dedilhado
            T.note('guitar-nylon', m, t + k * spb / 2 + rng.uniform(0, .01), spb * .9, .42 if k % 2 == 0 else .3, .5)
        for k in (0, 2):                                       # baixo
            T.note('cello', ch[0] - 12, t + k * spb, spb * .7, .3, .25)
    fl = mel('B4:1 D5:1 E5:1.5 D5:.5 B4:2 A4:2 G4:1 A4:1 B4:1 D5:1 A4:4 '
             'B4:1 D5:1 E5:1.5 G5:.5 F#5:1 E5:1 D5:2 E5:1 D5:1 B4:1 A4:1 G4:4 '
             'E5:2 D5:1 B4:1 C5:2 B4:1 A4:1 B4:1 A4:1 G4:1 A4:1 G4:4')
    play_mel(T, 'flute', fl, spb, t0=4 * 4 * spb, vel=.5, legato=.95, rel=.3)
    for i in (0, 2, 8, 10):                                    # brilhos de xilofone
        for k, m in enumerate(['D6', 'G6', 'B6']):
            T.note('xylophone', P(m), (i * 4 + 3 + k * .5) * spb, .4, .14)
    return T.render(.26, 1.8)

def song_tarde():
    bpm = 92
    spb = 60 / bpm
    chs = 'D G D A D Bm G A G D Em A D G A D'.split()
    T = Track(16 * 4 * spb)
    for i, c in enumerate(chs):
        ch = chord(c, 3)
        t = i * 4 * spb
        T.note('cello', ch[0] - 12, t, 4 * spb * .98, .3, .6)
        pat = [ch[0], ch[1], ch[2], ch[0] + 12, ch[1] + 12, ch[0] + 12, ch[2], ch[1]]
        for k, m in enumerate(pat):
            T.note('harp', m + 12, t + k * spb / 2, spb, .24, 1.0)
    cl = mel('F#4:2 A4:1 B4:1 A4:3 r:1 F#4:1 E4:1 D4:1 E4:1 F#4:4 '
             'F#4:2 A4:1 B4:1 D5:1 C#5:1 B4:1 A4:1 B4:2 A4:1 F#4:1 A4:4 '
             'B4:2 D5:1 C#5:1 B4:2 A4:2 G4:1 F#4:1 E4:1 F#4:1 E4:4 '
             'F#4:2 A4:1 B4:1 A4:1 F#4:1 E4:1 D4:1 E4:2 F#4:1 E4:1 D4:4')
    play_mel(T, 'clarinet', cl, spb, vel=.45, legato=.96, rel=.35)
    return T.render(.3, 2.2)

def song_chuva():
    bpm = 72
    spb = 60 / bpm
    chs = 'Am G F E Am Dm G E F Dm E Am'.split()
    T = Track(12 * 4 * spb)
    for i, c in enumerate(chs):
        ch = chord(c, 3)
        t = i * 4 * spb
        T.note('cello', ch[0] - 12, t, 4 * spb, .34, .8)
        for k, m in enumerate([ch[0], ch[2], ch[1] + 12, ch[2]]):
            T.note('piano', m, t + k * spb, spb * 1.6, .28, .8)
    rh = mel('E5:2 D5:1 C5:1 B4:4 C5:2 B4:1 A4:1 G#4:4 A4:2 C5:1 E5:1 F5:2 E5:2 '
             'D5:1 C5:1 B4:1 C5:1 B4:4 A4:2 B4:1 C5:1 D5:2 C5:1 B4:1 A4:3 G#4:1 A4:4')
    play_mel(T, 'piano', rh, spb, vel=.5, rel=1.0, hum=.02)
    for k in range(10):                                        # gotas de harpa
        T.note('harp', P(['A5', 'C6', 'E6', 'B5', 'G5'][k % 5]), rng.uniform(0, 12 * 4 * spb - 2), 1, .12, 1.5)
    return T.render(.42, 3.0)

def song_noite():
    bpm, bar = 64, 3
    spb = 60 / bpm
    chs = 'Em C Em B Em C Em B Am G C B Em C B Em'.split()
    T = Track(16 * bar * spb)
    for i, c in enumerate(chs):
        ch = chord(c, 3)
        t = i * bar * spb
        T.note('contrabass', ch[0] - 12, t, bar * spb * .95, .3, .6)
        for k, idx in enumerate([0, 1, 2, 1, 2, 1]):
            T.note('harp', ch[idx] + (12 if k >= 2 else 0), t + k * spb / 2, spb, .22, 1.4)
    fl = mel('G4:2 B4:1 C5:2 B4:1 G4:1 F#4:1 E4:1 F#4:3 G4:2 B4:1 C5:1 E5:1 D5:1 C5:1 B4:1 G4:1 B4:3 '
             'C5:2 E5:1 D5:2 B4:1 C5:1 B4:1 G4:1 F#4:3 G4:2 B4:1 C5:1 B4:1 G4:1 F#4:1 G4:1 F#4:1 E4:3')
    play_mel(T, 'flute', fl, spb, vel=.4, legato=.97, rel=.4)
    play_mel(T, 'xylophone', fl[:8], spb, vel=.08, octave=1, rel=.5)   # caixinha de música, bem baixinho
    return T.render(.45, 3.2)

def song_tunel():
    bpm = 56
    spb = 60 / bpm
    T = Track(8 * 4 * spb)
    for i in range(8):
        t = i * 4 * spb
        T.note('cello', P('D2'), t, 4 * spb, .32, 1.0)
        if i % 2 == 1:
            T.note('cello', P('A2'), t + spb * 2, 2 * spb, .22, 1.0)
    bs = mel('D3:2 F3:2 E3:4 D3:2 C3:2 D3:4 F3:2 G3:1 F3:1 E3:4 D3:2 C#3:2 D3:4')
    play_mel(T, 'bassoon', bs, spb, vel=.36, legato=.95, rel=.5)
    for k, (b, m) in enumerate([(3, 'Eb6'), (9.5, 'A5'), (14, 'D6'), (21, 'Bb5'), (27.5, 'E6')]):
        T.note('harp', P(m), b * spb, 1, .14, 2)
    for b in (0, 16):
        for m in ('D2', 'A2', 'Eb3'):
            T.note('piano', P(m), b * spb, 3 * spb, .2, 1.5)
    return T.render(.55, 3.6)

def drum_kick():
    n = int(.35 * SR); t = np.arange(n) / SR
    f = 50 + 90 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * .9

def drum_snare():
    n = int(.25 * SR); t = np.arange(n) / SR
    nz = rng.standard_normal(n)
    nz = np.convolve(nz, [1, -1], 'same')
    return (nz * .35 + np.sin(2 * np.pi * 190 * t) * .5) * np.exp(-t * 18)

def drum_hat():
    n = int(.06 * SR); t = np.arange(n) / SR
    nz = np.convolve(rng.standard_normal(n), [1, -2, 1], 'same')
    return nz * np.exp(-t * 70) * .12

def drum_tom():
    n = int(.6 * SR); t = np.arange(n) / SR
    f = 70 + 40 * np.exp(-t * 12)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5) * .8

def song_perseguicao():
    bpm = 148
    spb = 60 / bpm
    chs = 'Dm Dm Bb Bb Dm Dm Bb A Gm Gm A Dm Dm Dm Bb A'.split()
    T = Track(16 * 4 * spb)
    K, S, H, TM = drum_kick(), drum_snare(), drum_hat(), drum_tom()
    for i, c in enumerate(chs):
        ch = chord(c, 2)
        t = i * 4 * spb
        r = ch[0] + 12
        pat = [r, r, r + 12, r, ch[1] + 12, r, ch[2] + 12, r]
        for k, m in enumerate(pat):                            # ostinato em staccato
            T.note('cello', m, t + k * spb / 2, spb * .28, .5 if k % 2 == 0 else .38, .06)
        T.note('contrabass', ch[0], t, spb * 1.6, .45, .1)
        T.note('contrabass', ch[0], t + 2 * spb, spb * 1.6, .4, .1)
        if i % 2 == 0 or i >= 12:
            for m in chord(c, 3):
                T.note('french-horn', m, t, spb * 1.6, .3, .3)
        for k in range(8):
            T.raw(H, t + k * spb / 2, .3)
        T.raw(K, t); T.raw(K, t + 2.5 * spb)
        T.raw(S, t + spb, -.1); T.raw(S, t + 3 * spb, -.1)
        if i % 4 == 3:
            T.raw(TM, t + 3.5 * spb, .2); T.raw(TM * .8, t + 3.75 * spb, -.2)
    vl = mel('A4:1.5 A4:.5 D5:1 E5:1 F5:2 E5:1 D5:1 D5:1.5 C5:.5 Bb4:1 A4:1 A4:4 '
             'G4:1.5 A4:.5 Bb4:1 C5:1 D5:2 C5:1 Bb4:1 A4:1 Bb4:1 C#5:1 E5:1 D5:4')
    play_mel(T, 'violin', vl, spb, t0=4 * 4 * spb, vel=.5, legato=.9, rel=.15)
    play_mel(T, 'violin', vl[:12], spb, t0=12 * 4 * spb, vel=.45, legato=.9, rel=.15, octave=1)
    return T.render(.18, 1.4)

def song_vitoria():
    bpm = 70
    spb = 60 / bpm
    chs = 'C Am F G C Am F C'.split()
    T = Track(8 * 4 * spb)
    for i, c in enumerate(chs):
        ch = chord(c, 3)
        t = i * 4 * spb
        T.note('cello', ch[0] - 12, t, 4 * spb, .3, 1)
        T.note('violin', ch[1] + 12, t, 4 * spb, .1, 1)
        for k, m in enumerate([ch[0], ch[1], ch[2], ch[1] + 12, ch[2] + 12, ch[0] + 24]):
            T.note('harp', m, t + k * spb * .5, 1.5, .2, 1.5)
    pm = mel('E5:2 G5:1 A5:1 G5:3 E5:1 F5:2 E5:1 D5:1 D5:4 E5:2 G5:1 A5:1 C6:2 B5:1 A5:1 G5:2 E5:1 D5:1 C5:4')
    play_mel(T, 'piano', pm, spb, vel=.5, rel=1.2)
    return T.render(.4, 3.0)

# ----------------------------------------------------------------- ambientes (loops)
def lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    from scipy.signal import lfilter
    return lfilter([1 - a], [1, -a], x)

def amb(name, secs, fill, wet=.25, room=1.6):
    T = Track(secs)
    fill(T, secs)
    save_ogg('amb_' + name, T.render(wet, room), 2)

def chirp(f0, f1, d, vib=0):
    n = int(d * SR); t = np.arange(n) / SR
    f = np.linspace(f0, f1, n) + vib * np.sin(2 * np.pi * 30 * t) * 300
    e = np.sin(np.pi * np.arange(n) / n) ** 2
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * e

def fill_birds(T, secs):
    wind = lp(rng.standard_normal(int(secs * SR)), 400) * .06
    T.raw(wind, 0, 0, True)
    t = .3
    while t < secs - 1:
        pan = rng.uniform(-.8, .8)
        kind = rng.integers(3)
        for k in range(rng.integers(2, 6)):
            if kind == 0:
                y = chirp(3200, 4600, .06)
            elif kind == 1:
                y = chirp(5200, 2800, .09)
            else:
                y = chirp(2600, 2700, .12, 1)
            T.raw(y * rng.uniform(.05, .12), t + k * rng.uniform(.08, .14), pan, False)
        t += rng.uniform(.6, 1.8)

def fill_crickets(T, secs):
    for c in range(4):
        f = rng.uniform(3900, 4900)
        rate = rng.uniform(.55, .9)
        pan = rng.uniform(-.9, .9)
        t = rng.uniform(0, rate)
        while t < secs - .3:
            for k in range(3):
                n = int(.035 * SR); tt = np.arange(n) / SR
                y = np.sin(2 * np.pi * f * tt) * np.sin(np.pi * np.arange(n) / n) * .05
                T.raw(y, t + k * .05, pan, False)
            t += rate
    T.raw(lp(rng.standard_normal(int(secs * SR)), 300) * .05, 0, 0, True)

def fill_frogs(T, secs):
    t = .2
    while t < secs - 1:
        f = rng.uniform(150, 260)
        n = int(rng.uniform(.18, .32) * SR); tt = np.arange(n) / SR
        pulse = (np.sin(2 * np.pi * 28 * tt) > 0).astype(float)
        saw = 2 * ((f * tt) % 1) - 1
        y = lp(saw * pulse, 900) * np.sin(np.pi * np.arange(n) / n) * .2
        T.raw(y, t, rng.uniform(-.8, .8), False)
        if rng.random() < .5:
            T.raw(y * .7, t + .35, rng.uniform(-.8, .8), False)
        t += rng.uniform(.9, 2.4)
    T.raw(lp(rng.standard_normal(int(secs * SR)), 250) * .05, 0, 0, True)

def fill_wind(T, secs):
    n = int(secs * SR)
    x = lp(rng.standard_normal(n), 500)
    tt = np.arange(n) / SR
    m = .55 + .45 * np.sin(2 * np.pi * tt / secs * 2) * np.sin(2 * np.pi * tt / secs * 3 + 1)
    T.raw(x * m * .16, 0, -.2, True)
    T.raw(lp(rng.standard_normal(n), 1200) * m[::-1] * .05, 0, .3, True)

def fill_cave(T, secs):
    n = int(secs * SR)
    T.raw(lp(lp(rng.standard_normal(n), 120), 120) * .5, 0, 0, True)
    t = .4
    while t < secs - 1:
        d = int(.07 * SR); tt = np.arange(d) / SR
        f0 = rng.uniform(900, 1700)
        f = f0 * np.exp(-tt * 9)
        y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 40) * .25
        T.raw(y, t, rng.uniform(-.7, .7), False)
        t += rng.uniform(.7, 2.2)

# ----------------------------------------------------------------- efeitos com instrumentos
def sfx(name, secs, fill, wet=.2):
    T = Track(secs)
    fill(T)
    save_wav(name, T.render(wet, 1.2, loop=False))

if __name__ == '__main__':
    songs = {'tema': song_tema, 'manha': song_manha, 'tarde': song_tarde, 'chuva': song_chuva, 'noite': song_noite,
             'tunel': song_tunel, 'perseguicao': song_perseguicao, 'vitoria': song_vitoria}
    only = sys.argv[2:] if len(sys.argv) > 2 else None
    for k, f in songs.items():
        if only and k not in only:
            continue
        save_ogg('mus_' + k, f())
    if not only or 'amb' in only:
        amb('passaros', 12, fill_birds)
        amb('grilos', 8, fill_crickets)
        amb('sapos', 12, fill_frogs)
        amb('vento', 10, fill_wind, .1)
        amb('caverna', 12, fill_cave, .6, 2.6)
    if not only or 'sfx' in only:
        sfx('clue', 1.6, lambda T: [T.note('harp', P(m), i * .09, .8, .6, 1) for i, m in enumerate(['C5', 'E5', 'G5', 'C6'])])
        sfx('item', .9, lambda T: [T.note('xylophone', P(m), i * .08, .3, .6, .5) for i, m in enumerate(['G5', 'C6', 'E6'])])
        sfx('pen', .5, lambda T: T.note('xylophone', P('C7'), 0, .15, .5, .3))
        sfx('special', 1.8, lambda T: ([T.note('harp', P(m), i * .05, .6, .5, 1) for i, m in enumerate(['C5', 'D5', 'E5', 'G5', 'A5', 'C6', 'D6', 'E6'])],
                                       T.note('xylophone', P('G6'), .45, .4, .5, .6)))
        sfx('door', 2.2, lambda T: ([T.note('french-horn', P(m), 0, 1.2, .5, .6) for m in ('C3', 'G3', 'E4')],
                                    [T.note('harp', P(m), .3 + i * .1, 1, .4, 1) for i, m in enumerate(['C5', 'E5', 'G5', 'C6'])]))
        sfx('combine', 1.0, lambda T: [T.note('guitar-nylon', P(m), i * .025, .7, .6, .4) for i, m in enumerate(['C3', 'G3', 'C4', 'E4', 'G4', 'C5'])])
        sfx('die', 1.8, lambda T: [T.note('piano', P(m), i * .2, .5, .6, 1) for i, m in enumerate(['E4', 'D4', 'C4', 'A3', 'G#3'])])
        sfx('fire', 1.4, lambda T: ([T.note('harp', P(m), i * .07, .6, .45, 1) for i, m in enumerate(['G4', 'C5', 'E5'])],
                                    T.raw(lp(rng.standard_normal(int(.6 * SR)), 900) * np.linspace(.3, 0, int(.6 * SR)), 0)))
