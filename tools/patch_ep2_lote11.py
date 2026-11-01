#!/usr/bin/env python3
"""Episódio 2 — caixas de escudo antes dos trechos perigosos e dos chefes (rodar uma vez sobre o level2.json)."""
import json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import shield_crates
P = os.path.join(ROOT, 'assets', 'data', 'level2.json')
L = json.load(open(P))
if L.get('_lote11'):
    print('já aplicado'); raise SystemExit
L['_lote11'] = 1
print('escudos', shield_crates.add(L, [7400, 14300, 19500, 21700, 28300]))
json.dump(L, open(P, 'w'), ensure_ascii=False, indent=1)
