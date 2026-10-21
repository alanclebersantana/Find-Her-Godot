#!/usr/bin/env python3
"""Corta as folhas 2x2 de quadrinhos (tools/art_src/hq_*.jpg) em assets/comic/<id>.jpg."""
import os, subprocess, sys, shutil, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEETS = {
    'hq_emo1': ['cipo', 'mergulho', 'neve', 'pipoca'],
    'hq_emo2': ['picareta', 'cavalo', 'mina', 'toxico'],
    'hq_boss1': ['javali_a', None, 'gaviao_a', None],
    'hq_boss2': ['bagre_a', None, 'urso_a', None],
    'hq_tome1': ['javali_b', 'gaviao_b', 'bagre_b', 'urso_b'],
    'hq_vargas': ['vargas_a', 'vargas_b', None, None],
}
os.makedirs(os.path.join(ROOT, 'assets', 'comic'), exist_ok=True)
for sh, names in SHEETS.items():
    src = os.path.join(ROOT, 'tools', 'art_src', sh + '.jpg')
    if not os.path.exists(src):
        continue
    tmp = tempfile.mkdtemp()
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_panels.py'), src, os.path.join(tmp, 'p')], check=True, capture_output=True)
    for i, n in enumerate(names):
        if n:
            shutil.copy(os.path.join(tmp, 'p_%d.jpg' % i), os.path.join(ROOT, 'assets', 'comic', n + '.jpg'))
print(sorted(os.listdir(os.path.join(ROOT, 'assets', 'comic'))))
