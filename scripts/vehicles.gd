extends RefCounted
class_name Vehicles
## Os dois passeios automáticos novos (no mesmo espírito da cavalgada):
##  JANGADA  na corredeira entre o pântano e a neve: a correnteza leva sozinha; PULAR salta pedras,
##           troncos e as quedas-d'água (na beirada); ↓ abaixa sob os galhos.
##  BIPLANO  no período do Céu: o Tomé acha o avião na pista antes do precipício, decola e voa sobre
##           o vale; ↑ sobe, ↓ desce, desviando dos bandos de pássaros, gaviões e nuvens de tempestade.
## Cada batida custa um coração; sem corações, o passeio recomeça do começo.

var g
var RA := {}            # dados da jangada (L.raft)
var PL := {}            # dados do biplano (L.plane)
var mode := ""          # "" | "raft" | "plane"
var hx := 0.0
var hy := 0.0
var vy := 0.0
var spd := 0.0
var duck := false
var stumble := 0
var jbuf := 0
var tries := 0
var raft_done := false
var plane_done := false
var phase := ""         # avião: "taxi", "fly", "land", "stop"
var tilt := 0.0
var OBS: Array = []
var RAFT_SOL := {}

func _init(game) -> void:
	g = game

func load_level() -> void:
	mode = ""
	raft_done = false
	plane_done = false
	RA = g.L.get("raft", {}).duplicate(true)
	PL = g.L.get("plane", {}).duplicate(true)
	RAFT_SOL = {}
	if not RA.is_empty():
		RA.px = float(RA.x)
		# a jangada parada no cais é um chão de verdade: pular nela também embarca
		RAFT_SOL = {"t": "raftsol", "x": RA.px - 38.0, "y": water_y(RA.px) - 8.0, "w": 76.0, "h": 12.0, "oneway": 1, "raft": 1}
		g.SOL.append(RAFT_SOL)
	if not PL.is_empty():
		PL.px = float(PL.x)
		PL.py = float(PL.y)

func active() -> bool:
	return mode != ""

# ======================================================================
#  ÁGUA DA CORREDEIRA
# ======================================================================
## nível da água em x (cada queda-d'água desce 40 px)
func water_y(x: float) -> float:
	var y: float = RA.y
	for f in RA.get("falls", []):
		if x >= f:
			y += 40.0
	return y

## caiu no rio sem estar na jangada: a correnteza leva
func check_river() -> void:
	if RA.is_empty() or mode == "raft":
		return
	var p: Dictionary = g.player
	# pousou em cima da jangada: embarca e a corredeira começa
	if not RAFT_SOL.is_empty() and p.onGround and p._g == RAFT_SOL and not p.get("dog") and p.dyingT == 0:
		g.want_comic("jangada")
		_start_raft()
		return
	var pcx: float = p.x + p.w / 2
	if pcx > RA.x0 and pcx < RA.x1 and p.y + p.h > water_y(pcx) + 12 and p.dyingT == 0:
		g.die("A correnteza te levou! Suba na jangada (✦).")
	# o precipício do Céu
	for c in g.L.get("chasms", []):
		if pcx > c[0] and pcx < c[1] and p.y > c[2] and p.dyingT == 0:
			g.die("Você caiu no precipício.")

# ======================================================================
#  USAR
# ======================================================================
func near_raft() -> bool:
	if RA.is_empty() or raft_done or mode != "":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - RA.px) < 120 and abs(p.y + p.h - 500) < 60 and not p.get("dog")

func near_plane() -> bool:
	if PL.is_empty() or plane_done or mode != "":
		return false
	var p: Dictionary = g.player
	return abs(p.x + p.w / 2 - PL.px) < 150 and abs(p.y + p.h - PL.y) < 70 and not p.get("dog")

func use() -> bool:
	if near_raft():
		g.want_comic("jangada")
		_start_raft()
		return true
	if near_plane():
		g.want_comic("aviao")
		_start_plane()
		return true
	return false

func _common_start() -> void:
	var p: Dictionary = g.player
	p.hp = Game.MAXHP
	p.vine = null
	p.ladder = null
	p.bar = null
	p.crouch = false
	p.h = 34
	p.sink = 0.0
	stumble = 0
	jbuf = 0
	duck = false
	vy = 0.0
	if not g.X.DOG.is_empty() and g.X.dog_free():
		g.X.DOG.st = "ride"

func _start_raft() -> void:
	mode = "raft"
	_drop_raft_sol()
	_common_start()
	OBS = []
	for o in RA.get("obs", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		OBS.append(d)
	hx = float(RA.x)
	hy = water_y(hx)
	spd = 1.0
	_place_player()
	g.snap_camera()
	Audio.play("splash", -4)
	g.flash_tut("Segure firme!", "Corredeira! PULAR salta pedras, troncos e as quedas-d'água (pule na beirada). ↓ abaixa sob os galhos.", 260)

func _start_plane() -> void:
	mode = "plane"
	_common_start()
	OBS = []
	for o in PL.get("obs", []):
		var d: Dictionary = o.duplicate()
		d.hit = false
		d.t = 0
		d.st = "wait"
		d.ox = float(d.x)
		d.oy = float(d.y)
		OBS.append(d)
	hx = float(PL.x)
	hy = float(PL.y)
	spd = 0.0
	phase = "taxi"
	tilt = 0.0
	_place_player()
	g.snap_camera()
	Audio.play("roar", -10)
	g.flash_tut("Decolar!", "O avião vai decolar! No ar: ↑ sobe, ↓ desce. Desvie dos pássaros e das nuvens de tempestade.", 260)

## o Tomé acompanha o veículo (para câmera, lápis e o resto do jogo)
func _place_player() -> void:
	var p: Dictionary = g.player
	if mode == "raft":
		p.x = hx - p.w / 2
		p.y = hy - 8 - p.h + (12 if duck else 0)
	else:
		p.x = hx - p.w / 2 - 10
		p.y = hy - 40 - p.h
	p.vx = spd
	p.vy = vy
	p.onGround = mode == "raft" and hy >= water_y(hx) - 1
	p.face = 1

# ======================================================================
#  PASSO
# ======================================================================
func step() -> void:
	g.T += 1
	if mode == "raft":
		_raft_step()
	elif mode == "plane":
		_plane_step()
	var p: Dictionary = g.player
	if p.iframe > 0:
		p.iframe -= 1
	if mode != "":
		_place_player()

func box() -> Dictionary:
	if mode == "raft":
		var top: float = hy - (34 if duck else 50)
		return g.R(hx - 30, top, 60, hy - top)
	return g.R(hx - 50, hy - 46, 100, 40)

func _raft_step() -> void:
	if stumble > 0:
		stumble -= 1
		spd = move_toward(spd, 2.0, .4)
	else:
		spd = move_toward(spd, float(RA.spd), .08)
	var wl: float = water_y(hx)
	var on_water: bool = hy >= wl - 1
	if g.pressed("J"):
		jbuf = 9
	elif jbuf > 0:
		jbuf -= 1
	if jbuf > 0 and on_water and stumble < 20:
		jbuf = 0
		vy = -10.5
		Audio.play("jump", -4)
		g.burst(hx - 20, wl, 10, Color(.8, .9, 1))
	duck = g.kd("S") and on_water
	# queda-d'água logo à frente: se não pulou, a jangada despenca e bate
	var nxt: float = hx + spd
	for f in RA.get("falls", []):
		if hx < f and nxt >= f and on_water:
			_hurt_raft("queda")
	vy += .42 if (vy < 0 and g.kd("J")) else .6
	hy += vy
	hx = nxt
	wl = water_y(hx)
	if hy >= wl:
		if vy > 4:
			Audio.play("splash", -8)
			g.burst(hx, wl, 12, Color(.85, .93, 1))
		hy = wl
		vy = 0.0
	# balanço da água
	if hy >= wl - 1 and g.T % 4 == 0:
		g.PARTS.append({"x": hx - 34, "y": wl + 2, "vx": -spd * .4, "vy": -1.2, "life": 16, "col": Color(.9, .96, 1, .8)})
	var b := box()
	for o in OBS:
		if o.hit or o.x + 120 < hx - 80 or o.x > hx + 80:
			continue
		var oy: float = water_y(o.x)
		var bad := false
		match o.k:
			"rock":
				bad = Game.hit(b, g.R(o.x + 8, oy - 34, 44, 40))
			"log":
				bad = Game.hit(b, g.R(o.x + 6, oy - 18, 70, 20))
			"branch":
				bad = Game.hit(b, g.R(o.x + 4, oy - 104, 90, 18))
		if bad:
			o.hit = true
			_hurt_raft(o.k)
	_coins(b)
	if hx >= float(RA.x1) - 70:
		_finish_raft()

func _hurt_raft(_k: String) -> void:
	var p: Dictionary = g.player
	stumble = 40
	spd = 1.5
	vy = -5.0
	g.shake = 5
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.play("splash", -4)
	Audio.vib(60)
	g.burst(hx + 20, hy - 30, 12, Color("#e07a6a"))
	if p.iframe > 0:
		return
	p.iframe = 50
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		g.iris_t = 30
		g.flash("A jangada virou! De novo — PULAR para saltar, ↓ para abaixar.", 220)
		_start_raft()

func _drop_raft_sol() -> void:
	if not RAFT_SOL.is_empty():
		g.SOL.erase(RAFT_SOL)
		RAFT_SOL = {}

func _finish_raft() -> void:
	var p: Dictionary = g.player
	mode = ""
	raft_done = true
	_drop_raft_sol()
	RA.px = float(RA.x1) - 90
	p.x = float(RA.x1) + 10
	p.y = 500 - p.h - 4
	p.vx = 2.0
	p.vy = -4.0
	p.onGround = false
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "door"
		g.X.DOG.x = p.x - 30
		g.X.DOG.y = 500.0
	Audio.play("splash", -6)
	g.flash("Terra firme! Que corredeira...", 200)

# ---------- avião ----------
func _plane_step() -> void:
	var p: Dictionary = g.player
	match phase:
		"taxi":
			spd = min(spd + .1, float(PL.spd))
			hx += spd
			hy = float(PL.y)
			if g.T % 3 == 0:
				g.fx("fx_dust", hx - 50, hy - 4, 14, .14, -.2)
			if hx > float(PL.edge):
				phase = "fly"
				vy = 1.5
				g.note("Voando!")
		"fly":
			spd = move_toward(spd, float(PL.spd), .05)
			var up: bool = (g.kd("U") or g.kd("J")) and stumble < 25
			var dn: bool = g.kd("S") and stumble < 25
			var want: float = -4.2 if up else (4.2 if dn else .35)
			vy = move_toward(vy, want, .22)
			hy = clamp(hy + vy, float(PL.top), float(PL.low))
			hx += spd
			tilt = lerpf(tilt, vy * .06, .2)
			_plane_obs()
			if hx >= float(PL.x1) - 900:
				phase = "land"
		"land":
			# desce sozinho até a clareira
			var gy: float = float(PL.land)
			# desce na medida certa para tocar o chão um pouco antes do fim
			var left: float = max(8.0, (float(PL.x1) - 260.0 - hx) / max(spd, 1.0))
			vy = move_toward(vy, (gy - hy) / left, .3)
			hy = min(gy, hy + vy)
			hx += spd
			tilt = lerpf(tilt, vy * .05, .2)
			if hx > float(PL.x1) - 260 or hy >= gy - .5:
				hy = gy
				spd = move_toward(spd, 0.0, .12)
				tilt = lerpf(tilt, 0.0, .2)
				if g.T % 3 == 0:
					g.fx("fx_dust", hx - 50, hy - 4, 14, .14, -.2)
			if spd <= 0.0 and hy >= gy:
				_finish_plane()
	if stumble > 0:
		stumble -= 1
	if phase == "fly":
		_coins(box())

func _plane_obs() -> void:
	var b := box()
	for o in OBS:
		if o.x - hx > 900 or o.x - hx < -400:
			continue
		o.t += 1
		match o.k:
			"flock":
				o.x = o.ox - o.t * 1.2
				o.y = o.oy + sin(o.t * .05) * 16
				for i in int(o.get("n", 5)):
					var bx: float = o.x + (i % 3) * 34 - (i / 3) * 14
					var by: float = o.y + (i / 3) * 26 + (i % 3) * 6
					if not o.hit and Game.hit(b, g.R(bx - 12, by - 8, 24, 16)):
						o.hit = true
						_hurt_plane()
			"hawk":
				# avisa (!), mergulha até a altura em que o avião estava e varre a faixa voando reto
				match o.st:
					"wait":
						if o.x - hx < 700:
							o.st = "warn"
							o.t = 0
							o.ty = hy - 26
					"warn":
						if o.t > 40:
							o.st = "dive"
							o.t = 0
							o.vx = -120.0 / 30.0
							o.vy = (o.ty - o.y) / 30.0
					"dive":
						o.x += o.vx
						o.y += o.vy
						if o.t >= 30:
							o.st = "sweep"
							o.t = 0
							o.y = o.ty
					"sweep":
						o.x -= 6.0
						if o.t > 120:
							o.st = "gone"
				if o.st in ["dive", "sweep"] and not o.hit and Game.hit(b, g.R(o.x - 22, o.y - 12, 44, 24)):
					o.hit = true
					_hurt_plane()
			"cloud":
				if not o.hit and Game.hit(b, g.R(o.x + 20, o.y + 14, o.w - 40, o.h - 28)):
					o.hit = true
					g.flash_t = 0
					_hurt_plane()

func _hurt_plane() -> void:
	var p: Dictionary = g.player
	stumble = 40
	vy = 2.5
	g.shake = 6
	g.hit_stop = 4
	Audio.play("hurt")
	Audio.play("thunder", -10)
	Audio.vib(60)
	g.burst(hx + 30, hy - 30, 14, Color("#e07a6a"))
	if p.iframe > 0:
		return
	p.iframe = 50
	p.hp -= 1
	if p.hp <= 0:
		tries += 1
		g.iris_t = 30
		g.flash("O avião rodopiou! De novo — ↑ sobe, ↓ desce.", 220)
		_start_plane()
		# recomeça já no ar, logo depois do precipício
		phase = "fly"
		hx = float(PL.edge) + 20
		hy = float(PL.y) + 30
		vy = 0.0
		spd = float(PL.spd)
		_place_player()
		g.snap_camera()

func _finish_plane() -> void:
	var p: Dictionary = g.player
	mode = ""
	plane_done = true
	PL.px = hx
	PL.py = hy
	p.x = hx - 110
	p.y = hy - p.h - 4
	p.vx = 0.0
	p.vy = -5.0
	p.onGround = false
	p.hp = max(p.hp, 1)
	if g.X.DOG.get("st", "") == "ride":
		g.X.DOG.st = "door"
		g.X.DOG.x = p.x - 30
		g.X.DOG.y = hy
	Audio.play("stomp", -8)
	g.flash("Pouso perfeito! A mina fica logo ali.", 220)

func _coins(b: Dictionary) -> void:
	for c in g.coins_near(hx - 120, hx + 120):
		if not c.got and abs(c.x - hx) < 90 and Game.hit(b, g.R(c.x - 15, c.y - 15, 30, 30)):
			c.got = true
			g.STATS.pen += 1
			g.gain_coin(c.x, c.y)

func save_data() -> Dictionary:
	return {"raft": raft_done, "plane": plane_done, "ppx": PL.get("px", 0.0), "ppy": PL.get("py", 0.0)}

func restore(d: Dictionary) -> void:
	raft_done = d.get("raft", false)
	plane_done = d.get("plane", false)
	if raft_done and not RA.is_empty():
		RA.px = float(RA.x1) - 90
		_drop_raft_sol()
	if plane_done and not PL.is_empty():
		PL.px = d.get("ppx", PL.x1)
		PL.py = d.get("ppy", PL.land)
