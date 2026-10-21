extends RefCounted
class_name Kings
## Os outros dois reis do caminho:
##  - GAVIÃO-REI (nas copas, à tarde): avisa o mergulho com a sombra no chão; se errar, as garras
##    ficam presas na madeira e a picareta acerta. O facho da lanterna confunde. 4 golpes;
##    depois de 2, mergulha duas vezes seguidas e chama corvos.
##  - BAGRE-REI (no fundo do lago): investe, revolve a lama e suga. Cansado, mostra as escamas
##    que brilham: é ali que o arpão acerta. 4 acertos. Vencido, abre a corrente de bolhas.

var g
var HAWK := {}
var FISH := {}
var BEAR := {}

func _init(game) -> void:
	g = game

func load_level() -> void:
	HAWK = {}
	FISH = {}
	BEAR = {}
	var L: Dictionary = g.L
	if L.has("bear"):
		var b: Dictionary = L.bear
		BEAR = {"x0": b.x0, "x1": b.x1, "gy": b.y, "trig": b.trig, "maxhp": b.hp, "hp": b.hp, "st": "wait",
			"x": b.x1 - 160.0, "dir": -1, "t": 0, "red": 0, "anim": 0.0, "active": false, "done": false, "hx": 0.0, "miss": 0}
	if L.has("hawk"):
		var h: Dictionary = L.hawk
		HAWK = {"x0": h.x0, "x1": h.x1, "gy": h.y, "trig": h.trig, "maxhp": h.hp, "hp": h.hp, "st": "wait",
			"x": (h.x0 + h.x1) / 2.0, "y": h.y - 340.0, "t": 0, "dir": 1, "tx": 0.0, "sx": 0.0, "sy": 0.0,
			"red": 0, "active": false, "done": false, "conf": false, "second": false, "crows": false}
	if L.has("fish"):
		var f: Dictionary = L.fish
		FISH = {"x0": f.x0, "x1": f.x1, "y0": f.y0, "y1": f.y1, "trig": f.trig, "maxhp": f.hp, "hp": f.hp,
			"st": "wait", "x": f.x1 - 160.0, "y": (f.y0 + f.y1) / 2.0, "vx": 0.0, "dir": -1, "t": 0, "red": 0,
			"active": false, "done": false, "cyc": 0, "mud": 0.0, "mouth": 0.0, "scales": [true, true, true, true], "al": 1.0}

func active() -> bool:
	return (not HAWK.is_empty() and HAWK.active and not HAWK.done) or (not FISH.is_empty() and FISH.active and not FISH.done) or bear_on()

func bear_on() -> bool:
	return not BEAR.is_empty() and BEAR.active and not BEAR.done

func fish_done() -> bool:
	return FISH.is_empty() or FISH.done

func _gate(id: String, on: bool, r: Rect2) -> void:
	for s in g.SOL.duplicate():
		if s.get("id") == id:
			g.SOL.erase(s)
	if on:
		g.SOL.append({"t": "kinggate", "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "id": id})

func post() -> void:
	_hawk()
	_fish()
	_bear()

# ======================================================================
#  GAVIÃO-REI
# ======================================================================
func hawk_box() -> Dictionary:
	return g.R(HAWK.x - 46, HAWK.y - 58, 92, 64)

func _hawk() -> void:
	if HAWK.is_empty() or HAWK.done:
		return
	var h: Dictionary = HAWK
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	var gy: float = h.gy
	if h.red > 0:
		h.red -= 1
	var enraged: bool = h.hp <= 2
	match h.st:
		"wait":
			if pcx > h.trig and pcx < h.x1 and feet <= gy + 4 and feet > gy - 300 and p.dyingT == 0:
				h.active = true
				h.st = "circle"
				h.t = 0
				h.x = h.x1 - 100.0
				h.y = gy - 420.0
				h.hp = h.maxhp
				_gate("hawkL", true, Rect2(h.x0 - 24, gy - 260, 24, 260))
				_gate("hawkR", true, Rect2(h.x1, gy - 260, 24, 260))
				Audio.play("thunder", -8)
				g.start_cine("gaviao", (h.x0 + h.x1) / 2.0, gy - 160, 250,
					[[150, 245, "TOMÉ", "Que gavião enorme! Preciso ficar longe da sombra dele...", "tome"]],
					[60, 150, "GAVIÃO-REI", "o senhor das copas"])
			return
		"circle":
			h.t += 1
			var cx: float = (h.x0 + h.x1) / 2.0 + sin(h.t * .022) * (h.x1 - h.x0) * .38
			h.dir = 1 if cos(h.t * .022) > 0 else -1
			h.x = lerpf(h.x, cx, .06)
			h.y = lerpf(h.y, gy - 165 + sin(h.t * .07) * 12, .05)
			if h.t > (70 if enraged else 110) and p.dyingT == 0:
				_mark(h, pcx)
		"mark":
			h.t += 1
			h.x = lerpf(h.x, h.tx, .08)
			h.y = lerpf(h.y, gy - 160, .08)
			h.dir = 1 if h.tx > h.x else h.dir
			# o facho da lanterna confunde: ele mergulha no lugar errado
			if not h.conf and g.X.in_cone(h.x, h.y - 20, 520.0):
				h.conf = true
				var away: float = h.x0 + 80 if pcx > (h.x0 + h.x1) / 2.0 else h.x1 - 80
				h.tx = away
				g.burst(h.x, h.y - 30, 12, Color("#ffe9a0"))
				Audio.play("dj", -6)
				g.note("O facho ofuscou o Gavião-Rei!")
			if h.t > (26 if h.second else (40 if enraged else 52)):
				h.st = "dive"
				h.t = 0
				h.sx = h.x
				h.sy = h.y
				Audio.play("slide", -2)
		"dive":
			h.t += 1
			var u: float = min(1.0, h.t / 20.0)
			h.x = lerpf(h.sx, h.tx, u)
			h.y = lerpf(h.sy, gy, u * u)
			if p.dyingT == 0 and Game.hit(p, hawk_box()):
				g.hurt(1, h.x)
			if u >= 1.0:
				g.shake = 10
				g.burst(h.x, gy, 14, Color("#cdbfa6"))
				g.fx("fx_pieces", h.x, gy - 8, 16, .3, -.4)
				Audio.play("stomp", -6)
				if enraged and not h.second and not h.conf:
					# primeiro de dois mergulhos: sobe um pouco e vem de novo
					h.second = true
					h.st = "mark"
					h.t = 0
					h.tx = clamp(pcx, h.x0 + 60, h.x1 - 60)
				else:
					h.second = false
					h.conf = false
					h.st = "stuck"
					h.t = 0
					if not g.L.get("_hawk_tip", false):
						g.L["_hawk_tip"] = true
						g.flash_tut("As garras ficaram presas! GOLPE!", "As garras ficaram presas no chão! Corra e acerte com a picareta (GOLPE)!", 180)
		"stuck":
			h.t += 1
			h.y = gy + sin(h.t * .9) * 1.5
			if h.t > (110 if enraged else 150):
				h.st = "rise"
				h.t = 0
				Audio.play("dj", -8)
		"rise":
			h.t += 1
			h.y = lerpf(h.y, gy - 165, .07)
			if h.t > 40:
				h.st = "circle"
				h.t = 0
		"flee":
			h.t += 1
			h.x += 5.0
			h.y -= 4.0
			if h.t > 120:
				h.done = true
				h.active = false

func _mark(h: Dictionary, pcx: float) -> void:
	h.st = "mark"
	h.t = 0
	h.conf = false
	h.tx = clamp(pcx, h.x0 + 60, h.x1 - 60)
	Audio.play("roar", -16)

## sombra do mergulho (posição e força) para o desenho
func hawk_shadow() -> Vector2:
	if HAWK.is_empty() or HAWK.st not in ["mark", "dive"]:
		return Vector2(-1, 0)
	var k: float = clamp(HAWK.t / 40.0, .2, 1.0) if HAWK.st == "mark" else 1.0
	return Vector2(HAWK.tx, k)

## golpe de picareta (Mech chama com a caixa do golpe)
func swing_hits(hb: Dictionary) -> void:
	if not BEAR.is_empty() and not BEAR.done and BEAR.st == "dizzy" and BEAR.red == 0 and Game.hit(hb, bear_box()):
		_bear_hit()
		return
	if HAWK.is_empty() or HAWK.done or HAWK.st != "stuck" or HAWK.red > 0:
		return
	if not Game.hit(hb, hawk_box()):
		return
	var h: Dictionary = HAWK
	h.hp -= 1
	h.red = 30
	g.hit_stop = 6
	g.shake = 10
	Audio.play("stomp")
	Audio.play("roar", -10)
	Audio.vib(60)
	g.burst(h.x, h.y - 30, 18, Color("#e0c8a0"))
	for i in 6:
		g.PARTS.append({"x": h.x, "y": h.y - 30, "vx": (randf() - .5) * 5, "vy": -randf() * 4, "life": 40, "col": Color("#7a5232")})
	if h.hp <= 0:
		h.st = "flee"
		h.t = 0
		_gate("hawkL", false, Rect2())
		_gate("hawkR", false, Rect2())
		for e in g.EN:
			if e.k == "crow" and e.get("minion") and not e.dead:
				g.kill_enemy(e, "hit")
		for i in 10:
			g.gain_coin(h.x, h.y - 40, true)
		g.player.hp = Game.MAXHP
		Audio.play("door", -4)
		g.flash("O Gavião-Rei fugiu para as nuvens! O caminho está livre.", 240)
		return
	h.st = "rise"
	h.t = 0
	if h.hp == 2 and not h.crows:
		h.crows = true
		for k in 1:
			var cx: float = h.x0 + 150 + k * (h.x1 - h.x0 - 300)
			g.EN.append({"k": "crow", "x": cx, "y": h.gy - 260.0, "cy": h.gy - 230.0 - k * 30, "r": [h.x0 + 40, h.x1 - 40],
				"dir": -1, "dead": 0, "base": h.gy - 230.0, "stun": 0, "leap": 0, "x0": cx, "sx": cx, "minion": 1})
		g.flash("Acertou! Ele chamou um corvo — e agora mergulha duas vezes!", 200)
	else:
		g.flash("Acertou! Falta%s %d." % ["m" if h.hp > 1 else "", h.hp], 120)


# ======================================================================
#  URSO-PARDO-REI (fim da neve)
#  anda até o Tomé, se ergue com um rugido e dá uma patada forte no chão à frente.
#  Na terceira patada errada fica tonto: pular na cabeça dele ou bater com a picareta. 4 acertos.
#  Na clareira há blocos de gelo e galhos para subir e pular por cima dele.
# ======================================================================
func bear_box() -> Dictionary:
	var b: Dictionary = BEAR
	match b.st:
		"rear", "slam":
			return g.R(b.x - 60, b.gy - 180, 120, 180)
		"dizzy":
			return g.R(b.x - 70, b.gy - 120, 140, 120)
		"down", "flee":
			return g.R(-9999, -9999, 0, 0)
	return g.R(b.x - 95, b.gy - 130, 190, 130)

## área da patada (à frente do urso)
func bear_paw() -> Rect2:
	var b: Dictionary = BEAR
	var a: float = b.x + b.dir * 25.0
	var c: float = b.x + b.dir * 215.0
	return Rect2(min(a, c), b.gy - 80, abs(c - a), 80)

func _bear() -> void:
	if BEAR.is_empty() or BEAR.done:
		return
	var b: Dictionary = BEAR
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	var gy: float = b.gy
	if b.red > 0:
		b.red -= 1
	var lvl: int = b.maxhp - b.hp          # 0..3: fica mais rápido a cada acerto
	match b.st:
		"wait":
			if pcx > b.trig and pcx < b.x1 and feet <= gy + 4 and feet > gy - 300 and p.dyingT == 0:
				b.active = true
				b.st = "walk"
				b.t = 0
				b.hp = b.maxhp
				b.miss = 0
				b.x = b.x1 - 420.0
				b.dir = -1
				_gate("bearL", true, Rect2(b.x0 - 24, gy - 260, 24, 260))
				_gate("bearR", true, Rect2(b.x1, gy - 260, 24, 260))
				Audio.play("roar", -4)
				g.start_cine("urso", (b.x0 + b.x1) / 2.0, gy - 140, 250,
					[[150, 245, "TOMÉ", "Um urso enorme... e de coroa! Quando ele errar a patada, é a minha vez.", "tome"]],
					[60, 150, "URSO-PARDO-REI", "o guardião da neve"])
			return
		"walk":
			b.t += 1
			var dx: float = pcx - b.x
			b.dir = 1 if dx > 0 else -1
			var spd: float = 1.7 + lvl * .35
			b.x = clamp(b.x + b.dir * spd, b.x0 + 100, b.x1 - 100)
			b.anim += spd * .05
			if abs(dx) < 200 and b.t > 30 and p.dyingT == 0:
				b.st = "rear"
				b.t = 0
				Audio.play("roar", -6)
		"rear":
			# se ergue: aviso para o jogador sair da frente
			b.t += 1
			if b.t > 46 - lvl * 5:
				b.st = "slam"
				b.t = 0
				var hit_tome := false
				var paw := bear_paw()
				if p.dyingT == 0 and pcx > paw.position.x - 12 and pcx < paw.end.x + 12 and feet > gy - 90:
					hit_tome = true
					g.hurt(1, b.x)
				g.shake = 14
				Audio.play("stomp")
				Audio.vib(80)
				g.burst(b.x + b.dir * 150, gy, 24, Color(.95, .97, 1))
				g.fx("fx_dust", b.x + b.dir * 150, gy - 10, 20, .4, -.3)
				b.missed = not hit_tome
		"slam":
			b.t += 1
			if b.t > 22:
				b.t = 0
				if b.missed:
					b.miss = b.get("miss", 0) + 1
				if b.missed and b.miss >= 3:
					# a terceira patada errada cansa o urso: fica tonto
					b.miss = 0
					b.st = "dizzy"
					Audio.play("dj", -6)
					if not g.L.get("_bear_tip", false):
						g.L["_bear_tip"] = true
						g.flash_tut("Ele está tonto: pule na cabeça ou GOLPE!", "Três patadas erradas e o urso ficou tonto! Pule na cabeça dele ou acerte com a picareta (GOLPE)!", 200)
				else:
					b.st = "back"
					if b.missed:
						g.note("Errou a patada! (%d/3)" % b.miss)
						if b.miss == 1 and not g.L.get("_bear_tip0", false):
							g.L["_bear_tip0"] = true
							g.flash_tut("Desvie das patadas!", "Desvie das patadas: na terceira que ele errar, ele fica tonto. Suba no gelo e nos galhos para pular por cima dele!", 220)
		"dizzy":
			b.t += 1
			# pular na cabeça dele conta como acerto
			if p.vy > 0 and p.dyingT == 0 and abs(pcx - b.x) < 70 and feet > gy - 128 and feet < gy - 96 and b.red == 0:
				p.vy = -10.5
				p.y = gy - 128 - p.h
				_bear_hit()
				return
			if b.t > 150 - lvl * 20:
				b.st = "back"
				b.t = 0
		"back":
			# acorda e se afasta um pouco antes de voltar a andar
			b.t += 1
			var away: float = -1.0 if pcx > b.x else 1.0
			b.dir = -int(away)
			b.x = clamp(b.x + away * 4.5, b.x0 + 100, b.x1 - 100)
			b.anim += .2
			if b.t > 45:
				b.st = "walk"
				b.t = 0
		"flee":
			b.t += 1
			b.dir = 1
			b.x += 4.0
			b.anim += .2
			if b.t > 140:
				b.done = true
				b.active = false
	# encostar no urso (sem ser em cima dele tonto) machuca
	if b.st in ["walk", "rear"] and p.dyingT == 0 and Game.hit(p, bear_box()):
		if p.vy > 0 and feet < gy - 110:
			p.vy = -8.0
		else:
			g.hurt(1, b.x)

func _bear_hit() -> void:
	var b: Dictionary = BEAR
	b.hp -= 1
	b.red = 30
	g.hit_stop = 6
	g.shake = 10
	Audio.play("stomp")
	Audio.play("roar", -10)
	Audio.vib(60)
	g.burst(b.x, b.gy - 100, 18, Color("#c89a6a"))
	if b.hp <= 0:
		b.st = "flee"
		b.t = 0
		_gate("bearL", false, Rect2())
		_gate("bearR", false, Rect2())
		for i in 10:
			g.gain_coin(b.x, b.gy - 120, true)
		g.player.hp = Game.MAXHP
		Audio.play("door", -4)
		g.flash("O Urso-Rei voltou para a floresta! O caminho da mina está livre.", 240)
		return
	b.st = "back"
	b.t = 0
	g.flash("Acertou! Falta%s %d." % ["m" if b.hp > 1 else "", b.hp], 120)

# ======================================================================
#  BAGRE-REI
# ======================================================================
func fish_box() -> Dictionary:
	return g.R(FISH.x - 120, FISH.y - 46, 240, 92)

## escamas que brilham (pontos fracos), em coordenadas do mundo
func scale_pts() -> Array:
	var out := []
	var f: Dictionary = FISH
	# as 4 escamas azuis do desenho (em relação ao centro do bagre, olhando para a direita)
	for p in [Vector2(-1, 7), Vector2(23, 8), Vector2(34, -6), Vector2(44, 3)]:
		out.append(Vector2(f.x + p.x * f.dir, f.y + p.y))
	return out

func fish_weak() -> bool:
	return not FISH.is_empty() and FISH.st == "tired"

func _fish() -> void:
	if FISH.is_empty() or FISH.done:
		return
	var f: Dictionary = FISH
	var p: Dictionary = g.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	if f.red > 0:
		f.red -= 1
	f.mud = max(0.0, f.mud - .004)
	f.al = move_toward(f.al, .25 if f.mud > .45 and f.st in ["mud", "lurk"] else 1.0, .03)
	var mid: float = (f.y0 + f.y1) / 2.0
	match f.st:
		"wait":
			if pc.x > f.trig and pc.x < f.x1 and pc.y > f.y0 and p.swim and p.dyingT == 0:
				if not g.NT.helmet:
					if not g.L.get("_fish_air", false):
						g.L["_fish_air"] = true
						g.flash("Algo enorme se mexe no escuro... Sem ar de sobra não dá para ficar aqui!", 200)
					return
				f.active = true
				f.st = "intro"
				f.t = 0
				f.x = f.x1 + 120.0
				f.y = mid
				f.hp = f.maxhp
				f.scales = [true, true, true, true]
				_gate("fishL", true, Rect2(f.x0 - 24, f.y0, 24, f.y1 - f.y0))
				_gate("fishR", true, Rect2(f.x1, f.y0, 24, f.y1 - f.y0))
				Audio.play("thunder", -8)
				g.start_cine("bagre", (f.x0 + f.x1) / 2.0 + 120, mid, 250,
					[[150, 245, "TOMÉ", "Um bagre do tamanho de um barco! As escamas que brilham devem ser o ponto fraco.", "tome"]],
					[60, 150, "BAGRE-REI", "o rei do lago escuro"])
			return
		"intro":
			f.t += 1
			f.dir = -1
			f.x = lerpf(f.x, f.x1 - 170, .04)
			if f.t > 60:
				f.st = "idle"
				f.t = 0
		"idle":
			f.t += 1
			f.dir = 1 if pc.x > f.x else -1
			f.y = lerpf(f.y, clamp(pc.y, f.y0 + 70, f.y1 - 70), .02)
			f.x += f.dir * .5
			f.x = clamp(f.x, f.x0 + 130, f.x1 - 130)
			if f.t > 70:
				f.t = 0
				var att: Array = ["charge", "suck", "mud"]
				f.st = att[f.cyc % 3]
				f.cyc += 1
				if f.st == "charge":
					f.st = "aim"
		"aim":
			f.t += 1
			f.dir = 1 if pc.x > f.x else -1
			if f.t < 28:
				f.y = lerpf(f.y, clamp(pc.y, f.y0 + 60, f.y1 - 60), .08)
			if f.t > 44:
				f.st = "charge"
				f.t = 0
				f.vx = 0.0
				Audio.play("roar", -12)
		"charge":
			f.t += 1
			f.vx = move_toward(f.vx, f.dir * 9.0, .7)
			f.x += f.vx
			if p.dyingT == 0 and Game.hit(p, fish_box()):
				g.hurt(1, f.x)
			if f.x - 120 < f.x0 or f.x + 120 > f.x1:
				f.x = clamp(f.x, f.x0 + 120, f.x1 - 120)
				g.shake = 12
				Audio.play("stomp", -4)
				g.burst(f.x + f.dir * 120, f.y, 16, Color(.6, .7, .7))
				_tired(f, 170)
		"suck":
			f.t += 1
			f.dir = 1 if pc.x > f.x else -1
			f.mouth = min(1.0, f.mouth + .05)
			var mouth := Vector2(f.x + f.dir * 118, f.y + 6)
			if f.t > 30 and f.t < 190 and p.swim:
				var d: Vector2 = mouth - pc
				var k: float = clamp(1.0 - d.length() / 700.0, 0.0, 1.0)
				p.vx += sign(d.x) * .42 * k
				p.vy += sign(d.y) * .12 * k
				if g.T % 4 == 0:
					g.X.BUB.append({"x": pc.x + (randf() - .5) * 120, "y": pc.y + (randf() - .5) * 80, "t": 0, "top": f.y0})
				if d.length() < 46 and p.dyingT == 0:
					g.hurt(1, mouth.x)
					p.vx = -f.dir * 7.0
					p.vy = -2.0
			if f.t > 190:
				f.mouth = 0.0
				_tired(f, 150)
		"mud":
			f.t += 1
			f.y = lerpf(f.y, f.y1 - 60, .06)
			if f.t % 6 == 0:
				f.mud = min(1.0, f.mud + .08)
			if f.t > 90:
				f.st = "lurk"
				f.t = 0
		"lurk":
			# escondido na lama, sobe de surpresa por baixo do Tomé
			f.t += 1
			f.x = lerpf(f.x, pc.x, .03)
			if f.t > 60:
				f.st = "aim"
				f.t = 20
		"tired":
			f.t += 1
			f.y = lerpf(f.y, mid + sin(f.t * .05) * 30, .03)
			if f.t > f.get("tired_t", 150):
				f.st = "idle"
				f.t = 0
		"hurt":
			f.t += 1
			f.x += -f.dir * 2.0
			if f.t > 30:
				f.st = "idle"
				f.t = 0
		"down":
			f.t += 1
			f.y = lerpf(f.y, f.y0 + 30, .02)
			if f.t > 160:
				f.done = true
				f.active = false
	f.x = clamp(f.x, f.x0 - 200, f.x1 + 200)

func _tired(f: Dictionary, n: int) -> void:
	f.st = "tired"
	f.t = 0
	f.tired_t = n
	f.vx = 0.0
	if not g.L.get("_fish_tip", false):
		g.L["_fish_tip"] = true
		g.flash_tut("Agora: arpão nas escamas!", "Ele cansou! As escamas brilhando são o ponto fraco: mire e aperte GOLPE para o arpão.", 200)

## o arpão acertou alguma coisa do bagre?
func harpoon_hit(hp: Dictionary) -> bool:
	if FISH.is_empty() or FISH.done or not FISH.active or FISH.st == "down":
		return false
	var f: Dictionary = FISH
	var tip := Vector2(hp.x, hp.y)
	if f.st == "tired":
		var pts := scale_pts()
		# acerta a escama mais perto do arpão quando ele chega à fileira de escamas
		var best := -1
		var bd := 99999.0
		var inside: bool = Game.hit(g.R(tip.x - 6, tip.y - 4, 12, 8), fish_box())
		for i in 4:
			var dd: float = tip.distance_to(pts[i])
			if f.scales[i] and dd < bd and (dd < 34 or (inside and abs(tip.y - pts[i].y) < 30)):
				bd = dd
				best = i
		for i in ([best] if best >= 0 else []):
			if true:
				f.scales[i] = false
				f.hp -= 1
				f.red = 30
				g.hit_stop = 6
				g.shake = 10
				Audio.play("stomp")
				Audio.play("roar", -10)
				Audio.vib(70)
				g.burst(pts[i].x, pts[i].y, 20, Color("#9ff0ff"))
				if f.hp <= 0:
					f.st = "down"
					f.t = 0
					_gate("fishR", false, Rect2())
					_gate("fishL", false, Rect2())
					for k in 10:
						g.gain_coin(f.x, f.y, true)
					g.player.hp = Game.MAXHP
					Audio.play("door", -4)
					g.flash("O Bagre-Rei foi vencido! Uma corrente de bolhas se abriu à direita: entre nela para subir.", 280)
				else:
					f.st = "hurt"
					f.t = 0
					g.flash("Acertou a escama! Falta%s %d." % ["m" if f.hp > 1 else "", f.hp], 120)
				return true
	if Game.hit(g.R(tip.x - 6, tip.y - 4, 12, 8), fish_box()):
		Audio.play("unlock", -10)
		g.burst(tip.x, tip.y, 6, Color(.8, .85, .9))
		if not g.L.get("_fish_clank", false):
			g.L["_fish_clank"] = true
			g.note("Clanc! O couro é duro. Espere ele cansar e mire nas escamas que brilham.")
		return true
	return false

func cine_step(_c: Dictionary) -> void:
	pass

func cine_end(id: String) -> void:
	match id:
		"gaviao":
			g.tip("Fuja da sombra! Se ele errar, acerte com a picareta. O facho (segure ✦) ofusca o gavião.", 220)
		"urso":
			g.tip("Fique longe da frente dele quando ele se erguer. Se a patada errar, pule na cabeça ou use a picareta (GOLPE).", 220)
		"bagre":
			g.tip("Com o capacete você não perde fôlego. Fuja das investidas e use o arpão (GOLPE) nas escamas brilhantes.", 220)

func reset_on_respawn() -> void:
	if not HAWK.is_empty() and HAWK.active and not HAWK.done:
		HAWK.active = false
		HAWK.st = "wait"
		HAWK.hp = HAWK.maxhp
		HAWK.crows = false
		_gate("hawkL", false, Rect2())
		_gate("hawkR", false, Rect2())
		for e in g.EN:
			if e.get("minion"):
				e.dead = 99
	if bear_on():
		BEAR.active = false
		BEAR.st = "wait"
		BEAR.hp = BEAR.maxhp
		BEAR.miss = 0
		BEAR.x = BEAR.x1 - 160.0
		_gate("bearL", false, Rect2())
		_gate("bearR", false, Rect2())
	if not FISH.is_empty() and FISH.active and not FISH.done:
		FISH.active = false
		FISH.st = "wait"
		FISH.hp = FISH.maxhp
		FISH.mud = 0.0
		FISH.x = FISH.x1 - 160.0
		_gate("fishL", false, Rect2())
		_gate("fishR", false, Rect2())

func save_data() -> Dictionary:
	return {"hawk": HAWK.get("done", false), "fish": FISH.get("done", false), "bear": BEAR.get("done", false)}

func restore(d: Dictionary) -> void:
	if d.get("hawk", false) and not HAWK.is_empty():
		HAWK.done = true
	if d.get("fish", false) and not FISH.is_empty():
		FISH.done = true
	if d.get("bear", false) and not BEAR.is_empty():
		BEAR.done = true
