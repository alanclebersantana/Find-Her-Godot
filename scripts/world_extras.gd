extends RefCounted
class_name WorldExtras
## Desenho dos sistemas novos que ficam no mundo (escurecem com a noite):
## capim que balança, pegadas, giz da Isis, rochas rachadas, grades, espelhos, cristais,
## plataformas de luz, troncos e o Javali-Rei, e os inimigos novos (morcego, aranha, toupeira).

const WSt = preload("res://scripts/world_static.gd")
const CHALK := Color(.96, .95, .9, .82)

static func h(x: float, k: int = 0) -> float:
	## ruído fixo 0..1 a partir de x
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

# ---------------------------------------------------------------- capim
static func grass(g: Game, T: int) -> void:
	## tufos de grama pintados (mesma arte do cenário): balançam com o vento e abrem quando o Tomé passa
	var x0: float = g.cam - 40
	var x1: float = g.cam + g.W + 40
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var wind: float = g.AMB.get("wind", 0.0)
	for s in g.SOL:
		if s.t != "ground" or s.x > x1 or s.x + s.w < x0 or s.get("snow"):
			continue
		if WSt.gt_at(g, s.x + s.w / 2) != "":
			continue   # chão de pedra (mina, rua da vila): sem capim
		var xa: float = max(s.x + 14, floor(x0 / 34.0) * 34.0)
		var xb: float = min(s.x + s.w - 14, x1)
		var tc: Color = WSt.tint_at(g, xa)
		var x: float = xa
		while x < xb:
			var r := h(x)
			if r > .3:
				var by: float = s.y + 4
				var near: float = clamp(1.0 - abs(x - pcx) / 34.0, 0, 1) if abs(p.y + p.h - s.y) < 40 else 0.0
				var push: float = sign(x - pcx) * near * 8.0
				var sway: float = sin(T * (.03 + wind * .05) + x * .03) * (1.2 + wind * 4.0) + wind * 3.0
				var kind: int = int(h(x, 3) * 5)
				var w: float = [22.0, 30.0, 30.0, 30.0, 28.0][kind] * (.85 + h(x, 4) * .35)
				Spr.P("grass%d" % kind, x + (h(x, 5) - .5) * 10, by, w, h(x, 6) > .5, sway + push, tc)
			x += 34

## flores do chão: balançam com a brisa (cada uma no seu ritmo), deitam quando o Tomé passa
## e voltam com um balanço de mola
static var _fspring := {}
static func flowers(g: Game, T: int) -> void:
	var x0: float = g.cam - 40
	var x1: float = g.cam + g.W + 40
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var wind: float = g.AMB.get("wind", 0.0)
	for s in g.SOL:
		if s.t != "ground" or s.x > x1 or s.x + s.w < x0:
			continue
		var fl: Array = WSt.flowers_of(g, s)
		if fl.is_empty():
			continue
		for f in fl:
			var fx: float = f[0]
			if fx < x0 or fx > x1:
				continue
			var near: float = clamp(1.0 - abs(fx - pcx) / 30.0, 0, 1) if abs(p.y + p.h - s.y) < 40 else 0.0
			# mola: o empurrão decai e a flor volta balançando
			var key: int = int(fx)
			var sp: Vector2 = _fspring.get(key, Vector2.ZERO)
			var tgt: float = sign(fx - pcx) * near * (6.0 + abs(p.vx) * 1.2)
			sp.y += (tgt - sp.x) * .18
			sp.y *= .78
			sp.x += sp.y
			_fspring[key] = sp
			var sway: float = sin(T * (.035 + wind * .05) + fx * .05) * (1.4 + wind * 4.0) + wind * 3.0
			Spr.P(f[1], fx, s.y + 2, f[2], f[3], sway + sp.x, WSt.tint_at(g, fx))
	if _fspring.size() > 400:
		_fspring.clear()

# ---------------------------------------------------------------- passagens baixas
static func crawl(g: Game, T: int) -> void:
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	for c in g.X.CRAWL:
		if c.x > g.cam + g.W + 50 or c.x + c.w < g.cam - 50:
			continue
		var gap: float = c.y - c.top
		# vão escuro embaixo, com a borda de baixo do obstáculo bem marcada
		Spr.vgrad(c.x - 4, c.top, c.w + 8, gap, Color(0, 0, 0, .65), Color(0, 0, 0, .25))
		Spr.rect(c.x - 4, c.top - 3, c.w + 8, 3, Color(1, .9, .6, .35))
		var near: bool = abs(pcx - (c.x + c.w / 2)) < c.w / 2 + 170 and abs(p.y + p.h - c.y) < 40 and not p.crouch
		if near:
			var b := sin(T * .15) * 4
			var cx: float = c.x + c.w / 2
			var iy: float = min(c.top - 40, c.y - 70) + b
			Spr.circle(cx, iy, 22, Color(0, 0, 0, .35))
			Spr.ci.draw_texture_rect(Spr.tex.pad_S, Rect2(cx - 18, iy - 18, 36, 36), false, Color(1, 1, 1, .95))
			Spr.text("abaixe", cx, iy + 34, 13, Color(1, .93, .7, .9), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

# ---------------------------------------------------------------- pegadas
static func footprints(g: Game) -> void:
	for f in g.X.FOOT:
		var a: float = clamp(1.0 - f.t / 900.0, 0, 1) * .5
		var fc := Color(.45, .55, .72, a) if f.get("snow") else Color(.12, .08, .05, a)
		Spr.ellipse(f.x, f.y - (5 if f.get("snow") else 1), 5, 2, fc)
		Spr.ellipse(f.x + f.f * 5, f.y - (5.5 if f.get("snow") else 1.5), 2.2, 1.6, fc)

# ---------------------------------------------------------------- giz da Isis
static func _stroke(pts: PackedVector2Array, w: float = 3.0) -> void:
	# giz de verdade: vários riscos finos e falhados, com grão (falhas onde o giz não pegou na pedra)
	for pass_i in 3:
		var jx: float = (pass_i - 1) * w * .28
		var jy: float = (1 - pass_i) * w * .2 + (pass_i % 2) * .4
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n: int = max(1, int(a.distance_to(b) / 3.0))
			for k in n:
				var u0: float = k / float(n)
				var u1: float = (k + 1) / float(n)
				var pa := a.lerp(b, u0)
				var hv: float = h(pa.x * 3.1 + pa.y * 1.7 + pass_i * 13.0, 5)
				if hv < .14:
					continue
				var al: float = CHALK.a * (.45 + hv * .5) * (1.0 if pass_i == 1 else .55)
				Spr.ci.draw_line(pa + Vector2(jx, jy), a.lerp(b, u1) + Vector2(jx, jy), Color(CHALK.r, CHALK.g, CHALK.b, al), w * (.55 if pass_i == 1 else .35), true)
	# pozinho de giz embaixo do traço
	if pts.size() > 0:
		var q: Vector2 = pts[pts.size() / 2]
		Spr.circle(q.x + 2, q.y + 5, 1.2, Color(1, 1, 1, .18))

static func chalk(g: Game, T: int) -> void:
	for c in g.X.CHALK:
		if c.x < g.cam - 80 or c.x > g.cam + g.W + 80:
			continue
		var x: float = c.x
		var y: float = c.y
		match c.k:
			"seta":
				var d: int = int(c.get("d", 1))
				if d == 0:
					_stroke(PackedVector2Array([Vector2(x, y + 22), Vector2(x, y - 20)]))
					_stroke(PackedVector2Array([Vector2(x - 10, y - 8), Vector2(x, y - 21), Vector2(x + 10, y - 8)]))
				else:
					_stroke(PackedVector2Array([Vector2(x - 22 * d, y), Vector2(x + 20 * d, y + 1)]))
					_stroke(PackedVector2Array([Vector2(x + 8 * d, y - 10), Vector2(x + 21 * d, y + 1), Vector2(x + 8 * d, y + 11)]))
				if c.get("q"):
					Spr.text("?", x - 30 * d, y + 8, 20, CHALK, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
			"coracao":
				var pts := PackedVector2Array()
				for i in 25:
					var t := TAU * i / 24.0
					pts.push_back(Vector2(x + 16 * pow(sin(t), 3) * .7, y - (13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) * .7))
				_stroke(pts)
			"papai":
				Spr.text("PAPAI", x, y, 18, CHALK, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
				var pts2 := PackedVector2Array()
				for i in 13:
					var t2 := TAU * i / 12.0
					pts2.push_back(Vector2(x + 40 + 7 * pow(sin(t2), 3), y - 8 - (6 * cos(t2) - 2.5 * cos(2 * t2) - cos(3 * t2))))
				_stroke(pts2, 2.0)
			"sol":
				var o := PackedVector2Array()
				for i in 17:
					o.push_back(Vector2(x + cos(TAU * i / 16.0) * 10, y + sin(TAU * i / 16.0) * 10))
				_stroke(o)
				for i in 8:
					var a := TAU * i / 8.0
					_stroke(PackedVector2Array([Vector2(x + cos(a) * 14, y + sin(a) * 14), Vector2(x + cos(a) * 21, y + sin(a) * 21)]), 2.0)
			"estrela":
				var st := PackedVector2Array()
				for i in 11:
					var a2 := -PI / 2 + TAU * i / 10.0
					var rr := 18.0 if i % 2 == 0 else 8.0
					st.push_back(Vector2(x + cos(a2) * rr, y + sin(a2) * rr))
				_stroke(st)
			"flor":
				for i in 5:
					var a3 := TAU * i / 5.0
					var pe := PackedVector2Array()
					for j in 9:
						var b := TAU * j / 8.0
						pe.push_back(Vector2(x + cos(a3) * 9 + cos(b) * 5, y + sin(a3) * 9 + sin(b) * 5))
					_stroke(pe, 2.0)
				_stroke(PackedVector2Array([Vector2(x, y + 14), Vector2(x + 2, y + 34)]), 2.0)
			"x":
				if not g.X.broken.has("slab"):
					_stroke(PackedVector2Array([Vector2(x - 10, y - 7), Vector2(x + 10, y + 7)]), 3.5)
					_stroke(PackedVector2Array([Vector2(x + 10, y - 7), Vector2(x - 10, y + 7)]), 3.5)

# ---------------------------------------------------------------- peças com estado
static func solids(g: Game, T: int) -> void:
	for s in g.SOL:
		if s.x > g.cam + g.W + 100 or s.x + s.w < g.cam - 100:
			continue
		match s.t:
			"crack":
				_crack(s, T)
			"bars":
				# grade de ferro forjado, com pontas de lança, presa numa soleira de pedra
				Spr.PR("gate_iron", s.x - 6, s.y - 14, s.w + 12, s.h + 14)
				Spr.PR("wb3", s.x - 10, s.y + s.h - 8, s.w + 20, 14, Color(.85, .82, .78))
			"bossgate":
				WorldKings.gate(s, T)
			"bosslog":
				_log(s.x, s.y)
			"dogdoor":
				Spr.rr(s.x - 2, s.y, s.w + 4, s.h, 3, Color("#3a2414"))
				Spr.rr(s.x, s.y + 2, s.w, s.h - 3, 3, Color("#a8804a"))
				Spr.circle(s.x + s.w / 2, s.y + 15, 3, Color(.3, .2, .1))
				for k in 3:
					Spr.circle(s.x + s.w / 2 - 4 + k * 4, s.y + 9, 1.5, Color(.3, .2, .1))
			"hatchd":
				for i in 4:
					Spr.rect(s.x + 2 + i * 15, s.y, 12, 8, Color("#6b4a2a"))
				Spr.rect(s.x, s.y + 2, s.w, 3, Color("#4a3220"))
			"snowfill", "snowbank", "kinggate":
				WorldNature.solid(s, T)
	# plataformas de luz
	for gp in g.X.GHOST:
		var a: float = gp.a
		var c := Color(.75, .9, 1, .14 + a * .7)
		Spr.rr(gp.x, gp.y, gp.w, 14, 6, Color(.55, .75, 1, .06 + a * .5))
		Spr.ci.draw_rect(Rect2(gp.x, gp.y, gp.w, 14), c, false, 1.5)
		if a > .3:
			for k in 3:
				Spr.circle(gp.x + 10 + k * (gp.w - 20) / 2.0, gp.y + 7, 2, Color(1, 1, 1, a * .8))
	# espelhos
	for m in g.X.MIRRORS:
		var fl: float = m.flash / 14.0
		if m.get("ceil"):
			Spr.rect(m.x - 2, m.y - 30, 4, 18, Color(.35, .3, .25))
		else:
			Spr.rect(m.x - 10, m.y + 10, 20, 14, Color(.35, .3, .25))
		Spr.save()
		Spr.translate(m.x, m.y)
		Spr.rotate(-PI / 4 if int(m.s) == 0 else PI / 4)
		Spr.rr(-18, -5, 36, 10, 3, Color("#5a4a3a"))
		Spr.rect(-15, -3, 30, 6, Color(.75 + fl * .25, .88 + fl * .1, 1))
		Spr.rect(-13, -2, 10, 2, Color(1, 1, 1, .8))
		Spr.restore()
		if g.X.near_floor_mirror() == m:
			Spr.text("✦ GIRAR", m.x, m.y - 30 + sin(T * .15) * 3, 15, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	# cristais
	for c2 in g.X.CRYSTALS:
		var e: float = 1.0 if c2.on else c2.charge / 60.0
		var pts := PackedVector2Array([Vector2(c2.x, c2.y - 15), Vector2(c2.x + 10, c2.y - 2), Vector2(c2.x + 5, c2.y + 14), Vector2(c2.x - 5, c2.y + 14), Vector2(c2.x - 10, c2.y - 2)])
		Spr.poly(pts, Color(.35 + e * .5, .5 + e * .45, .8 + e * .2))
		Spr.ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(.15, .2, .35), 2, true)
		Spr.seg(c2.x - 3, c2.y - 9, c2.x - 6, c2.y + 4, Color(1, 1, 1, .6), 2)

static func _crack(s: Dictionary, T: int) -> void:
	var ink := Color(.12, .1, .09)
	if s.get("kind") == "slam":
		# chão de terra rachado (a mesma textura do chão), com fendas fundas e um brilho dourado
		var t: Texture2D = Spr.tex.chao
		Spr.ci.draw_texture_rect_region(t, Rect2(s.x - 2, s.y - 28, s.w + 4, 58), Rect2(10, 0, s.w + 4, 58), Color(.92, .88, .82))
		var cxs: float = s.x + s.w / 2
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(s.x + 4, s.y + 6), Vector2(cxs - 8, s.y + 12), Vector2(cxs, s.y + 4), Vector2(cxs + 9, s.y + 15), Vector2(s.x + s.w - 4, s.y + 8)]), ink, 2.6, true)
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(cxs, s.y + 4), Vector2(cxs + 2, s.y + 20)]), ink, 2, true)
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(cxs - 8, s.y + 12), Vector2(cxs - 14, s.y + 22)]), ink, 1.6, true)
		return
	if s.get("kind") == "slab":
		Spr.PR("slab2", s.x - 4, s.y - 3, s.w + 8, s.h + 6, Color(.92, .9, .86))
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(s.x + 8, s.y + 4), Vector2(s.x + 22, s.y + 12), Vector2(s.x + 30, s.y + 6), Vector2(s.x + 44, s.y + 16), Vector2(s.x + 54, s.y + 9)]), ink, 2, true)
		return
	# rocha pintada rachada, assentada no chão com musgo na base
	Spr.ellipse(s.x + s.w / 2, s.y + s.h + 2, s.w * .6, 6, Color(0, 0, 0, .28))
	Spr.PR("rock1", s.x - 8, s.y - 6, s.w + 16, s.h + 10)

static func _log(x: float, y: float) -> void:
	Spr.ellipse(x + 65, y + 32, 60, 5, Color(0, 0, 0, .25))
	Spr.PR("log", x - 4, y - 4, 138, 36, Color.WHITE, true)

# ---------------------------------------------------------------- Javali-Rei
static func boss(g: Game, T: int) -> void:
	var b: Dictionary = g.X.BOSS
	if b.is_empty() or b.done or b.st == "wait":
		return
	var fr := 0
	var shake_x := 0.0
	var bd: float = Spr.edist(b)
	match b.st:
		"idle":
			fr = 4
		"paw":
			fr = 4
			shake_x = sin(T * 1.3) * 2
		"charge", "flee":
			fr = 5 if int(bd / 16.0) % 2 == 0 else 3
		"stun", "down":
			fr = 6
		"trot":
			fr = int(bd / 16.0) % 4
		_:
			fr = 0
	if b.get("skin", "boar") == "dog":
		_brutus(b, T, bd)
		return
	var sc := 1.12
	Spr.ellipse(b.x, 502, 90, 12, Color(0, 0, 0, .3))
	Spr.save()
	Spr.translate(b.x + shake_x, b.y)
	if b.st in ["charge", "trot", "flee"]:
		# galope: o corpo sobe e desce com a passada e inclina para a frente na investida
		Spr.translate(0, -abs(sin(bd * PI / 32.0)) * (4.0 if b.st == "charge" else 2.5))
		Spr.rotate(b.dir * (.05 if b.st == "charge" else .02))
	if b.st == "down":
		# tomba de lado e some devagar
		Spr.rotate(-b.dir * min(1.0, b.t / 30.0) * 1.35)
	Spr.scale(1 if b.dir > 0 else -1, 1)
	var tint := Color(1, .45, .4, 1) if b.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1, 1)
	if b.st == "down":
		tint.a = clamp(1.0 - (b.t - 90) / 60.0, 0.0, 1.0)
	Spr.ci.draw_texture_rect_region(Spr.tex.javali, Rect2(-105 * sc, -136 * sc + 4, 210 * sc, 140 * sc), Rect2(fr * 210, 0, 210, 140), tint)
	# coroa de folhas (é o rei)
	var cx := 30.0
	var cy := -128.0 * sc + 10
	for i in 5:
		var a := -PI / 2 + (i - 2) * .38
		Spr.ellipse(cx + cos(a) * 16, cy + sin(a) * 10 + 4, 7, 4, Color("#4f8a2a"), a)
	Spr.circle(cx, cy + 6, 4, Color("#e0463a"))
	Spr.restore()
	if b.st == "stun":
		for i in 4:
			var a2 := T * .12 + TAU * i / 4.0
			Spr.text("★", b.x + cos(a2) * 34, b.y - 136 + sin(a2) * 10, 16, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	if b.st == "paw" and (T / 8) % 2 == 0:
		Spr.text("!", b.x + b.dir * 30, b.y - 150, 32, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)

## Brutus, o cão de guarda do Vargas (arte do Gemini: cao.png bem grande, com coleira de pregos)
static func _brutus(b: Dictionary, T: int, bd: float = 0.0) -> void:
	var fr := 4
	match b.st:
		"idle":
			fr = 4 if (T / 40) % 3 != 2 else 5
		"paw":
			fr = 5
		"charge":
			fr = int(bd / 14.0) % 4
		"trot":
			fr = int(bd / 15.0) % 4
		"stun":
			fr = 6
		"down":
			fr = 6
		"intro":
			fr = 7
	var tint := Color(1, .45, .4, 1) if b.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1, 1)
	var a: float = 1.0
	var dx: float = 0.0
	if b.st == "down":
		# foge correndo para fora do quintal
		dx = b.dir * -min(float(b.t) * 6.0, 900.0)
		fr = [0, 1, 2, 3][(T / 3) % 4]
		a = clamp(1.0 - (b.t - 90) / 60.0, 0.0, 1.0)
	var flip: bool = b.dir < 0 if b.st != "down" else b.dir > 0
	Spr.ellipse(b.x + dx, 502, 92, 12, Color(0, 0, 0, .3 * a))
	var gb: float = -abs(sin(bd * PI / 28.0)) * (4.0 if b.st == "charge" else 2.5) if b.st in ["charge", "trot"] else 0.0
	Spr.sheet("cao", fr, 200, 150, b.x + dx, b.y + 4 + gb, 210.0, flip, Color(tint.r, tint.g, tint.b, a))
	if b.st == "stun":
		for i in 4:
			var a2 := T * .12 + TAU * i / 4.0
			Spr.text("★", b.x + cos(a2) * 40, b.y - 150 + sin(a2) * 10, 18, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	if b.st == "paw" and (T / 8) % 2 == 0:
		Spr.text("AU!", b.x + b.dir * 60, b.y - 160, 26, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)

# ---------------------------------------------------------------- inimigos novos (desenhados por código)
static func _pc(n: String, cx: float, cy: float, w: float) -> void:
	## peça pintada centrada em (cx, cy)
	var hgt: float = Spr.PH(n, w)
	Spr.PR(n, cx - w / 2, cy - hgt / 2, w, hgt)

static func bat(e: Dictionary, T: int) -> void:
	if e.dead:
		_pc("bat2", 0, 0, 40)
		return
	if e.get("st", 0) == 0:
		# pendurado de cabeça para baixo, dormindo
		_pc("bat_hang", 0, 18, 24)
		return
	_pc("bat%d" % [0, 1, 2, 1][(T / 4) % 4], 0, 0, 50)

static func spider(e: Dictionary, T: int) -> void:
	if not e.dead:
		Spr.seg(0, e.top - e.y, 0, -8, Color(.92, .92, .92, .6), 1.2)
	var st: int = e.get("st", 0)
	if st in [1, 3] and not e.dead:
		# descendo ou subindo pelo fio: pendurada, balançando de leve
		Spr.save()
		Spr.rotate(sin(T * .08 + e.x) * .12)
		_pc("spider_hang", 0, 10, 30)
		Spr.restore()
	else:
		_pc("spider%d" % ((T / 7) % 3), 0, 6, 42)

static func mole(e: Dictionary, T: int) -> void:
	var st: int = e.get("st", 0)
	var dirt := Color("#6b4a2a")
	var fur := Color("#6e6070")
	var helm: bool = e.get("helm", false) and not e.get("helm_off", false)
	var nn := "toupeira_capacete" if helm else "toupeira"
	if not e.dead and Spr.novos.has(nn):
		var f := 0
		match st:
			1: f = 1 + (T / 6) % 2
			2: f = 4 if (e.t > 8 and e.t < 20) else 3
			3: f = 2
			5: f = 5
		Spr.novo(nn, f, 56 if st in [2, 5] else 40, e.dir < 0)
		if st == 5:
			for k in 3:
				var a := T * .15 + TAU * k / 3.0
				Spr.text("★", cos(a) * 18, -36 + sin(a) * 5, 11, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 2)
		return
	if e.dead:
		Spr.ellipse(0, -8, 16, 9, fur)
		return
	if st == 0 or st == 6:
		var sh: float = sin(T * 1.4) * 2.0 if st == 6 else 0.0
		Spr.ellipse(sh, 0, 22, 9, dirt)
		Spr.ellipse(-4 + sh, -3, 10, 4, Color("#8a6a42"))
		if helm:
			Spr.ci.draw_arc(Vector2(sh + 4, -6), 6, PI, TAU, 10, Color("#e8b030"), 3, true)
		if T % 10 < 5:
			Spr.circle(10, -4, 2, Color("#4a3220"))
		return
	if st == 5:
		# de barriga para cima, tonta
		Spr.ellipse(0, 2, 24, 6, dirt)
		Spr.ellipse(0, -10, 17, 11, fur)
		Spr.ellipse(0, -12, 10, 7, Color("#9a8ca0"))
		for k in 4:
			var lx := -10.0 + k * 7
			Spr.seg(lx, -18, lx + sin(T * .4 + k) * 2, -24, Color("#f2a0b0"), 2)
		Spr.circle(16, -8, 4, Color("#f2a0b0"))
		for k in 3:
			var a := T * .15 + TAU * k / 3.0
			Spr.text("★", cos(a) * 18, -30 + sin(a) * 5, 11, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 2)
		return
	var up: float = 1.0
	if st == 1:
		up = .25 + sin(T * 1.2) * .08
	elif st == 3:
		up = clamp(1.0 - e.t / 14.0, 0, 1)
	var yy: float = -30 * up
	Spr.ellipse(0, 2, 24, 8, dirt)
	if up > .1:
		Spr.ellipse(0, yy + 14, 15, 15 * up, fur)
		Spr.ellipse(0, yy + 18, 9, 9 * up, Color("#8e8090"))
		Spr.circle(10, yy + 9, 4, Color("#f2a0b0"))
		Spr.circle(-1, yy + 5, 1.8, Color.BLACK)
		Spr.circle(5, yy + 5, 1.8, Color.BLACK)
		var arm: float = -8.0 if (st == 2 and e.t > 8 and e.t < 18) else 0.0
		for k in 3:
			Spr.seg(-14 + k * 3, yy + 22 + arm, -16 + k * 3, yy + 27 + arm, Color("#f2a0b0"), 2)
			Spr.seg(10 + k * 3, yy + 22 + arm, 12 + k * 3, yy + 27 + arm, Color("#f2a0b0"), 2)
		if helm:
			Spr.ci.draw_arc(Vector2(2, yy + 4), 11, PI, TAU, 16, Color("#e8b030"), 5, true)
			Spr.circle(2, yy - 6, 3, Color("#fff4b0"))
		if st == 2 and e.t < 16:
			Spr.circle(e.dir * 14, yy + 2, 6, Color("#7a5a3a"))
	Spr.ellipse(0, 4, 26, 5, dirt)

# ---------------------------------------------------------------- Pipoca e as tocas
static func tocas(g: Game, T: int) -> void:
	var p: Dictionary = g.player
	for tc in g.X.TOCAS:
		if tc.x < g.cam - 100 or tc.x > g.cam + g.W + 100:
			continue
		Spr.ellipse(tc.x, tc.y - 10, 34, 18, Color("#6a5e52"))
		Spr.ellipse(tc.x - 10, tc.y - 18, 16, 9, Color("#857868"))
		Spr.ellipse(tc.x + 2, tc.y - 4, 14, 10, Color("#120c08"))
		for k in 3:
			Spr.circle(tc.x - 26 + k * 24, tc.y - 2, 5, Color("#4a3f36"))
		var near: bool = abs(p.x + p.w / 2 - tc.x) < 80 and abs(p.y + p.h - tc.y) < 50
		if not tc.done and near:
			var lbl := "✦ BUSCA, PIPOCA!" if g.X.dog_free() else "?"
			Spr.text(lbl, tc.x, tc.y - 46 + sin(T * .15) * 3, 15, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

static func dog(g: Game, T: int) -> void:
	var d: Dictionary = g.X.DOG
	if d.is_empty() or d.st == "in_toca":
		return
	var x: float = d.x
	var y: float = d.y + d.hy
	if d.st == "tied":
		# estaca e corda
		Spr.rect(d.x0 - 64, d.y - 34, 6, 36, Color("#5a3e24"))
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(d.x0 - 61, d.y - 24), Vector2((d.x0 - 61 + x) / 2, d.y - 12), Vector2(x - d.face * 6, d.y - 30)]), Color("#c9a26a"), 2.5, true)
	Spr.ellipse(x, d.y + 1, 20, 4, Color(0, 0, 0, .25))
	var fr := "dog0"
	if d.moving:
		fr = "dog%d" % (int(d.anim) % 4)
	var sc := .4
	var bob: float = 0.0 if d.moving else sin(T * .1) * .015
	if d.st == "sit":
		bob = -.06
	Spr.save()
	Spr.translate(x, y)
	var nf := 6 + (T / 20) % 2
	if d.moving:
		nf = int(d.anim) % 6
	if d.bark > 0:
		nf = 8 + (T / 6) % 2
	if d.st == "dig":
		nf = 10 + (T / 6) % 2
	if d.carry:
		nf = 12
	if d.st == "tied" and not d.moving:
		nf = 13
	# corpo vivo: inclina para a frente na corrida (suave), respira parado, vira girando
	var dvx: float = x - float(d.get("_lx", x))
	d._lx = x
	d._lean = lerp(float(d.get("_lean", 0.0)), clamp(dvx / 5.0, -1, 1) * .07, .15)
	var dfs: float = move_toward(float(d.get("_fs", d.face)), d.face, .2)
	d._fs = dfs
	var ns: float = sign(dfs) * max(abs(dfs), .2) if dfs != 0 else float(d.face)
	var breath: float = 0.0 if d.moving else sin(T * .09) * .018
	var gal: float = abs(sin(d.anim * PI / 3.0)) * 1.4 if d.moving else 0.0
	Spr.save()
	Spr.translate(0, -gal)
	Spr.rotate(d._lean)
	Spr.scale(abs(ns), 1.0 + breath)
	var drew: bool = Spr.novo("pipoca", nf, 54, ns < 0)
	Spr.restore()
	if not drew:
		if d.st == "dig":
			Spr.rotate(d.face * .25)
		# parado: de vez em quando fareja o chão ou coça a orelha
		var wag_k := .14
		if d.st == "sit":
			var ct: int = (int(d.t) + 140) % 520
			wag_k = .32
			if ct < 80:
				var u: float = sin(clamp(ct / 80.0, 0, 1) * PI)
				Spr.rotate(d.face * .16 * u)
				if ct % 12 == 0 and ct > 10 and ct < 70:
					g.PARTS.append({"x": x + d.face * 34, "y": y - 8, "vx": d.face * .4, "vy": -.3, "life": 14, "col": Color(.85, .8, .7, .7)})
			elif ct > 300 and ct < 360:
				Spr.rotate(-d.face * .08)
				Spr.translate(0, -abs(sin(T * .9)) * 2.0)
				wag_k = .05
		Spr.scale(sc if d.face > 0 else -sc, sc * (1.0 + bob))
		_dog_frame(fr, sin(T * (.45 if d.st == "sit" else .3)) * wag_k)
	Spr.restore()
	if d.carry:
		Spr.save()
		Spr.translate(x + d.face * 26, y - 30)
		Spr.rotate(.3 * d.face)
		Spr.A("drawing", 0, 0, .35)
		Spr.restore()
	_dog_guide(g, d, x, y, T)
	if d.bark > 0:
		var k: float = d.bark / 30.0
		Spr.text("AU!", x + d.face * 28, y - 58 - (1.0 - k) * 8, 16, Color(1, 1, 1, k), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	if d.st == "tied":
		var p: Dictionary = g.player
		if abs(p.x + p.w / 2 - d.x) < 70 and abs(p.y + p.h - d.y) < 50:
			Spr.text("✦ SOLTAR", x, y - 70 + sin(T * .15) * 3, 16, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

## o Pipoca guia: quando fareja algo escondido por perto (desenho da Isis, segredo, lápis dourado),
## para, aponta o focinho, mostra um "!" e late uma vez só
static var _barked := {}
static func _dog_guide(g: Game, d: Dictionary, x: float, y: float, T: int) -> void:
	if not d.st in ["follow", "sit"]:
		return
	var best = null
	var bd := 330.0
	var bkey := ""
	for dr in g.DRWS:
		if not dr.get("got", false):
			var dd: float = Vector2(dr.x - x, (dr.y - y) * .6).length()
			if dd < bd:
				bd = dd
				best = Vector2(dr.x, dr.y)
				bkey = "d%d_%d" % [int(dr.x), int(dr.y)]
	for sc in g.L.get("secrets", []):
		if g.X.found.has(sc.id):
			continue
		var cx: float = sc.x + sc.w / 2.0
		var dd2: float = abs(cx - x)
		if dd2 < bd and abs(sc.y - y) < 500:
			bd = dd2
			best = Vector2(cx, sc.y)
			bkey = "s" + str(sc.id)
	if not g.X.GOLD.is_empty() and not g.X.GOLD.got:
		var dd3: float = Vector2(g.X.GOLD.x - x, g.X.GOLD.y - y).length()
		if dd3 < bd:
			best = Vector2(g.X.GOLD.x, g.X.GOLD.y)
			bkey = "gold"
	if best == null:
		return
	if not _barked.has(bkey):
		_barked[bkey] = true
		Audio.play("bark", -10)
		d.bark = 30
	# focinho apontando e um "!" piscando sobre a cabeça
	var bv: Vector2 = best
	var dir: Vector2 = (bv - Vector2(x, y - 20)).normalized()
	var a: float = .6 + .4 * sin(T * .2)
	for k in 3:
		var q: Vector2 = Vector2(x, y - 22) + dir * (30 + k * 14 + fmod(T * .8, 14.0))
		Spr.circle(q.x, q.y, 2.6 - k * .6, Color(1, .95, .7, a * (1.0 - k * .28)))
	Spr.text("!", x, y - 70 + sin(T * .2) * 3, 24, Color(1, .9, .4, a), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4, Color(.3, .15, 0, .9))

## o Pipoca desenhado em dois pedaços: o corpo e o rabo (que abana girando na base)
static func _dog_frame(fr: String, wag: float) -> void:
	var r = Spr.AR.get(fr)
	if r == null:
		return
	var t: Texture2D = Spr.atlas_tex(r)
	var c := Color(1, 1, 1, Spr.alpha)
	var ax: float = r[4]
	var ay: float = r[5]
	const TX := 25.0     # o rabo fica à esquerda desta coluna...
	const TY := 74.0     # ...e acima desta linha (no quadro virado para a direita)
	# corpo: tudo à direita do rabo + a parte de baixo da coluna do rabo (a pata de trás)
	Spr.ci.draw_texture_rect_region(t, Rect2(-ax + TX, -ay, r[2] - TX, r[3]), Rect2(r[0] + TX, r[1], r[2] - TX, r[3]), c)
	Spr.ci.draw_texture_rect_region(t, Rect2(-ax, -ay + TY, TX, r[3] - TY), Rect2(r[0], r[1] + TY, TX, r[3] - TY), c)
	# rabo girando em volta da base (onde encosta no corpo)
	var piv := Vector2(-ax + TX, -ay + TY - 8)
	Spr.save()
	Spr.translate(piv.x, piv.y)
	Spr.rotate(wag)
	Spr.ci.draw_texture_rect_region(t, Rect2(-TX, -(TY - 8), TX + 1, TY), Rect2(r[0], r[1], TX + 1, TY), c)
	Spr.restore()

# ---------------------------------------------------------------- golpe, defesa e parede
static func tool_fx(g: Game, T: int) -> void:
	var p: Dictionary = g.player
	var cx: float = p.x + p.w / 2
	var f: float = p.face
	if p.get("act", "") == "swing" and p.actT > 0:
		# arco do golpe da picareta
		var k: float = 1.0 - (p.actT - 0.0) / 22.0
		if p.actT <= 17 and p.actT >= 6:
			var a0: float = -1.9
			var a1: float = lerpf(-1.6, 1.1, clamp((17 - p.actT) / 9.0, 0, 1))
			var pts := PackedVector2Array()
			var steps := 10
			for i in steps + 1:
				var a: float = lerpf(a0, a1, i / float(steps))
				pts.push_back(Vector2(cx + f * cos(a) * 42, p.y + 14 + sin(a) * 34))
			Spr.ci.draw_polyline(pts, Color(1, .95, .8, .55 * (1.0 - k * .6)), 7, true)
			Spr.ci.draw_polyline(pts, Color(1, 1, 1, .9 * (1.0 - k * .5)), 2.5, true)
			var tip: Vector2 = pts[pts.size() - 1]
			if Rig.ready("tome"):
				return
			Spr.save()
			Spr.translate(tip.x, tip.y)
			Spr.rotate(a1 * f + (0.0 if f > 0 else PI))
			Spr.A("it_picareta", 0, 0, .3, f < 0)
			Spr.restore()
	if p.get("guard", false):
		var lx: float = cx + f * 18
		var ly: float = p.y + 12
		Spr.glow(lx, ly, 46 + sin(T * .4) * 3, Color(1, .9, .55, .45))
		Spr.ci.draw_arc(Vector2(lx, ly), 28, -1.1 if f > 0 else PI - 1.1, 1.1 if f > 0 else PI + 1.1, 18, Color(1, .95, .7, .75), 3, true)
	if p.get("wslide", false):
		Spr.rect(cx + f * (p.w / 2) - 1, p.y + 4, 3, p.h - 6, Color(1, 1, 1, .12))

# ---------------------------------------------------------------- placas, portões, caixas e tábuas que caem
static func mech(g: Game, T: int) -> void:
	var M: Mech = g.M
	if M == null:
		return
	var c0: float = g.cam - 150
	var c1: float = g.cam + g.W + 150
	for pl in M.PLATES:
		if pl.x + pl.w < c0 or pl.x > c1:
			continue
		var dd: float = pl.d * 4
		# placa de pedra entalhada, afundando quando tem peso; a moldura de pedra fica fixa
		Spr.rr(pl.x - 6, pl.y - 3, pl.w + 12, 11, 5, Color(.16, .13, .1))
		Spr.PR("plate", pl.x - 2, pl.y - 11 + dd, pl.w + 4, 15, Color(1, 1, 1) if not pl.on else Color(1.25, 1.1, .7))
		if pl.on:
			Spr.glow(pl.x + pl.w / 2, pl.y - 4, 30, Color(1, .85, .4, .35))
	for gt in M.GATES:
		if gt.x + gt.w < c0 or gt.x > c1:
			continue
		var lift: float = gt.open * (gt.h - 18)
		var y0: float = gt.y - lift
		var hh: float = gt.h
		# batentes de madeira dos lados e o portão de tábuas com ferragens subindo entre eles
		# (portões altos: vão até bem acima da tela, em gomos do tamanho normal, sem esticar a pintura)
		# portões baixos (porta de manivela): um gomo só, do tamanho do vão
		var seg: float = min(260.0, hh)
		var nseg: int = int(ceil(hh / seg))
		var bot: float = gt.y + gt.h
		for k in nseg:
			var sy: float = bot - (k + 1) * seg
			if sy + seg < g.cam_y - 100 or sy > g.cam_y + g.H + 100:
				continue
			Spr.PR("stake", gt.x - 13, sy - 14, 12, seg + 22, Color(.8, .76, .72))
			Spr.PR("stake", gt.x + gt.w + 1, sy - 14, 12, seg + 22, Color(.8, .76, .72), true)
		for k in nseg:
			var py: float = y0 + hh - (k + 1) * seg
			if py + seg < g.cam_y - 100 or py > g.cam_y + g.H + 100:
				continue
			Spr.PR("gate_wood", gt.x - 6, py - 4, gt.w + 12, seg + 4)
		if gt.get("dogpass"):
			# portinhola para o cachorro, embaixo
			var fy: float = gt.y + gt.h - 24
			if gt.open < .3:
				Spr.rr(gt.x - 3, fy, gt.w + 6, 24, 4, Color("#3a2414"))
				Spr.rr(gt.x - 1, fy + 3, gt.w + 2, 19, 3, Color("#a8804a"))
				var px: float = gt.x + gt.w / 2
				Spr.circle(px, fy + 15, 3.2, Color(.3, .2, .1))
				for k in 3:
					Spr.circle(px - 4 + k * 4, fy + 9, 1.6, Color(.3, .2, .1))
	for c in M.PUSH:
		if c.dead or c.x + c.w < c0 or c.x > c1:
			continue
		if c.get("snow"):
			WorldNature.snowball(c, T)
			continue
		Spr.ellipse(c.x + c.w / 2, c.y + c.h + 1, c.w * .55, 4, Color(0, 0, 0, .25))
		Spr.PR("crate", c.x - 2, c.y - 2, c.w + 4, c.h + 4)
		if g.player.get("pushT", 0) > 0 and Game.hit(g.R(g.player.x - 6, g.player.y, g.player.w + 12, g.player.h), c):
			Spr.text("⇆", c.x + c.w / 2, c.y - 10, 16, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	for s in M.CRUMB:
		if s.x + s.w < c0 or s.x > c1:
			continue
		var shake: float = (sin(T * 1.7) * 2.0) if (s.ct > 0 and not s.fallen) else 0.0
		var yy: float = s.y + s.fy
		if s.fallen and s.fy > 400:
			continue
		var a: float = 1.0 if not s.fallen else clamp(1.0 - s.fy / 400.0, 0, 1)
		var wood := Color(.42, .29, .17, a) if not s.get("icy") else Color(.72, .86, 1, a * .9)
		if s.get("trestle") and not s.fallen:
			for lx in [s.x + 8, s.x + s.w - 16]:
				Spr.rect(lx, s.y + 10, 8, 700 - s.y, Color("#4a3220"))
		if s.get("tile") and not s.get("roofhole"):
			# sarrafos finos esticados entre os telhados (as telhas ficam soltas em cima deles)
			Spr.seg(s.x - 4, s.y + 12, s.x + s.w + 4, s.y + 12, Color("#3a2414"), 3)
			Spr.seg(s.x - 4, s.y + 12, s.x + s.w + 4, s.y + 12, Color("#8a6a42"), 1.2)
		if s.fallen and s.get("roofhole"):
			# buraco no telhado: dá para ver os caibros e o escuro lá dentro
			Spr.rect(s.x, s.y - 4, s.w, 22, Color("#120a06"))
			for kx in [s.x + 6, s.x + s.w - 12]:
				Spr.rect(kx, s.y - 4, 6, 22, Color("#5a3a1e"))
		if s.fallen:
			# quebrou: três pedaços caindo e girando cada um para um lado
			for i in 3:
				var pw: float = s.w / 3.0
				var px0: float = s.x + i * pw + (i - 1) * s.fy * .18
				var py0: float = yy + s.fy * i * .12
				Spr.save()
				Spr.translate(px0 + pw / 2, py0 + 8)
				Spr.rotate((i - 1) * s.fy * .012 + (s.fy * .004 if i == 1 else 0.0))
				if s.get("tile"):
					Spr.rr(-pw / 2, -7, pw, 14, 4, Color(.7, .32, .18, a))
				else:
					Spr.PRs("seesaw_plank", -pw / 2, -9, pw, 18, i / 3.0, (i + 1) / 3.0, Color(.85, .8, .75, a) if not s.get("icy") else Color(.8, .92, 1.1, a))
				Spr.restore()
			continue
		if s.get("tile") and s.get("roofhole"):
			# telhas soltas no meio do telhado: tortas, com frestas escuras entre elas
			Spr.rect(s.x, yy - 2, s.w, 14, Color(.07, .04, .03, .9))
			var k2 := 0
			var tx2: float = s.x + 2
			while tx2 < s.x + s.w - 4:
				Spr.save()
				Spr.translate(tx2 + 9 + shake, yy + 3 + (k2 % 2) * 2.0)
				Spr.rotate((.16 if k2 % 2 == 0 else -.12) + (sin(T * 1.9 + k2) * .08 if s.ct > 0 else 0.0))
				Spr.rr(-10, -6, 20, 12, 3, Color("#c0603a"))
				Spr.rr(-10, -6, 20, 4, 2, Color("#e08058"))
				Spr.restore()
				tx2 += 22
				k2 += 1
			Spr.text("!", s.x + s.w / 2, yy - 16 + sin(T * .12) * 2, 14, Color(1, .8, .4, .85), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
			if s.ct > 0 and T % 4 == 0:
				g.PARTS.append({"x": s.x + randf() * s.w, "y": yy + 10, "vx": randf_range(-.5, .5), "vy": .6, "life": 18, "col": Color(.75, .35, .2, .9)})
			continue
		if s.get("tile"):
			# telhas soltas na beira do telhado: tremem e despencam logo depois de pisar
			var tc := Color("#b4502e")
			var tw: float = 24.0
			var tx: float = s.x
			var k := 0
			while tx < s.x + s.w - 2:
				var jy: float = (sin(T * 1.9 + k) * 1.5 if s.ct > 0 else 0.0) + (k % 2) * 1.5
				Spr.rr(tx + shake, yy - 4 + jy, min(tw + 2, s.x + s.w - tx), 14, 4, tc)
				Spr.rr(tx + shake, yy - 4 + jy, min(tw + 2, s.x + s.w - tx), 5, 3, Color("#d8704a"))
				Spr.seg(tx + tw * .6 + shake, yy + jy, tx + tw * .4 + shake, yy + 9 + jy, Color(0, 0, 0, .35), 1.2)
				tx += tw
				k += 1
			Spr.rr(s.x - 2 + shake, yy - 6, s.w + 4, 18, 7, Color(1, .7, .4, (.1 + .08 * sin(T * .1 + s.x)) * a))
			if s.ct > 0 and T % 4 == 0:
				g.PARTS.append({"x": s.x + randf() * s.w, "y": yy + 10, "vx": randf_range(-.5, .5), "vy": .6, "life": 18, "col": Color(.75, .35, .2, .9)})
			continue
		# tábua podre: rachaduras à mostra e um contorno pálido pulsando (dá para ver que é perigosa)
		var pulse: float = .18 + .12 * sin(T * .08 + s.x)
		Spr.rr(s.x - 2 + shake, yy - 2, s.w + 4, 20, 8, Color(1, .85, .55, pulse * a))
		Spr.PR("seesaw_plank", s.x + shake - 2, yy - 1, s.w + 4, 19, Color(.85, .8, .75, a) if not s.get("icy") else Color(.8, .92, 1.1, a))
		Spr.seg(s.x + 12 + shake, yy + 4, s.x + 30 + shake, yy + 12, Color(0, 0, 0, .45 * a), 1.5)
		Spr.seg(s.x + s.w - 20 + shake, yy + 3, s.x + s.w - 34 + shake, yy + 13, Color(0, 0, 0, .45 * a), 1.5)
		Spr.seg(s.x + s.w * .5 + shake, yy + 2, s.x + s.w * .45 + shake, yy + 14, Color(0, 0, 0, .35 * a), 1.2)
		if s.ct > 0 and T % 3 == 0:
			# serragem caindo antes de quebrar
			g.PARTS.append({"x": s.x + randf() * s.w, "y": yy + 15, "vx": randf_range(-.4, .4), "vy": .5, "life": 22,
				"col": Color(.85, .7, .45, .9) if not s.get("icy") else Color(.9, .97, 1, .9)})
