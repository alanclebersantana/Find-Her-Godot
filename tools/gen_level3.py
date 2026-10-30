#!/usr/bin/env python3
"""Gera assets/data/level3.json — Episódio 3: O Covil do Vargas.

Atrás da porta de ferro com o V: o esconderijo do Vargas, a fundição onde ele derrete o ouro roubado.
O trem de carga saiu com a Isis pela passagem secreta; o Tomé segue os trilhos.

Trechos (cada um termina numa fogueira grande, menos o último):
  A  A fundição            0 .. 9200     metal derretido, vapor para planar, prensas, plataformas que andam
  B  O rio subterrâneo     9200 .. 18400 caverna escura; a descida de barco pelo rio, com quedas
  C  A cidade abandonada   18400 .. 27600 a vila velha dos mineiros enterrada na rocha: telhados tortos,
                                         cordas, telhas podres e a engrenagem gigante
  D  O cofre               27600 .. 33800 o salão do ouro: alavancas, placas, prensas, prateleiras
  E  A fuga ao amanhecer   33800 ..      o carrinho nos trilhos atrás do trem, saindo da montanha

Rodar:  python3 tools/gen_level3.py
"""
import json, math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GY = 500

L = {
    "name": "O Covil do Vargas",
    "theme": "mine", "seed": 11, "weather": "limpo", "top": -620, "bottom": 1150, "under": 640,
    "spawn": {"x": 190, "y": 500}, "combat": "stomp", "time": 520, "results": 1,
    "intro": "Atrás da porta de ferro fica o covil do Vargas: a fundição onde ele derrete o ouro roubado. "
             "O trem de carga saiu com a Isis pela passagem secreta. Siga os trilhos — e os lápis dela.",
    "introImg": "res://assets/ui/cut_ep2fim.jpg",
    "introSub": "EPISÓDIO 3",
    "endTitle": "FIM DO COVIL",
    "periods": ["A fundição", "O rio subterrâneo", "A cidade abandonada", "O cofre", "A fuga ao amanhecer"],
    "clueIds": [13, 14, 15, 16, 17, 18],
    "rests": {
        "1": ["FIM DA FUNDIÇÃO", "Ela me ajudava a acender o fogão de lenha, soprando as brasas com as bochechas cheias.",
              "O fogo daqui é ruim, filha. Mas eu passo por ele."],
        "2": ["FIM DO RIO", "A gente fazia barquinhos de papel e soltava no riacho depois da chuva. O dela sempre chegava primeiro.",
              "Desci o rio inteiro, Isis. O seu barquinho ganhou de novo."],
        "3": ["FIM DA CIDADE VELHA", "Ela inventava cidades inteiras no chão do quintal, com caixas de fósforo e tampinhas.",
              "Achei uma cidade de verdade, filha. Vazia sem você."],
        "4": ["FIM DO COFRE", "Ela guardava os tesouros dela numa lata de biscoito: pedrinhas, botões, um dente de leite.",
              "Todo esse ouro... e o único tesouro que eu quero está naquele trem."],
    },
    "sections": [], "darkZones": [], "caves": [], "solids": [], "swamp": [], "lily": [], "mud": [],
    "climb": [], "entrances": [], "bushes": [], "items": [], "locks": [], "clues": [], "specials": [],
    "drawings": [], "vines": [], "springs": [], "crates": [], "enemies": [], "coins": [], "clocks": [],
    "checks": [], "hints": [], "pits": [], "water": [], "mirrors": [], "crystals": [], "ghost": [],
    "secrets": [], "chalk": [], "plates": [], "traps": [], "decor": [], "bars": [], "oil": [],
    "cranks": [], "movers": [], "comics": [], "relics": [], "fireflies": [],
    "tocas": [], "coolers": [], "dog": {"x": 120, "y": 500, "free": 1},
}
S = L["solids"]


def ground(x0, x1, y=GY, h=None):
    S.append({"t": "ground", "x": x0, "y": y, "w": x1 - x0, "h": h if h is not None else (640 - y if y < 640 else 140)})


def rock(x0, x1, y0, y1, ceil=False):
    d = {"t": "rockw", "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}
    if ceil:
        d["ceil"] = 1
    S.append(d)


def plat(x, y, w, **kw):
    d = {"t": "plat", "x": x, "y": y, "w": w}
    d.update(kw)
    S.append(d)


def stone(x, top, w=70, bottom=640):
    S.append({"t": "stone", "x": x, "y": top, "w": w, "h": bottom - top})


def coins_line(x0, x1, y, step=44):
    x = x0
    while x <= x1:
        L["coins"].append([int(x), int(y)])
        x += step


def coins_arc(x0, x1, y, h, n=5):
    for i in range(n):
        u = i / (n - 1)
        L["coins"].append([int(x0 + (x1 - x0) * u), int(y - math.sin(u * math.pi) * h)])


def check(x, y=GY, rest=None):
    L["checks"].append([x, y] if rest is None else [x, y, "rest", rest])


def hint(a, b, t, **kw):
    d = {"a": a, "b": b, "t": t}
    d.update(kw)
    L["hints"].append(d)


def bat(x, cy, r, ceil_y):
    """morcego pendurado numa ponta de rocha que desce do teto"""
    L["enemies"].append({"k": "bat", "x": x, "y": cy, "cy": cy, "r": r})
    rock(x - 34, x + 34, ceil_y - 10, cy - 14, True)


def lava(x, w, y=530):
    """poço de metal derretido: cair nele é perder a vida (como o brejo tóxico, mas laranja e quente)"""
    L["swamp"].append({"x": x, "y": y, "w": w, "h": 640 - y, "lava": 1, "pit": 1})
    S.append({"t": "dirt", "x": x, "y": 600, "w": w, "h": 540, "deco": 1})


def steam(x, w=80, top=-40, pow_=1.0):
    """respiradouro de vapor: a corrente de ar quente deixa planar por cima do metal derretido"""
    L["traps"].append({"k": "wind", "smoke": 1, "steam": 1, "x": x, "y": top, "w": w, "h": 530 - top, "pow": pow_})


# ======================================================================
#  A · A FUNDIÇÃO  (0 .. 9200)
# ======================================================================
A1 = 9200
L["sections"].append({"x": 0, "song": "tunel", "bg": "fundicao", "gt": "mina", "dark": .4, "night": 1, "per": 0,
                      "tint": "rgba(255,110,30,.07)", "forge": 1})
L["darkZones"].append({"x": 0, "w": A1, "dark": .62})
rock(-200, 1500, -620, -40, True)
rock(1500, 2750, -620, -160, True)
rock(2750, 4400, -620, -60, True)
rock(4400, 6100, -620, -200, True)
rock(6100, A1, -620, -60, True)

# A1 · a entrada da fundição (logo atrás da porta de ferro do Episódio 2)
ground(-200, 1500)
S.append({"t": "wall", "x": -200, "y": -60, "w": 60, "h": 560})
L["crates"].append({"t": "break", "x": 560, "y": 462, "n": 5})
L["oil"].append([760, 468])
coins_line(260, 1000, 470)
L["clues"].append({"x": 1150, "y": 470, "id": 13})
hint(0, 700, "Episódio 3 · O covil do Vargas. Aqui ele derrete o ouro roubado. Siga os trilhos e os lápis da Isis!")
hint(800, 1300, "O Pipoca veio junto! Perto de um monte de terra revirada, toque ✦ USAR: ele fareja e cava o que estiver enterrado.")
L["coolers"] += [{"x": 1380, "y": 500}, {"x": 2080, "y": 500}, {"x": 4330, "y": 500}, {"x": 5015, "y": 420},
                 {"x": 5705, "y": 380}, {"x": 6200, "y": 500}]
hint(1300, 1480, "Que calor! Perto do metal derretido o Tomé esquenta (veja o termômetro). Passe pela névoa dos barris d'água para esfriar.")
check(1300)

# A2 · os primeiros poços de metal derretido: pilares de pedra e o vapor que sobe
lava(1500, 400)
stone(1600, 440)
stone(1760, 400)
coins_arc(1500, 1640, 420, 60, 4)
coins_arc(1640, 1800, 380, 60, 4)
ground(1900, 2200)
hint(1300, 1520, "Metal derretido! Não encoste: pule de pilar em pilar.")
lava(2200, 520)
steam(2410, 90, -60)
coins_line(2240, 2680, 300, 55)
L["specials"].append({"x": 2455, "y": 120, "c": "vermelho"})
hint(2050, 2220, "Um poço largo demais... mas o vapor quente sobe forte: pule nele e PLANE (segure PULAR).")
ground(2720, 4400)
check(2000)

# A3 · as prensas da fundição (sobem e descem no ritmo) e o martelo-pêndulo
L["traps"].append({"k": "spikes", "x": 3020, "y": GY, "w": 96, "per": 150, "ph": 0, "press": 1})
L["traps"].append({"k": "spikes", "x": 3280, "y": GY, "w": 96, "per": 150, "ph": 75, "press": 1})
L["traps"].append({"k": "axe", "x": 3760, "y": 230, "len": 200, "amp": .5, "per": 140, "ph": 0, "frame": 3680, "hammer": 1})
coins_line(2800, 2980, 470)
coins_line(3420, 3600, 470)
plat(3880, 380, 130, trestle=1)
L["drawings"].append({"x": 3945, "y": 346, "txt": "Um desenho da Isis: o papai de capacete, passando pelo fogo sem medo."})
L["drawings"].append({"x": 9580, "y": 470, "toca": 1, "txt": "Um desenho da Isis, enterrado pelo Pipoca? Não... ela escondeu aqui: o Pipoca de capa de herói, farejando o caminho."})
bat(4150, 120, [3950, 4350], -60)
hint(2800, 3000, "Prensas! Elas batem no ritmo: passe quando estiverem lá em cima.")
hint(3600, 3700, "O martelo da fundição balança: passe quando ele for para o outro lado.")
check(2820)
check(3500)

# A4 · o grande tanque: plataformas que vão e vêm sobre o metal derretido
lava(4400, 1700)
L["movers"].append({"k": "path", "x0": 4430, "x1": 4860, "y0": 450, "y1": 450, "w": 100, "per": 400})
stone(4960, 420, 110)
L["movers"].append({"k": "path", "x0": 5100, "x1": 5560, "y0": 430, "y1": 380, "w": 100, "per": 440})
stone(5660, 380, 90)
steam(5790, 80, -150, .9)
coins_line(4440, 4860, 400, 60)
coins_line(5110, 5560, 360, 60)
L["specials"].append({"x": 5005, "y": 300, "c": "laranja"})
hint(4250, 4420, "O tanque grande: espere a tábua chegar e pule nela. No fim, o vapor leva você por cima.")
check(4300)
ground(6100, A1)
check(6240)

# A5 · a porta de manivela, o caixote da placa e o portão de ferro
L["cranks"].append({"x": 6560, "y": GY, "gate": "cf1"})
S.append({"t": "pgate", "id": "cf1", "x": 6640, "y": 376, "w": 22, "h": 124, "crank": 1})
rock(6600, 6700, -620, 376)
hint(6400, 6650, "Porta de manivela: aperte USAR várias vezes seguidas para girar.")
L["enemies"].append({"k": "spider", "x": 6950, "y": 500, "top": 260, "r": [6950, 6950]})
coins_line(6720, 6900, 470)
L["crates"].append({"t": "push", "x": 7140, "y": 430, "w": 70, "h": 70})
S.append({"t": "dirt", "x": 7420, "y": 520, "w": 70, "h": 120})
ground(7490, A1)
# (o chão de baixo do buraco da placa)
for o in list(S):
    if o["t"] == "ground" and o["x"] == 6100:
        S.remove(o)
ground(6100, 7420)
L["plates"].append({"x": 7420, "y": 520, "w": 70, "gate": "gf1"})
S.append({"t": "pgate", "x": 7580, "y": -700, "w": 22, "h": 1200, "id": "gf1"})
hint(7060, 7420, "Empurre o caixote até o buraco da placa: o portão de ferro sobe.")
check(7000)
coins_line(7700, 8300, 470)
L["enemies"].append({"k": "fly", "x": 8000, "y": 380, "r": [7800, 8300], "cy": 380})
L["clues"].append({"x": 8420, "y": 470, "id": 14})
check(8100)
check(8820, GY, 1)

# ======================================================================
#  B · O RIO SUBTERRÂNEO  (9200 .. 18400)
# ======================================================================
B0, B1 = A1, 18400
L["sections"].append({"x": B0, "song": "tunel", "bg": "caverna", "gt": "mina", "dark": .5, "night": 1, "per": 1,
                      "tint": "rgba(20,70,130,.14)", "map": "rio"})
L["darkZones"].append({"x": B0, "w": B1 - B0, "dark": .7})
rock(B0, 10700, -620, -40, True)
ground(B0, 10640)
hint(B0, B0 + 600, "Água correndo dentro da rocha... um rio subterrâneo! Os trilhos acabam aqui: o resto é de barco.")
coins_line(B0 + 100, B0 + 900, 470)
bat(B0 + 700, 100, [B0 + 500, B0 + 900], -40)
L["specials"].append({"x": B0 + 1100, "y": 380, "c": "amarelo"})
plat(B0 + 1040, 420, 120, trestle=1)
L["oil"].append([B0 + 1300, 468])
# a grade de ferro antes do barco: abre quando a luz da lanterna chega no cristal lá no alto
S.append({"t": "bars", "x": 10560, "y": 380, "w": 24, "h": 120, "id": "crb1"})
rock(10540, 10610, -620, 380)
L["mirrors"] += [{"x": 10462, "y": 474, "s": 1}, {"x": 10462, "y": 150, "s": 0, "ceil": 1}]
L["crystals"].append({"x": 10524, "y": 150, "door": "crb1"})
hint(10280, 10540, "Uma grade... e um cristal lá no alto. Segure ✦ USAR para concentrar a luz da lanterna. Perto do espelho, ✦ USAR vira o espelho.")
L["tocas"].append({"x": B0 + 380, "y": 500, "id": 1, "dig": 1})
check(B0 + 150)
check(B0 + 1200)
L["raft"] = {"x": 10760, "x0": 10640, "x1": 17200, "y": 530, "spd": 5.2, "falls": [12900, 15300], "cave": 1,
             "obs": [{"k": "rock", "x": 11300}, {"k": "log", "x": 11850}, {"k": "net", "x": 12350},
                     {"k": "rock", "x": 13450}, {"k": "bridge", "x": 13950}, {"k": "rapid", "x": 14200, "w": 170},
                     {"k": "log", "x": 14550}, {"k": "rock", "x": 15800}, {"k": "net", "x": 16250},
                     {"k": "log", "x": 16600}, {"k": "rock", "x": 16950}],
             "cps": [13150, 15550]}
hint(10600, 10700, "Um barco velho amarrado na margem! Chegue nele para descer o rio.")
ground(17200, B1)
rock(17200, B1, -620, -40, True)
L["clues"].append({"x": 17700, "y": 470, "id": 15})
coins_line(17300, 18200, 470)
check(17350)
check(18000, GY, 2)

# ======================================================================
#  C · A CIDADE ABANDONADA  (18400 .. 27600)
# ======================================================================
C0 = B1
L["sections"].append({"x": C0, "song": "noite", "bg": "cidade", "gt": "vila", "night": 1, "dark": .45, "per": 2,
                      "tint": "rgba(25,30,60,.42)", "leaves": 4, "flock": "bats"})
L["darkZones"].append({"x": C0, "w": 9200, "dark": .55})
rock(C0, C0 + 9200, -620, -500, True)          # o teto da caverna enorme, lá no alto

HOUSE = [
    {"w": 421, "h": 515, "walk": [40, 380, 58], "sides": [[10, 40, 150], [380, 410, 150]], "chim": [290, 345, 5]},
    {"w": 461, "h": 483, "walk": [70, 420, 58], "sides": [[20, 70, 125], [420, 452, 125]], "chim": [85, 150, 3]},
    {"w": 490, "h": 476, "walk": [50, 440, 55], "sides": [[5, 50, 170], [440, 485, 170]], "chim": [100, 165, 0]},
]
ROOF_H = 24
houses = []


def house(x, v, sc, flip=False):
    hv = HOUSE[v]
    w = hv["w"] * sc
    top = GY - hv["h"] * sc

    def fx(a):
        return x + (w - a * sc if flip else a * sc)
    S.append({"t": "house", "x": round(x), "y": GY, "w": round(w), "v": v, "flip": flip, "deco": 1, "old": 1})
    xa, xb = sorted([fx(hv["walk"][0]), fx(hv["walk"][1])])
    wt = top + hv["walk"][2] * sc
    S.append({"t": "roof", "x": round(xa), "y": round(wt), "w": round(xb - xa), "h": ROOF_H, "walk": 1})
    for sd in hv["sides"]:
        a, b = sorted([fx(sd[0]), fx(sd[1])])
        st = top + sd[2] * sc
        S.append({"t": "roof", "x": round(a), "y": round(st), "w": round(b - a), "h": ROOF_H, "oneway": 1})
    ca, cb = sorted([fx(hv["chim"][0]), fx(hv["chim"][1])])
    ct = top + hv["chim"][2] * sc
    S.append({"t": "roof", "x": round(ca), "y": round(ct), "w": round(cb - ca), "h": round(wt - ct), "chim": 1, "hot": 0})
    info = {"x": x, "w": w, "wx0": xa, "wx1": xb, "wt": wt, "st": top + hv["sides"][0][2] * sc,
            "edge0": min(fx(hv["sides"][0][0]), fx(hv["sides"][1][1])),
            "edge1": max(fx(hv["sides"][0][0]), fx(hv["sides"][1][1])), "ch": (ca, cb, ct)}
    houses.append(info)
    return info


plan = [
    (60, 1, .62, False),     # 0
    (140, 0, .66, True),     # 1
    (330, 2, .62, False),    # 2  vão largo: corda
    (140, 1, .70, True),     # 3
    (300, 0, .58, False),    # 4  telhas podres no vão
    (140, 2, .66, True),     # 5
    (380, 1, .64, False),    # 6  corda sobre o desabamento
    (140, 0, .70, False),    # 7
    (150, 2, .62, True),     # 8
]
x = C0 + 160
for gap, v, sc, fl in plan:
    x += gap
    house(x, v, sc, fl)
    x += houses[-1]["w"]
CITY_END = round(x)
S.append({"t": "ground", "x": C0, "y": GY, "w": CITY_END + 200 - C0, "h": 140, "street": 1})
hint(C0, C0 + 500, "Uma cidade inteira enterrada na rocha: a vila velha dos mineiros. A rua desabou em vários lugares — vá pelos telhados!", yl=100)
check(C0 + 120)

# a rua desabou: buracos entre algumas casas (só os telhados levam adiante)
for i in [2, 4, 6]:
    a, b = houses[i - 1], houses[i]
    x0, x1 = a["x"] + a["w"] + 10, b["x"] - 10
    L["pits"].append([round(x0), round(x1)])

for i, h in enumerate(houses):
    coins_line(h["wx0"] + 20, h["wx1"] - 20, h["wt"] - 30, 52)

# escadas nas paredes
for i in [0, 3, 5, 7]:
    h = houses[i]
    L["climb"].append({"x": round(h["edge0"] - 30), "y": round(h["st"]), "w": 30, "h": round(GY - h["st"]), "kind": "ladder"})

# cordas esticadas sobre os vãos largos (2 e 6)
for i in [2, 6]:
    a, b = houses[i - 1], houses[i]
    L["bars"].append({"x0": round(a["wx1"] - 30), "x1": round(b["wx0"] + 30), "y": round(min(a["wt"], b["wt"]) + 30)})
    hint(round(a["wx1"] - 160), round(a["wx1"]), "Uma corda velha esticada: pule nela e vá pendurado. PULAR dá impulso para cima.", yl=-150)

# telhas podres no vão 3→4
a, b = houses[3], houses[4]
y = round(a["wt"])
x0 = a["wx1"]
span = b["wx0"] - x0
for k in range(3):
    S.append({"t": "plat", "x": round(x0 + 6 + k * (span - 12) / 3), "y": y, "w": round((span - 12) / 3 - 4), "crumble": 1, "tile": 1})
hint(round(a["wx1"] - 120), round(a["wx1"] + 60), "Telhas podres! Elas despencam logo depois que você pisa: não pare.", yl=-150)

# bichos: morcegos pendurados no teto alto e aranhas nas casas
for i in [1, 5, 8]:
    h = houses[i]
    cx = round((h["wx0"] + h["wx1"]) / 2)
    bat(cx, round(h["wt"]) - 150, [cx - 260, cx + 260], -500)
L["enemies"].append({"k": "spider", "x": round(houses[3]["x"] + houses[3]["w"] / 2), "y": GY, "top": 260,
                     "r": [round(houses[3]["x"] + houses[3]["w"] / 2)] * 2})


def hpos(i, u=.5):
    h = houses[i]
    return h["wx0"] + (h["wx1"] - h["wx0"]) * u, h["wt"]


x, y = hpos(1, .6)
L["specials"].append({"x": round(x), "y": round(y) - 30, "c": "verde"})
x, y = hpos(4, .5)
L["clues"].append({"x": round(x), "y": round(y) - 30, "id": 16})
x, y = hpos(7, .4)
L["drawings"].append({"x": round(x), "y": round(y) - 36, "txt": "Um desenho da Isis: uma cidade de casinhas tortas, com o papai e ela de mãos dadas na rua."})
for i, u in [(2, .3), (5, .5), (8, .7)]:
    x, y = hpos(i, u)
    check(round(x), round(y))

# a engrenagem gigante: as tábuas presas nos dentes levam o Tomé até a saída lá no alto
GEAR_X = CITY_END + 520
GEAR_HUB = 120
L["movers"].append({"k": "wheel", "x": GEAR_X, "y": GEAR_HUB, "r": 300, "n": 4, "w": 96, "spd": .0075,
                    "a0": math.pi / 4, "tower": 300, "gy": GY, "gear": 1, "lock": "gear1"})
L["locks"].append({"x": GEAR_X - 160, "y": 380, "w": 120, "h": 120, "id": "gear1", "kind": "mill", "need": "engrenagem",
                   "parts": ["engrenagem"], "short": "a engrenagem gigante",
                   "where": {"engrenagem": "enterrada na rua da cidade (o Pipoca fareja onde)"},
                   "pre": "A engrenagem gigante está parada: falta a engrenagem pequena do eixo.",
                   "place": "Vá até a engrenagem gigante e toque em ✦ USAR.", "use": "Toque em ✦ USAR para encaixar a engrenagem no eixo.",
                   "hint": "A engrenagem gigante está parada: falta a engrenagem pequena do eixo. O Pipoca está farejando alguma coisa na rua...",
                   "msg": "A engrenagem encaixou! A roda gigante voltou a girar: suba numa tábua."})
L["tocas"].append({"x": CITY_END + 90, "y": 500, "id": 2, "dig": 1})
L["items"].append({"x": CITY_END + 90, "y": 470, "id": "engrenagem", "toca": 2})
S.append({"t": "ground", "x": CITY_END + 200, "y": GY, "w": 700, "h": 140, "street": 1})
check(CITY_END + 260)
hint(CITY_END + 160, CITY_END + 460, "Uma engrenagem gigante, parada... falta uma peça no eixo. Pipoca, fareja!", yl=100)
PY = -150
HI0 = GEAR_X + 380
S.append({"t": "ground", "x": HI0, "y": PY, "w": 27600 - HI0, "h": 650})
coins_line(HI0 + 60, 27400, PY - 30, 60)
L["specials"].append({"x": HI0 + 300, "y": PY - 140, "c": "azul"})
plat(HI0 + 240, PY - 100, 120, trestle=1)
check(HI0 + 100, PY)
check(27300, PY, 3)

# ======================================================================
#  D · O COFRE  (27600 .. 33800)
# ======================================================================
D0, D1 = 27600, 33800
L["sections"].append({"x": D0, "song": "tunel", "bg": "cofre", "gt": "mina", "dark": .45, "night": 1, "per": 3,
                      "tint": "rgba(110,80,20,.18)"})
L["darkZones"].append({"x": D0, "w": D1 - D0, "dark": .6})
# o salão do cofre fica lá no alto: a entrada desce em degraus do barranco até o chão
S.append({"t": "ground", "x": D0, "y": PY, "w": 300, "h": 650})
for i, (sx, top) in enumerate([(D0 + 300, -60), (D0 + 440, 40), (D0 + 580, 140), (D0 + 720, 240), (D0 + 860, 340)]):
    S.append({"t": "stone", "x": sx, "y": top, "w": 140, "h": GY - top})
ground(D0 + 1000, D0 + 3560)
ground(D0 + 4600, D0 + 5200)
rock(D0, D1, -620, -300, True)
coins_line(D0 + 1050, D0 + 1500, 470)
check(D0 + 1100)

# D1 · as duas alavancas do portão do cofre
L["levers"] = {"y": GY, "list": [{"x": D0 + 1700}, {"x": D0 + 1780}], "gate": {"x": D0 + 1880, "y": 380, "w": 22, "h": 120}}
rock(D0 + 1850, D0 + 1940, -620, 380)
hint(D0 + 1500, D0 + 1860, "O portão do cofre: puxe as duas alavancas (USAR).")
coins_line(D0 + 1950, D0 + 2300, 470)
check(D0 + 1980)

# D2 · as prensas do ouro e o martelo
L["traps"].append({"k": "spikes", "x": D0 + 2400, "y": GY, "w": 96, "per": 140, "ph": 0, "press": 1})
L["traps"].append({"k": "spikes", "x": D0 + 2620, "y": GY, "w": 96, "per": 140, "ph": 70, "press": 1})
L["traps"].append({"k": "axe", "x": D0 + 3060, "y": 230, "len": 200, "amp": .5, "per": 130, "ph": 30, "frame": D0 + 2980, "hammer": 1})
L["specials"].append({"x": D0 + 2565, "y": 300, "c": "roxo"})
plat(D0 + 2510, 380, 110, trestle=1)
L["clues"].append({"x": D0 + 3300, "y": 470, "id": 17})
check(D0 + 3250)

# D3 · prateleiras do ouro (algumas podres) até o alto, e a descida
L["items"].append({"x": D0 + 3420, "y": 470, "id": "ima"})
L["bars"].append({"x0": D0 + 4190, "x1": D0 + 4600, "y": 236, "mag": 1})
hint(D0 + 3360, D0 + 3440, "Um ímã de ferro enorme! Ele gruda em ferro... como naquelas vigas lá na frente.")
hint(D0 + 3980, D0 + 4160, "Vigas de ferro sobre o ouro derretido: pule nelas e vá pendurado pelo ímã. No fim, solte (↓) em cima da prateleira.", yl=-120)
for x, y, w, kw in [(3500, 440, 110, {}), (3640, 380, 110, {}), (3780, 320, 140, {"crumble": 1}),
                    (3960, 280, 200, {}), (4520, 440, 110, {})]:
    d = {"t": "plat", "x": D0 + x, "y": y, "w": w, "trestle": 1}
    d.update(kw)
    S.append(d)
lava(D0 + 3560, 1040)          # ouro derretido escorrendo pelo chão do cofre
coins_line(D0 + 3980, D0 + 4140, 250, 40)
L["drawings"].append({"x": D0 + 4060, "y": 246, "txt": "Um desenho da Isis: uma montanha de ouro, e ela e o papai indo embora de mãos dadas, sem olhar para trás."})
hint(D0 + 3460, D0 + 3530, "Ouro derretido no chão do cofre! Vá pelas prateleiras — cuidado com a podre.")
check(D0 + 4700)

# D4 · o caixote e a placa do último portão
L["crates"].append({"t": "push", "x": D0 + 4900, "y": 430, "w": 70, "h": 70})
S.append({"t": "dirt", "x": D0 + 5200, "y": 520, "w": 70, "h": 120})
L["plates"].append({"x": D0 + 5200, "y": 520, "w": 70, "gate": "gc1"})
ground(D0 + 5270, D1)
S.append({"t": "pgate", "x": D0 + 5370, "y": -700, "w": 22, "h": 1200, "id": "gc1"})
hint(D0 + 4800, D0 + 5200, "O último portão: empurre o caixote até a placa.")
L["clues"].append({"x": D0 + 5600, "y": 470, "id": 18})
coins_line(D0 + 5450, D0 + 5900, 470)
check(D0 + 5480)

# ======================================================================
#  E · A FUGA AO AMANHECER  (o carrinho atrás do trem)
# ======================================================================
E0 = D1
L["sections"].append({"x": E0, "song": "tema", "bg": "amanhecer", "per": 4, "tint": "rgba(255,170,130,.08)", "dawn": 1})
CART_X = E0 + 200
ground(D1, CART_X + 400)
check(E0 + 60, GY, 4)
L["sled"] = {"x": CART_X, "x1": CART_X + 1500, "y": GY, "tx0": 60000, "len": 7000, "skin": "cart", "vargas": 1, "dawn": 1,
             "endMsg": "Os trilhos saíram da montanha... o trem do Vargas parou na estação velha, lá na frente!",
             "pts": [[0, 300], [400, 300], [900, 360], [1300, 380], [1900, 460], [2300, 470], [2900, 540], [3300, 560],
                     [3900, 620], [4300, 630], [4900, 700], [5300, 720], [5900, 780], [6400, 790], [7000, 795]],
             "obs": [{"k": "rock", "u": 800}, {"k": "branch", "u": 1600}, {"k": "crack", "u": 2400, "w": 90},
                     {"k": "log", "u": 3200}, {"k": "rock", "u": 3900}, {"k": "branch", "u": 4600},
                     {"k": "crack", "u": 5300, "w": 100}, {"k": "log", "u": 5900}, {"k": "rock", "u": 6500}]}
hint(E0 - 100, CART_X + 60, "Um carrinho nos trilhos da passagem secreta! Suba nele e vá atrás do trem.")
F0 = CART_X + 1500
ground(CART_X + 400, F0 + 1400)
rock(CART_X + 400, F0 - 200, -620, 500)
check(F0 + 60)
coins_line(F0 + 100, F0 + 900, 470)
L["door"] = {"x": F0 + 1100, "y": 410, "kind": "station"}
hint(F0, F0 + 900, "A estação velha... e o trem do Vargas parado nos trilhos. Vá até lá!")
L["spanX"] = F0 + 1400

# ----------------------------------------------------------------------
L["solids"] = [s for s in S if s]


def _fix_coin(c):
    for _ in range(12):
        moved = False
        for so in L["solids"]:
            if so.get("deco") or so["t"] in ("plat", "branch", "barrier", "pgate", "house"):
                continue
            if so["x"] - 14 <= c[0] <= so["x"] + so["w"] + 14 and so["y"] - 18 <= c[1] <= so["y"] + so.get("h", 0) + 8:
                if so.get("ceil"):
                    c[1] = int(so["y"] + so["h"] + 30)
                else:
                    c[1] = int(so["y"] - 30)
                moved = True
        if not moved:
            return


for c in L["coins"]:
    _fix_coin(c)
out = os.path.join(ROOT, "assets", "data", "level3.json")
json.dump(L, open(out, "w"), ensure_ascii=False, indent=1)
print("level3.json:", len(L["solids"]), "sólidos,", len(L["coins"]), "lápis, spanX", L["spanX"],
      "casas", len(houses), "cidade até", CITY_END, "engrenagem", GEAR_X)
