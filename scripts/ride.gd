extends RefCounted
class_name Ride
## O cavalo preso no arame farpado: o Tomé solta (✦), uma cena curta, e o cavalo dispara sozinho
## pela trilha da neve (uns 25 s). PULAR salta troncos, pedras e buracos; ↓ abaixa sob galhos e
## cordas. Cada batida custa um coração e o cavalo tropeça; sem corações, a cavalgada recomeça.

var g
var H := {}            # o cavalo
var OBS: Array = []     # obstáculos da trilha
var riding := false
var hx := 0.0
var hy := 500.0
var vy := 0.0
var spd := 0.0
var duck := false
var stumble := 0
var gallop := 0.0
var done := false
var tries := 0

const BOX_W := 66.0
var jbuf := 0          # PULAR apertado um pouco antes de pousar ainda vale

func _init(game) -> void:
	g = game

func load_level() -> void:
	H = {}
	OBS = []
	riding = false
	done = false
	if g.L.has("horse"):
		H = g.L.horse.duplicate()
		H.st = "trapped"
		H.t = 0
		H.hx = float(H.x)
	for o in g.L.get("ride", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		OBS.append(d)

func near_horse() -> bool:
	if H.is_empty() or H.st != "trapped":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - H.x) < 110 and abs(p.y + p.h - H.y) < 60 and not p.get("dog")

## ✦ USAR perto do cavalo: solta do arame
func use() -> bool:
	if not near_horse():
		return false
	H.st = "free"
	H.t = 0
	Audio.play("unlock")
	Audio.vib(40)
	g.burst(H.x - 40, H.y - 40, 16, Color("#cdbfa6"))
	g.start_cine("cavalo", H.x + 40, H.y - 80, 300,
		[[20, 120, "TOMÉ", "Calma, garoto... pronto, o arame saiu. Você está livre!", "tome"],
		 [130, 240, "TOMÉ", "Me leva até a mina? A Isis está me esperando. Vamos!", "tome"]],
		[])
	return true

func cine_step(c: Dictionary) -> void:
	if c.id != "cavalo":
		return
	H.t = c.t
	if c.t == 100:
		Audio.play("roar", -16)
	if c.t == 250:
		Audio.play("jump", -4)

func cine_end(id: String) -> void:
	if id != "cavalo":
		return
	_start()

func _start() -> void:
	var p: Dictionary = g.player
	H.st = "ride"
	riding = true
	hx = float(H.ride0)
	hy = 500.0
	vy = 0.0
	spd = 1.0
	duck = false
	stumble = 0
	jbuf = 0
	for o in OBS:
		o.hit = false
	for s in g.SOL.duplicate():
		if s.get("id") == "horsebank":
			g.SOL.erase(s)
	p.hp = Game.MAXHP
	p.vine = null
	p.ladder = null
	p.bar = null
	if not g.X.DOG.is_empty() and g.X.dog_free():
		g.X.DOG.st = "ride"
	_place_player()
	g.snap_camera()
	g.flash_tut("Segure firme!", "Segure firme! PULAR salta (pule nas marcas de cascos na neve). ↓ abaixa sob galhos e cordas. → acelera, ← segura.", 240)

func _place_player() -> void:
	var p: Dictionary = g.player
	p.x = hx - p.w / 2 + 6
	p.y = hy - 74 - p.h + (14 if duck else 0)
	p.vx = spd
	p.vy = vy
	p.onGround = hy >= 500.0
	p.face = 1

## caixa do cavalo com o Tomé montado (do tamanho do desenho)
func box() -> Dictionary:
	var top: float = hy - (100 if duck else 124)
	return g.R(hx - BOX_W / 2, top, BOX_W, hy - top)

## pulo sempre igual (preciso): sobe JUMP_V, gravidade JUMP_G
const JUMP_V := 10.5
const JUMP_G := .5

## área de batida de cada obstáculo (é a mesma usada no desenho)
static func obs_rect(o: Dictionary) -> Rect2:
	match o.k:
		"log":
			return Rect2(o.x + 10, 478, 44, 22)
		"rock":
			return Rect2(o.x + 12, 464, 36, 36)
		"fence":
			return Rect2(o.x + 12, 462, 36, 38)
		"branch":
			return Rect2(o.x, 368, 90, 28)
		"rope":
			return Rect2(o.x, 378, 84, 18)
	return Rect2()

## centro do obstáculo de pular (para a marca de cascos no melhor ponto de salto)
static func obs_center(o: Dictionary) -> float:
	match o.k:
		"log":
			return o.x + 32
		"rock":
			return o.x + 30
		"fence":
			return o.x + 30
		"gap":
			return o.x + o.w / 2.0
	return -1.0

## onde saltar para passar bem no meio (metade do tempo no ar antes do centro)
func takeoff_x(o: Dictionary) -> float:
	return obs_center(o) - float(H.spd) * (JUMP_V / JUMP_G)

func step() -> void:
	var p: Dictionary = g.player
	g.T += 1
	# galope suave: 8 quadros, a cadência acompanha a velocidade
	gallop += spd * .042
	var want: float = float(H.spd)
	if g.kd("R"):
		want += .8
	elif g.kd("L"):
		want -= .9
	if stumble > 0:
		stumble -= 1
		spd = move_toward(spd, 2.0, .3)
	else:
		spd = move_toward(spd, want, .04)
	var on_ground: bool = hy >= 500.0
	if g.pressed("J"):
		jbuf = 9
	elif jbuf > 0:
		jbuf -= 1
	if jbuf > 0 and on_ground and stumble < 20:
		jbuf = 0
		vy = -JUMP_V
		Audio.play("jump", -6)
		g.burst(hx - 30, 500, 8, Color(.95, .97, 1))
	duck = g.kd("S") and on_ground
	# pulo sempre do mesmo tamanho: dá para acertar o ponto (marca dos cascos na neve)
	vy += JUMP_G
	hy = min(500.0, hy + vy)
	if hy >= 500.0:
		if vy > 6:
			g.fx("fx_dust", hx - 20, 494, 14, .12, -.2)
		vy = 0.0
	hx += spd
	# neve levantada pelos cascos e o bafo do cavalo no frio
	if on_ground and g.T % 4 == 0:
		g.PARTS.append({"x": hx - 30 + randf_range(-10, 10), "y": 498, "vx": -spd * .35 + randf_range(-.3, .3), "vy": -1.2 - randf() * .8, "life": 18, "col": Color(.96, .98, 1, .85)})
	if g.T % 48 == 0:
		for k in 3:
			g.PARTS.append({"x": hx + 66, "y": hy - 98 + (14 if duck else 0), "vx": .9 + spd * .4 + k * .2, "vy": -.25, "life": 30, "col": Color(1, 1, 1, .45)})
	# obstáculos
	var b := box()
	for o in OBS:
		if o.hit or o.x + 140 < hx - 80 or o.x > hx + 80:
			continue
		var bad := false
		# as caixas de batida têm uma folga: raspar de leve não conta
		if o.k == "gap":
			bad = hy >= 498 and hx > o.x + 22 and hx < o.x + o.w - 22
		else:
			var r := obs_rect(o)
			bad = Game.hit(b, g.R(r.position.x, r.position.y, r.size.x, r.size.y))
		if bad:
			o.hit = true
			_hurt(o)
	# lápis
	for c in g.coins_near(hx - 120, hx + 120):
		if not c.got and abs(c.x - hx) < 70 and Game.hit(b, g.R(c.x - 15, c.y - 15, 30, 30)):
			c.got = true
			g.STATS.pen += 1
			g.gain_coin(c.x, c.y)
	_place_player()
	if p.iframe > 0:
		p.iframe -= 1
	if hx >= float(H.ride1):
		_finish()

func _hurt(o: Dictionary) -> void:
	var p: Dictionary = g.player
	if o.k == "gap":
		# tropeça na beirada e salta por cima
		vy = -9.0
		hy = 499.0
	stumble = 40
	spd = 1.5
	g.shake = 4
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.play("stomp", -8)
	Audio.vib(60)
	g.burst(hx + 30, hy - 60, 12, Color("#e07a6a"))
	if p.iframe > 0:
		return
	p.iframe = 50
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		g.iris_t = 30
		g.flash("O cavalo empacou! Vamos de novo — PULAR para saltar, ↓ para abaixar.", 220)
		_start()

func _finish() -> void:
	var p: Dictionary = g.player
	riding = false
	done = true
	H.st = "gone"
	H.t = 0
	H.hx = hx
	p.x = hx + 30
	p.y = 500 - p.h
	p.vx = 2.0
	p.vy = -6.0
	p.onGround = false
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "door"
		g.X.DOG.x = hx - 30
		g.X.DOG.y = 500.0
	Audio.play("roar", -14)
	g.flash("Valeu, amigo! O cavalo voltou para a vila. A trilha da mina começa aqui.", 240)

## o cavalo indo embora depois da cavalgada
func post() -> void:
	if H.is_empty():
		return
	H.t += 1
	if H.st == "gone":
		H.hx -= 6.0
		if H.t > 200:
			H.st = "away"

func save_data() -> Dictionary:
	return {"done": done}

func restore(d: Dictionary) -> void:
	if d.get("done", false) and not H.is_empty():
		done = true
		H.st = "away"
		for s in g.SOL.duplicate():
			if s.get("id") == "horsebank":
				g.SOL.erase(s)
