extends RefCounted
class_name Critters
## Bichinhos de ambiente que não atacam: passarinhos que bicam o chão e voam quando o Tomé chega,
## borboletas, coelhos que fogem pulando, sapinhos que pulam na água e corujas piscando à noite.
## Tudo só visual: nascem em pontos fixos da fase perto da câmera e voltam depois de um tempo.

static var C := {}
static var TU := {}
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
		TU = {}
		level_ref = g.L
	_toucans(g, T)
	_flock(g, T)
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
					k = "bird"
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

## bando de passarinhos (ou morcegos, à noite) cruzando o céu de vez em quando, lá no alto
static func _flock(g: Game, T: int) -> void:
	var kind = g.sec_param("flock", null)
	if kind == null or g.indoors():
		return
	var per: int = 900
	var ph: int = T % per
	if ph > 520:
		return
	var cyc: int = T / per
	var dir: float = 1.0 if cyc % 2 == 0 else -1.0
	var u: float = ph / 520.0
	var x0: float = g.cam - 200 if dir > 0 else g.cam + g.W + 200
	var bx: float = x0 + dir * u * (g.W + 400)
	var by: float = g.cam_y + 70 + hh(cyc, 4) * 90 + sin(u * 6.0) * 10
	var n: int = 5 + int(hh(cyc, 5) * 5)
	var bat: bool = str(kind) == "bats"
	for k in n:
		var row: int = (k + 1) / 2
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var px: float = bx - dir * row * 26
		var py: float = by + side * row * 12 * (0.0 if k == 0 else 1.0) + sin(T * .2 + k) * 2
		var fl: float = sin(T * (.45 if bat else .3) + k * 1.3)
		var w: float = 9.0 if not bat else 8.0
		var c := Color(.12, .1, .14, .85) if bat else Color(.18, .14, .12, .75)
		Spr.line(PackedVector2Array([Vector2(px - w, py - fl * 5), Vector2(px - 2, py), Vector2(px, py + 1), Vector2(px + 2, py), Vector2(px + w, py - fl * 5)]), c, 2.0)
		if bat:
			Spr.circle(px, py + 1, 2.2, c)

## cor dos bichinhos do cenário: um pouco mais clara e suave
const SOFT := Color(1.08, 1.08, 1.1, .92)

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
		elif int(c.t) % 90 >= 60 and int(c.t) % 90 < 68:
			# pulinho: anda 8 px num arco curto (em vez de teletransportar)
			c.x += c.f * 1.0
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
	var pk: int = int(c.t) % 50
	# bicada: abaixa e volta suave (curva), não num estalo
	var peck: float = 0.0 if fly else (sin(pk / 8.0 * PI) * 2.0 if pk < 8 else 0.0)
	var hop_ph: int = int(c.t) % 90 - 60
	var hop: float = sin(hop_ph / 8.0 * PI) * 5.0 if (not fly and hop_ph >= 0 and hop_ph < 8) else 0.0
	Spr.save()
	Spr.translate(c.x, c.y - hop)
	if fly:
		# bate as asas: o corpo sobe na batida para baixo e as asas "fecham" (achata na vertical)
		var fl: float = sin(T * .8 + c.x0)
		Spr.translate(0, 4 - fl * 2)
		Spr.rotate(clamp(c.vy * -.05, -.25, .25) * -c.f)
		Spr.scale(1, .8 + .2 * abs(fl))
		Spr.P("bird_fly", 0, 0, 22, c.f < 0, 0.0, SOFT)
	else:
		Spr.rotate(peck * .12 * c.f)
		Spr.P("bird_sit", 0, 1, 17, c.f < 0, 0.0, SOFT)
	Spr.restore()

## borboleta: voa em volta de um ponto, batendo as asas
static func _butterfly(c: Dictionary, T: int, i: int) -> void:
	var t: float = T * .02 + i
	var x: float = c.x0 + sin(t * 1.3) * 60 + sin(t * 3.1) * 12
	var y: float = c.y0 - 40 - abs(sin(t * 2.0)) * 30 + sin(t * 5.0) * 6
	var flap: float = abs(sin(T * .35 + i))
	var col: Color = [Color(1, 1, 1), Color(.7, .85, 1.2), Color(1.1, .75, .95), Color(1.1, 1.05, .6)][i % 4]
	# asas abrindo e fechando: alterna a borboleta aberta (achatando) e de lado
	if flap > .45:
		Spr.PR("bfly_open", x - 8, y - 6, 16, 12 * flap + 2, col)
	else:
		Spr.P("bfly_side", x, y + 6, 11, sin(t) < 0, 0.0, col)

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
	Spr.ellipse(c.x, c.y + 1, 11, 2.5, Color(0, 0, 0, .2))
	var n := "rab_sit"
	if c.st == "run":
		n = "rab_jump" if hop > 5 else "rab_land"
	elif int(c.t / 70) % 3 == 1:
		n = "rab_alert"
	Spr.P(n, c.x, c.y + 1 - hop, 30 if c.st == "run" else 22, c.f < 0, 0.0, SOFT)

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
	Spr.P("frog_jump" if c.st == "jump" else "frog_sit", c.x, c.y + 1 - jy, 26 if c.st == "jump" else 20, c.f < 0)

## coruja num galho alto: pisca devagar e vira a cabeça
static func _owl(c: Dictionary, T: int, i: int) -> void:
	# coruja num mourão de madeira fincado no chão: pisca devagar e vira a cabeça
	var x: float = c.x0
	var gy: float = c.y0
	var ph: float = 70 + hh(i, 7) * 30
	Spr.ellipse(x, gy + 2, 12, 3, Color(0, 0, 0, .25))
	Spr.PR("stake", x - 8, gy - ph, 16, ph + 10, Color(.75, .7, .66))
	var blink: bool = (T + i * 37) % 180 < 8
	Spr.P("owl1" if blink else "owl0", x, gy - ph + 6, 28, sin(T * .004 + i) < 0)

## tucanos: chegam voando, pousam num galho, ficam olhando em volta e abrindo o bico;
## se o Tomé chega perto, levantam voo. Onde não há galho, só atravessam o céu de vez em quando.
static func _toucans(g: Game, T: int) -> void:
	if g.indoors():
		return
	var p: Dictionary = g.player
	var px: float = p.x + p.w / 2
	var py: float = p.y + p.h
	var i0: int = int(floor((g.cam - 300) / 900.0))
	var i1: int = int(floor((g.cam + g.W + 300) / 900.0))
	for i in range(i0, i1 + 1):
		if not TU.has(i):
			var cx: float = i * 900 + 450
			var th := _theme(g, cx)
			var many: bool = g.sec_param("toucans", 0) != 0
			if not th in ["manha", "tarde", "chuva"] or hh(i, 21) < (0.0 if many else .35):
				TU[i] = {"k": ""}
				continue
			var perch = null
			for so in g.SOL:
				# tucano só lá no alto (galhos altos), longe do caminho do Tomé
				if str(so.get("t", "")) == "branch" and so.y < 300 and so.x + so.w > i * 900 and so.x < i * 900 + 900:
					perch = so
					break
			var gy: float = _ground_y(g, cx)
			if perch == null and gy == INF:
				TU[i] = {"k": ""}
				continue
			var t := {"k": "tu", "st": "away", "t": -int(hh(i, 22) * 400), "f": 1.0, "x": 0.0, "y": 0.0, "fr": 0}
			if perch != null:
				t.px = perch.x + perch.w * (.3 + hh(i, 23) * .4)
				t.py = perch.y + 2 + perch.get("dip", 0.0)
				t.perch = perch
			else:
				t.px = cx
				t.py = gy - 380
			TU[i] = t
		var u: Dictionary = TU[i]
		if u.k == "":
			continue
		u.t += 1
		var has_perch: bool = u.has("perch")
		if has_perch:
			u.py = u.perch.y + 2 + u.perch.get("dip", 0.0)
		match u.st:
			"away":
				if u.t > 0 and abs(px - u.px) > 260:
					u.st = "in"
					u.f = 1.0 if hh(i + u.t, 24) > .5 else -1.0
					u.x = u.px - u.f * (g.W * .7 + 100)
					u.y = u.py - 240
					u.t = 0
			"in":
				var tx: float = u.px
				var ty: float = u.py
				if not has_perch:
					tx = u.px + u.f * (g.W + 600)
				var dx: float = tx - u.x
				var spd: float = 4.2
				u.x += sign(dx) * min(abs(dx), spd)
				if has_perch:
					var k: float = clamp(abs(dx) / (g.W * .7 + 100), 0, 1)
					u.y = ty - 240 * k * k - sin(k * PI) * 30
					if abs(dx) < 40:
						u.st = "land"
						u.t = 0
				else:
					u.y = ty + sin(u.t * .03) * 20
					if abs(dx) < 5:
						u.st = "away"
						u.t = -1600
			"land":
				u.x = lerpf(u.x, u.px, .2)
				u.y = lerpf(u.y, u.py, .25)
				if u.t > 14:
					u.st = "sit"
					u.t = 0
			"sit":
				u.x = u.px
				u.y = u.py
				if abs(px - u.px) < 170 and abs(py - u.py) < 220:
					u.st = "off"
					u.f = 1.0 if u.px > px else -1.0
					u.t = 0
			"off":
				u.x += u.f * 4.5
				u.y -= 3.2
				if u.t > 140:
					u.st = "away"
					u.t = -1400
		if u.st == "away":
			continue
		if u.x < g.cam - 120 or u.x > g.cam + g.W + 120:
			continue
		var n := "tuc_sit0"
		var fl := [0, 1, 2, 1]
		match u.st:
			"in", "off":
				if u.st == "in" and has_perch and int(u.t) % 90 > 60:
					n = "tuc_glide"
				else:
					n = "tuc_f%d" % fl[(T / 5) % 4]
			"land":
				n = "tuc_land"
			"sit":
				var cyc: int = (int(u.t) + i * 53) % 400
				n = "tuc_sit2" if cyc > 330 and cyc < 370 else ("tuc_sit1" if cyc > 200 and cyc < 230 else "tuc_sit0")
				if cyc == 260:
					u.f = -u.f
		# bichos do cenário: menores e de cor suave (os inimigos são grandes, fortes e com contorno vermelho)
		var w: float = 36.0 if u.st == "sit" else 42.0
		Spr.P(n, u.x, u.y + (0.0 if u.st == "sit" else 16.0), w, u.f < 0, 0.0, SOFT)
