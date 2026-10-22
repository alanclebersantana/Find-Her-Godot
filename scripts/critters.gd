extends RefCounted
class_name Critters
## Bichinhos de ambiente que não atacam: passarinhos que bicam o chão e voam quando o Tomé chega,
## borboletas, coelhos que fogem pulando, sapinhos que pulam na água e corujas piscando à noite.
## Tudo só visual: nascem em pontos fixos da fase perto da câmera e voltam depois de um tempo.

static var C := {}
static var level_ref = null

static func hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

static func _ground_y(g: Game, x: float) -> float:
	var best := INF
	for s in g.SOL:
		if s.t in ["ground", "cliff"] and x > s.x + 20 and x < s.x + s.w - 20 and s.y > 0 and s.y < best:
			best = s.y
	return best

static func _theme(g: Game, x: float) -> String:
	var th := "manha"
	for sc in g.L.get("sections", []):
		if sc.x <= x:
			th = "neve" if sc.get("bg", "") == "neve" else sc.get("song", "manha")
	return th

static func draw(g: Game, T: int) -> void:
	if level_ref != g.L:
		C = {}
		level_ref = g.L
	g.bird_near = false
	var p: Dictionary = g.player
	var px: float = p.x + p.w / 2
	var py: float = p.y + p.h
	var i0: int = int(floor((g.cam - 200) / 520.0))
	var i1: int = int(floor((g.cam + g.W + 200) / 520.0))
	for i in range(i0, i1 + 1):
		if hh(i, 1) < .45:
			continue
		if not C.has(i):
			var x: float = i * 520 + 60 + hh(i, 2) * 400
			var gy: float = _ground_y(g, x)
			if gy == INF:
				C[i] = {"k": ""}
				continue
			var th := _theme(g, x)
			var k := ""
			match th:
				"manha", "tarde":
					k = ["bird", "butterfly", "rabbit"][int(hh(i, 3) * 3)]
				"chuva":
					k = "frog" if hh(i, 4) < .6 else "bird"
				"noite", "perseguicao":
					k = "owl"
				"neve", "tema":
					k = "bird" if hh(i, 5) < .5 else "rabbit"
			if g.indoors() and k != "owl":
				k = ""
			C[i] = {"k": k, "x": x, "y": gy, "x0": x, "y0": gy, "st": "idle", "t": 0.0, "vx": 0.0, "vy": 0.0, "f": 1.0 if hh(i, 6) > .5 else -1.0}
		var c: Dictionary = C[i]
		if c.k == "":
			continue
		c.t += 1
		match c.k:
			"bird":
				_bird(g, c, px, py, T)
			"butterfly":
				_butterfly(c, T, i)
			"rabbit":
				_rabbit(c, px, py, T)
			"frog":
				_frog(g, c, px, py, T)
			"owl":
				_owl(c, T, i)

static func _respawn(c: Dictionary) -> void:
	c.x = c.x0
	c.y = c.y0
	c.st = "idle"
	c.t = 0.0
	c.vx = 0.0
	c.vy = 0.0

## passarinho: bica o chão, dá pulinhos e voa quando o Tomé chega perto
static func _bird(g: Game, c: Dictionary, px: float, py: float, T: int) -> void:
	if c.st == "idle":
		if abs(px - c.x) < 140 and abs(py - c.y) < 120:
			c.st = "fly"
			c.vx = sign(c.x - px) * 3.0 if c.x != px else 3.0
			c.vy = -3.4
			c.f = sign(c.vx)
		elif int(c.t) % 90 == 60:
			c.x += c.f * 8
		elif int(c.t) % 200 == 0:
			c.f = -c.f
	elif c.st == "fly":
		c.x += c.vx
		c.y += c.vy
		c.vy = max(c.vy - .02, -4.0)
		if abs(px - c.x) < 260 and c.y < py - 40:
			g.bird_near = true
		if c.y < c.y0 - 700:
			c.st = "gone"
			c.t = 0
	elif c.st == "gone":
		if c.t > 900 and abs(px - c.x0) > 600:
			_respawn(c)
		return
	var fly: bool = c.st == "fly"
	var peck: float = 0.0 if fly else (3.0 if int(c.t) % 50 < 8 else 0.0)
	var col := Color("#6b4a32")
	Spr.save()
	Spr.translate(c.x, c.y - 6)
	Spr.scale(c.f, 1)
	Spr.ellipse(0, 0, 7, 5, col)
	Spr.ellipse(1, 2, 5, 3, Color("#c9a26a"))
	Spr.circle(6, -4 + peck, 3.6, col)
	Spr.poly(PackedVector2Array([Vector2(9, -4 + peck), Vector2(13, -3 + peck), Vector2(9, -2 + peck)]), Color("#e0a030"))
	Spr.circle(7, -5 + peck, .9, Color(0, 0, 0))
	Spr.poly(PackedVector2Array([Vector2(-6, -1), Vector2(-12, -3), Vector2(-7, 2)]), col.darkened(.3))
	if fly:
		var w: float = sin(T * .8) * 8
		Spr.poly(PackedVector2Array([Vector2(-2, -2), Vector2(-4, -2 - 10 - w), Vector2(4, -3)]), col.darkened(.15))
	else:
		Spr.seg(-1, 4, -1, 7, Color("#3a2414"), 1.2)
		Spr.seg(2, 4, 2, 7, Color("#3a2414"), 1.2)
	Spr.restore()

## borboleta: voa em volta de um ponto, batendo as asas
static func _butterfly(c: Dictionary, T: int, i: int) -> void:
	var t: float = T * .02 + i
	var x: float = c.x0 + sin(t * 1.3) * 60 + sin(t * 3.1) * 12
	var y: float = c.y0 - 40 - abs(sin(t * 2.0)) * 30 + sin(t * 5.0) * 6
	var flap: float = abs(sin(T * .35 + i))
	var col: Color = [Color("#f0a030"), Color("#7ab0f0"), Color("#f07ab0"), Color("#f0e060")][i % 4]
	Spr.ellipse(x - 4 * flap, y - 2, 4 * flap + .5, 4, col)
	Spr.ellipse(x + 4 * flap, y - 2, 4 * flap + .5, 4, col)
	Spr.ellipse(x - 3 * flap, y + 2, 3 * flap + .5, 2.5, col.darkened(.2))
	Spr.ellipse(x + 3 * flap, y + 2, 3 * flap + .5, 2.5, col.darkened(.2))
	Spr.seg(x, y - 4, x, y + 4, Color("#2a1a0e"), 1.4)

## coelho: mastiga parado, mexe as orelhas e foge pulando quando o Tomé chega
static func _rabbit(c: Dictionary, px: float, py: float, T: int) -> void:
	if c.st == "idle" and abs(px - c.x) < 170 and abs(py - c.y) < 120:
		c.st = "run"
		c.f = 1.0 if c.x > px else -1.0
		c.t = 0
	var hop: float = 0.0
	if c.st == "run":
		c.x += c.f * 4.2
		hop = abs(sin(c.t * .25)) * 14
		if c.t > 120:
			c.st = "gone"
			c.t = 0
	elif c.st == "gone":
		if c.t > 900 and abs(px - c.x0) > 600:
			_respawn(c)
		return
	var col := Color("#9a8a7a")
	Spr.ellipse(c.x, c.y + 1, 10, 2.5, Color(0, 0, 0, .2))
	Spr.save()
	Spr.translate(c.x, c.y - 8 - hop)
	Spr.scale(c.f, 1)
	Spr.ellipse(0, 0, 10, 7, col)
	Spr.circle(8, -5, 5, col)
	var ear: float = sin(T * .1) * .2 if c.st == "idle" else -.5
	for e in [0, 1]:
		Spr.save()
		Spr.translate(6 + e * 3, -9)
		Spr.rotate(-.3 + ear + e * .2)
		Spr.ellipse(0, -6, 2.2, 6, col.darkened(.05))
		Spr.ellipse(0, -6, 1, 4, Color("#e8b0b0"))
		Spr.restore()
	Spr.circle(11, -6, 1, Color(0, 0, 0))
	Spr.circle(-10, -2, 3, Color(.95, .95, .95))
	Spr.restore()

## sapinho do brejo: coaxa (papo inflando) e pula na água quando o Tomé chega
static func _frog(g: Game, c: Dictionary, px: float, py: float, T: int) -> void:
	if c.st == "idle" and abs(px - c.x) < 150 and abs(py - c.y) < 120:
		c.st = "jump"
		c.f = 1.0 if c.x > px else -1.0
		c.t = 0
	var jy: float = 0.0
	if c.st == "jump":
		var u: float = c.t / 30.0
		c.x += c.f * 3.0
		jy = sin(min(u, 1.0) * PI) * 40
		if u >= 1:
			if g.WV:
				g.WV.splash(c.x, c.y, 2.5)
			c.st = "gone"
			c.t = 0
	elif c.st == "gone":
		if c.t > 700 and abs(px - c.x0) > 600:
			_respawn(c)
		return
	if Spr.tex.has("en_frog2"):
		var ff: int = 4 if c.st == "jump" else (int(c.t / 22) % 2)
		Spr.save()
		Spr.translate(c.x, c.y - jy)
		Spr.scale(c.f, 1)
		Spr.frame(Spr.tex.en_frog2, ff, 130, 70, 65, 68, 0, 2, .38)
		Spr.restore()

## coruja num galho alto: pisca devagar e vira a cabeça
static func _owl(c: Dictionary, T: int, i: int) -> void:
	var x: float = c.x0
	var y: float = c.y0 - 210 - hh(i, 7) * 60
	Spr.rr(x - 30, y + 14, 60, 7, 3, Color("#3a2414"))
	var col := Color("#7a6248")
	Spr.ellipse(x, y, 11, 14, col)
	Spr.ellipse(x, y + 3, 7, 9, Color("#c9b08a"))
	Spr.poly(PackedVector2Array([Vector2(x - 9, y - 10), Vector2(x - 6, y - 19), Vector2(x - 3, y - 11)]), col)
	Spr.poly(PackedVector2Array([Vector2(x + 9, y - 10), Vector2(x + 6, y - 19), Vector2(x + 3, y - 11)]), col)
	var blink: bool = (T + i * 37) % 180 < 8
	var look: float = sin(T * .01 + i) * 2.0
	for e in [-1, 1]:
		var ex: float = x + e * 4.5 + look
		Spr.circle(ex, y - 6, 3.6, Color(1, .85, .3))
		if blink:
			Spr.seg(ex - 3, y - 6, ex + 3, y - 6, Color("#2a1a0e"), 1.6)
		else:
			Spr.circle(ex, y - 6, 1.6, Color(0, 0, 0))
	Spr.poly(PackedVector2Array([Vector2(x - 2 + look, y - 3), Vector2(x + look, y + 1), Vector2(x + 2 + look, y - 3)]), Color("#e0a030"))
