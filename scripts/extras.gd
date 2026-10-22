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
var RELICS: Array = []
var GOLD := {}
var WATER: Array = []
var CHALK: Array = []
var BOSS := {}
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
var DOG := {}
var TRAIL: Array = []       # pegadas do Tomé no chão (o cachorro segue esse caminho)
var TOCAS: Array = []
var CRAWL: Array = []       # passagens baixas (só passa abaixado)
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
	CRAWL = []
	for so in g.SOL:
		if so.get("oneway") or so.get("crate") or so.t in ["crack", "bars"]:
			continue
		var bot: float = so.y + so.h
		var surf: float = g._rest_y(so.x + so.w / 2, bot, 40)
		if surf > 0 and surf - bot >= 16 and surf - bot < 34:
			CRAWL.append({"x": so.x, "w": so.w, "top": bot, "y": surf})
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
	# lembranças da Isis escondidas em pedras rachadas (quebram com a picareta), atrás de uma moita
	RELICS = []
	for r in L.get("relics", []):
		var ro: Dictionary = r.duplicate()
		ro.broken = false
		ro.got = false
		RELICS.append(ro)
		SECRETS.append({"id": ro.id, "x": ro.x, "y": ro.y, "w": 0, "h": 0, "a": 0.0, "relic": true})
	GOLD = {}
	if L.has("gold"):
		GOLD = {"x": L.gold.x, "y": L.gold.y, "got": false}
	WATER = L.get("water", []).duplicate(true)
	CHALK = L.get("chalk", [])
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
	TRAIL = []
	DOG = {}
	if L.has("dog"):
		DOG = {"x": float(L.dog.x), "y": float(L.dog.y), "x0": float(L.dog.x), "st": "tied", "face": -1, "i": 0, "t": 0,
			"hop": 0.0, "hy": 0.0, "anim": 0.0, "bark": 0, "carry": false, "mole": null, "toca": null, "moving": false}
	TOCAS = []
	for tc in L.get("tocas", []):
		var o: Dictionary = tc.duplicate()
		o.done = false
		TOCAS.append(o)
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
			g.tip("Na água: PULAR dá braçadas para cima, ↓ mergulha. De olho no fôlego!", 220)
	was_swim = p.swim
	if p.swim and p.y + 8 > w.y and g.NT.air_ok():
		breath = BREATH
		if g.T % 14 == 0:
			BUB.append({"x": p.x + p.w / 2 + p.face * 8, "y": p.y + 4, "t": 0, "top": w.y})
	elif p.swim and p.y + 8 > w.y and g.NT.in_vent():
		breath = min(BREATH, breath + 9)
		if not g.L.get("_vent_note", false):
			g.L["_vent_note"] = true
			g.tip("As bolhas do fundo devolvem o fôlego!", 160)
	elif p.swim and p.y + 8 > w.y:
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
	if g.M.is_dog():
		if g.keys.get("Ap", false):
			g.keys.Ap = false
			g.M.dog_action()
	elif g.keys.get("Ap", false):
		if g.RD.use() or g.VH.use() or g.EV.use() or _use_dog() or _use_toca() or _use_crack() or _use_mirror():
			g.keys.Ap = false
			focus_block = true
	if not g.kd("A"):
		focus_block = false
	focus = g.kd("A") and not focus_block and not g.M.is_dog() and g.lantern_lit and p.nearL == null and p.ladder == null and p.vine == null and not p.swim and p.dyingT == 0
	if focus and a_notes < 1:
		a_notes = 1
		g.tip("Facho concentrado: espanta corujas e morcegos e revela o que está escondido no escuro.")
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
	for r in RELICS:
		if r.broken and not r.got and Game.hit(p, g.R(r.x - 18, r.y - 40, 36, 40)):
			r.got = true
			found[r.id] = true
			Audio.play("special")
			Audio.vib(60)
			g.burst(r.x, r.y - 20, 22, Color("#ffd76a"))
			g.flash(r.txt + " (%d/%d segredos)" % [found.size(), SECRETS.size()], 320)
	for s in SECRETS:
		if s.get("relic"):
			continue
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
		g.flash("O LÁPIS DOURADO! O lápis mais especial da Isis — ela guardava para desenhar o sol.", 300)
	_boss()
	_dog()
	_critters()
	_footprints()

func weather_amb() -> void:
	var under: bool = g.indoors()
	g.AMB.fog = 0.0
	g.AMB.wind = 0.0
	if under or g.AMB.get("snow", 0.0) > .3:
		return
	match weather:
		"garoa":
			g.AMB.rain = max(g.AMB.rain, .32)
		"neblina":
			g.AMB.fog = .75
		"vento":
			g.AMB.wind = 1.0

# ---------- passagens baixas ----------
func crawl_auto(dir: int) -> bool:
	var p: Dictionary = g.player
	var feet: float = p.y + p.h
	for c in CRAWL:
		if abs(feet - c.y) > 3:
			continue
		var x0: float = p.x
		var x1: float = p.x + p.w
		if x1 > c.x - 2 and x0 < c.x + c.w + 2:
			return true
		if dir > 0 and x1 <= c.x and c.x - x1 < 10:
			return true
		if dir < 0 and x0 >= c.x + c.w and x0 - (c.x + c.w) < 10:
			return true
	return false

## tem alguma coisa para USAR aqui perto? (o botão da mão só aparece nessa hora)
func near_use() -> bool:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	if not DOG.is_empty() and DOG.st == "tied" and abs(pcx - DOG.x) < 70 and abs(feet - DOG.y) < 50:
		return true
	for tc in TOCAS:
		if not tc.done and abs(pcx - tc.x) < 80 and abs(feet - tc.y) < 50:
			return true
	for c in CRACKS:
		if not broken.has(c.id) and c.get("kind") != "slam" and Game.hit(g.R(p.x - 46, p.y - 40, p.w + 92, p.h + 60), c):
			return true
	for m in MIRRORS:
		if not m.get("ceil") and abs(pcx - m.x) < 42 and abs(p.y + p.h / 2 - m.y) < 60:
			return true
	return false

## o facho da lanterna serve para alguma coisa aqui? (gavião, coruja, morcego, cristal)
func beam_useful() -> bool:
	if not g.lantern_lit:
		return false
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	if g.K and not g.K.HAWK.is_empty() and g.K.HAWK.active and not g.K.HAWK.done:
		return true
	for e in g.EN:
		if not e.dead and e.k in ["owl", "bat"] and abs(e.x - pcx) < 360:
			return true
	for c in CRYSTALS:
		if not c.on and abs(c.x - pcx) < 320:
			return true
	return false

# ---------- picareta ----------
func _use_crack() -> bool:
	var p: Dictionary = g.player
	for c in CRACKS:
		if broken.has(c.id):
			continue
		if Game.hit(g.R(p.x - 46, p.y - 40, p.w + 92, p.h + 60), c):
			if c.get("kind") == "slam":
				g.tip("Rachado demais para a picareta... pule e aperte ↓ no ar: o MERGULHO quebra!", 200)
				return true
			if g.has_item("picareta"):
				break_crack(c, true)
			else:
				g.tip("Uma rocha rachada. Com uma picareta dava para quebrar...", 200)
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
#  CENAS DRAMÁTICAS (chamadas por Game._cine_step)
# ======================================================================
func cine_step(c: Dictionary) -> void:
	var t: int = c.t
	match c.id:
		"boss":
			var b: Dictionary = BOSS
			if b.st == "intro":
				b.vy += .7
				b.y = min(500.0, b.y + b.vy)
				c.fy = clamp(b.y + 40, 300.0, 430.0)
				if b.y >= 500:
					b.st = "idle"
					b.t = 0
					g.shake = 18
					Audio.play("stomp")
					Audio.vib(100)
					g.burst(b.x, 500, 30, Color("#b7a77f"))
					g.fx("fx_dust", b.x, 480, 30, .5, -.3)
			else:
				b.t = 0
				b.dir = 1 if g.player.x > b.x else -1
			if t == 72:
				Audio.play("roar")
				g.shake = 14
				Audio.vib(160)
		"vargas":
			if t == 6:
				g.lightning = 12
				Audio.play("thunder", -2)
				g.shake = 8
			if t == 135:
				Audio.play("hurt", -10)
		"cao":
			if t == 60 or t == 150:
				Audio.play("bark")
			if DOG:
				DOG.hop = 1.0 if t in range(140, 160) else 0.0

func cine_end(id: String) -> void:
	match id:
		"boss":
			if BOSS.st == "intro":
				BOSS.y = 500.0
				BOSS.st = "idle"
			BOSS.t = 0
			g.flash_tut("Faça o Javali-Rei bater a cabeça 4 vezes!", "Fique no chão para ele investir. Quando ele correr, pule para um galho: ele bate a cabeça na árvore ou no barranco. 4 batidas!", 260)
		"vargas":
			g.tip("Atrás dele! Pule os buracos e abaixe sob as vigas.", 180)
		"cao":
			g.flash_tut("O Pipoca agora vai com você!", "O Pipoca agora vai com você! Perto de uma toca, toque ✦ USAR e ele busca o que tiver lá dentro.", 260)

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
	# o Tomé está no chão da clareira (e não num galho)? só aí o javali investe
	var on_floor: bool = p.onGround and p.y + p.h >= 494 and pcx > b.x0 and pcx < b.x1
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
				Audio.play("thunder", -6)
				g.shake = 6
				g.start_cine("boss", b.spawn - 60, 420, 260,
					[[165, 250, "TOMÉ", "Um javali desse tamanho... Forte demais para enfrentar de frente. Vou fazer ele bater a cabeça!", "tome"]],
					[75, 160, "JAVALI-REI", "o terror da clareira"])
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
			if on_floor and b.t > 30:
				b.st = "paw"
				b.t = 0
			elif not on_floor and b.t > 240:
				b.t = 0
				g.tip("Desça ao chão para chamar a atenção dele. Quando ele vier, pule para um galho!", 180)
		"paw":
			b.t += 1
			b.dir = 1 if pcx > b.x else -1
			if b.t % 9 == 0:
				g.fx("fx_dust", b.x - b.dir * 50, 494, 16, .14, -.3)
				Audio.play("slide", -12)
			if not on_floor and b.t < 20:
				b.st = "idle"
				b.t = 0
			elif b.t > 44:
				b.st = "charge"
				b.t = 0
				b.spd = 2.0
				Audio.play("roar", -14)
		"charge":
			b.spd = min(b.spd + .42, 8.0)
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
			if crash:
				g.shake = 18
				g.hit_stop = 6
				Audio.play("stomp")
				Audio.play("thunder", -12)
				Audio.vib(120)
				g.burst(b.x + b.dir * 70, 440, 20, Color("#cdbfa6"))
				g.fx("fx_pieces", b.x + b.dir * 76, 420, 18, .3, -.4)
				boss_damage()
		"stun":
			b.t += 1
			if b.t > 110:
				b.st = "trot"
				b.t = 0
		"trot":
			if b.t == 0:
				b.side = 1 if b.x > (b.x0 + b.x1) / 2.0 else -1
			b.t += 1
			var tx: float = (b.x0 + b.x1) / 2.0 + b.side * -60.0
			b.dir = 1 if tx > b.x else -1
			b.x += b.dir * 3.0
			if abs(tx - b.x) < 4:
				b.st = "idle"
				b.t = 0
		"down":
			b.t += 1
			if b.t == 1:
				Audio.play("roar", -6)
			if b.t > 150:
				b.done = true
				b.active = false
	# contato com o Tomé
	if b.st in ["intro", "idle", "paw", "charge", "stun", "trot"] and p.dyingT == 0:
		var bb := boss_box()
		if Game.hit(p, bb):
			var feet: float = p.y + p.h
			if p.vy > 0.5 and feet - bb.y < 34:
				p.vy = -8.5
				p.y = bb.y - p.h - 1
				p.cutOk = false
				Audio.play("spring", -8)
				g.tip("O couro dele é duro! Faça ele bater a cabeça na árvore ou no barranco.")
			elif b.st == "charge" or b.st == "intro":
				g.hurt(1, b.x)

## o Javali-Rei bateu a cabeça: perde uma vida
func boss_damage(from_slam: bool = false) -> void:
	var b: Dictionary = BOSS
	b.hp -= 1
	# batida de cabeça deixa ele tonto: um mergulho perto vale uma batida extra (uma vez por batida)
	b.bang = not from_slam
	b.red = 30
	Audio.play("roar", -10)
	if b.hp <= 0:
		b.st = "down"
		b.t = 0
		_gate_on(false)
		g.flash("O Javali-Rei caiu! Você ganhou uma armadura de casca de árvore (aguenta 1 golpe).", 260)
		g.player.armor = 1
		for i in 12:
			g.gain_coin(b.item[0], b.item[1] - 20, true)
		Audio.play("door", -4)
	else:
		b.st = "stun"
		b.t = 0
		if b.hp == b.maxhp - 1:
			g.flash_tut("Bum! Falta%s %d." % ["m" if b.hp > 1 else "", b.hp], "Bum! Ele bateu a cabeça. Falta%s %d. Volte ao chão e chame de novo!" % ["m" if b.hp > 1 else "", b.hp], 160)
		else:
			g.flash("Bum! Falta%s %d." % ["m" if b.hp > 1 else "", b.hp], 120)

func boss_reset() -> void:
	if BOSS.is_empty() or BOSS.done:
		return
	BOSS.active = false
	BOSS.st = "wait"
	BOSS.hp = BOSS.maxhp
	BOSS.x = BOSS.spawn
	_gate_on(false)

func boss_finish_silent() -> void:
	if BOSS.is_empty():
		return
	BOSS.done = true
	BOSS.active = false

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
	var under: bool = g.indoors()
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
	var gk: String = g.ground_kind() if p.onGround else ""
	var snow: bool = gk == "snow"
	var soft: bool = p.mud or snow or (gt == "ground" and (song == "chuva" or weather == "garoa"))
	if p.onGround and soft and abs(p.vx) > .6 and g.T % 13 == 0 and not p.crouch:
		FOOT.append({"x": p.x + p.w / 2 + (4 if (g.T / 13) % 2 == 0 else -4), "y": p.y + p.h, "f": p.face, "t": 0, "snow": snow})
		# correndo na lama: respingos
		if not snow and abs(p.vx) > 3:
			for k in 3:
				g.PARTS.append({"x": p.x + p.w / 2 - p.face * 6, "y": p.y + p.h - 2, "vx": -p.face * randf_range(.6, 2.2), "vy": -randf_range(1.5, 3.2), "life": 20, "col": Color(.3, .22, .13, .9)})
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
		"boss": BOSS.get("done", false), "dog": dog_free(), "tocas": TOCAS.filter(func(t): return t.done).map(func(t): return t.get("id", 1))}

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
		for r in RELICS:
			if r.id == id:
				r.broken = true
				r.got = true
	if d.get("gold", false) and not GOLD.is_empty():
		GOLD.got = true
	if d.get("boss", false):
		boss_finish_silent()
	for id in d.get("tocas", []):
		for tc in TOCAS:
			if tc.get("id", 1) == id:
				tc.done = true
	if d.get("dog", false) and not DOG.is_empty():
		DOG.st = "follow"
		DOG.x = -9999.0   # aparece perto do Tomé no primeiro passo
		TRAIL = []

# ======================================================================
#  PIPOCA, O CACHORRO
# ======================================================================
func dog_free() -> bool:
	return not DOG.is_empty() and DOG.st != "tied"

func _use_dog() -> bool:
	if DOG.is_empty() or DOG.st != "tied":
		return false
	var p: Dictionary = g.player
	if abs(p.x + p.w / 2 - DOG.x) < 70 and abs(p.y + p.h - DOG.y) < 50:
		DOG.st = "follow"
		DOG.t = 0
		TRAIL = [Vector2(DOG.x, DOG.y)]
		DOG.i = 0
		g.burst(DOG.x - 30, DOG.y - 20, 10, Color("#c9a26a"))
		Audio.play("item")
		g.start_cine("cao", DOG.x - 40, DOG.y - 40, 215,
			[[24, 110, "TOMÉ", "Calma, amigão... Você é o Pipoca! O vira-lata que a Isis alimentava todo dia!", "tome"],
			[110, 205, "TOMÉ", "O Vargas te amarrou aqui para você não seguir a Isis, né? Vem comigo, vamos achá-la!", "tome"]],
			[150, 205, "PIPOCA", "o melhor amigo da Isis"])
		return true
	return false

func _use_toca() -> bool:
	var p: Dictionary = g.player
	for tc in TOCAS:
		if tc.done or abs(p.x + p.w / 2 - tc.x) > 80 or abs(p.y + p.h - tc.y) > 50:
			continue
		if not dog_free():
			g.flash("Uma toca estreita, cheirando a cachorro. O Tomé não cabe aí...", 200)
		elif DOG.st in ["follow", "sit", "stay"]:
			DOG.st = "to_toca"
			DOG.toca = tc
			DOG.t = 0
			Audio.play("bark")
			g.note("Busca, Pipoca!")
		return true
	return false

func dog_dist() -> float:
	var p: Dictionary = g.player
	return Vector2(DOG.x, DOG.y).distance_to(Vector2(p.x + p.w / 2, p.y + p.h))

func _dog() -> void:
	if DOG.is_empty():
		return
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var feet: float = p.y + p.h
	DOG.t += 1
	if DOG.bark > 0:
		DOG.bark -= 1
	DOG.moving = false
	# caminho do Tomé no chão
	if p.onGround and not p.ladder and not p.vine and not p.swim and p.dyingT == 0 and not p.get("dog") and (g.ZN == null or g.ZN.zone == null):
		var cur := Vector2(pcx, feet)
		if TRAIL.is_empty() or TRAIL[TRAIL.size() - 1].distance_to(cur) > 6:
			TRAIL.append(cur)
			if TRAIL.size() > 600:
				TRAIL.pop_front()
				DOG.i = max(0, DOG.i - 1)
	match DOG.st:
		"ctrl", "dig":
			pass
		"door":
			# esperando do lado de fora da torre
			DOG.moving = false
			if g.ZN == null or g.ZN.zone == null:
				DOG.st = "follow"
				TRAIL = [Vector2(pcx, feet)]
				DOG.x = pcx - p.face * 40
				DOG.y = feet
				_resync()
		"stay":
			DOG.moving = false
			if dog_dist() > 1400:
				DOG.st = "follow"
				_resync()
		"tied":
			DOG.x = DOG.x0 + sin(DOG.t * .03) * 16
			DOG.face = 1 if cos(DOG.t * .03) > 0 else -1
			DOG.moving = true
			if abs(pcx - DOG.x) < 320 and DOG.t % 110 == 0:
				_bark()
		"follow", "sit":
			_follow()
			_look_for_moles()
		"to_toca":
			var tc: Dictionary = DOG.toca
			if _run_to(tc.x, tc.y, 5.5):
				DOG.st = "in_toca"
				DOG.t = 0
				g.burst(tc.x, tc.y - 6, 12, Color("#7a5a3a"))
		"in_toca":
			if DOG.t % 8 == 0:
				g.PARTS.append({"x": DOG.toca.x + (randf() - .5) * 20, "y": DOG.toca.y - 6, "vx": (randf() - .5) * 4, "vy": -2 - randf() * 2, "life": 20, "col": Color("#7a5a3a")})
			if DOG.t == 50:
				Audio.play("bark", -6)
			if DOG.t > 100:
				DOG.st = "return"
				DOG.carry = true
				DOG.toca.done = true
				Audio.play("item")
		"return":
			if _run_to(pcx - p.face * 26, feet, 6.0) or dog_dist() < 40:
				DOG.st = "follow"
				DOG.carry = false
				_bark()
				for d in g.DRWS:
					if d.get("hidden") and d.get("toca") == DOG.toca.get("id", 1):
						d.hidden = false
						d.x = pcx
						d.y = p.y + 10
				_resync()
		"hunt":
			var e: Dictionary = DOG.mole
			DOG.hunt_t = DOG.get("hunt_t", 0) + 1
			var pl: Dictionary = g.player
			if e.dead or e.get("st", 0) not in [0, 6] or DOG.hunt_t > 240 or abs(pl.x + pl.w / 2 - DOG.x) > 520:
				# não alcançou a toupeira (ou o Tomé foi embora): desiste e volta a seguir
				DOG.hunt_t = 0
				e.cd_dog = 400
				DOG.st = "follow"
				_resync()
			elif _run_to(e.x, e.base, 6.0):
				DOG.hunt_t = 0
				DOG.st = "dig"
				DOG.t = 0
				e.st = 6
				e.t = 0
				_bark()
		"dig":
			var e2: Dictionary = DOG.mole
			if DOG.t % 5 == 0:
				g.PARTS.append({"x": DOG.x - DOG.face * 14, "y": DOG.y - 4, "vx": -DOG.face * (2 + randf() * 2), "vy": -2 - randf() * 2, "life": 18, "col": Color("#7a5a3a")})
			if DOG.t > 50:
				e2.st = 5
				e2.t = 0
				e2.helm_off = true
				e2.cd_dog = 500
				g.shake = 6
				Audio.play("stomp", -6)
				g.burst(e2.x, e2.base - 10, 14, Color("#7a5a3a"))
				g.note("O Pipoca puxou a toupeira para fora! Pule nela agora!")
				DOG.st = "follow"
				_resync()

func _bark() -> void:
	DOG.bark = 30
	Audio.play("bark", -4)

## volta a seguir o caminho a partir do ponto mais perto
func _resync() -> void:
	var best := 0
	var bd := INF
	for i in TRAIL.size():
		var d: float = TRAIL[i].distance_to(Vector2(DOG.x, DOG.y))
		if d < bd:
			bd = d
			best = i
	DOG.i = best

func _run_to(x: float, y: float, spd: float) -> bool:
	var dx: float = x - DOG.x
	if abs(dx) > 2:
		DOG.face = 1 if dx > 0 else -1
		DOG.moving = true
	DOG.x += clamp(dx, -spd, spd)
	DOG.y = lerpf(DOG.y, y, .25)
	DOG.anim += abs(clamp(dx, -spd, spd)) * .08
	return abs(dx) < 4 and abs(DOG.y - y) < 4

func _follow() -> void:
	if TRAIL.is_empty():
		return
	# alvo: um pouco atrás do Tomé, no caminho que ele fez
	var ti := TRAIL.size() - 1
	var acc := 0.0
	while ti > 0 and acc < 58:
		acc += TRAIL[ti].distance_to(TRAIL[ti - 1])
		ti -= 1
	DOG.i = clamp(DOG.i, 0, TRAIL.size() - 1)
	var far: float = Vector2(DOG.x, DOG.y).distance_to(TRAIL[ti])
	var spd: float = clamp(far * .08, 2.2, 7.5)
	# muito longe (o Tomé entrou num esconderijo, subiu uma escada...): aparece perto dele
	var off_screen: bool = DOG.x < g.cam - 120 or DOG.x > g.cam + g.W + 120 or DOG.y < g.cam_y - 120 or DOG.y > g.cam_y + g.H + 120
	if (far > 700 or (off_screen and far > 260)) and g.player.onGround:
		DOG.x = TRAIL[ti].x
		DOG.y = TRAIL[ti].y
		DOG.i = ti
		DOG.hy = 0.0
		g.burst(DOG.x, DOG.y - 16, 10, Color("#d8c8a0"))
		return
	if DOG.i >= ti:
		DOG.st = "sit" if DOG.t % 600 > 30 else "follow"
		DOG.hy = 0.0
		DOG.v = 0.0
		DOG.wake = 0
		return
	# reage com um atraso de cachorro: percebe que o Tomé saiu, levanta e pega velocidade aos poucos
	if DOG.st == "sit" and far < 220:
		DOG.wake = DOG.get("wake", 0) + 1
		if DOG.wake < 16:
			return
	DOG.st = "follow"
	DOG.v = lerpf(DOG.get("v", 0.0), spd, .1)
	var budget: float = max(DOG.v, .8)
	while budget > 0 and DOG.i < ti:
		var nxt: Vector2 = TRAIL[DOG.i + 1]
		var here := Vector2(DOG.x, DOG.y)
		var d: float = here.distance_to(nxt)
		var prev: Vector2 = TRAIL[DOG.i]
		var seg: float = prev.distance_to(nxt)
		if seg > 280:
			DOG.x = nxt.x
			DOG.y = nxt.y
			DOG.i += 1
			continue
		if d <= budget:
			DOG.x = nxt.x
			DOG.y = nxt.y
			DOG.i += 1
			budget -= d
		else:
			var v := (nxt - here) / d * budget
			DOG.x += v.x
			DOG.y += v.y
			budget = 0
		DOG.face = 1 if nxt.x >= prev.x else -1
		# trecho longo entre duas pegadas = pulo (buraco, degrau): faz um arco
		if seg > 26:
			var u: float = clamp(prev.distance_to(Vector2(DOG.x, DOG.y)) / seg, 0, 1)
			DOG.hy = -min(80.0, seg * .45) * sin(u * PI)
		else:
			DOG.hy = 0.0
	DOG.moving = true
	DOG.anim += spd * .08

func _look_for_moles() -> void:
	var p: Dictionary = g.player
	for e in g.EN:
		if e.k != "mole" or e.dead or e.get("st", 0) != 0 or e.get("cd_dog", 0) > 0:
			continue
		if abs(e.x - DOG.x) < 280 and abs(e.base - DOG.y) < 40 and abs(e.x - (p.x + p.w / 2)) < 420:
			DOG.st = "hunt"
			DOG.mole = e
			_bark()
			return
	for e in g.EN:
		if e.k == "mole" and e.get("cd_dog", 0) > 0:
			e.cd_dog -= 1
