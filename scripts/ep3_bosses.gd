extends RefCounted
class_name Ep3Bosses
## Os chefes do Episódio 3 (a fortaleza do Vargas), cada um com uma mecânica própria e fácil de ler:
##  - ENGUIA DE CRISTAL (a cisterna dos porões): a água inteira dá choque. Ela nada por trás dos pilares
##    e sobe brilhando no vão ao lado do pilar do Tomé (aviso); dá o bote no pilar. Se o Tomé pulou para o
##    vizinho, ela morde a pedra e os dentes ficam presos: pulo na cabeça ou picareta, um golpe por bote.
##    Fica mais rápida a cada golpe e, na última vida, dá bote duplo. 4 golpes.
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

const NAMES := {"enguia": "ENGUIA DE CRISTAL", "salamandra": "SALAMANDRA DE FOGO", "guardiao": "GUARDIÃO DE FERRO", "vargas": "ADEMAR VARGAS"}
const SUBS := {"enguia": "a guardiã da cisterna", "salamandra": "o fogo das forjas", "guardiao": "o porteiro da torre", "vargas": "o dono da mina"}
const LINES := {
	"enguia": "Uma enguia de cristal! Quando ela subir brilhando do lado do meu pilar, eu pulo para o outro... se ela morder a pedra, os dentes ficam presos!",
	"salamandra": "Uma salamandra pegando fogo! Lá nos balcões tem caixas d'água... se eu virar uma em cima dela, o fogo apaga.",
	"guardiao": "Um gigante de ferro! Quando ele socar o chão, eu pulo a onda... e com os punhos presos, é a vez da picareta!",
	"vargas": "Acabou, Vargas! A Isis está trancada na cabine, longe de você. Agora somos só nós dois.",
}
const TIPS := {
	"enguia": "Ela sobe brilhando do lado do seu pilar: PULE para o vizinho! Mordeu a pedra e prendeu os dentes: pule na cabeça (ou ⛏).",
	"salamandra": "Suba num balcão: lá as bolas de fogo não alcançam. Quando ela passar embaixo da caixa d'água, toque ✦ USAR na corrente. Apagada, pule em cima dela!",
	"guardiao": "Ele ergue os punhos: afaste-se e PULE as ondas de choque (e cuidado com as pedras do teto). Punhos presos no chão: UMA picaretada (⛏)!",
	"vargas": "Pule os barris, desvie do carvão e da picareta. Quando a lâmpada do capacete acender, toque ✦: a lanterna do Tomé ofusca ele de volta! Cansado, ele fica tonto: pule na cabeça ou use a picareta.",
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
				"weak": b.st in ["stun", "cool", "stuck"], "fast": b.st in ["leap", "lunge", "slam"], "dir": b.dir, "gy": b.y})
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
			"vargas":
				_vargas(b)
			"enguia":
				_eel(b)
			"salamandra":
				_sal(b)
			"guardiao":
				_gua(b)
	_shots()
	_tanks()
	_blind_step()

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

## a cabeça (onde vale o pulo / a picareta): com os dentes presos na pedra, ela fica em cima do pilar
func eel_head(b: Dictionary) -> Dictionary:
	return g.R(float(b.hx) - 44, float(b.hy) - 40, 88, 52)

## vãos de água entre os pilares (a enguia só sobe por eles; nunca atravessa pedra)
func _gaps(b: Dictionary) -> Array:
	var out: Array = []
	var a: float = float(b.get("wx0", float(b.x0)))
	for px0 in b.pillars:
		out.append([a, float(px0)])
		a = float(px0) + float(b.pw)
	out.append([a, float(b.get("wx1", float(b.x1)))])
	return out

## centro do vão ao lado do pilar i (side -1 = à esquerda, 1 = à direita)
func _gap_x(b: Dictionary, i: int, side: int) -> float:
	var gp: Array = _gaps(b)[i if side < 0 else i + 1]
	return (float(gp[0]) + float(gp[1])) / 2.0

## a pedra mais perto do vão por onde ela sai: ali ela crava os dentes
func _bite_x(b: Dictionary, i: int, side: int) -> float:
	return _pc(b, i) + float(side) * (float(b.pw) / 2.0 - 18.0)

func _eel(b: Dictionary) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	var surf: float = float(b.surf)
	b.t += 1
	var fury: int = int(b.fury)
	if not b.has("hx"):
		b.hx = b.x
		b.hy = surf + 40
	# caiu na água: choque (a água inteira da cisterna dá choque) e volta para cima de um pilar
	var in_water: bool = pcx > float(b.get("wx0", b.x0)) and pcx < float(b.get("wx1", b.x1)) and feet > surf + 6 and p.dyingT == 0
	if in_water and b.st not in ["down"] and p.iframe <= 0:
		var i: int = _pillar_of(pcx, b)
		g.hurt(1, b.x)
		g.burst(pcx, surf, 22, Color("#9ff4ff"))
		Audio.play("unlock", -4, 1.6)
		g.shake = max(g.shake, 6)
		p.x = _pc(b, i) - p.w / 2
		p.y = float(b.ptop) - p.h - 2
		p.vy = -6.0
		p.vx = 0.0
		p.swim = false
		if not g.L.get("_eel_zap", false):
			g.L["_eel_zap"] = true
			g.tip("NÃO ENTRE NA ÁGUA: dá choque! Fique em cima dos pilares.", 200)
	var spd: float = 3.4 + fury * .9
	match b.st:
		"fight0", "swim":
			if b.st == "fight0":
				b.st = "swim"
				b.cd = 60
				b.side = -1
				b.dbl = false
			# nada por TRÁS dos pilares, debaixo d'água, até o vão do lado do pilar do Tomé
			var on: int = _on_pillar(b)
			var tgt: int = on if on >= 0 else _pillar_of(pcx, b)
			var side: int = int(b.side)
			# o vão do lado escolhido; se não houver água ali (borda), o outro
			var gx: float = _gap_x(b, tgt, side)
			b.dir = 1 if gx > b.x else -1
			b.x = move_toward(b.x, gx, spd)
			b.y = surf + 50 + sin(b.t * .1) * 4
			b.hx = b.x
			b.hy = b.y
			b.cd -= 1
			if b.cd <= 0 and abs(gx - b.x) < 2 and p.dyingT == 0 and on >= 0:
				b.st = "warn"
				b.t = 0
				b.tp = tgt
				b.gx = gx
		"warn":
			# sobe no vão com a crista brilhando: o aviso do bote no pilar
			b.y = move_toward(b.y, surf - 6, 3.0)
			b.hx = b.x
			b.hy = b.y - 30
			b.dir = 1 if _pc(b, int(b.tp)) > b.x else -1
			if b.t % 5 == 0:
				Polish.part("drop", b.x + randf_range(-30, 30), surf - 2, randf_range(-.4, .4), -randf_range(1.5, 3.2), 26, Color("#c8fbff"))
			if b.t % 14 == 1:
				Audio.play("splash", -14, 1.6)
			if b.t > max(24, 44 - fury * 7):
				b.st = "lunge"
				b.t = 0
				b.sx = b.x
				b.sy = surf - 20
				b.tx = _bite_x(b, int(b.tp), -int(b.dir))
				Audio.play("splash", -4)
				Audio.play("roar", -10, 1.8)
				g.burst(b.x, surf, 16, Color("#bff6ff"))
		"lunge":
			# o bote: a cabeça vai do vão até em cima do pilar (o corpo continua na água)
			var dur: float = max(12.0, 18.0 - fury * 1.5)
			var u: float = clamp(b.t / dur, 0.0, 1.0)
			b.hx = lerpf(float(b.sx), float(b.tx), u)
			b.hy = lerpf(float(b.sy), float(b.ptop) - 18, u) - sin(u * PI) * 70.0
			if _touch(g.R(float(b.hx) - 34, float(b.hy) - 30, 68, 50)):
				g.hurt(1, b.hx)
			if u >= 1.0:
				g.shake = max(g.shake, 10)
				Audio.play("stomp", -2)
				Audio.vib(80)
				g.burst(float(b.hx), float(b.ptop) - 10, 18, Color("#9ff4ff"))
				for k in 8:
					g.PARTS.append({"x": float(b.hx), "y": float(b.ptop) - 4, "vx": (randf() - .5) * 6, "vy": -randf() * 4, "life": 26, "col": Color(.6, .58, .55)})
				if _on_pillar(b) == int(b.tp):
					g.hurt(1, b.hx)
				# a última vida: bote DUPLO (volta para a água e sai do outro lado do pilar do Tomé)
				if int(b.hp) <= 1 and not b.dbl:
					b.dbl = true
					b.dbl_go = true
					b.st = "dive"
					b.t = 0
					b.side = -int(b.side)
				else:
					b.st = "stuck"
					b.t = 0
					b.hits_now = 0
					if not g.L.get("_eel_presa", false):
						g.L["_eel_presa"] = true
						g.flash_tut("Os dentes ficaram PRESOS na pedra!", "A enguia mordeu a pedra e ficou presa: pule na cabeça dela (ou use a picareta ⛏)!", 220)
		"stuck":
			# os dentes presos na pedra: se debate (a hora do pulo na cabeça ou da picareta)
			b.hy = float(b.ptop) - 18 + sin(b.t * .7) * 3
			if b.t % 9 == 0:
				g.PARTS.append({"x": float(b.hx), "y": float(b.ptop) - 6, "vx": (randf() - .5) * 4, "vy": -randf() * 3, "life": 20, "col": Color(.6, .58, .55)})
			if b.t > max(96, 150 - fury * 18):
				b.st = "dive"
				b.t = 0
				Audio.play("splash", -6)
		"hurt":
			b.hy = float(b.ptop) - 18
			if b.t > 18:
				b.st = "dive"
				b.t = 0
		"dive":
			# solta a pedra e volta para a água pelo mesmo vão
			b.hx = move_toward(float(b.hx), b.x, 10.0)
			b.hy = move_toward(float(b.hy), surf + 50, 10.0)
			b.y = move_toward(b.y, surf + 50, 8.0)
			if b.hy >= surf + 49:
				b.st = "swim"
				b.t = 0
				if b.get("dbl_go", false):
					b.dbl_go = false
					b.cd = 4
				else:
					b.cd = max(16, 50 - fury * 10)
					b.side = -int(b.side)
				g.burst(b.x, surf, 14, Color("#bff6ff"))
				Audio.play("splash", -8)
		"down":
			b.y = move_toward(b.y, surf + 4, 2.0)
			b.hx = b.x
			b.hy = b.y
			if b.t > 200:
				b.done = true
				b.active = false
	if b.st == "stuck" and int(b.get("hits_now", 0)) == 0:
		if _stomp(eel_head(b)):
			_eel_hit(b)

## um golpe na cabeça presa (pulo ou picareta): um só por bote
func _eel_hit(b: Dictionary) -> void:
	_hit(b)
	b.hits_now = 1
	g.burst(float(b.hx), float(b.hy) - 10, 18, Color("#bff6ff"))
	Audio.play("unlock", -4, .7)
	if b.hp <= 0:
		b.y = float(b.surf)
		_win(b, "A Enguia de Cristal soltou a pedra e afundou na cisterna! Dá para seguir.")
		return
	b.st = "hurt"
	b.t = 0
	var n: int = int(b.hp)
	g.flash("Toma! Falta%s %d golpe%s. Ela ficou mais rápida!" % ["m" if n > 1 else "", n, "s" if n > 1 else ""], 140)

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
			b.x += b.dir * (2.0 + fury * .5)
			# 2ª fase (metade da vida): deixa poças de fogo no chão
			if int(b.hp) * 2 <= int(b.maxhp) and b.t % 80 == 40:
				SHOTS.append({"k": "patch", "x": b.x - b.dir * 90.0, "y": float(b.y), "vx": 0.0, "vy": 0.0, "t": 0, "life": 300})
				Audio.play("fire", -12, .8)
			if b.x < lo:
				b.x = lo
				b.dir = 1
			elif b.x > hi:
				b.x = hi
				b.dir = -1
			b.cd -= 1
			# embaixo do balcão onde o Tomé está: às vezes ergue a cabeça e solta uma COLUNA de fogo para cima
			var above: bool = p.onGround and p.y + p.h < float(b.y) - 100 and abs(pcx - b.x) < 90
			if above and int(b.get("flarecd", 0)) <= 0 and randf() < .5:
				b.st = "flare"
				b.t = 0
				b.flx = pcx
				b.flarecd = 260
			elif b.cd <= 0 and p.dyingT == 0:
				b.st = "breath"
				b.t = 0
				b.dir = 1 if pcx > b.x else -1
			elif above:
				b.flarecd = int(b.get("flarecd", 0)) - 1
		"breath":
			# abre a boca (aviso) e cospe a bola de fogo na direção do Tomé
			if b.t == max(16, 30 - fury * 4):
				var m: Vector2 = sal_mouth(b)
				var feet: float = p.y + p.h
				if feet < float(b.y) - 60 and p.dyingT == 0:
					# o Tomé está num balcão: bola de fogo em ARCO, que cai lá em cima
					var n := 46.0
					var tx: float = pcx
					var ty: float = feet - 10.0
					SHOTS.append({"k": "fire", "arc": true, "x": m.x, "y": m.y, "vx": (tx - m.x) / n, "vy": (ty - m.y - .5 * .35 * n * n) / n, "t": 0})
				else:
					# a bola de fogo corre rente ao chão
					SHOTS.append({"k": "fire", "x": m.x, "y": b.y - 34, "vx": b.dir * (6.0 + fury * .7), "vy": 0.0, "t": 0})
				Audio.play("fire", -6, 1.2)
				Audio.play("roar", -12, 1.4)
			if b.t > max(30, 48 - fury * 5):
				b.st = "walk"
				b.t = 0
				b.cd = max(50, 110 - fury * 16)
		"flare":
			# aviso: o balcão de cima esquenta (brilho); depois a coluna de fogo sobe
			if b.t == 34:
				Audio.play("fire", -2, .7)
				Audio.play("roar", -8, 1.1)
				g.shake = max(g.shake, 6)
			if b.t >= 34 and b.t < 70:
				var fx: float = float(b.flx)
				if _touch(g.R(fx - 44, float(b.y) - 420, 88, 420)):
					g.hurt(1, fx)
				if b.t % 3 == 0:
					Polish.part("drop", fx + randf_range(-30, 30), float(b.y) - randf_range(40, 380), randf_range(-.6, .6), -randf_range(2, 4), 20, Color(1, .6, .2, .9))
			if b.t > 80:
				b.st = "walk"
				b.t = 0
				b.cd = max(b.cd, 40)
		"cool":
			# apagada: cinza e tonta (a hora de pular em cima)
			if b.t % 9 == 0:
				Polish.part("drop", b.x + randf_range(-110, 110), b.y - 110, randf_range(-.3, .3), -randf_range(.8, 1.6), 40, Color(.9, .92, .95, .6))
			if b.t > max(90, 150 - fury * 16):
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
	if b.st in ["walk", "breath", "relight", "fight0", "flare"]:
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
		# em qualquer ponto do balcão (de pé nele, ou pulando logo acima)
		var bx0: float = float(t.x) - 186.0
		var bx1: float = float(t.x) - 54.0
		if pcx > bx0 and pcx < bx1 and p.y + p.h > float(t.py) - 50 and p.y + p.h < float(t.py) + 8:
			return t
	return {}

func use() -> bool:
	if _defend():
		return true
	var t: Dictionary = near_lever()
	if t.is_empty():
		return false
	if t.st != "full":
		g.flash("A caixa ainda está enchendo... (%d%%)" % int(clamp(float(t.t) / 330.0, 0.0, 1.0) * 100), 90)
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
				if t.t > 6 and t.t < 46 and not b.is_empty() and b.active and b.st in ["walk", "breath", "relight", "flee", "flare"]:
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
				if t.t > 330:
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
			var gsp: float = 3.0 if int(b.hp) <= 1 else 1.3 + fury * .3
			b.x = clamp(b.x + b.dir * gsp, lo, hi)
			if b.t % 30 == 0:
				Audio.play("stomp", -14, .6)
				g.shake = max(g.shake, 2)
			b.cd -= 1
			if b.cd <= 0 and abs(pcx - b.x) < 340 and p.dyingT == 0:
				b.st = "raise"
				b.t = 0
				b.dbl = fury >= 2 and randf() < .45
		"raise":
			# ergue os punhos e o olho fica vermelho: o aviso do soco no chão
			if b.t % 6 == 0:
				Polish.part("drop", b.x - b.dir * 30, b.y - 300, randf_range(-.5, .5), -randf_range(1, 2), 30, Color(.7, .7, .72, .6))
			if b.t > max(18, 38 - fury * 4):
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
					SHOTS.append({"k": "wave", "x": b.x + s * 80, "y": float(b.y), "vx": s * (8.0 + fury * .7), "vy": 0.0, "t": 0})
				# o tranco solta pedras do teto, perto do Tomé (sombra no chão avisa)
				for r in (1 + (1 if fury >= 3 else 0)):
					var rx: float = clamp(pcx + randf_range(-160, 160), float(b.x0) + 30, float(b.x1) - 30)
					SHOTS.append({"k": "rock", "x": rx, "y": float(b.y) - 460, "vx": 0.0, "vy": 0.0, "t": -30 - r * 14})
		"slam":
			if b.t > 10:
				if b.get("dbl", false):
					# soco DUPLO: ergue de novo rapidinho e soca outra vez
					b.dbl = false
					b.st = "raise"
					b.t = 22
				else:
					b.st = "stuck"
					b.t = 0
					b.hs = 0
				if not g.L.get("_gua_preso", false):
					g.L["_gua_preso"] = true
					g.flash_tut("Os punhos ficaram presos! PICARETA!", "O Guardião está preso no chão: chegue perto e use a picareta (⛏) nele!", 200)
		"stuck":
			if b.t % 8 == 0:
				Polish.part("drop", b.x + randf_range(-40, 40), b.y - 4, randf_range(-1.5, 1.5), -randf_range(1, 3), 20, Color("#ffcf6a"))
			if b.t > max(70, 120 - fury * 10):
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
	# (levantando do chão ele ainda não machuca: dá tempo de se afastar)
	if ((b.st == "walk" and b.t > 24) or b.st == "raise") and _touch(gua_box(b)):
		g.hurt(1, b.x)

## golpe de picareta (Kings.swing_hits passa a caixa do golpe)
func swing_hits(hb: Dictionary) -> void:
	var v: Dictionary = boss("vargas")
	if not v.is_empty() and v.active and not v.done and v.st == "tired" and v.t >= 0 and v.red <= 0 and Game.hit(hb, vargas_box(v)):
		_vhit(v)
		return
	var e: Dictionary = boss("enguia")
	if not e.is_empty() and e.active and not e.done and e.st == "stuck" and int(e.get("hits_now", 0)) == 0 and Game.hit(hb, eel_head(e)):
		_eel_hit(e)
		return
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
	# um golpe só por vez: solta os punhos e levanta
	b.st = "hurt"
	b.t = 0
	var n: int = int(b.hp)
	g.flash("Clanc! Falta%s %d golpe%s." % ["m" if n > 1 else "", n, "s" if n > 1 else ""], 140)

# ======================================================================
#  ADEMAR VARGAS (em cima dos vagões parados na ponte, ao amanhecer)
#  Joga barris (rolam pelo teto: pule), joga carvão (em arco: desvie), acende a lâmpada do capacete
#  para cegar o Tomé (toque ✦ no aviso: a lanterna ofusca ele de volta) e investe com a picareta (pule
#  por cima). Depois de cada ataque fica cansado e tonto: a hora do pulo na cabeça ou da picareta.
#  3 fases (2 golpes cada), cada uma mais rápida. No fim, cai sentado no vagão de carvão.
# ======================================================================
var blindT := 0
const VG_H := 150.0

func vargas_head(b: Dictionary) -> Dictionary:
	return g.R(b.x - 30, b.y - VG_H - 4, 60, 44)

func vargas_box(b: Dictionary) -> Dictionary:
	return g.R(b.x - 30, b.y - VG_H + 10, 60, VG_H - 10)

func _vphase(b: Dictionary) -> int:
	return clampi(1 + (int(b.maxhp) - int(b.hp)) / 2, 1, 3)

## a lâmpada do capacete está acendendo (aviso): ✦ defende com a lanterna
func can_defend() -> bool:
	var b: Dictionary = boss("vargas")
	return not b.is_empty() and b.active and b.st == "lamp" and b.t < int(b.get("lampT", 40)) and not b.get("def", false)

func _defend() -> bool:
	if not can_defend():
		return false
	var b: Dictionary = boss("vargas")
	b.def = true
	var p: Dictionary = g.player
	p.face = 1 if b.x > p.x else -1
	p.act = "lantern"
	p.actT = 40
	Audio.play("special", -6)
	if not g.L.get("_vg_def", false):
		g.L["_vg_def"] = true
		g.flash("A lanterna do Tomé brilhou de volta!", 140)
	return true

func _blind_step() -> void:
	if blindT > 0:
		blindT -= 1
		var p: Dictionary = g.player
		p.vx *= .55

func _vargas(b: Dictionary) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	b.t += 1
	var ph: int = _vphase(b)
	var lo: float = float(b.x0) + 70
	var hi: float = float(b.x1) - 70
	var gy: float = float(b.get("y0", b.y))
	if not b.has("y0"):
		b.y0 = b.y
	match b.st:
		"fight0":
			b.st = "idle"
			b.t = 0
			b.cd = 60
			b.n = 0
		"idle":
			# anda de lado, de olho no Tomé, mantendo uma distância
			b.dir = 1 if pcx > b.x else -1
			var want: float = clamp(pcx - b.dir * 330.0, lo, hi)
			b.x = move_toward(b.x, want, 1.4 + ph * .5)
			b.cd -= 1
			if b.cd <= 0 and p.dyingT == 0:
				var opts: Array = ["barrel", "coal", "lamp", "charge"]
				var pick: String = opts[int(b.n) % 4] if ph == 1 else opts[randi() % 4]
				if pick == str(b.get("last", "")):
					pick = opts[(opts.find(pick) + 1) % 4]
				b.last = pick
				b.n = int(b.n) + 1
				b.st = pick
				b.t = 0
				b.def = false
				b.lampT = max(26, 52 - ph * 9)
		"barrel":
			# ergue um barril e joga: ele rola pelo teto dos vagões
			if b.t == max(12, 26 - ph * 4):
				var nb: int = 1 if ph < 3 else 2
				for k in nb:
					SHOTS.append({"k": "barrel", "x": b.x + b.dir * 40, "y": gy, "vx": b.dir * (4.6 + ph * 1.0), "vy": 0.0, "t": -k * 34, "rot": 0.0})
				Audio.play("slide", -4, .7)
			if b.t > 46:
				_vtired(b)
		"coal":
			# punhados de carvão em arco, caindo onde o Tomé está (e em volta)
			var tt: int = max(10, 22 - ph * 3)
			if b.t == tt or (ph >= 2 and b.t == tt + 20) or (ph >= 3 and b.t == tt + 40):
				var n := 40.0
				for k in (2 + ph):
					var tx: float = pcx + (k - (1 + ph) / 2.0) * 70.0
					var sx: float = b.x + b.dir * 30
					var sy: float = gy - 120
					SHOTS.append({"k": "coal", "x": sx, "y": sy, "vx": (tx - sx) / n, "vy": (gy - 10 - sy - .5 * .4 * n * n) / n, "t": 0})
				Audio.play("jump", -10, .6)
			if b.t > tt + 30 + (20 * (ph - 1)):
				_vtired(b)
		"lamp":
			# a lâmpada do capacete vai acendendo (aviso). Sem defesa, o clarão cega o Tomé
			var lt: int = int(b.get("lampT", 40))
			if b.t == lt:
				g.shake = max(g.shake, 6)
				Audio.play("special", -2, 1.6)
				if b.get("def", false):
					# a lanterna do Tomé ofuscou de volta: ele fica tonto por mais tempo
					b.st = "tired"
					b.t = -50
					g.flash("O Vargas ficou ofuscado! Agora!", 120)
				else:
					blindT = 110 + ph * 20
					g.flash("O clarão cegou o Tomé! (Da próxima vez, toque ✦ quando a lâmpada acender.)", 160)
			if b.st == "lamp" and b.t > lt + 30:
				_vtired(b)
		"charge":
			# ergue a picareta (aviso) e corre até a outra ponta: pule por cima
			var wt: int = max(14, 30 - ph * 5)
			if b.t < wt:
				b.dir = 1 if pcx > b.x else -1
			elif b.t == wt:
				Audio.play("roar", -10, .9)
				b.tx = hi if b.dir > 0 else lo
			else:
				b.x = move_toward(b.x, float(b.tx), 6.5 + ph * 1.4)
				if g.T % 4 == 0:
					g.fx("fx_dust", b.x - b.dir * 30, gy - 4, 14, .16, -.25)
				if _touch(vargas_box(b)) and p.iframe == 0:
					g.hurt(1, b.x)
				if abs(b.x - float(b.tx)) < 1:
					g.shake = max(g.shake, 8)
					Audio.play("stomp", -4)
					_vtired(b)
		"tired":
			# cansado, ofegante e tonto: a hora de bater
			if b.t > max(70, 130 - ph * 20):
				b.st = "idle"
				b.t = 0
				b.cd = max(24, 70 - ph * 16)
		"hurt":
			var kb: float = float(b.get("kb", 0.0))
			if abs(kb) > .1:
				b.x = clamp(b.x + kb, lo, hi)
				b.kb = kb * .85
			if b.t > 34:
				b.st = "idle"
				b.t = 0
				b.cd = max(20, 50 - ph * 10)
		"down":
			# cambaleia de costas e cai sentado no vagão de carvão
			var cx: float = float(b.get("coalX", float(b.x1) + 150))
			if b.t < 50:
				b.x = lerpf(float(b.get("dx0", b.x)), cx, b.t / 50.0)
				b.y = gy - sin(b.t / 50.0 * PI) * 90.0
			else:
				b.x = cx
				b.y = gy + 36
			if b.t == 50:
				g.shake = 12
				Audio.play("stomp", -2, .6)
				g.burst(cx, gy + 10, 30, Color(.15, .14, .14))
				g.flash("O Vargas caiu sentado no vagão de carvão! — Tá bom, tá bom... eu desisto!", 260)
			if b.t > 260:
				b.done = true
				b.active = false
				g.running = false
				g.results_ready.emit()
	# acertar: pulo na cabeça (só cansado/tonto)
	if b.st == "tired" and b.t >= 0 and _stomp(vargas_head(b)):
		_vhit(b)

func _vtired(b: Dictionary) -> void:
	b.st = "tired"
	b.t = 0
	if not g.L.get("_vg_tired", false):
		g.L["_vg_tired"] = true
		g.flash_tut("Ele cansou! BATA AGORA!", "O Vargas está cansado e tonto: pule na cabeça dele ou use a picareta (⛏)!", 200)

func _vhit(b: Dictionary) -> void:
	_hit(b)
	g.burst(b.x, b.y - VG_H, 18, Color("#ffd76a"))
	Audio.play("hurt", -6, .8)
	if b.hp <= 0:
		b.st = "down"
		b.t = 0
		b.dx0 = b.x
		SHOTS = []
		blindT = 0
		WON[b.id] = 1
		Polish.final_blow()
		_gate(b, false)
		return
	b.st = "hurt"
	b.t = 0
	b.kb = 6.0 if g.player.x < b.x else -6.0
	var ph0: int = _vphase(b)
	var lines := ["", "— Você não vai levar a menina, mineiro!", "— Esse trem é MEU! Essa mina é MINHA!"]
	if int(b.hp) % 2 == 0 and ph0 >= 2:
		g.flash(lines[ph0 - 1] + "  (Ele ficou mais rápido!)", 200)
	else:
		g.flash("Toma, Vargas! Falta%s %d." % ["m" if b.hp > 1 else "", b.hp], 140)

# ======================================================================
#  bolas de fogo e ondas de choque
# ======================================================================
func _shots() -> void:
	var keep: Array = []
	for s in SHOTS:
		s.t += 1
		s.x += s.vx
		s.y += s.vy
		var b: Dictionary = boss("salamandra" if s.k in ["fire", "patch", "flame"] else ("vargas" if s.k in ["barrel", "coal"] else "guardiao"))
		var alive: bool = s.t < 200 and not b.is_empty() and b.active and s.x > float(b.x0) - 10 and s.x < float(b.x1) + 10 and s.y > float(b.y) - 520 and s.y < float(b.y) + 20
		if s.k == "barrel":
			alive = not b.is_empty() and b.active and s.x > float(b.x0) - 30 and s.x < float(b.x1) + 30 and s.t < 400
			if s.t < 0:
				s.x -= s.vx
			else:
				s.rot = float(s.rot) + s.vx * .05
				if _touch(g.R(s.x - 22, s.y - 44, 44, 44)):
					g.hurt(1, s.x - s.vx * 4)
					alive = false
					g.burst(s.x, s.y - 22, 14, Color("#8a5a2a"))
		elif s.k == "coal":
			alive = not b.is_empty() and b.active and s.t < 200
			s.vy = float(s.vy) + .4
			if _touch(g.R(s.x - 12, s.y - 12, 24, 24)):
				g.hurt(1, s.x - s.vx * 4)
				alive = false
			if s.y >= float(b.y) - 6 and s.vy > 0:
				alive = false
				g.burst(s.x, float(b.y) - 6, 8, Color(.12, .11, .11))
		elif s.k == "patch" or s.k == "flame":
			# poça de fogo no chão / chama no balcão onde a bola caiu
			alive = s.t < int(s.get("life", 60)) and not b.is_empty() and b.active
			if s.t % 4 == 0:
				Polish.part("drop", s.x + randf_range(-26, 26), s.y - 4, randf_range(-.3, .3), -randf_range(1, 2.5), 16, Color(1, .55, .15, .85))
			if s.t > 10 and _touch(g.R(s.x - 34, s.y - 26, 68, 26)):
				g.hurt(1, s.x)
		elif s.k == "rock":
			# pedra do teto: espera (sombra), depois despenca
			alive = not b.is_empty() and b.active and s.t < 160
			if s.t > 0:
				s.vy = min(float(s.vy) + .8, 16.0)
				s.y += s.vy
				if _touch(g.R(s.x - 18, s.y - 18, 36, 36)):
					g.hurt(1, s.x)
					alive = false
				if s.y >= float(b.y) - 16:
					alive = false
					g.burst(s.x, float(b.y) - 6, 12, Color("#8a7a6a"))
					Audio.play("stomp", -12, 1.3)
		elif s.k == "fire":
			if s.get("arc", false):
				s.vy = float(s.vy) + .35
			if s.t % 3 == 0:
				Polish.part("drop", s.x, s.y, randf_range(-.5, .5), randf_range(-1, .2), 18, Color(1, .6, .2, .8))
			if _touch(g.R(s.x - 16, s.y - 16, 32, 32)):
				g.hurt(1, s.x - s.vx * 4)
				alive = false
			# bate em sólido (balcões, paredes)
			for so in g.SOL:
				if so.get("t") in ["plat"] and s.vy > 0 and s.x > float(so.x) and s.x < float(so.x) + float(so.w) and abs(s.y - float(so.y)) < 10:
					alive = false
					# a bola em arco pega fogo no balcão por um tempinho
					keep.append({"k": "flame", "x": s.x, "y": float(so.y), "vx": 0.0, "vy": 0.0, "t": 0, "life": 70})
					break
			if s.get("arc", false) and s.y >= float(b.y) - 4:
				alive = false
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
