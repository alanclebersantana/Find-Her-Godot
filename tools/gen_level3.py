#!/usr/bin/env python3
"""Gera assets/data/level3.json — Episódio 3: O Covil do Vargas (a fortaleza na serra).

Atrás da porta de ferro com o V, um túnel sobe pela montanha até a fortaleza do Vargas, lá no alto
da serra. A Isis está num trem que vai sair da estação velha, do outro lado da fortaleza.

Trechos (cada um termina numa fogueira grande, menos o último):
  A  A trilha da serra    0 .. 6000      trilha de pedra à noite: degraus, pedras rolando, ponte podre,
                                          o caminho de cima (penhasco) ou o de baixo (túnel abaixado);
                                          a muralha: subir saltando entre as paredes OU entrar pelo bueiro
  B  O pátio dos vigias   6000 .. 12600  vigias com lampião e cães de guarda no pátio; abaixar atrás dos
                                          caixotes OU ir pelas passarelas lá em cima; o Pipoca cava a chave
  C  Os porões            12600 .. 21000 labirinto de três andares: passagens baixas, escadas, becos sem
                                          saída com prêmio, rachaduras para a picareta, espelhos e cristal,
                                          corda sobre os espinhos, e a cisterna
  D  As forjas            21000 .. 27600 calor, metal derretido, vapor, barris d'água, tábuas que andam,
                                          prensas, martelo, o ímã e as vigas de ferro
  E  As torres            27600 ..       a torre ao amanhecer: elevador, saltos entre paredes, ventania,
                                          a ponte que desaba, e a descida até a estação velha

Rodar:  python3 tools/gen_level3.py
"""
import json, math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GY = 500

L = {
    "name": "O Covil do Vargas",
    "theme": "mine", "seed": 11, "weather": "limpo", "top": -620, "bottom": 1150, "under": 640,
    "spawn": {"x": 190, "y": 500}, "combat": "stomp", "time": 560, "results": 1,
    "intro": "Atrás da porta de ferro, um túnel sobe pela montanha até a fortaleza do Vargas, no alto da serra. "
             "Do outro lado dela fica a estação velha — e o trem com a Isis. Siga os lápis dela.",
    "introImg": "res://assets/ui/cut_ep3_fort.jpg",
    "introSub": "EPISÓDIO 3",
    "endTitle": "FIM DO COVIL",
    "periods": ["A trilha da serra", "O pátio dos vigias", "Os porões", "As forjas", "As torres"],
    "clueIds": [13, 14, 15, 16, 17, 18],
    "rests": {
        "1": ["FIM DA TRILHA", "Ela me ajudava a acender o fogão de lenha, soprando as brasas com as bochechas cheias.",
              "Lá em cima tem fogo aceso, filha. Estou chegando."],
        "2": ["FIM DO PÁTIO", "A gente brincava de esconde-esconde no quintal. Ela sempre se escondia atrás da mesma pilha de lenha.",
              "Hoje fui eu que me escondi, Isis. E ninguém me achou."],
        "3": ["FIM DOS PORÕES", "Ela inventava cidades inteiras no chão do quarto, com caixas de fósforo e tampinhas, cheias de corredores.",
              "Passei por um labirinto de verdade, filha. Sem você não tem graça."],
        "4": ["FIM DAS FORJAS", "Ela guardava os tesouros dela numa lata de biscoito: pedrinhas, botões, um dente de leite.",
              "Todo esse ouro... e o único tesouro que eu quero está naquele trem."],
    },
    "sections": [], "darkZones": [], "caves": [], "solids": [], "swamp": [], "lily": [], "mud": [],
    "climb": [], "entrances": [], "bushes": [], "items": [], "locks": [], "clues": [], "specials": [],
    "drawings": [], "vines": [], "springs": [], "crates": [], "enemies": [], "coins": [], "clocks": [],
    "checks": [], "hints": [], "pits": [], "water": [], "mirrors": [], "crystals": [], "ghost": [],
    "secrets": [], "chalk": [], "plates": [], "traps": [], "decor": [], "bars": [], "oil": [],
    "cranks": [], "movers": [], "comics": [], "relics": [], "fireflies": [],
    "tocas": [], "coolers": [], "dog": {"x": 120, "y": 500, "free": 1},
    "watchmen": [], "dogs": [], "hides": [],
    "watchMsg": "Um vigia te pegou com o lampião! Você foi levado de volta. Abaixe (↓) atrás dos caixotes e barris, ou vá pelas passarelas lá em cima.",
}
S = L["solids"]


# ---------------------------------------------------------------- ajudantes
def ground(x0, x1, y=GY, h=None):
    S.append({"t": "ground", "x": x0, "y": y, "w": x1 - x0, "h": h if h is not None else (640 - y if y < 640 else 140)})


def wall(x0, x1, y0, y1, **kw):
    """muralha / laje de pedra da fortaleza (alvenaria)"""
    d = {"t": "brickw", "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}
    d.update(kw)
    S.append(d)


def rock(x0, x1, y0, y1, ceil=False):
    d = {"t": "rockw", "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}
    if ceil:
        d["ceil"] = 1
    S.append(d)


def cliff(x0, x1, y0, y1):
    S.append({"t": "cliff", "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0})


def stone(x, top, w=70, bottom=640):
    S.append({"t": "stone", "x": x, "y": top, "w": w, "h": bottom - top})


def plat(x, y, w, **kw):
    d = {"t": "plat", "x": x, "y": y, "w": w}
    d.update(kw)
    S.append(d)


def ladder(x, top, bottom):
    L["climb"].append({"x": x, "y": top, "w": 30, "h": bottom - top, "kind": "ladder"})


def coins_line(x0, x1, y, step=46):
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


def enemy(k, x, y=GY, **kw):
    d = {"k": k, "x": x, "y": y}
    d.update(kw)
    L["enemies"].append(d)


def bat(x, cy, r, ceil_y):
    """morcego pendurado numa ponta de rocha que desce do teto"""
    enemy("bat", x, cy, cy=cy, r=r)
    rock(x - 34, x + 34, ceil_y - 10, cy - 14, True)


def spider(x, floor, top):
    enemy("spider", x, floor, top=top, r=[x, x])


def lava(x, w, y=530):
    L["swamp"].append({"x": x, "y": y, "w": w, "h": 640 - y, "lava": 1, "pit": 1})
    S.append({"t": "dirt", "x": x, "y": 600, "w": w, "h": 540, "deco": 1})


def steam(x, w=80, top=-40, pow_=1.0):
    L["traps"].append({"k": "wind", "smoke": 1, "steam": 1, "x": x, "y": top, "w": w, "h": 530 - top, "pow": pow_})


def spikes(x, w=96, y=GY, per=150, ph=0, **kw):
    d = {"k": "spikes", "x": x, "y": y, "w": w, "per": per, "ph": ph}
    d.update(kw)
    L["traps"].append(d)


# ======================================================================
#  A · A TRILHA DA SERRA  (0 .. 6000)
# ======================================================================
A1 = 6000
L["sections"].append({"x": 0, "song": "noite", "bg": "muralha", "gt": "vila", "night": 1, "dark": .25, "per": 0,
                      "tint": "rgba(40,50,110,.10)", "leaves": 3})
ground(-200, 1100)
S.append({"t": "brickw", "x": -200, "y": -400, "w": 60, "h": 900})
hint(0, 700, "Episódio 3 · O covil do Vargas. A fortaleza dele fica lá no alto da serra. Siga os lápis da Isis!")
hint(700, 1050, "O Pipoca veio junto! Perto de um monte de terra revirada, toque ✦ USAR: ele fareja e cava o que estiver enterrado.")
coins_line(260, 1000, 470)
check(300)

# A1 · degraus de pedra subindo a serra
for i, (sx, top) in enumerate([(1100, 420), (1240, 340), (1380, 260)]):
    stone(sx, top, 140)
enemy("crow", 1500, -150, cy=-150, r=[1200, 1900])
coins_arc(1110, 1500, 380, 80, 5)
check(1050)

# A2 · CAMINHO DUPLO: por cima do penhasco (lápis vermelho, corvos) ou por baixo (túnel baixo, pista 13)
cliff(1520, 2560, 260, 474)            # o túnel por baixo tem 26 px: só passa abaixado
ground(1100, 2700)
hint(1380, 1560, "Dois caminhos: por cima do penhasco, ou pela passagem baixa embaixo dele (segure ↓ para ir abaixado).", yl=-120)
L["specials"].append({"x": 2050, "y": 120, "c": "vermelho"})
plat(1990, 170, 120)
enemy("crow", 2100, -80, cy=-80, r=[1700, 2500])
coins_line(1560, 2500, 230, 60)
coins_line(1600, 2480, 487, 70)
L["clues"].append({"x": 2200, "y": 486, "id": 18})

# A3 · pedras rolando ladeira abaixo
ground(2700, 3320)
L["traps"].append({"k": "roll", "x": 3310, "y": 500, "trig": 2900, "dir": -1, "vmax": 4.4, "end": 2700, "r": 30})
L["traps"].append({"k": "roll", "x": 3310, "y": 500, "trig": 3080, "dir": -1, "vmax": 4.8, "end": 2700, "r": 26})
hint(2600, 2800, "Pedras rolando da serra! Pule por cima delas.")
check(2620)
coins_line(2720, 3260, 470)

# A4 · ponte podre sobre o abismo
L["pits"].append([3320, 3720])
for i in range(4):
    plat(3340 + i * 95, 470, 70, crumble=1)
ground(3720, 4470)
hint(3220, 3360, "Tábuas podres: elas caem logo depois que você pisa. Não pare!")
enemy("boar", 4000, r=[3800, 4200])
coins_arc(3330, 3710, 440, 60, 6)
check(3760)

# A5 · a muralha: subir saltando entre as paredes OU entrar pelo bueiro
wall(4300, 4370, -170, 370)                # pilar de fora (passa-se por baixo dele)
wall(4470, 5700, -260, GY)                 # muralha (o alto é a passarela das ameias)
for k in range(9):
    wall(4480 + k * 130, 4540 + k * 130, -300, -260, deco=1)   # ameias (enfeite: não atrapalham)
hint(4100, 4300, "A muralha! Suba saltando de uma parede para a outra (pule, encoste na parede e pule de novo). "
                 "Ou entre pelo bueiro, ali no chão (↓).", yl=-140)
L["entrances"].append({"x": 4180, "y": 440, "w": 70, "h": 60, "to": [4260, 940], "label": "Entrou no bueiro: um túnel por baixo da muralha.", "look": "drain"})
# o túnel do bueiro (por baixo da muralha)
L["caves"].append({"x": 4200, "y": 760, "w": 1600, "h": 200})
S.append({"t": "dirt", "x": 4200, "y": 960, "w": 1600, "h": 80})
S.append({"t": "dirt", "x": 4180, "y": 740, "w": 1640, "h": 20})
S.append({"t": "dirt", "x": 4180, "y": 760, "w": 20, "h": 200})
S.append({"t": "dirt", "x": 5800, "y": 760, "w": 20, "h": 200})
S.append({"t": "dirt", "x": 4700, "y": 760, "w": 260, "h": 174})     # passagem baixa no túnel
spider(5300, 960, 770)
L["drawings"].append({"x": 5500, "y": 920, "txt": "Um desenho da Isis: o papai e o Pipoca entrando escondidos pelo bueiro do castelo."})
coins_line(4300, 5650, 930, 70)
L["entrances"].append({"x": 5690, "y": 900, "w": 70, "h": 60, "exit": 1, "to": [5760, GY]})
# lá em cima: a passarela das ameias e a escada para o pátio
coins_line(4560, 5600, -290, 70)
L["traps"].append({"k": "gust", "x": 4900, "y": -420, "w": 360, "h": 160, "per": 260, "on": 110, "ph": 0})
ladder(5710, -260, GY)
ground(5700, A1)
check(4320)
check(5800, GY, 1)

# ======================================================================
#  B · O PÁTIO DOS VIGIAS  (6000 .. 12600)
# ======================================================================
B0, B1 = A1, 12600
L["sections"].append({"x": B0, "song": "noite", "bg": "patio", "gt": "vila", "night": 1, "dark": .35, "per": 1,
                      "tint": "rgba(30,40,90,.12)"})
ground(B0, B1)
hint(B0 + 100, B0 + 500, "O pátio da fortaleza. Os vigias do Vargas rondam com o lampião: se a luz pegar o Tomé, ele volta "
                         "para a fogueira. Abaixe (↓) atrás dos caixotes e barris, ou vá pelas passarelas lá em cima.")
# B1 · vigia 1 e os esconderijos
L["watchmen"].append({"x0": 6700, "x1": 7700, "spd": 1.0, "any": 0})
for hx, k in [(6900, "crate"), (7260, "barrel"), (7620, "crate")]:
    L["hides"].append({"x": hx, "w": 66 if k == "crate" else 46, "k": k, "h": 48 if k == "crate" else 54})
coins_line(6500, 7900, 470, 70)
check(6300)
# passarela de cima (caminho alternativo): escada, tábuas, uma podre
ladder(6450, 250, GY)
plat(6420, 250, 300, trestle=1)
plat(6800, 250, 220)
plat(7100, 230, 160, crumble=1)
plat(7330, 230, 260)
plat(7660, 250, 440, trestle=1)
spider(7000, 250, 40)
coins_line(6460, 7900, 220, 60)
L["specials"].append({"x": 7420, "y": 140, "c": "laranja"})

# B2 · cães de guarda: pelo alto (caixotes empilhados) ou correndo
L["dogs"].append({"x": 8700, "r": [8300, 9200]})
plat(8150, 400, 120, trestle=1)
plat(8340, 310, 160, trestle=1)
plat(8640, 290, 180, trestle=1)
plat(8930, 300, 140, trestle=1)
plat(9150, 380, 140, trestle=1)
hint(8000, 8200, "Cão de guarda! Vá por cima dos andaimes.", yl=-120)
coins_line(8260, 9300, 260, 60)
check(8000)
check(9500)

# B3 · o jardim do pátio: o Pipoca acha a chave da porta dos porões
L["tocas"].append({"x": 10100, "y": GY, "id": 1, "dig": 1})
L["items"].append({"x": 10100, "y": 470, "id": "chave", "toca": 1})
L["clues"].append({"x": 9800, "y": 470, "id": 16})
hint(9800, 10050, "Terra revirada no jardim... Pipoca, fareja!")
# vigia 2 (o lampião vira mais rápido) e mais esconderijos
L["watchmen"].append({"x0": 10500, "x1": 11700, "spd": 1.3})
for hx, k in [(10700, "barrel"), (11050, "crate"), (11420, "barrel")]:
    L["hides"].append({"x": hx, "w": 66 if k == "crate" else 46, "k": k, "h": 48 if k == "crate" else 54})
coins_line(10400, 11900, 470, 70)
check(10300)
# a porta dos porões (trancada: a chave que o Pipoca achou)
S.append({"t": "pgate", "id": "dg1", "x": 12320, "y": -700, "w": 22, "h": 1200, "crank": 1})
wall(12290, 12380, -620, 380)
L["locks"].append({"x": 12200, "y": 380, "w": 90, "h": 120, "id": "dg1", "kind": "gate", "gate": "dg1", "need": "chave",
                   "parts": ["chave"], "short": "a porta dos porões",
                   "where": {"chave": "enterrada no jardim do pátio (o Pipoca fareja onde)"},
                   "pre": "A porta dos porões está trancada.", "place": "Vá até a porta dos porões e toque em ✦ USAR.",
                   "use": "Toque em ✦ USAR na porta para destrancar.", "msg": "A chave girou! A porta dos porões está subindo..."})
check(12000, GY, 2)

# ======================================================================
#  C · OS PORÕES  (12600 .. 21000)   — labirinto de três andares
#      térreo (chão 500) · meio (chão 280) · alto (chão 60); teto em -160
# ======================================================================
C0, C1 = B1, 21000
L["sections"].append({"x": C0, "song": "tunel", "bg": "poroes", "gt": "vila", "night": 1, "dark": .5, "per": 2,
                      "tint": "rgba(40,60,80,.10)"})
L["darkZones"].append({"x": C0, "w": C1 - C0, "dark": .62})
ground(C0, C1)
wall(C0, C1, -620, -160, ceil=1)                     # o teto dos porões
F1, F2 = 280, 60
hint(C0 + 60, C0 + 500, "Os porões: um labirinto de corredores em três andares. Tem caminho que não leva a lugar nenhum... "
                        "e tem prêmio escondido nos becos!")

# C1 · térreo: passagens baixas (abaixado) e morcegos
wall(12900, 13300, F1 + 40, 474)       # passagem baixa 1
wall(13600, 14000, F1 + 40, 474)       # passagem baixa 2
wall(12600, 14300, F1, F1 + 40)        # piso do andar do meio (por cima das passagens)
bat(13450, F1 + 140, [13350, 13560], F1 + 40)
coins_line(12900, 14000, 487, 70)
check(12720)
# a escada para o andar do meio
ladder(14370, F1, GY)
check(14250)
# térreo continua: o beco do Pipoca (desenho enterrado) e espinhos
wall(14400, 17870, F1, F1 + 40)        # piso do meio
spikes(14700, 100, per=140)
spikes(15100, 100, per=140, ph=70)
L["tocas"].append({"x": 15700, "y": GY, "id": 2, "dig": 1})
L["drawings"].append({"x": 15700, "y": 470, "toca": 2, "txt": "Um desenho da Isis, enterrado no porão: um labirinto, e no meio um coração."})
L["specials"].append({"x": 16100, "y": 380, "c": "amarelo"})
plat(16040, 420, 120, trestle=1)
wall(16400, 16470, F1 + 40, GY)        # fim do beco (sem saída pelo térreo)
coins_line(14500, 16300, 470, 70)
hint(14400, 14650, "Térreo: um beco... o Pipoca está farejando alguma coisa lá no fundo.")

# C2 · andar do meio: espelhos e cristal abrem a grade
wall(12600, 14700, F2, F2 + 40)        # piso do andar de cima = teto do meio (com os buracos das escadas)
wall(14760, 17540, F2, F2 + 40)
wall(17600, 19060, F2, F2 + 40)
S.append({"t": "bars", "x": 15900, "y": F1 - 120, "w": 24, "h": 120, "id": "crc1"})
wall(15880, 15950, F2 + 40, F1 - 120)
L["mirrors"] += [{"x": 15560, "y": F1 - 26, "s": 1}, {"x": 15560, "y": F2 + 70, "s": 0, "ceil": 1}]
L["crystals"].append({"x": 15860, "y": F2 + 70, "door": "crc1"})
hint(15200, 15500, "Uma grade... e um cristal lá no alto. Segure ✦ USAR para concentrar a luz da lanterna; perto do espelho, ✦ USAR vira o espelho.", yl=-200)
coins_line(14400, 15800, F1 - 30, 70)
check(14500, F1)
# depois da grade: rachaduras na parede (picareta) e a pista 17
S.append({"t": "crack", "x": 16300, "y": F2 + 40, "w": 60, "h": F1 - F2 - 40, "id": "cr1", "kind": "boulder", "msg": "Crack! A parede rachada virou cascalho."})
L["clues"].append({"x": 16700, "y": F1 - 30, "id": 17})
spider(16900, F1, F2 + 50)
coins_line(16000, 17500, F1 - 30, 70)
check(16050, F1)
hint(16150, 16300, "Parede rachada: chegue perto e use a picareta (⛏).")
# beco do meio que volta para cima (labirinto): escada para o andar de cima no começo
ladder(14730, F2, F1)
# o andar de cima, à esquerda: beco sem saída com a pista 15 (prêmio do labirinto)
L["clues"].append({"x": 13300, "y": F2 - 30, "id": 15})
coins_line(13000, 14600, F2 - 30, 70)
bat(13900, F2 - 110, [13700, 14100], -160)
wall(12600, 12700, -160, F2)
# o andar de cima, à direita: escada no fim do meio
ladder(17570, F2, F1)
check(17500, F1)
wall(17800, 17870, F2 + 40, F1)        # fim do corredor do meio

# C3 · andar de cima, à direita: corda sobre os espinhos e o lápis verde
L["bars"].append({"x0": 18050, "x1": 18650, "y": F2 - 110, "floor": F2})
spikes(18100, 520, y=F2, per=9999, ph=0, always=1)
L["specials"].append({"x": 18350, "y": F2 - 90, "c": "verde"})
hint(17850, 18050, "Espinhos no chão do corredor! Pule na corda e vá pendurado.", yl=-120)
coins_line(18100, 18600, F2 - 150, 60)
check(17700, F2)
check(18800, F2)
# o buraco no fim do andar de cima: desce para a cisterna
wall(19200, 19260, -160, F2 + 40)
ladder(19060, F2, GY)

# C4 · a cisterna (água esverdeada, pilares de pedra)
L["water"].append({"x": 19400, "y": 430, "w": 1100, "h": 70})
S.append({"t": "dirt", "x": 19400, "y": 500, "w": 1100, "h": 140})
for sx in [19560, 19800, 20060, 20300]:
    stone(sx, 400, 90)
ground(C0, 19400)
ground(20500, C1)
coins_line(19450, 20450, 360, 60)
hint(19200, 19400, "A cisterna dos porões. Vá pelos pilares (ou nade).")
L["drawings"].append({"x": 20345, "y": 370, "txt": "Um desenho da Isis: um peixe enorme de cristal, sorrindo para o papai."})
check(19250)
check(20700, GY, 3)

# ======================================================================
#  D · AS FORJAS  (21000 .. 27600)   — o calor da fortaleza
# ======================================================================
D0, D1 = C1, 27600
L["sections"].append({"x": D0, "song": "tunel", "bg": "fundicao", "gt": "mina", "night": 1, "dark": .4, "per": 3,
                      "tint": "rgba(255,110,30,.07)", "forge": 1})
L["darkZones"].append({"x": D0, "w": D1 - D0, "dark": .55})
wall(D0, D1, -620, -200, ceil=1)
ground(D0, D0 + 600)
hint(D0, D0 + 500, "As forjas do Vargas: que calor! Perto do metal derretido o Tomé esquenta (veja o termômetro). "
                   "Passe pela névoa dos barris d'água para esfriar.")
L["coolers"] += [{"x": D0 + 520, "y": GY}]
# D1 · pilares sobre o metal derretido
lava(D0 + 600, 420)
stone(D0 + 700, 440)
stone(D0 + 860, 400)
ground(D0 + 1020, D0 + 1400)
L["coolers"] += [{"x": D0 + 1200, "y": GY}]
L["clues"].append({"x": D0 + 1300, "y": 470, "id": 13})
coins_arc(D0 + 600, D0 + 1010, 400, 70, 6)
check(D0 + 300)
# D2 · o vapor que leva por cima (lápis azul lá no alto)
lava(D0 + 1400, 520)
steam(D0 + 1610, 90, -150)
L["specials"].append({"x": D0 + 1655, "y": 40, "c": "azul"})
ground(D0 + 1920, D0 + 3000)
hint(D0 + 1250, D0 + 1420, "Largo demais para pular... mas o vapor sobe forte: pule nele e segure PULAR para planar.")
coins_line(D0 + 1440, D0 + 1880, 300, 55)
check(D0 + 2000)
# D3 · prensas e o martelo-pêndulo
spikes(D0 + 2200, 96, per=150, press=1)
spikes(D0 + 2450, 96, per=150, ph=75, press=1)
L["traps"].append({"k": "axe", "x": D0 + 2850, "y": 230, "len": 200, "amp": .5, "per": 140, "ph": 0, "frame": D0 + 2770, "hammer": 1})
enemy("fly", D0 + 2600, 380, cy=380, r=[D0 + 2300, D0 + 2900])
coins_line(D0 + 2050, D0 + 2950, 470, 70)
check(D0 + 2100)
# D4 · o tanque grande: tábuas que andam sobre o metal derretido
lava(D0 + 3000, 1500)
L["movers"].append({"k": "path", "x0": D0 + 3030, "x1": D0 + 3500, "y0": 450, "y1": 450, "w": 100, "per": 400})
stone(D0 + 3600, 420, 110)
L["coolers"] += [{"x": D0 + 3655, "y": 420}, {"x": D0 + 2960, "y": GY}]
L["movers"].append({"k": "path", "x0": D0 + 3740, "x1": D0 + 4250, "y0": 430, "y1": 380, "w": 100, "per": 440})
stone(D0 + 4350, 380, 150)
L["coolers"] += [{"x": D0 + 4425, "y": 380}]
ground(D0 + 4500, D1)
hint(D0 + 2900, D0 + 3020, "O tanque grande: espere a tábua chegar e pule nela.")
coins_line(D0 + 3040, D0 + 4250, 400, 60)
check(D0 + 4600)
# D5 · o ímã e as vigas de ferro sobre o canal de metal
L["items"].append({"x": D0 + 4800, "y": 470, "id": "ima"})
hint(D0 + 4700, D0 + 4850, "Um ímã de ferro enorme! Ele gruda em ferro... como naquelas vigas lá na frente.")
lava(D0 + 5100, 700)
L["bars"].append({"x0": D0 + 5060, "x1": D0 + 5860, "y": 236, "mag": 1})
ground(D0 + 4500, D0 + 5100)
plat(D0 + 4960, 340, 110, trestle=1)
hint(D0 + 4950, D0 + 5080, "Vigas de ferro sobre o metal: pule nelas e vá pendurado pelo ímã. No fim, solte (↓).", yl=-120)
L["clues"].append({"x": D0 + 6100, "y": 470, "id": 14})
coins_line(D0 + 5100, D0 + 5800, 300, 60)
ground(D0 + 5800, D1)
check(D0 + 5900)
check(D0 + 6300, GY, 4)

# ======================================================================
#  E · AS TORRES  (27600 .. )   — ao amanhecer, até a estação velha
# ======================================================================
E0 = D1
L["sections"].append({"x": E0, "song": "tema", "bg": "amanhecer", "gt": "vila", "per": 4, "tint": "rgba(255,170,130,.06)", "dawn": 1})
ground(E0, E0 + 640)
hint(E0, E0 + 500, "O sol nascendo! Lá do alto da torre dá para ver a estação velha. Suba!")
# E1 · o elevador da torre
L["movers"].append({"k": "lift", "x": E0 + 640, "y0": -260, "y1": GY, "w": 110, "start": "bottom"})
wall(E0 + 760, E0 + 1800, -260, GY)               # a torre (o alto é o primeiro patamar)
hint(E0 + 500, E0 + 700, "Um elevador velho: suba nele e toque ✦ USAR.", yl=-80)
check(E0 + 300)
# E2 · saltos entre paredes até o alto da torre
wall(E0 + 1640, E0 + 1700, -380, -260)          # pilar (degrau)
wall(E0 + 1800, E0 + 2400, -440, GY)             # a torre de cima
hint(E0 + 1300, E0 + 1600, "Suba pelo pilar, ou saltando entre o pilar e a torre!", yl=-320)
L["specials"].append({"x": E0 + 1860, "y": -520, "c": "roxo"})
coins_line(E0 + 800, E0 + 1450, -290, 60)
check(E0 + 1350, -260)
# E3 · ventania no alto e a ponte que desaba
L["traps"].append({"k": "gust", "x": E0 + 1900, "y": -600, "w": 360, "h": 160, "per": 240, "on": 100, "ph": 40})
coins_line(E0 + 1750, E0 + 2350, -470, 60)
check(E0 + 2200, -440)
L["traps"].append({"k": "bridge", "x": E0 + 2400, "y": -440, "w": 1100, "gaps": [8, 9, 17], "spd": 5.0, "delay": 30})
hint(E0 + 2250, E0 + 2400, "Uma ponte velha até a outra torre... ela vai desabar atrás de você: corra e pule os buracos!", yl=-560)
wall(E0 + 3500, E0 + 4100, -440, GY)
L["coins"] += [[E0 + 3800, -480]]
check(E0 + 3600, -440)
# E4 · a descida pela escada e o caminho até a estação
ladder(E0 + 4110, -440, GY)
ground(E0 + 4100, E0 + 7200)
L["drawings"].append({"x": E0 + 4600, "y": 470, "txt": "Um desenho da Isis: a estação de trem, e o papai chegando correndo com o Pipoca."})
enemy("crow", E0 + 5200, -100, cy=-100, r=[E0 + 4800, E0 + 5600])
coins_line(E0 + 4200, E0 + 6500, 470, 70)
check(E0 + 4300)
F0 = E0 + 5600
L["door"] = {"x": F0 + 1100, "y": 410, "kind": "station"}
hint(F0, F0 + 900, "A estação velha... e o trem do Vargas parado nos trilhos. Vá até lá!")
check(F0 + 60)
L["spanX"] = F0 + 1400

# ----------------------------------------------------------------------
assert sorted(c["id"] for c in L["clues"]) == [13, 14, 15, 16, 17, 18]
L["solids"] = [s for s in S if s]


def _fix_coin(c):
    for _ in range(12):
        moved = False
        for so in L["solids"]:
            if so.get("deco") or so["t"] in ("plat", "branch", "barrier", "pgate", "house", "bars", "crack"):
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
L["coins"] = [c for c in L["coins"] if c[1] > -600]

json.dump(L, open(os.path.join(ROOT, "assets", "data", "level3.json"), "w"), ensure_ascii=False, indent=1)
print("level3.json: %d sólidos, %d lápis, spanX %d, pistas %s" % (len(L["solids"]), len(L["coins"]), L["spanX"],
                                                                  sorted(c["id"] for c in L["clues"])))
