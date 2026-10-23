#!/usr/bin/env python3
"""Gera assets/data/level3.json — Episódio 2, epílogo jogável: A fuga da Isis.

A Isis (pequena: cabe nos buracos, pula mais baixo, sem pulo duplo) foge do quarto de pedra
por uma fresta, passa escondida pelo lampião do Vargas (abaixada atrás de caixotes e barris),
deixa lápis pelo caminho e, quase na saída, o Vargas a pega.

Rodar:  python3 tools/gen_level3.py
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GY = 500
L = {
    "name": "A Fuga da Isis",
    "theme": "mine", "seed": 11, "weather": "limpo", "top": -300, "bottom": 1000, "under": 640,
    "spawn": {"x": 170, "y": 500}, "combat": "stomp", "time": 300, "results": 1, "isis": 1,
    "introSub": "EPISÓDIO 2 · EPÍLOGO",
    "intro": "Do outro lado da porta de ferro, a Isis achou uma fresta na parede do quarto de pedra. "
             "Ela é pequena: cabe nos buracos. Mas o Vargas anda pelos túneis com o lampião...",
    "introImg": "res://assets/ui/cut_isis_b.jpg",
    "introTitle": "A FUGA DA ISIS",
    "endTitle": "A FUGA DA ISIS",
    "periods": ["Quarto de pedra", "Túnel do lampião", "Prateleiras"],
    "clueIds": [],
    "rests": {},
    "sections": [], "darkZones": [], "caves": [], "solids": [], "swamp": [], "lily": [], "mud": [],
    "climb": [], "entrances": [], "bushes": [], "items": [], "locks": [], "clues": [], "specials": [],
    "drawings": [], "vines": [], "springs": [], "crates": [], "enemies": [], "coins": [], "clocks": [],
    "checks": [], "hints": [], "pits": [], "water": [], "mirrors": [], "crystals": [], "ghost": [],
    "secrets": [], "chalk": [], "plates": [], "traps": [], "decor": [], "bars": [], "oil": [],
    "cranks": [], "movers": [], "comics": [], "relics": [], "fireflies": [],
    "watchmen": [], "hides": [], "drops": [],
}
S = L["solids"]


def rock(x0, x1, y0, y1, ceil=False):
    d = {"t": "rockw", "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}
    if ceil:
        d["ceil"] = 1
    S.append(d)


def check(x, y=GY):
    L["checks"].append([x, y])


def hint(a, b, t, **kw):
    d = {"a": a, "b": b, "t": t}
    d.update(kw)
    L["hints"].append(d)


def hide(x, w, k="crate", h=48):
    L["hides"].append({"x": x, "w": w, "k": k, "h": h})


SPAN = 3500
L["sections"].append({"x": 0, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .45, "night": 1, "per": 0,
                      "tint": "rgba(60,35,10,.16)"})
L["sections"].append({"x": 620, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .5, "night": 1, "per": 1})
L["sections"].append({"x": 1900, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .5, "night": 1, "per": 2})
L["darkZones"].append({"x": 0, "w": SPAN, "dark": .7})
S.append({"t": "ground", "x": -200, "y": GY, "w": SPAN + 400, "h": 140})
rock(-200, SPAN + 200, -300, 130, True)

# o quarto de pedra: desenhos de giz da Isis nas paredes, a vela no banquinho
S.append({"t": "brickw", "x": -200, "y": 130, "w": 240, "h": GY - 130})
for x, k in [(90, "papai"), (170, "coracao"), (250, "sol"), (330, "estrela"), (400, "flor")]:
    L["chalk"].append({"x": x, "y": 400 if k != "sol" else 360, "k": k, "d": 1})
L["oil"].append([300, 468])
# a parede do quarto com uma fresta embaixo (30 px: a Isis passa em pé, um adulto não)
S.append({"t": "brickw", "x": 480, "y": 130, "w": 80, "h": GY - 30 - 130})
hint(260, 480, "Uma fresta embaixo da parede! A Isis é pequena: ela cabe. Vá para a direita.", yl=200)
L["drops"].append({"x": 610, "c": "#e04a3a", "msg": "A Isis deixou cair um lápis vermelho: o papai vai achar a trilha."})
check(640)

# túnel do lampião: o Vargas faz a ronda; abaixe (↓) atrás dos caixotes quando a luz vier
L["watchmen"].append({"x0": 980, "x1": 1500, "spd": .9, "any": 1, "vargas": 1})
hide(760, 66)
hide(1080, 46, "barrel", 54)
hide(1330, 70)
hint(680, 980, "O Vargas está fazendo a ronda com o lampião. Quando a luz vier, segure ↓ atrás de um caixote ou barril: escondida, ele não vê.", yl=200)
# buraco baixo: só abaixada (↓) ela passa
S.append({"t": "brickw", "x": 1600, "y": 130, "w": 240, "h": GY - 24 - 130})
hint(1500, 1620, "Um buraco bem baixinho: segure ↓ e passe engatinhando.", yl=200)
L["drops"].append({"x": 1860, "c": "#3a7ad8", "msg": "Mais um lápis no chão, o azul. Siga a trilha, papai!"})
check(1900)

# prateleiras: por cima o lampião não alcança
for x, y, w in [(1990, 455, 100), (2080, 410, 100), (2170, 365, 440), (2630, 410, 90)]:
    S.append({"t": "plat", "x": x, "y": y, "w": w, "trestle": 1})
L["watchmen"].append({"x0": 2260, "x1": 2700, "spd": 1.0, "any": 1, "vargas": 1})
hide(2350, 46, "barrel", 54)
hide(2560, 66)
hint(1950, 2150, "Suba nas prateleiras: lá em cima a luz do lampião não chega.", yl=200)
L["drops"].append({"x": 2450, "c": "#3aa04a", "msg": "Lápis verde: ela deixou um em cada lugar por onde passou."})
L["chalk"].append({"x": 2900, "y": 420, "k": "seta", "d": 1})
check(2860)

# a saída... e o Vargas
L["isisCatch"] = {"x": 3120}
L["door"] = {"x": SPAN - 220, "y": 410, "kind": "exit"}
L["spanX"] = SPAN
L["rails"] = [2900, SPAN]
L["solids"] = [s for s in S if s]
out = os.path.join(ROOT, "assets", "data", "level3.json")
json.dump(L, open(out, "w"), ensure_ascii=False, indent=1)
print("level3.json:", len(L["solids"]), "sólidos")
