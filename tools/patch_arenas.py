#!/usr/bin/env python3
"""Arenas trancadas (pacote de ação): grava "arenas" nos JSON das fases.
Cada arena: x0..x1 no chão y; ondas de inimigos [tipo, deslocamento a partir de x0, variação];
pedras e barris de pólvora espalhados pelo chão (deslocamentos a partir de x0).
Uso: python3 tools/patch_arenas.py"""
import json, os

ARENAS = {
    1: [
        {"name": "neve", "x0": 34490, "x1": 35210, "y": 500,
         "waves": [[["boar", 520], ["boar", 600]],
                   [["boar", 560, "elite"], ["crow", 200], ["crow", 520]],
                   [["boar", 600, "big"], ["boar", 160, "shield"]]],
         "rocks": [120, 360], "barrels": []},
        {"name": "penhasco", "x0": 70000, "x1": 70720, "y": -420,
         "waves": [[["bat", 200], ["bat", 520], ["boar", 600]],
                   [["boar", 560, "shield"], ["boar", 140], ["fly", 360]],
                   [["boar", 600, "big"], ["bat", 300, "elite"], ["bat", 450]]],
         "rocks": [100, 620], "barrels": [360]},
    ],
    2: [
        {"name": "mina", "x0": 1940, "x1": 2660, "y": 500,
         "waves": [[["fly", 300], ["fly", 500]],
                   [["bat", 200], ["bat", 520], ["spider", 360]],
                   [["boar", 600, "elite"], ["boar", 140], ["bat", 380]]],
         "rocks": [100], "barrels": [250, 560]},
        {"name": "moinho", "x0": 9900, "x1": 10620, "y": 500,
         "waves": [[["frog", 300], ["frog", 520]],
                   [["frog", 560, "elite"], ["fly", 200], ["fly", 450]],
                   [["frog", 600, "big"], ["crow", 300], ["frog", 140, "shield"]]],
         "rocks": [120, 620], "barrels": [380]},
        {"name": "tunel", "x0": 24548, "x1": 25268, "y": 500,
         "waves": [[["bat", 220], ["bat", 500]],
                   [["spider", 360], ["bat", 300, "elite"], ["boar", 620]],
                   [["boar", 600, "big"], ["boar", 140, "shield"], ["bat", 400]]],
         "rocks": [100], "barrels": [300, 520]},
    ],
    3: [
        {"name": "patio", "x0": 6040, "x1": 6680, "y": 500,
         "waves": [[["boar", 480], ["boar", 560]],
                   [["boar", 520, "shield"], ["crow", 160], ["crow", 460]],
                   [["boar", 540, "big"], ["boar", 120, "shield"], ["crow", 320, "elite"]]],
         "rocks": [100], "barrels": [320]},
        {"name": "patio2", "x0": 9540, "x1": 10180, "y": 500,
         "waves": [[["boar", 500, "shield"], ["boar", 140, "shield"]],
                   [["crow", 200, "elite"], ["crow", 440, "elite"], ["fly", 320]],
                   [["boar", 540, "big"], ["boar", 120, "elite"], ["fly", 320], ["crow", 400]]],
         "rocks": [80, 600], "barrels": [300]},
        {"name": "amanhecer", "x0": 28820, "x1": 29540, "y": 500,
         "waves": [[["boar", 520], ["boar", 600], ["crow", 300]],
                   [["boar", 600, "big"], ["crow", 200, "elite"], ["crow", 500, "elite"]],
                   [["boar", 160, "shield"], ["boar", 600, "shield"], ["boar", 380, "big"], ["fly", 300]]],
         "rocks": [100, 640], "barrels": [260, 460]},
    ],
}

root = os.path.join(os.path.dirname(__file__), "..", "assets", "data")
for lv, arenas in ARENAS.items():
    p = os.path.join(root, "level%d.json" % lv)
    with open(p) as f:
        txt = f.read()
    L = json.loads(txt)
    L["arenas"] = arenas
    with open(p, "w") as f:
        json.dump(L, f, ensure_ascii=False, indent=1)
    print("level%d: %d arenas" % (lv, len(arenas)))
