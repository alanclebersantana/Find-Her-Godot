#!/usr/bin/env python3
"""Gera assets/data/level2.json — Episódio 2: As Profundezas da Mina.

Quatro trechos (cada um termina numa fogueira grande, menos o último):
  A  Boca da mina      0 .. 9800      escuro, lanterna, trilhos, porta de manivela, elevador, lago tóxico
  B  Vale do moinho    9800 .. 16800  campo ao entardecer; a vela nova faz o moinho girar e as tábuas
                                      das pás levam o Tomé até o alto do barranco
  C  Telhados da vila  16800 .. 27000 noite; de telhado em telhado, varais, fumaça das chaminés
  D  Profundezas       27000 .. 31600 porteira (chave), carrinho nos trilhos atrás do Vargas, porta do cofre

Rodar:  python3 tools/gen_level2.py
"""
import json, math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GY = 500

L = {
    "name": "As Profundezas da Mina",
    "theme": "mine", "seed": 7, "weather": "limpo", "top": -620, "bottom": 1150, "under": 640,
    "spawn": {"x": 190, "y": 500}, "combat": "stomp", "time": 480, "results": 1,
    "intro": "A trilha de lápis entra mina adentro. Desça pelos túneis, atravesse o vale do moinho e os "
             "telhados da vila dos mineiros. O Vargas está levando a Isis para o fundo da mina.",
    "introImg": "res://assets/ui/cut_ep2_a.jpg",
    "endTitle": "FIM DAS PROFUNDEZAS",
    "periods": ["Boca da mina", "Vale do moinho", "Telhados da vila", "Profundezas"],
    "clueIds": [7, 8, 9, 10, 11, 12],
    "rests": {
        "1": ["FIM DA BOCA DA MINA", "Ela tinha medo do escuro. Eu deixava a lanterna acesa na porta do quarto.", "Estou com a lanterna, filha. O escuro não vence a gente."],
        "2": ["FIM DO VALE", "No domingo a gente ia ver o moinho girar. Ela contava as voltas até dormir no meu colo.", "Mais uma volta, Isis. Estou chegando."],
        "3": ["FIM DOS TELHADOS", "Ela subia no telhado do galpão para ver as estrelas. Eu fingia que brigava.", "Lá embaixo, nos trilhos. Aguenta firme, filha."],
    },
    "sections": [], "darkZones": [], "caves": [], "solids": [], "swamp": [], "lily": [], "mud": [],
    "climb": [], "entrances": [], "bushes": [], "items": [], "locks": [], "clues": [], "specials": [],
    "drawings": [], "vines": [], "springs": [], "crates": [], "enemies": [], "coins": [], "clocks": [],
    "checks": [], "hints": [], "pits": [], "water": [], "mirrors": [], "crystals": [], "ghost": [],
    "secrets": [], "chalk": [], "plates": [], "traps": [], "decor": [], "bars": [], "oil": [],
    "cranks": [], "movers": [], "comics": [], "relics": [], "fireflies": [],
}
S = L["solids"]


def ground(x0, x1, y=GY, h=None):
    S.append({"t": "ground", "x": x0, "y": y, "w": x1 - x0, "h": h if h is not None else (640 - y if y < 640 else 140)})


def rock(x0, x1, y0, y1, ceil=False):
    """maciço de rocha da mina (teto ou parede)"""
    d = {"t": "rockw", "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}
    if ceil:
        d["ceil"] = 1
    S.append(d)


def plat(x, y, w, **kw):
    d = {"t": "plat", "x": x, "y": y, "w": w}
    d.update(kw)
    S.append(d)


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


def lake(x, w, stake_x):
    """lago de veneno com estaca: o mergulho na estaca baixa a ponte"""
    L["swamp"].append({"x": x, "y": 530, "w": w, "h": 110, "fumes": 1, "pit": 1})
    S.append({"t": "dirt", "x": x, "y": 560, "w": w, "h": 580, "deco": 1})
    L.setdefault("slam", {"stakes": [], "seesaw": [], "fruit": []})
    L["slam"]["stakes"].append({"x": stake_x, "y": GY, "bridge": {"x": x, "y": GY, "w": w}})


# ======================================================================
#  A · BOCA DA MINA  (0 .. 9800)
# ======================================================================
L["sections"].append({"x": 0, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .5, "night": 1, "per": 0,
                      "tint": "rgba(60,35,10,.16)"})
L["darkZones"].append({"x": 0, "w": 9800, "dark": .82})
# (sem "tunnel": o teto baixo do túnel do Episódio 1 cobriria as galerias altas)
# teto de rocha ao longo de quase todo o trecho (com aberturas mais altas)
rock(-200, 1350, -620, 40, True)
rock(1350, 2750, -620, -40, True)
rock(2750, 4180, -620, 40, True)
rock(4180, 4380, -620, -220, True)
rock(4380, 9800, -620, -160, True)

# A1: o salão de entrada
ground(-200, 1400)
L["crates"].append({"t": "break", "x": 640, "y": 462, "n": 5})
L["chalk"].append({"x": 760, "y": 440, "k": "seta", "d": 1})
plat(900, 400, 130, trestle=1)
coins_line(300, 860, 470)
coins_line(920, 1010, 370, 40)
L["clues"].append({"x": 1220, "y": 470, "id": 7})
L["oil"].append([1100, 468])
hint(0, 700, "Episódio 2 · A boca da mina. Siga os lápis da Isis pelos trilhos. A lanterna clareia o caminho: pegue o óleo pelo caminho.")
check(1300)

# A2: o poço com cavaletes (tábuas sobre o vão)
L["pits"].append([1400, 1900])
plat(1450, 450, 96, trestle=1)
plat(1600, 410, 96, trestle=1)
plat(1760, 440, 96, trestle=1)
coins_arc(1430, 1560, 430, 50, 4)
coins_arc(1590, 1710, 390, 50, 4)
coins_arc(1740, 1880, 420, 50, 4)
L["specials"].append({"x": 1650, "y": 300, "c": "vermelho"})
L["enemies"].append({"k": "bat", "x": 1650, "y": 250, "cy": 250, "r": [1450, 1880]})
ground(1900, 3720)
hint(1300, 1500, "Cavaletes sobre o poço: pule de tábua em tábua. Cuidado com o morcego!")
check(2000)

# A3: porta de manivela e a porta da placa
L["cranks"].append({"x": 3020, "y": GY, "gate": "cg1"})
S.append({"t": "pgate", "id": "cg1", "x": 3100, "y": 376, "w": 22, "h": 124, "crank": 1})
rock(3060, 3170, -620, 376)
coins_line(2100, 2950, 470)
L["oil"].append([2700, 468])
hint(2850, 3110, "Porta de manivela: aperte USAR várias vezes seguidas para girar e a porta sobe.")
L["enemies"].append({"k": "spider", "x": 3380, "y": 500, "top": 300, "r": [3380, 3380]})
L["crates"].append({"t": "push", "x": 3480, "y": 430, "w": 70, "h": 70})
S.append({"t": "dirt", "x": 3720, "y": 520, "w": 70, "h": 120})
L["plates"].append({"x": 3720, "y": 520, "w": 70, "gate": "g1"})
ground(3790, 4272)
# poço do elevador (rasinho: dá para sair pulando se o elevador estiver lá em cima)
S.append({"t": "dirt", "x": 4272, "y": 590, "w": 108, "h": 50})
L["pits"].append([4272, 4380])
S.append({"t": "pgate", "x": 3880, "y": -700, "w": 22, "h": 1200, "id": "g1"})
hint(3420, 3760, "Empurre a caixa até o buraco da placa: o portão de ferro sobe.")
check(3250)
coins_line(3950, 4250, 470)

# A4: elevador da mina até a galeria de cima
rock(4380, 5700, 60, 500)                      # maciço (o chão de cima é o topo dele)
S.append({"t": "ground", "x": 4380, "y": 60, "w": 1320, "h": 30, "mine": 1})
L["movers"].append({"k": "lift", "x": 4280, "w": 96, "y0": 60, "y1": 500, "start": "bottom"})
hint(4100, 4380, "Elevador da mina: suba na gaiola e aperte USAR.")
check(4150)
L["items"].append({"x": 4760, "y": 36, "id": "corda"})
coins_line(4450, 5600, 30)
L["enemies"].append({"k": "bat", "x": 5100, "y": -60, "cy": -60, "r": [4700, 5500]})
L["specials"].append({"x": 5250, "y": -60, "c": "laranja"})
L["oil"].append([5450, 28])
L["drawings"].append({"x": 5560, "y": 26, "txt": "Um desenho da Isis: o papai de capacete, com a lanterna, descendo na gaiola."})
check(4600, 60)
# desce do alto (chão de baixo volta em 5700)
ground(5700, 5860)
lake(5860, 360, 5800)
ground(6220, 7480)
hint(5700, 5900, "Lago de veneno! Pule e mergulhe (↓ no ar) em cima da estaca: a ponte desce.")
check(5740)
coins_arc(5870, 6210, 450, 60, 7)

# A5: carrinhos parados e espinhos de pedra
S.append({"t": "cart", "x": 6520, "y": 446, "w": 84, "h": 54})
S.append({"t": "cart", "x": 6830, "y": 446, "w": 84, "h": 54})
plat(6950, 340, 120, trestle=1)
L["traps"].append({"k": "spikes", "x": 6640, "y": GY, "w": 96, "per": 150, "ph": 0})
coins_line(6300, 6500, 470)
coins_line(6530, 6600, 420, 35)
coins_line(6840, 6910, 420, 35)
coins_line(6970, 7060, 310, 40)
L["oil"].append([6400, 468])
L["drawings"].append({"x": 7010, "y": 306, "txt": "Um desenho da Isis: um carrinho de mina cheio de estrelas."})
check(7200)

# A6: a saída: degraus de pedra subindo e o portão das alavancas
for i, (sx, sh) in enumerate([(7480, 60), (7630, 130), (7780, 200), (7930, 270)]):
    S.append({"t": "stone", "x": sx, "y": GY - sh, "w": 150 if i < 3 else 140, "h": sh})
ground(7480, 9800)
S.append({"t": "ground", "x": 8070, "y": 230, "w": 520, "h": 270})
coins_arc(7480, 8070, 400, 160, 9)
coins_line(8100, 8560, 200)
L["enemies"].append({"k": "bat", "x": 8300, "y": 60, "cy": 60, "r": [8100, 8560]})
L["levers"] = {"y": GY, "list": [{"x": 8860}, {"x": 8930}], "gate": {"x": 9020, "y": 380, "w": 22, "h": 120}}
rock(8990, 9080, -620, 380)
hint(8700, 9000, "Duas alavancas: puxe as duas (USAR) para o portão subir.")
coins_line(8650, 8980, 470)
check(8650)
check(9450, GY, 1)
coins_line(9100, 9400, 470)

# ======================================================================
#  B · VALE DO MOINHO  (9800 .. 16800)
# ======================================================================
L["sections"].append({"x": 9800, "song": "tarde", "bg": "moinho", "per": 1, "tint": "rgba(255,160,70,.10)"})
ground(9800, 12650)
for x, s in []:
    L["decor"].append({"k": "pine", "x": x, "y": GY, "s": s})
hint(9800, 10300, "O vale do moinho. Lá longe, um moinho velho com as velas rasgadas...")
coins_line(9850, 10500, 470)
L["enemies"].append({"k": "crow", "x": 10800, "y": 300, "cy": 300, "r": [10500, 11200]})
L["traps"].append({"k": "flower", "x": 10950, "y": GY, "to": [11230, 200]})
S.append({"t": "stone", "x": 11180, "y": 200, "w": 110, "h": 300})
L["specials"].append({"x": 11235, "y": 150, "c": "amarelo"})
coins_arc(10960, 11220, 330, 120, 6)
check(10600)
# o celeiro: a lona está lá dentro (porta baixa: entre abaixado)
S.append({"t": "shed", "x": 11500, "y": 380, "w": 300, "h": 20})
S.append({"t": "wall", "x": 11500, "y": 380, "w": 20, "h": 96})
S.append({"t": "wall", "x": 11780, "y": 380, "w": 20, "h": 96})
L["items"].append({"x": 11650, "y": 476, "id": "lona"})
hint(11380, 11520, "O celeiro tem a porta baixa: segure ↓ para entrar abaixado.")
coins_line(11540, 11760, 470, 55)
L["clues"].append({"x": 12100, "y": 470, "id": 8})
L["enemies"].append({"k": "frog", "x": 12300, "y": GY, "r": [12200, 12450]})
check(12000)
# riacho: pedras para atravessar
L["water"].append({"x": 12650, "y": 520, "w": 420, "h": 160})
S.append({"t": "dirt", "x": 12650, "y": 680, "w": 420, "h": 460})
for sx in [12730, 12880]:
    S.append({"t": "stone", "x": sx, "y": 470, "w": 60, "h": 60})
coins_arc(12660, 13060, 420, 80, 7)
ground(13070, 14000)
L["enemies"].append({"k": "crow", "x": 13300, "y": 220, "cy": 220, "r": [13100, 13500]})
# O MOINHO: as tábuas nas pontas das pás só giram depois das velas novas
MILL_X, MILL_HUB = 13620, 113
L["movers"].append({"k": "wheel", "x": MILL_X, "y": MILL_HUB, "r": 300, "n": 4, "w": 96, "spd": .0075,
                    "a0": math.pi / 4, "lock": "mill1", "tower": 300, "gy": GY})
L["locks"].append({"x": MILL_X - 40, "y": 380, "w": 80, "h": 120, "id": "mill1", "kind": "mill",
                   "need": "vela", "parts": ["lona", "corda"],
                   "where": {"lona": "dentro do celeiro do vale (entre abaixado pela porta baixa)",
                             "corda": "na galeria de cima da mina (suba pelo elevador)"},
                   "pre": "As velas do moinho estão rasgadas: o vento passa direto.",
                   "place": "Vá até a porta do moinho e toque em ✦ USAR.",
                   "use": "Toque em ✦ USAR na porta do moinho para pôr a vela nova.",
                   "msg": "Vela nova! O vento pegou e as pás começaram a girar. Suba numa tábua e vá lá para cima!"})
L["comics"].append({"id": "moinho", "x": 13200})
hint(13250, 13650, "As tábuas presas nas pás do moinho só giram se ele tiver velas. Junte a lona com a corda na mochila.")
check(13300)
coins_arc(MILL_X - 300, MILL_X + 300, 120, 0, 2)
for k in range(10):
    a = math.pi / 2 + k * 2 * math.pi / 10
    L["coins"].append([int(MILL_X + math.cos(a) * 300), int(MILL_HUB + math.sin(a) * 300 - 40)])
# o alto do barranco (só se chega pelas pás)
S.append({"t": "ground", "x": 14000, "y": -150, "w": 2820, "h": 650})
hint(13960, 14200, "Pule da tábua para o alto do barranco quando ela passar perto!", yl=-100)
check(14100, -150)
coins_line(14100, 16700, -180, 60)
L["drawings"].append({"x": 14800, "y": -200, "txt": "Um desenho da Isis: o moinho girando, com o papai e ela de mãos dadas."})
L["enemies"].append({"k": "crow", "x": 15300, "y": -330, "cy": -330, "r": [14900, 15700]})
L["specials"].append({"x": 15900, "y": -260, "c": "verde"})
S.append({"t": "stone", "x": 15860, "y": -230, "w": 80, "h": 80})
check(16300, -150, 2)

# ======================================================================
#  C · TELHADOS DA VILA  (16800 .. 27000)
# ======================================================================
L["sections"].append({"x": 16800, "song": "noite", "bg": "vila", "gt": "vila", "night": 1, "dark": .35, "per": 2,
                      "tint": "rgba(20,28,70,.26)"})
L["comics"].append({"id": "telhados", "x": 16700})

# casas: (largura e altura da pintura, caminho do telhado [x0, x1, topo], abas [[x0, x1, topo]], chaminé)
HOUSE = [
    {"w": 421, "h": 515, "walk": [40, 380, 58], "sides": [[10, 40, 150], [380, 410, 150]], "chim": [290, 345, 5]},
    {"w": 461, "h": 483, "walk": [70, 420, 58], "sides": [[20, 70, 125], [420, 452, 125]], "chim": [85, 150, 3]},
    {"w": 490, "h": 476, "walk": [50, 440, 55], "sides": [[5, 50, 170], [440, 485, 170]], "chim": [100, 165, 0]},
]
houses = []


def house(x, v, sc, flip=False, smoke=False):
    hv = HOUSE[v]
    w = hv["w"] * sc
    top = GY - hv["h"] * sc

    def fx(a):
        return x + (w - a * sc if flip else a * sc)
    S.append({"t": "house", "x": round(x), "y": GY, "w": round(w), "v": v, "flip": flip, "deco": 1})
    xa, xb = sorted([fx(hv["walk"][0]), fx(hv["walk"][1])])
    wt = top + hv["walk"][2] * sc
    S.append({"t": "roof", "x": round(xa), "y": round(wt), "w": round(xb - xa), "h": round(GY - wt)})
    for sd in hv["sides"]:
        a, b = sorted([fx(sd[0]), fx(sd[1])])
        st = top + sd[2] * sc
        S.append({"t": "roof", "x": round(a), "y": round(st), "w": round(b - a), "h": round(GY - st)})
    ca, cb = sorted([fx(hv["chim"][0]), fx(hv["chim"][1])])
    ct = top + hv["chim"][2] * sc
    S.append({"t": "roof", "x": round(ca), "y": round(ct), "w": round(cb - ca), "h": round(wt - ct), "chim": 1})
    if smoke:
        L["traps"].append({"k": "wind", "smoke": 1, "x": round(ca) - 10, "y": round(ct) - 430, "w": round(cb - ca) + 20,
                           "h": 430, "pow": 1.0})
    info = {"x": x, "w": w, "wx0": xa, "wx1": xb, "wt": wt, "st": top + hv["sides"][0][2] * sc, "edge0": min(fx(hv["sides"][0][0]), fx(hv["sides"][1][1])),
            "edge1": max(fx(hv["sides"][0][0]), fx(hv["sides"][1][1])), "ch": (ca, cb, ct)}
    houses.append(info)
    return info


# primeira descida: do alto do barranco para o primeiro telhado
plan = [  # (gap antes, variante, escala, espelhada, fumaça)
    (40, 1, .62, False, False), (110, 0, .66, False, False), (90, 2, .58, True, False), (150, 1, .70, False, True),
    (260, 0, .60, True, False), (100, 2, .64, False, False), (120, 1, .58, True, True), (300, 0, .72, False, False),
    (110, 2, .60, False, False), (90, 1, .66, True, False), (140, 0, .62, False, True), (420, 2, .70, False, False),
    (100, 1, .60, False, False), (130, 0, .68, True, False), (100, 2, .62, False, True), (280, 1, .72, True, False),
    (110, 0, .60, False, False), (120, 2, .66, True, False), (100, 1, .62, False, False),
]
x = 16900
for gap, v, sc, fl, sm in plan:
    x += gap
    h = house(x, v, sc, fl, sm)
    x += h["w"]
VILLAGE_END = x
# a beira do barranco desce um degrau até o primeiro telhado
S.append({"t": "stone", "x": 16820, "y": -10, "w": 120, "h": 510})
hint(16820, 17200, "Os capangas do Vargas vigiam a rua. Vá por cima: de telhado em telhado!", yl=100)
check(16880, -10)

# lápis em cima dos telhados e arcos sobre os vãos
for i, h in enumerate(houses):
    coins_line(h["wx0"] + 20, h["wx1"] - 20, h["wt"] - 30, 52)
    if i + 1 < len(houses):
        n = houses[i + 1]
        coins_arc(h["wx1"] - 10, n["wx0"] + 10, min(h["wt"], n["wt"]) - 30, 70, 5)
    # escada na parede (para voltar da rua para a aba do telhado)
    if i > 0 and h["x"] - (houses[i - 1]["x"] + houses[i - 1]["w"]) < 380:
        lx = h["edge0"] - 30
        L["climb"].append({"x": round(lx), "y": round(h["st"]), "w": 30, "h": round(GY - h["st"]), "kind": "ladder"})

# varais nos vãos largos (ande pendurado) e a fumaça das chaminés para planar
for i in range(len(houses) - 1):
    a, b = houses[i], houses[i + 1]
    gap = b["wx0"] - a["wx1"]
    if gap > 330:
        y = min(a["wt"], b["wt"]) + 30
        L["bars"].append({"x0": round(a["wx1"] - 30), "x1": round(b["wx0"] + 30), "y": round(y), "clothes": 1})

# os vãos mais largos têm o esgoto embaixo (veneno): cair ali é perigoso
for i in range(len(houses) - 1):
    a, b = houses[i], houses[i + 1]
    if b["x"] - (a["x"] + a["w"]) >= 380:
        x0 = round(a["x"] + a["w"] + 20)
        x1 = round(b["x"] - 20)
        L["swamp"].append({"x": x0, "y": 530, "w": x1 - x0, "h": 110, "fumes": 1, "pit": 1})
        S.append({"t": "dirt", "x": x0, "y": 560, "w": x1 - x0, "h": 580, "deco": 1})

def hpos(i, u=.5):
    h = houses[i]
    return h["wx0"] + (h["wx1"] - h["wx0"]) * u, h["wt"]

# objetos e pistas nos telhados
x, y = hpos(4)
L["items"].append({"x": round(x), "y": round(y) - 24, "id": "chave_a"})
x, y = hpos(7, .3)
L["clues"].append({"x": round(x), "y": round(y) - 30, "id": 9})
x, y = hpos(9)
L["specials"].append({"x": round(x), "y": round(y) - 110, "c": "azul"})
x, y = hpos(13)
L["items"].append({"x": round(x), "y": round(y) - 24, "id": "chave_b"})
x, y = hpos(15, .6)
L["clues"].append({"x": round(x), "y": round(y) - 30, "id": 10})
x, y = hpos(11)
L["drawings"].append({"x": round(x), "y": round(y) - 36, "txt": "Um desenho da Isis: a vila de noite, com o papai pulando nos telhados."})
for i in [3, 9, 14]:
    x, y = hpos(i)
    L["enemies"].append({"k": "crow", "x": round(x), "y": round(y) - 160, "cy": round(y) - 160, "r": [round(x) - 300, round(x) + 300]})
for i in [2, 6, 10, 14, 17]:
    x, y = hpos(i, .3)
    check(round(x), round(y))
hint(round(houses[3]["x"]), round(houses[3]["x"] + 400), "Fumaça quente da chaminé: plane (segure PULAR no ar) em cima dela para subir.", yl=-200)

# fim da vila: desce para a rua, porteira da mina (chave)
gx = VILLAGE_END + 380
ground(16860, round(gx + 22))                  # a rua (pedras)
check(round(VILLAGE_END + 120), GY, 3)
S.append({"t": "pgate", "id": "vgate", "x": gx, "y": -700, "w": 22, "h": 1200, "crank": 1})
L["locks"].append({"x": gx - 60, "y": 380, "w": 80, "h": 120, "id": "vgate", "kind": "gate", "gate": "vgate",
                   "need": "chave", "parts": ["chave_a", "chave_b"],
                   "where": {"chave_a": "num telhado no começo da vila", "chave_b": "num telhado depois do esgoto largo"},
                   "pre": "A porteira da mina está trancada.",
                   "place": "Vá até a porteira da mina e toque em ✦ USAR.",
                   "use": "Toque em ✦ USAR na porteira para destrancar.",
                   "msg": "A chave girou! A porteira da mina se abriu."})
hint(round(gx - 300), round(gx + 10), "A porteira da mina: junte as duas metades da chave na mochila.")
coins_line(VILLAGE_END + 40, gx - 80, 470)

# ======================================================================
#  D · PROFUNDEZAS E O CARRINHO
# ======================================================================
D0 = round(gx + 40)
L["sections"].append({"x": D0, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .6, "night": 1, "per": 3,
                      "tint": "rgba(60,35,10,.2)"})
L["darkZones"].append({"x": D0, "w": 6000, "dark": .85})
ground(round(gx + 22), D0 + 1500)
rock(D0, D0 + 4000, -620, 120, True)
L["oil"].append([D0 + 200, 468])
L["clues"].append({"x": D0 + 600, "y": 470, "id": 11})
L["specials"].append({"x": D0 + 900, "y": 360, "c": "roxo"})
plat(D0 + 840, 400, 120, trestle=1)
coins_line(D0 + 80, D0 + 1100, 470)
L["enemies"].append({"k": "bat", "x": D0 + 700, "y": 260, "cy": 260, "r": [D0 + 400, D0 + 1100]})
check(D0 + 150)
CART_X = D0 + 1300
L["sled"] = {"x": CART_X, "x1": CART_X + 1500, "y": GY, "tx0": 60000, "len": 7000, "skin": "cart", "vargas": 1,
             "endMsg": "O carrinho bateu no fim dos trilhos. O Vargas sumiu por uma porta de ferro...",
             "pts": [[0, 300], [400, 300], [900, 380], [1300, 400], [1900, 470], [2300, 490], [2900, 560], [3300, 580],
                     [3900, 640], [4300, 660], [4900, 720], [5300, 740], [5900, 800], [6400, 810], [7000, 815]],
             "obs": [{"k": "rock", "u": 900}, {"k": "branch", "u": 1800}, {"k": "crack", "u": 2700, "w": 90},
                     {"k": "log", "u": 3600}, {"k": "branch", "u": 4500}, {"k": "crack", "u": 5400, "w": 100},
                     {"k": "rock", "u": 6200}]}
hint(CART_X - 300, CART_X + 60, "Um carrinho de mina! Toque em ✦ USAR para subir e ir atrás do Vargas.")
check(CART_X - 120)
# depois do carrinho: a porta do cofre
E0 = CART_X + 1500
rock(D0 + 1500, E0 - 200, -620, 500)          # rocha: até a porta do cofre, só pelos trilhos
ground(E0 - 200, E0 + 900)
rock(E0 - 200, E0 + 900, -620, 100, True)
check(E0 + 60)
L["clues"].append({"x": E0 + 400, "y": 470, "id": 12})
coins_line(E0 + 100, E0 + 600, 470)
L["door"] = {"x": E0 + 700, "y": 410, "kind": "vault"}
L["rails"] = [E0 - 200, E0 + 900]
L["spanX"] = E0 + 900
hint(E0, E0 + 600, "A porta de ferro do Vargas... Pegue a pista e vá até a porta.")

# ----------------------------------------------------------------------
L["solids"] = [s for s in S if s]
out = os.path.join(ROOT, "assets", "data", "level2.json")
json.dump(L, open(out, "w"), ensure_ascii=False, indent=1)
print("level2.json:", len(L["solids"]), "sólidos,", len(L["coins"]), "lápis, spanX", L["spanX"],
      "casas", len(houses), "vila até", round(VILLAGE_END))
