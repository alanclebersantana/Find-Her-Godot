extends RefCounted
class_name Ep3Bosses
## Os chefes do Episódio 3 (a fortaleza do Vargas), cada um com uma mecânica própria e fácil de ler:
##  - ENGUIA DE CRISTAL (a cisterna dos porões): nada por baixo da água e borbulha embaixo do pilar onde
##    o Tomé está — aviso do bote. Ela salta e cai em cima daquele pilar: quem ficou lá leva o bote.
##    Bateu na pedra, fica tonta enrolada no pilar: pulo na cabeça. 3 pulos. Cair na água dá choque.
##  - SALAMANDRA DE FOGO (a sala das caixas d'água nas forjas): anda pegando fogo e cospe bolas de fogo.
##    Em chamas não dá para encostar. Lá em cima, em cada balcão, uma corrente: ✦ USAR vira a caixa
##    d'água; se ela estiver embaixo, apaga o fogo e ela fica cinza e tonta — pule em cima. 3 vezes.
##  - GUARDIÃO DE FERRO (o pé da torre, antes da estação): anda pesado; ergue os punhos (aviso) e soca o
##    chão: ondas de choque correm pelo chão dos dois lados (pule). Os punhos ficam presos no chão:
##    é a hora da picareta (⛏) nas costas dele. 4 golpes, e ele desmonta.
## O estado de cada chefe fica num dicionário em B; os vencidos ficam em WON (vai no salvamento).

var g
var B: Array = []
var SHOTS: Array = []     # bolas de fogo (salamandra) e ondas de choque (guardião)
var TANKS: Array = []     # caixas d'água da salamandra (com o balcão e a corrente)
var WON := {}

const NAMES := {"enguia": "ENGUIA DE CRISTAL", "salamandra": "SALAMANDRA DE FOGO", "guardiao": "GUARDIÃO DE FERRO"}
const SUBS := {"enguia": "a guardiã da cisterna", "salamandra": "o fogo das forjas", "guardiao": "o porteiro da torre"}
const LINES := {
	"enguia": "Uma enguia de cristal! Quando borbulhar embaixo do meu pilar, eu pulo para outro... e se ela bater na pedra, pulo na cabeça dela!",
	"salamandra": "Uma salamandra pegando fogo! Lá nos balcões tem caixas d'água... se eu virar uma em cima dela, o fogo apaga.",
	"guardiao": "Um gigante de ferro! Quando ele socar o chão, eu pulo a onda... e com os punhos presos, é a vez da picareta!",
}
const TIPS := {
	"enguia": "Borbulhou embaixo do seu pilar? PULE para outro! Ela bate na pedra e fica tonta: pule na cabeça dela.",
	"salamandra": "Suba num balcão: lá as bolas de fogo não alcançam. Quando ela passar embaixo da caixa d'água, toque ✦ USAR na corrente. Apagada, pule em cima dela!",
	"guardiao": "Ele ergue os punhos: afaste-se e PULE as ondas de choque. Com os punhos presos no chão, use a picareta (⛏) nele!",
}

# escala dos desenhos (px da arte -> px do mundo)
const K_EEL := .5
const K_SAL := .62
const K_GUA := .62
# ponta do focinho em cada quadro da salamandra (px da arte): alinha os quadros entre si
const SAL_SNOUT := [452.0, 445.0, 478.0, 462.0, 465.0, 475.0]

func _init(game) -> void:
	g = game

func load_level() -> void:
	B = []
	SHOTS = []
	TANKS = []
	for d in g.L.get("bosses3", []):
		var b: Dictionary = d.duplicate(true)
		b.maxhp = int(d.hp)
		b.hp = b.maxhp
		b.st = "wait"
		b.t = 0
		b.red = 0
		b.active = false
		b.done = false
		b.dir = -1
		b.x = float(d.home)
		b.y = float(d.y)
		b.cd = 60
		b.fury = 0
		B.append(b)
		if b.id == "salamandra":
			for tx in d.tanks:
				TANKS.append({"x": float(tx), "y": float(d.tankY), "py": float(d.balcY), "st": "full", "t": 0, "lever": float(tx) - 92.0})

func boss(id: String) -> Dictionary:
	for b in B:
		if b.id == id:
			return b
	return {}

func active() -> bool:
	for b in B:
		if b.active and not b.done and b.st != "wait":
			return true
	return false

## barras de vida (Polish.bosses)
func bars() -> Array:
	var out: Array = []
	for b in B:
		if b.active and not b.done and b.st not in ["wait", "intro"]:
			out.append({"name": NAMES[b.id], "hp": b.hp, "max": b.maxhp, "x": b.x, "y": b.y - 80, "ref": b, "kind": b.id,
				"weak": b.st in ["stun", "cool", "stuck"], "fast": b.st in ["leap", "slam"], "dir": b.dir, "gy": b.y})
	return out

func save_data() -> Array:
	return WON.keys()

func restore(arr) -> void:
	if not (arr is Array):
		return
	for id in arr:
		WON[str(id)] = 1
	for b in B:
		if WON.has(b.id):
			b.done = true
			b.active = false
			b.st = "gone"
			b.hp = 0

func on_respawn() -> void:
	SHOTS = []
	for t in TANKS:
		t.st = "full"
		t.t = 0
	for b in B:
		if b.done or b.st in ["down", "gone"]:
			continue
		if b.active or b.st != "wait":
			b.active = false
			b.st = "wait"
			b.hp = b.maxhp
			b.t = 0
			b.red = 0
			b.x = float(b.home)
			b.y = float(b.get("y0", b.y)) if b.has("y0") else b.y
			b.fury = 0
			_gate(b, false)

# ======================================================================
#  passo
# ======================================================================
func post() -> void:
	if B.is_empty():
		return
	for b in B:
		if b.red > 0:
			b.red -= 1
		if b.done:
			continue
		if b.st == "wait":
			_trigger(b)
			continue
		if b.st == "intro":
			# a apresentação (câmera, nome e a fala do Tomé) acabou: começa a luta
			if g.CINE.is_empty():
				b.st = "fight0"
				b.t = 0
				g.tip(TIPS[b.id], 300)
			continue
		match b.id:
			"enguia":
				_eel(b)
			"salamandra":
				_sal(b)
			"guardiao":
				_gua(b)
	_shots()
	_tanks()

func _trigger(b: Dictionary) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	if p.dyingT > 0 or p.get("dog") or WON.has(b.id):
		return
	if pcx > float(b.trig) and pcx < float(b.x1) - 30 and p.y + p.h > float(b.y) - 260:
		b.active = true
		b.st = "intro"
		b.t = 0
		b.hp = b.maxhp
		_gate(b, true)
		Audio.play("roar", -8)
		g.start_cine(b.id, (float(b.x0) + float(b.x1)) / 2.0, float(b.y) - 170, 240,
			[[150, 235, "TOMÉ", LINES[b.id], "tome"]], [60, 150, NAMES[b.id], SUBS[b.id]])

func _gate(b: Dictionary, on: bool) -> void:
	for id in [b.id + "L", b.id + "R"]:
		for s in g.SOL.duplicate():
			if s.get("id") == id:
				g.SOL.erase(s)
				if g.K:
					g.K.sink_gate(s)
	if on:
		var top: float = float(b.get("gateTop", float(b.y) - 380))
		var h: float = float(b.y) - top
		g.SOL.append({"t": "kinggate", "x": float(b.x0) - 24, "y": top, "w": 24, "h": h, "id": b.id + "L"})
		g.SOL.append({"t": "kinggate", "x": float(b.x1), "y": top, "w": 24, "h": h, "id": b.id + "R"})
	g.blockers_dirty()

func _win(b: Dictionary, msg: String) -> void:
	b.st = "down"
	b.t = 0
	b.hp = 0
	WON[b.id] = 1
	Polish.final_blow()
	Polish.loot_arc(b.x, b.y - 60, 12, float(b.y))
	_gate(b, false)
	SHOTS = []
	for i in 10:
		g.gain_coin(b.x, b.y - 80, true)
	g.player.hp = Game.MAXHP
	Audio.play("door", -4)
	g.flash(msg, 280)

func _hit(b: Dictionary) -> void:
	b.hp -= 1
	b.red = 30
	b.fury = b.maxhp - b.hp
	g.hit_stop = 6
	g.shake = max(g.shake, 12)
	Audio.play("stomp", 0)
	Audio.vib(110)

## pulo em cima (a caixa hb); devolve true se acertou por cima
func _stomp(hb: Dictionary) -> bool:
	var p: Dictionary = g.player
	if p.dyingT > 0 or p.vy <= .5 or p.get("dog"):
		return false
	if not Game.hit(p, hb):
		return false
	if p.y + p.h - float(hb.y) > 30:
		return false
	p.y = float(hb.y) - p.h - 1
	p.vy = -9.5
	p.onGround = false
	p.cutOk = false
	return true

func _touch(box: Dictionary) -> bool:
	var p: Dictionary = g.player
	return p.dyingT == 0 and not p.get("dog") and Game.hit(p, box)

# ======================================================================
#  ENGUIA DE CRISTAL
# ======================================================================
func _pillar_of(x: float, b: Dictionary) -> int:
	var best := -1
	var bd := 1e9
	for i in b.pillars.size():
		var c: float = float(b.pillars[i]) + float(b.pw) / 2
		if abs(c - x) < bd:
			bd = abs(c - x)
			best = i
	return best

func _pc(b: Dictionary, i: int) -> float:
	return float(b.pillars[i]) + float(b.pw) / 2

## o Tomé em cima de qual pilar (-1 = em nenhum)
func _on_pillar(b: Dictionary) -> int:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	for i in b.pillars.size():
		var x0: float = float(b.pillars[i])
		if pcx > x0 - 14 and pcx < x0 + float(b.pw) + 14 and abs(feet - float(b.ptop)) < 8:
			return i
	return -1

func eel_head(b: Dictionary) -> Dictionary:
	return g.R(b.x - 64, float(b.ptop) - 96, 128, 56)

func _eel(b: Dictionary) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	var surf: float = float(b.surf)
	b.t += 1
	var fury: int = int(b.fury)
	# caiu na água no meio da luta: choque e volta para cima de um pilar
	var in_water: bool = pcx > float(b.x0) + 70 and pcx < float(b.x1) - 60 and feet > surf + 6 and p.dyingT == 0
	if in_water and b.st not in ["down"] and p.iframe <= 0:
		var i: int = _pillar_of(pcx, b)
		g.hurt(1, b.x)
		g.burst(pcx, surf, 22, Color("#9ff4ff"))
		Audio.play("unlock", -4, 1.6)
		p.x = _pc(b, i) - p.w / 2
		p.y = float(b.ptop) - p.h - 2
		p.vy = -6.0
		p.vx = 0.0
		p.swim = false
		if not g.L.get("_eel_zap", false):
			g.L["_eel_zap"] = true
			g.tip("A água da cisterna dá choque perto da enguia! Fique nos pilares.", 200)
	match b.st:
		"fight0", "swim":
			if b.st == "fight0":
				b.st = "swim"
				b.cd = 70
			# nada por baixo da água até o pilar onde o Tomé está
			var tgt: int = _on_pillar(b)
			if tgt < 0:
				tgt = _pillar_of(pcx, b)
			b.tgt = tgt
			var tx: float = _pc(b, tgt) - float(b.get("side", 1)) * 250.0
			tx = clamp(tx, float(b.x0) + 60, float(b.x1) - 60)
			var dx: float = tx - b.x
			b.dir = 1 if dx > 0 else -1
			b.x += clamp(dx, -3.8 - fury * .6, 3.8 + fury * .6)
			b.y = surf + 46 + sin(b.t * .1) * 4
			b.cd -= 1
			if b.cd <= 0 and abs(dx) < 12 and p.dyingT == 0 and _on_pillar(b) >= 0:
				b.st = "warn"
				b.t = 0
				b.tx = _pc(b, tgt)
				b.sx = clamp(b.tx - float(b.get("side", 1)) * 250.0, float(b.x0) + 40, float(b.x1) - 40)
				b.x = b.sx
		"warn":
			# borbulha embaixo do pilar (o aviso do bote)
			if b.t % 5 == 0:
				Polish.part("drop", float(b.tx) + randf_range(-40, 40), surf - 2, randf_range(-.4, .4), -randf_range(1.5, 3.2), 26, Color("#c8fbff"))
			if b.t % 14 == 1:
				Audio.play("splash", -16, 1.6)
			if b.t > 58 - fury * 9:
				b.st = "leap"
				b.t = 0
				Audio.play("splash", -4)
				g.burst(b.sx, surf, 16, Color("#bff6ff"))
		"leap":
			# salta da água e cai em cima do pilar
			var dur := 34.0
			var u: float = clamp(b.t / dur, 0.0, 1.0)
			var y0: float = surf + 20
			var y1: float = float(b.ptop) - 26
			var ox: float = b.x
			var oy: float = b.y
			b.x = lerpf(float(b.sx), float(b.tx), u)
			b.y = lerpf(y0, y1, u) - sin(u * PI) * 150.0
			if b.t > 1:
				b.ang = atan2(b.y - oy, b.x - ox)
			b.dir = 1 if float(b.tx) > float(b.sx) else -1
			# a cabeça vem na frente
			var hx: float = b.x + 80.0 * cos(float(b.get("ang", 0.0)))
			var hy: float = b.y + 80.0 * sin(float(b.get("ang", 0.0)))
			if _touch(g.R(hx - 34, hy - 30, 68, 60)):
				g.hurt(1, b.x)
			if u >= 1.0:
				b.st = "stun"
				b.t = 0
				b.x = float(b.tx)
				b.y = float(b.ptop)
				g.shake = max(g.shake, 12)
				Audio.play("stomp", -2)
				Audio.vib(80)
				g.burst(b.x, float(b.ptop) - 30, 18, Color("#9ff4ff"))
				# quem ficou no pilar leva o bote
				var on: int = _on_pillar(b)
				if on >= 0 and abs(_pc(b, on) - b.x) < 5:
					g.hurt(1, b.x)
				if not g.L.get("_eel_tonta", false):
					g.L["_eel_tonta"] = true
					g.flash_tut("Bateu na pedra! PULE NA CABEÇA!", "A enguia bateu no pilar e ficou tonta: pule em cima dela agora!", 200)
		"stun":
			# tonta, enrolada no pilar: a hora do pulo na cabeça
			if b.t > 170 - fury * 22:
				b.st = "dive"
				b.t = 0
		"hurt":
			if b.t > 26:
				b.st = "dive"
				b.t = 0
		"dive":
			# escorrega de volta para a água
			b.y += 9.0
			if b.y > surf + 40:
				b.st = "swim"
				b.t = 0
				b.cd = 80 - fury * 12
				b.side = -float(b.get("side", 1))
				g.burst(b.x, surf, 14, Color("#bff6ff"))
				Audio.play("splash", -8)
		"down":
			b.y = move_toward(b.y, surf + 4, 2.0)
			if b.t > 200:
				b.done = true
				b.active = false
	if b.st == "stun":
		if _stomp(eel_head(b)):
			_hit(b)
			g.burst(b.x, float(b.ptop) - 80, 18, Color("#bff6ff"))
			Audio.play("unlock", -4, .7)
			if b.hp <= 0:
				b.y = float(b.surf)
				_win(b, "A Enguia de Cristal desistiu e afundou na cisterna! Dá para seguir.")
				return
			b.st = "hurt"
			b.t = 0
			var n: int = int(b.hp)
			g.flash("Toma! Falta%s %d pulo%s." % ["m" if n > 1 else "", n, "s" if n > 1 else ""], 140)

# ======================================================================
#  SALAMANDRA DE FOGO
# ======================================================================
func sal_box(b: Dictionary) -> Dictionary:
	return g.R(b.x - 120, b.y - 100, 240, 100)

func sal_back(b: Dictionary) -> Dictionary:
	return g.R(b.x - 130, b.y - 128, 260, 50)

func sal_mouth(b: Dictionary) -> Vector2:
	return Vector2(b.x + b.dir * 128.0, b.y - 70)

func _sal(b: Dictionary) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	b.t += 1
	var fury: int = int(b.fury)
	var lo: float = float(b.x0) + 170
	var hi: float = float(b.x1) - 170
	match b.st:
		"fight0":
			b.st = "walk"
			b.cd = 120
		"walk":
			b.x += b.dir * (1.5 + fury * .45)
			if b.x < lo:
				b.x = lo
				b.dir = 1
			elif b.x > hi:
				b.x = hi
				b.dir = -1
			b.cd -= 1
			if b.cd <= 0 and p.dyingT == 0:
				b.st = "breath"
				b.t = 0
				b.dir = 1 if pcx > b.x else -1
		"breath":
			# abre a boca (aviso) e cospe a bola de fogo na direção do Tomé
			if b.t == 34 - fury * 5:
				# a bola de fogo corre rente ao chão (nos balcões o Tomé está a salvo; no chão, pule)
				var m: Vector2 = sal_mouth(b)
				SHOTS.append({"k": "fire", "x": m.x, "y": b.y - 34, "vx": b.dir * (5.0 + fury * .6), "vy": 0.0, "t": 0})
				Audio.play("fire", -6, 1.2)
				Audio.play("roar", -12, 1.4)
			if b.t > 54 - fury * 5:
				b.st = "walk"
				b.t = 0
				b.cd = 150 - fury * 30
		"cool":
			# apagada: cinza e tonta (a hora de pular em cima)
			if b.t % 9 == 0:
				Polish.part("drop", b.x + randf_range(-110, 110), b.y - 110, randf_range(-.3, .3), -randf_range(.8, 1.6), 40, Color(.9, .92, .95, .6))
			if b.t > 230 - fury * 25:
				b.st = "relight"
				b.t = 0
				Audio.play("roar", -8)
		"relight":
			if b.t > 30:
				b.st = "walk"
				b.t = 0
				b.cd = 90
		"hurt":
			if b.t > 36:
				# foge para o outro lado da sala (dá tempo de o Tomé voltar para um balcão)
				b.st = "flee"
				b.t = 0
				b.dir = -1 if pcx > b.x else 1
		"flee":
			b.x += b.dir * 3.4
			if b.x < lo or b.x > hi or b.t > 160:
				b.x = clamp(b.x, lo, hi)
				b.dir = -b.dir
				b.st = "walk"
				b.t = 0
				b.cd = 110
		"down":
			if b.t > 200:
				b.done = true
				b.active = false
	if b.st in ["cool"]:
		if _stomp(sal_back(b)):
			_hit(b)
			Audio.play("roar", -6, 1.3)
			g.burst(b.x, b.y - 120, 18, Color("#ffd76a"))
			if b.hp <= 0:
				_win(b, "A Salamandra de Fogo apagou de vez e rolou de barriga para cima! O caminho está livre.")
				return
			b.st = "hurt"
			b.t = 0
			var n: int = int(b.hp)
			g.flash("Toma! Falta%s %d vez%s." % ["m" if n > 1 else "", n, "es" if n > 1 else ""], 140)
		return
	if b.st in ["walk", "breath", "relight", "fight0"]:
		# pegando fogo: encostar ou pular nela queima
		if _touch(sal_back(b)) and g.player.vy > .5:
			g.hurt(1, b.x)
			if not g.L.get("_sal_quente", false):
				g.L["_sal_quente"] = true
				g.tip("Ai! Ela está pegando fogo! Apague com a caixa d'água primeiro (✦ USAR na corrente, lá no balcão).", 240)
		elif _touch(sal_box(b)):
			g.hurt(1, b.x)

## ✦ USAR perto da corrente de uma caixa d'água cheia
func near_lever() -> Dictionary:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	for t in TANKS:
		if abs(pcx - float(t.lever)) < 44 and abs(p.y + p.h - float(t.py)) < 10:
			return t
	return {}

func use() -> bool:
	var t: Dictionary = near_lever()
	if t.is_empty():
		return false
	if t.st != "full":
		g.flash("A caixa ainda está enchendo...", 90)
		return true
	t.st = "pour"
	t.t = 0
	Audio.play("splash", -2, .8)
	Audio.play("unlock", -6, .7)
	return true

func _tanks() -> void:
	var b: Dictionary = boss("salamandra")
	for t in TANKS:
		t.t += 1
		match t.st:
			"pour":
				# a água cai num jorro até o chão
				if t.t % 2 == 0:
					Polish.part("drop", float(t.x) + randf_range(-40, 40), float(t.y) + 10, randf_range(-.6, .6), randf_range(6, 9), 30, Color("#9fd8ff"))
				if t.t > 6 and t.t < 46 and not b.is_empty() and b.active and b.st in ["walk", "breath", "relight", "flee"]:
					if abs(b.x - float(t.x)) < 130:
						b.st = "cool"
						b.t = 0
						g.burst(b.x, b.y - 100, 26, Color(.92, .94, 1))
						Audio.play("splash", -2)
						Audio.play("slide", -4, .6)
						if not g.L.get("_sal_cool", false):
							g.L["_sal_cool"] = true
							g.flash_tut("O fogo apagou! PULE EM CIMA!", "A salamandra ficou cinza e tonta: pule em cima dela antes que ela pegue fogo de novo!", 200)
				if t.t > 50:
					t.st = "fill"
					t.t = 0
			"fill":
				if t.t > 220:
					t.st = "full"
					t.t = 0

func water_on(t: Dictionary) -> bool:
	return t.st == "pour" and t.t > 4 and t.t < 48

# ======================================================================
#  GUARDIÃO DE FERRO
# ======================================================================
func gua_box(b: Dictionary) -> Dictionary:
	return g.R(b.x - 72, b.y - 230, 144, 230)

func _gua(b: Dictionary) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	b.t += 1
	var fury: int = int(b.fury)
	var lo: float = float(b.x0) + 110
	var hi: float = float(b.x1) - 110
	match b.st:
		"fight0":
			b.st = "walk"
			b.cd = 60
		"walk":
			b.dir = 1 if pcx > b.x else -1
			b.x = clamp(b.x + b.dir * (1.15 + fury * .3), lo, hi)
			if b.t % 30 == 0:
				Audio.play("stomp", -14, .6)
				g.shake = max(g.shake, 2)
			b.cd -= 1
			if b.cd <= 0 and abs(pcx - b.x) < 300 and p.dyingT == 0:
				b.st = "raise"
				b.t = 0
		"raise":
			# ergue os punhos e o olho fica vermelho: o aviso do soco no chão
			if b.t % 6 == 0:
				Polish.part("drop", b.x - b.dir * 30, b.y - 300, randf_range(-.5, .5), -randf_range(1, 2), 30, Color(.7, .7, .72, .6))
			if b.t > 44 - fury * 6:
				b.st = "slam"
				b.t = 0
				g.shake = max(g.shake, 18)
				Audio.play("stomp", 2, .5)
				Audio.vib(140)
				Polish.roar(b.x, b.y - 20)
				g.burst(b.x + b.dir * 60, b.y - 6, 24, Color("#8a7a6a"))
				# os punhos no chão machucam quem estiver ali
				if _touch(g.R(b.x + b.dir * 40 - 90, b.y - 90, 180, 90)):
					g.hurt(1, b.x)
				for s in [-1, 1]:
					SHOTS.append({"k": "wave", "x": b.x + s * 80, "y": float(b.y), "vx": s * (6.5 + fury * .6), "vy": 0.0, "t": 0})
		"slam":
			if b.t > 10:
				b.st = "stuck"
				b.t = 0
				b.hs = 0
				if not g.L.get("_gua_preso", false):
					g.L["_gua_preso"] = true
					g.flash_tut("Os punhos ficaram presos! PICARETA!", "O Guardião está preso no chão: chegue perto e use a picareta (⛏) nele!", 200)
		"stuck":
			if b.t % 8 == 0:
				Polish.part("drop", b.x + randf_range(-40, 40), b.y - 4, randf_range(-1.5, 1.5), -randf_range(1, 3), 20, Color("#ffcf6a"))
			if b.t > 170 - fury * 18:
				b.st = "walk"
				b.t = 0
				b.cd = 110 - fury * 12
				Audio.play("stomp", -6, .7)
		"hurt":
			# levou o segundo golpe seguido: solta os punhos e levanta, bravo
			if b.t > 30:
				b.st = "walk"
				b.cd = 100 - fury * 12
				b.t = 0
		"down":
			if b.t % 10 == 0 and b.t < 160:
				Polish.part("drop", b.x + randf_range(-80, 80), b.y - 60, randf_range(-.4, .4), -randf_range(1, 2), 50, Color(.6, .6, .62, .6))
			if b.t > 200:
				b.done = true
				b.active = false
	if b.st in ["walk", "raise"] and _touch(gua_box(b)):
		g.hurt(1, b.x)

## golpe de picareta (Kings.swing_hits passa a caixa do golpe)
func swing_hits(hb: Dictionary) -> void:
	var b: Dictionary = boss("guardiao")
	if b.is_empty() or b.done or not b.active or b.red > 0:
		return
	if not Game.hit(hb, gua_box(b)):
		return
	if b.st != "stuck":
		if b.st in ["walk", "raise"] and int(b.get("clang", 0)) < g.T:
			b.clang = g.T + 40
			Audio.play("unlock", -4, .6)
			g.burst(hb.x + hb.w / 2, hb.y + 20, 8, Color("#ffd76a"))
			if not g.L.get("_gua_clang", false):
				g.L["_gua_clang"] = true
				g.tip("Clanc! De pé ele aguenta a picareta. Espere ele socar o chão e ficar preso!", 200)
		return
	_hit(b)
	b.hs = int(b.get("hs", 0)) + 1
	g.burst(b.x - b.dir * 30, b.y - 150, 22, Color("#ffcf6a"))
	for i in 8:
		g.PARTS.append({"x": b.x, "y": b.y - 140, "vx": (randf() - .5) * 6, "vy": -randf() * 5, "life": 40, "col": Color("#5a4a3a")})
	if b.hp <= 0:
		_win(b, "O Guardião de Ferro desmontou inteirinho! A estação velha está logo ali.")
		return
	if int(b.hs) >= 2:
		b.st = "hurt"
		b.t = 0
	var n: int = int(b.hp)
	g.flash("Clanc! Falta%s %d golpe%s." % ["m" if n > 1 else "", n, "s" if n > 1 else ""], 140)

# ======================================================================
#  bolas de fogo e ondas de choque
# ======================================================================
func _shots() -> void:
	var keep: Array = []
	for s in SHOTS:
		s.t += 1
		s.x += s.vx
		s.y += s.vy
		var b: Dictionary = boss("salamandra" if s.k == "fire" else "guardiao")
		var alive: bool = s.t < 200 and not b.is_empty() and b.active and s.x > float(b.x0) - 10 and s.x < float(b.x1) + 10 and s.y > float(b.y) - 520 and s.y < float(b.y) + 20
		if s.k == "fire":
			if s.t % 3 == 0:
				Polish.part("drop", s.x, s.y, randf_range(-.5, .5), randf_range(-1, .2), 18, Color(1, .6, .2, .8))
			if _touch(g.R(s.x - 16, s.y - 16, 32, 32)):
				g.hurt(1, s.x - s.vx * 4)
				alive = false
			# bate em sólido (balcões, paredes)
			for so in g.SOL:
				if so.get("t") in ["plat"] and s.vy > 0 and s.x > float(so.x) and s.x < float(so.x) + float(so.w) and abs(s.y - float(so.y)) < 8:
					alive = false
					break
		else:
			if s.t % 4 == 0:
				g.fx("fx_dust", s.x, s.y - 4, 16, .16, -.3)
			if _touch(g.R(s.x - 20, s.y - 36, 40, 36)):
				g.hurt(1, s.x - s.vx * 4)
		if alive:
			keep.append(s)
		elif s.k == "fire":
			g.burst(s.x, s.y, 10, Color(1, .6, .2))
	SHOTS = keep
