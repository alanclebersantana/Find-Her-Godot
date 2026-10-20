extends RefCounted
class_name Extras
## Sistemas novos da fase, separados do núcleo (game.gd):
## clima, lanterna (foco, plataformas de luz, espelhos e cristais), picareta e rochas rachadas,
## salas secretas, lápis dourado, água com fôlego, chefe javali, e o "mundo que reage"
## (mariposas, vaga-lumes, pegadas, ondinhas na água).

var g  # Game
var weather := "limpo"
var weather_msg_t := 40
var CRACKS: Array = []
var MIRRORS: Array = []
var CRYSTALS: Array = []
var GHOST: Array = []
var SECRETS: Array = []
var GOLD := {}
var WATER: Array = []
var CHALK: Array = []
var BOSS := {}
var LOGS: Array = []
var BEAM: Array = []          # pontos do raio refletido pelos espelhos (para desenhar)
var focus := false
var focus_block := false
var MOTHS: Array = []
var FIRE: Array = []
var FOOT: Array = []
var RIP: Array = []
var BUB: Array = []
var broken := {}
var opened := {}
var found := {}
var a_notes := 0
var breath := 480
var was_swim := false
const BREATH := 480
const BEAM_LEN := 400.0
const BEAM_ANG := 0.42        # meia-abertura do facho (rad)

func _init(game) -> void:
	g = game

# ======================================================================
#  CARREGAR
# ======================================================================
func load_level() -> void:
	var L: Dictionary = g.L
	CRACKS = []
	for s in g.SOL:
		if s.t == "crack":
			CRACKS.append(s)
	MIRRORS = []
	for m in L.get("mirrors", []):
		var o: Dictionary = m.duplicate()
		o.cd = 0
		o.flash = 0
		MIRRORS.append(o)
	CRYSTALS = []
	for c in L.get("crystals", []):
		var o: Dictionary = c.duplicate()
		o.charge = 0.0
		o.on = false
		CRYSTALS.append(o)
	GHOST = []
	for p in L.get("ghost", []):
		var o := {"t": "ghost", "x": p.x, "y": p.y, "w": p.w, "h": 16, "oneway": 1, "ghost": 1, "on": false, "a": 0.0}
		g.SOL.append(o)
		GHOST.append(o)
	SECRETS = []
	for s in L.get("secrets", []):
		var o: Dictionary = s.duplicate()
		o.a = 1.0
		SECRETS.append(o)
	GOLD = {}
	if L.has("gold"):
		GOLD = {"x": L.gold.x, "y": L.gold.y, "got": false}
	WATER = L.get("water", []).duplicate(true)
	CHALK = L.get("chalk", [])
	LOGS = []
	BOSS = {}
	if L.has("boss"):
		var b: Dictionary = L.boss
		BOSS = {"x": b.spawn, "y": 500.0, "st": "wait", "t": 0, "hp": b.hp, "maxhp": b.hp, "dir": -1, "spd": 0.0,
			"vy": 0.0, "x0": b.x0, "x1": b.x1, "trig": b.trig, "spawn": b.spawn, "active": false, "done": false, "red": 0, "item": b.item}
	broken = {}
	opened = {}
	found = {}
	breath = BREATH
	was_swim = false
	BEAM = []
	FOOT = []
	RIP = []
	BUB = []
	MOTHS = []
	for i in 5:
		MOTHS.append({"a": randf() * TAU, "r": 22 + randf() * 30, "s": .04 + randf() * .05, "ph": randf() * TAU})
	FIRE = []
	var opts := ["limpo", "limpo", "neblina", "garoa", "vento"]
	weather = opts[randi() % opts.size()]
	weather_msg_t = 40

func weather_text() -> String:
	match weather:
		"neblina": return "Neblina no bosque hoje: olhe bem onde pisa."
		"garoa": return "Uma garoa fina caindo sobre o bosque."
		"vento": return "Ventania: as folhas voam por todo lado."
	return ""

# ======================================================================
#  ANTES DA FÍSICA: água e fôlego
# ======================================================================
func water_at(x: float, y: float):
	for w in WATER:
		if x > w.x and x < w.x + w.w and y > w.y and y < w.y + w.h:
			return w
	return null

func pre_step() -> void:
	var p: Dictionary = g.player
	var w = water_at(p.x + p.w / 2, p.y + p.h * .55)
	p.swim = w != null
	p.water = w
	if p.swim and not was_swim:
		Audio.play("splash", -4)
		g.burst(p.x + p.w / 2, w.y, 10, Color(.7, .85, .95))
		ripple(p.x + p.w / 2, w.y, 1.2)
		if p.crouch:
			p.crouch = false
			p.h = 34
			p.y -= 14
		if a_notes < 99 and not g.L.get("_swim_note", false):
			g.L["_swim_note"] = true
			g.flash("Na água: PULAR dá braçadas para cima, ↓ mergulha. De olho no fôlego!", 220)
	was_swim = p.swim
	if p.swim and p.y + 8 > w.y:
		breath -= 1
		if g.T % 9 == 0:
			BUB.append({"x": p.x + p.w / 2 + p.face * 8, "y": p.y + 8, "t": 0, "top": w.y})
		if breath == 150:
			g.flash("O ar está acabando! Suba para respirar!", 120)
			Audio.vib(40)
		if breath <= 0:
			breath = BREATH
			g.die("Ficou sem ar.")
	else:
		breath = min(BREATH, breath + 6)

func near_surface() -> bool:
	var p: Dictionary = g.player
	return p.water != null and p.y < p.water.y + 6

## física de nado (chamada no lugar da corrida/pulo normais)
func swim() -> void:
	var p: Dictionary = g.player
	p.puff = false
	p.slam = false
	p.run = 0
	p.airJumps = 1
	var want := -1 if (g.kd("L") and not g.kd("R")) else (1 if (g.kd("R") and not g.kd("L")) else 0)
	if want != 0:
		p.face = want
	p.vx += (want * 2.5 - p.vx) * .12
	if g.pressed("J"):
		if near_surface():
			p.vy = Game.JUMP * .86
			p.cutOk = true
			Audio.play("jump", -6)
			g.burst(p.x + p.w / 2, p.y + p.h, 8, Color(.7, .85, .95))
		else:
			p.vy = min(p.vy, -3.6)
			Audio.play("splash", -14)
			for i in 3:
				BUB.append({"x": p.x + p.w / 2, "y": p.y + 20, "t": 0, "top": p.water.y if p.water else p.y - 100})
	if g.kd("U"):
		p.vy -= .2
	if g.kd("S"):
		p.vy += .24
	if p.vy < -5.0:
		p.vy += .3      # saindo da água num pulo: não freia
	else:
		p.vy = clamp((p.vy + .09) * .965, -4.6, 2.6)
	p.anim += .05

# ======================================================================
#  LANTERNA: origem, facho e luz
# ======================================================================
func lamp() -> Vector2:
	var p: Dictionary = g.player
	return Vector2(p.x + p.w / 2 + p.face * 14, p.y + (6 if p.crouch else 12))

func in_cone(x: float, y: float, rng: float = BEAM_LEN) -> bool:
	if not focus:
		return false
	var o := lamp()
	var d := Vector2(x, y) - o
	if d.x * g.player.face <= 0 or d.length() > rng:
		return false
	return abs(atan2(d.y, abs(d.x))) < BEAM_ANG

func lit(x: float, y: float, r: float = 150.0) -> bool:
	if not g.lantern_lit:
		return false
	return lamp().distance_to(Vector2(x, y)) < r or in_cone(x, y)

## coruja e morcego fogem do facho
func scare(x: float, y: float) -> bool:
	return focus and in_cone(x, y, BEAM_LEN + 40)

# ======================================================================
#  DEPOIS DA FÍSICA
# ======================================================================
func post() -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	if weather_msg_t > 0:
		weather_msg_t -= 1
		if weather_msg_t == 0 and weather_text() != "":
			g.note(weather_text())
	# ✦ USAR: picareta, espelho do chão
	if g.keys.get("Ap", false):
		if _use_crack() or _use_mirror():
			g.keys.Ap = false
			focus_block = true
	if not g.kd("A"):
		focus_block = false
	focus = g.kd("A") and not focus_block and g.lantern_lit and p.nearL == null and p.ladder == null and p.vine == null and not p.swim and p.dyingT == 0
	if focus and a_notes < 1:
		a_notes = 1
		g.note("Facho concentrado: espanta corujas e morcegos e revela o que está escondido no escuro.")
	# espelhos do teto: girar com uma cabeçada
	for m in MIRRORS:
		if m.cd > 0:
			m.cd -= 1
		if m.flash > 0:
			m.flash -= 1
		if m.get("ceil") and m.cd == 0 and p.vy < 0 and Game.hit(p, _mbox(m)):
			_rotate(m)
			p.vy = 1.0
	_trace_beam()
	# plataformas de luz
	for gp in GHOST:
		var c := Vector2(gp.x + gp.w / 2, gp.y)
		gp.on = lit(c.x, c.y, 175.0)
		gp.a = move_toward(gp.a, 1.0 if gp.on else 0.0, .08)
	# salas secretas
	for s in SECRETS:
		var inside: bool = pcx > s.x and pcx < s.x + s.w and p.y + p.h > s.y and p.y < s.y + s.h
		if inside and not found.has(s.id):
			found[s.id] = true
			Audio.play("clue")
			Audio.vib(40)
			g.flash("Um lugar secreto! (%d/%d)" % [found.size(), SECRETS.size()], 200)
		if found.has(s.id):
			s.a = max(0.0, s.a - .05)
	# lápis dourado
	if not GOLD.is_empty() and not GOLD.got and Game.hit(p, g.R(GOLD.x - 20, GOLD.y - 24, 40, 48)):
		GOLD.got = true
		Save.setv("gallery", "gold", true)
		Audio.play("special")
		Audio.vib(80)
		g.shake = 6
		g.burst(GOLD.x, GOLD.y, 30, Color("#ffd76a"))
		g.flash("O LÁPIS DOURADO! O lápis mais especial da Lia — ela guardava para desenhar o sol.", 300)
	_boss()
	_logs()
	_critters()
	_footprints()

func weather_amb() -> void:
	var under: bool = g.L.has("under") and g.player.y > g.L.under
	g.AMB.fog = 0.0
	g.AMB.wind = 0.0
	if under:
		return
	match weather:
		"garoa":
			g.AMB.rain = max(g.AMB.rain, .32)
		"neblina":
			g.AMB.fog = .75
		"vento":
			g.AMB.wind = 1.0

# ---------- picareta ----------
func _use_crack() -> bool:
	var p: Dictionary = g.player
	for c in CRACKS:
		if broken.has(c.id):
			continue
		if Game.hit(g.R(p.x - 46, p.y - 40, p.w + 92, p.h + 60), c):
			if g.has_item("picareta"):
				break_crack(c, true)
			else:
				g.flash("Uma rocha rachada. Com uma picareta dava para quebrar...", 200)
			return true
	return false

func break_crack(c: Dictionary, fx: bool) -> void:
	broken[c.id] = true
	g.SOL.erase(c)
	if c.has("ladder"):
		var l: Array = c.ladder
		g.CLIMB.append({"x": l[0], "y": l[1], "w": 30, "h": l[2], "kind": "ladder"})
		g.SOL.append({"t": "hatchd", "x": c.x, "y": c.y, "w": c.w, "h": 16, "oneway": 1})
	if fx:
		var p: Dictionary = g.player
		p.act = "throw1"
		p.actT = 22
		g.shake = 10
		g.hit_stop = 4
		Audio.play("unlock")
		Audio.play("stomp", -4)
		Audio.vib(90)
		g.fx("fx_pieces", c.x + c.w / 2, c.y + c.h / 2, 22, .4, -.4)
		for i in 26:
			g.PARTS.append({"x": c.x + randf() * c.w, "y": c.y + randf() * c.h, "vx": (randf() - .5) * 6, "vy": -randf() * 6, "life": 30 + randf() * 20, "col": Color(.55, .5, .46)})
		g.flash(c.get("msg", "A rocha se partiu!"), 200)

func hint_crack(id: String) -> bool:
	return broken.has(id)

# ---------- espelhos e cristais ----------
func _mbox(m: Dictionary) -> Dictionary:
	return g.R(m.x - 15, m.y - 15, 30, 30)

func _use_mirror() -> bool:
	var p: Dictionary = g.player
	var best = null
	var bd := 9999.0
	for m in MIRRORS:
		if m.get("ceil"):
			continue
		var d: float = abs(p.x + p.w / 2 - m.x)
		if d < 42 and abs(p.y + p.h / 2 - m.y) < 60 and d < bd:
			best = m
			bd = d
	if best:
		_rotate(best)
		return true
	return false

func _rotate(m: Dictionary) -> void:
	m.s = 1 - int(m.s)
	m.cd = 26
	m.flash = 14
	Audio.play("climb")
	Audio.play("item", -14)
	Audio.vib(15)

func near_floor_mirror():
	var p: Dictionary = g.player
	for m in MIRRORS:
		if not m.get("ceil") and abs(p.x + p.w / 2 - m.x) < 42 and abs(p.y + p.h / 2 - m.y) < 60:
			return m
	return null

func _reflect(d: Vector2, s: int) -> Vector2:
	if s == 0:   # "/"
		return Vector2(-d.y, -d.x)
	return Vector2(d.y, d.x)   # "\"

func _trace_beam() -> void:
	BEAM = []
	for c in CRYSTALS:
		if not c.on:
			c.charge = max(0.0, c.charge - .6)
	if not focus or MIRRORS.is_empty():
		return
	var o := lamp()
	var near: Array = []
	for s in g.SOL:
		if not s.get("oneway") and s.x < o.x + 950 and s.x + s.w > o.x - 950 and s.y < o.y + 700 and s.y + s.h > o.y - 700:
			near.append(s)
	var pos := o
	var dir := Vector2(g.player.face, 0)
	BEAM.append(pos)
	var last = null
	var travelled := 0.0
	var hit_mirror := false
	while travelled < 1100:
		pos += dir * 4
		travelled += 4
		var stop := false
		for m in MIRRORS:
			if m != last and _pt_in(pos, _mbox(m)):
				pos = Vector2(m.x, m.y)
				BEAM.append(pos)
				dir = _reflect(dir, int(m.s))
				last = m
				hit_mirror = true
				break
		for c in CRYSTALS:
			if _pt_in(pos, g.R(c.x - 14, c.y - 14, 28, 28)):
				stop = true
				if not c.on:
					c.charge += 2.0
					if int(c.charge) % 10 == 0:
						g.PARTS.append({"x": c.x, "y": c.y, "vx": (randf() - .5) * 3, "vy": (randf() - .5) * 3, "life": 16, "col": Color(.7, .9, 1)})
					if c.charge >= 60:
						_open_crystal(c, true)
		if not stop:
			for s in near:
				if _pt_in(pos, s):
					stop = true
					break
		if stop:
			break
		if not hit_mirror and travelled > BEAM_LEN:
			break
	BEAM.append(pos)
	if not hit_mirror:
		BEAM = []

func _pt_in(p: Vector2, r: Dictionary) -> bool:
	return p.x >= r.x and p.x <= r.x + r.w and p.y >= r.y and p.y <= r.y + r.h

func _open_crystal(c: Dictionary, fx: bool) -> void:
	c.on = true
	c.charge = 60.0
	opened[c.door] = true
	for s in g.SOL.duplicate():
		if s.get("id") == c.door:
			g.SOL.erase(s)
	if fx:
		g.shake = 8
		Audio.play("unlock")
		Audio.play("special", -6)
		Audio.vib(80)
		g.burst(c.x, c.y, 26, Color(.7, .9, 1))
		g.flash("O cristal brilhou e as grades se abriram!", 220)

# ======================================================================
#  CHEFE: O JAVALI-REI
# ======================================================================
func boss_active() -> bool:
	return not BOSS.is_empty() and BOSS.active and not BOSS.done

func boss_box() -> Dictionary:
	return g.R(BOSS.x - 72, BOSS.y - 100, 144, 100)

func _gate_on(on: bool) -> void:
	for s in g.SOL.duplicate():
		if s.get("id") == "bossgate":
			g.SOL.erase(s)
	if on:
		g.SOL.append({"t": "bossgate", "x": BOSS.x0 - 24, "y": 280, "w": 24, "h": 220, "id": "bossgate"})

func _boss() -> void:
	if BOSS.is_empty() or BOSS.done:
		return
	var b: Dictionary = BOSS
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	if b.red > 0:
		b.red -= 1
	match b.st:
		"wait":
			if pcx > b.trig and pcx < b.x1 and p.y > 300 and p.dyingT == 0:
				b.active = true
				b.st = "intro"
				b.x = b.spawn
				b.y = 90.0
				b.vy = 0.0
				b.hp = b.maxhp
				b.dir = -1
				_gate_on(true)
				g.flash("O JAVALI-REI pulou do barranco! Ele é forte demais para pisar... suba num galho!", 260)
				Audio.play("thunder", -6)
				g.shake = 10
			return
		"intro":
			b.vy += .7
			b.y = min(500.0, b.y + b.vy)
			if b.y >= 500:
				b.st = "idle"
				b.t = 0
				g.shake = 16
				Audio.play("stomp")
				Audio.vib(80)
				g.burst(b.x, 500, 24, Color("#b7a77f"))
		"idle":
			b.t += 1
			b.dir = 1 if pcx > b.x else -1
			if b.t > 55:
				b.st = "paw"
				b.t = 0
		"paw":
			b.t += 1
			if b.t % 9 == 0:
				g.fx("fx_dust", b.x - b.dir * 50, 494, 16, .14, -.3)
				Audio.play("slide", -12)
			if b.t > 48:
				b.st = "charge"
				b.t = 0
				b.spd = 2.0
				b.dir = 1 if pcx > b.x else -1
		"charge":
			b.spd = min(b.spd + .45, 8.2)
			b.x += b.dir * b.spd
			if g.T % 4 == 0:
				g.fx("fx_dust", b.x - b.dir * 60, 494, 14, .16, -.25)
			var crash := false
			if b.dir < 0 and b.x - 72 <= b.x0:
				b.x = b.x0 + 72
				crash = true
			elif b.dir > 0 and b.x + 72 >= b.x1:
				b.x = b.x1 - 72
				crash = true
			for l in LOGS:
				if l.landed and Game.hit(boss_box(), l.s):
					crash = true
					l.dead = true
					g.SOL.erase(l.s)
					g.fx("fx_pieces", l.s.x + l.s.w / 2, l.s.y, 20, .35, -.4)
			if crash:
				b.st = "stun"
				b.t = 0
				g.shake = 18
				g.hit_stop = 4
				Audio.play("stomp")
				Audio.play("thunder", -12)
				Audio.vib(120)
				g.burst(b.x + b.dir * 70, 440, 20, Color("#cdbfa6"))
				if LOGS.filter(func(l): return not l.dead).size() < 2:
					var lx: float = b.x - b.dir * (170 + randf() * 90)
					lx = clamp(lx, b.x0 + 40, b.x1 - 160)
					LOGS.append({"x": lx, "y": -40.0, "vy": 0.0, "landed": false, "dead": false, "s": {}})
				if b.hp == b.maxhp and b.get("told", 0) == 0:
					b.told = 1
					g.flash("Ele bateu e ficou tonto! Agora: pule nas costas dele!", 200)
		"stun":
			b.t += 1
			if b.t > 160:
				b.st = "trot"
				b.t = 0
		"hit":
			b.t += 1
			if b.t > 36:
				b.st = "trot"
				b.t = 0
		"trot":
			if b.t == 0:
				b.side = 1 if b.x > (b.x0 + b.x1) / 2.0 else -1
			b.t += 1
			var tx: float = (b.x0 + 120) if b.side > 0 else (b.x1 - 120)
			b.dir = 1 if tx > b.x else -1
			b.x += b.dir * 3.0
			if abs(tx - b.x) < 4:
				b.st = "idle"
				b.t = 0
		"flee":
			b.t += 1
			b.dir = -1
			b.x -= 6.5
			if g.T % 4 == 0:
				g.fx("fx_dust", b.x + 60, 494, 14, .16, -.25)
			if b.x < b.x0 - 600:
				b.done = true
				b.active = false
	# contato com o Tomé
	if b.st in ["intro", "idle", "paw", "charge", "stun", "hit", "trot"] and p.dyingT == 0:
		var bb := boss_box()
		if Game.hit(p, bb):
			var feet: float = p.y + p.h
			var from_top: bool = p.vy > 0.5 and feet - bb.y < 34
			if from_top and b.st == "stun":
				b.hp -= 1
				b.red = 30
				p.vy = Game.STOMP * 1.05
				p.y = bb.y - p.h - 1
				p.cutOk = false
				p.airJumps = 1
				g.hit_stop = 7
				g.shake = 14
				Audio.play("stomp")
				Audio.play("hurt", -8)
				Audio.vib(70)
				g.burst(b.x, bb.y, 22, Color("#e0a0a0"))
				if b.hp <= 0:
					b.st = "flee"
					b.t = 0
					_gate_on(false)
					for l in LOGS:
						if l.s:
							g.SOL.erase(l.s)
							g.fx("fx_pieces", l.s.x + 65, l.s.y + 10, 20, .35, -.4)
						l.dead = true
					g.flash("O Javali-Rei fugiu para o mato! E deixou cair... uma picareta!", 260)
					var it := {"x": b.item[0], "y": b.item[1], "id": "picareta", "got": false}
					it.ry = g._rest_y(it.x, it.y)
					g.ITEMS.append(it)
					Audio.play("door", -4)
				else:
					b.st = "hit"
					b.t = 0
					g.flash("Acertou! Falta%s %d." % ["m" if b.hp > 1 else "", b.hp], 120)
			elif from_top:
				p.vy = -8.5
				p.y = bb.y - p.h - 1
				p.cutOk = false
				Audio.play("spring", -8)
				g.note("O couro dele é duro! Faça ele bater na árvore ou no barranco primeiro.")
			elif b.st == "charge" or b.st == "intro":
				g.hurt(1, b.x)

func boss_reset() -> void:
	if BOSS.is_empty() or BOSS.done:
		return
	BOSS.active = false
	BOSS.st = "wait"
	BOSS.hp = BOSS.maxhp
	BOSS.x = BOSS.spawn
	_gate_on(false)
	for l in LOGS:
		if l.s:
			g.SOL.erase(l.s)
	LOGS = []

func boss_finish_silent() -> void:
	if BOSS.is_empty():
		return
	BOSS.done = true
	BOSS.active = false
	var it := {"x": BOSS.item[0], "y": BOSS.item[1], "id": "picareta", "got": g.INV.has("picareta")}
	it.ry = g._rest_y(it.x, it.y)
	g.ITEMS.append(it)

func _logs() -> void:
	var p: Dictionary = g.player
	for l in LOGS:
		if l.dead or l.landed:
			continue
		l.vy += .55
		l.y += l.vy
		if Game.hit(p, g.R(l.x, l.y, 130, 28)) and p.dyingT == 0:
			g.hurt(1, l.x + 65)
		if l.y >= 472:
			l.y = 472.0
			l.landed = true
			l.s = {"t": "bosslog", "x": l.x, "y": 472.0, "w": 130, "h": 28}
			g.SOL.append(l.s)
			g.shake = max(g.shake, 8)
			Audio.play("stomp", -6)
			g.burst(l.x + 65, 500, 14, Color("#b7a77f"))
			if Game.hit(p, l.s):
				p.y = l.s.y - p.h

# ======================================================================
#  MUNDO QUE REAGE
# ======================================================================
func ripple(x: float, y: float, s: float = 1.0) -> void:
	RIP.append({"x": x, "y": y, "t": 0, "s": s})

func _critters() -> void:
	var p: Dictionary = g.player
	var o := lamp()
	for m in MOTHS:
		m.a += m.s
		m.ph += .3
	# vaga-lumes perto da câmera (tarde, pântano e noite, fora das cavernas)
	var want := 0
	var song: String = g.AMB.get("song", "manha")
	var under: bool = g.L.has("under") and p.y > g.L.under
	if not under and song in ["tarde", "chuva", "noite"]:
		want = 18
	while FIRE.size() < want:
		FIRE.append({"x": g.cam + randf() * g.W, "y": g.cam_y + 60 + randf() * (g.H * .6), "vx": 0.0, "vy": 0.0, "ph": randf() * TAU})
	if FIRE.size() > want:
		FIRE.resize(want)
	for f in FIRE:
		f.ph += .07
		f.vx += (randf() - .5) * .12
		f.vy += (randf() - .5) * .12
		if g.lantern_lit:
			var d := Vector2(f.x, f.y) - o
			var r := 150.0 if not focus else 260.0
			if d.length() < r and d.length() > 1:
				var push := d.normalized() * (1.0 - d.length() / r) * .7
				f.vx += push.x
				f.vy += push.y
		f.vx = clamp(f.vx * .96, -3, 3)
		f.vy = clamp(f.vy * .96, -3, 3)
		f.x += f.vx
		f.y += f.vy
		if f.x < g.cam - 120 or f.x > g.cam + g.W + 120 or f.y < g.cam_y - 80 or f.y > g.cam_y + g.H:
			f.x = g.cam + randf() * g.W
			f.y = g.cam_y + 60 + randf() * (g.H * .55)
			f.vx = 0.0
			f.vy = 0.0
	for r in RIP:
		r.t += 1
	RIP = RIP.filter(func(r): return r.t < 50)
	for b in BUB:
		b.t += 1
		b.y -= 1.1
		b.x += sin(b.t * .3) * .4
	BUB = BUB.filter(func(b): return b.y > b.top and b.t < 120)
	# ondinhas: vitórias-régias, nado e chuva
	if p._g != null and p._g.get("lily") and g.T % 22 == 0:
		ripple(p.x + p.w / 2, p._g.y + 6, .8)
	if p.swim and near_surface() and abs(p.vx) > .5 and g.T % 14 == 0:
		ripple(p.x + p.w / 2, p.water.y, .7)

func _footprints() -> void:
	var p: Dictionary = g.player
	var song: String = g.AMB.get("song", "manha")
	var gt: String = str(p._g.get("t", "")) if p._g != null else ""
	var soft: bool = p.mud or (gt == "ground" and (song == "chuva" or weather == "garoa"))
	if p.onGround and soft and abs(p.vx) > .6 and g.T % 13 == 0 and not p.crouch:
		FOOT.append({"x": p.x + p.w / 2 + (4 if (g.T / 13) % 2 == 0 else -4), "y": p.y + p.h, "f": p.face, "t": 0})
		if FOOT.size() > 40:
			FOOT.pop_front()
	for f in FOOT:
		f.t += 1
	FOOT = FOOT.filter(func(f): return f.t < 900)

# ======================================================================
#  SALVAR
# ======================================================================
func save_data() -> Dictionary:
	return {"broken": broken.keys(), "opened": opened.keys(), "found": found.keys(), "gold": GOLD.get("got", false),
		"boss": BOSS.get("done", false)}

func restore(d: Dictionary) -> void:
	for id in d.get("broken", []):
		for c in CRACKS:
			if c.id == id and not broken.has(id):
				break_crack(c, false)
	for id in d.get("opened", []):
		for c in CRYSTALS:
			if c.door == id and not c.on:
				_open_crystal(c, false)
	for id in d.get("found", []):
		found[id] = true
		for s in SECRETS:
			if s.id == id:
				s.a = 0.0
	if d.get("gold", false) and not GOLD.is_empty():
		GOLD.got = true
	if d.get("boss", false):
		boss_finish_silent()
