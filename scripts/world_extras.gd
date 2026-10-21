extends RefCounted
class_name WorldExtras
## Desenho dos sistemas novos que ficam no mundo (escurecem com a noite):
## capim que balança, pegadas, giz da Isis, rochas rachadas, grades, espelhos, cristais,
## plataformas de luz, troncos e o Javali-Rei, e os inimigos novos (morcego, aranha, toupeira).

const CHALK := Color(.96, .95, .9, .82)

static func h(x: float, k: int = 0) -> float:
	## ruído fixo 0..1 a partir de x
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

# ---------------------------------------------------------------- capim
static func grass(g: Game, T: int) -> void:
	var x0: float = g.cam - 40
	var x1: float = g.cam + g.W + 40
	var p: Dictionary = g.player
	var pcx: float = p.x + p.w / 2
	var song: String = g.AMB.get("song", "manha")
	var col := Color(.34, .58, .2)
	if song == "tarde":
		col = Color(.5, .55, .2)
	elif song == "chuva":
		col = Color(.25, .45, .3)
	elif song in ["noite", "perseguicao", "tunel"]:
		col = Color(.2, .38, .26)
	var wind: float = g.AMB.get("wind", 0.0)
	for s in g.SOL:
		if s.t != "ground" or s.x > x1 or s.x + s.w < x0:
			continue
		var xa: float = max(s.x + 6, floor(x0 / 30.0) * 30.0)
		var xb: float = min(s.x + s.w - 6, x1)
		var x: float = xa
		while x < xb:
			var r := h(x)
			if r > .35:
				var by: float = s.y - 3
				var near: float = clamp(1.0 - abs(x - pcx) / 34.0, 0, 1) if abs(p.y + p.h - s.y) < 40 else 0.0
				var push: float = sign(x - pcx) * near * 9.0
				var sway: float = sin(T * (.03 + wind * .05) + x * .03) * (1.5 + wind * 5.0) + wind * 4.0
				for k in 4:
					var bx: float = x + k * 3.2 - 5
					var hh: float = 8 + h(bx, 2) * 9
					var lean: float = sway + push + (k - 1.5) * 1.6
					Spr.ci.draw_polyline(PackedVector2Array([Vector2(bx, by), Vector2(bx + lean * .45, by - hh * .55), Vector2(bx + lean, by - hh)]),
						Color(col.r * (.85 + k * .06), col.g * (.85 + k * .06), col.b, .95), 1.6, true)
			x += 30

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
		Spr.ellipse(f.x, f.y - 1, 5, 2, Color(.12, .08, .05, a))
		Spr.ellipse(f.x + f.f * 5, f.y - 1.5, 2.2, 1.6, Color(.12, .08, .05, a))

# ---------------------------------------------------------------- giz da Isis
static func _stroke(pts: PackedVector2Array, w: float = 3.0) -> void:
	Spr.ci.draw_polyline(pts, CHALK, w, true)
	var o := PackedVector2Array()
	for q in pts:
		o.push_back(q + Vector2(.8, .9))
	Spr.ci.draw_polyline(o, Color(1, 1, 1, .25), 1.2, true)

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
				for i in 4:
					Spr.rect(s.x + 2 + i * 5, s.y, 3, s.h, Color(.42, .44, .5))
				Spr.rect(s.x - 2, s.y, s.w + 4, 8, Color(.3, .3, .35))
				Spr.rect(s.x - 2, s.y + s.h * .5, s.w + 4, 6, Color(.3, .3, .35))
			"bossgate":
				for i in 5:
					var yy: float = s.y + s.h - 26 - i * 42
					Spr.rr(s.x - 30 + (i % 2) * 10, yy, 84, 30, 14, Color("#6b4a2a"))
					Spr.circle(s.x - 18 + (i % 2) * 10, yy + 15, 11, Color("#c9a26a"))
					Spr.ring(s.x - 18 + (i % 2) * 10, yy + 15, 11, Color("#3a2414"), 2)
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
	if s.get("kind") == "slab":
		Spr.rect(s.x, s.y, s.w, s.h, Color(.48, .45, .42))
		Spr.rect(s.x, s.y, s.w, 3, Color(.62, .6, .56))
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(s.x + 8, s.y + 4), Vector2(s.x + 22, s.y + 12), Vector2(s.x + 30, s.y + 6), Vector2(s.x + 44, s.y + 16), Vector2(s.x + 54, s.y + 9)]), ink, 2, true)
		return
	var cx: float = s.x + s.w / 2
	var cy: float = s.y + s.h / 2
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		var r: float = s.w * .5 * (.88 + WorldExtras.h(s.x + i, 3) * .18)
		pts.push_back(Vector2(cx + cos(a) * r, cy + sin(a) * s.h * .52 * (.9 + WorldExtras.h(s.x - i, 4) * .14)))
	Spr.poly(pts, Color(.5, .46, .43))
	Spr.ci.draw_polyline(pts + PackedVector2Array([pts[0]]), ink, 2.5, true)
	Spr.ellipse(cx - s.w * .14, cy - s.h * .2, s.w * .2, s.h * .12, Color(1, 1, 1, .18))
	Spr.ci.draw_polyline(PackedVector2Array([Vector2(cx - 4, s.y + 4), Vector2(cx + 4, cy - 6), Vector2(cx - 6, cy + 4), Vector2(cx + 3, s.y + s.h - 6)]), ink, 2.2, true)
	Spr.ci.draw_polyline(PackedVector2Array([Vector2(cx + 4, cy - 6), Vector2(cx + 16, cy - 2)]), ink, 1.6, true)

static func _log(x: float, y: float) -> void:
	Spr.rr(x, y, 130, 28, 13, Color("#6b4a2a"))
	Spr.rect(x + 10, y + 5, 110, 3, Color(1, 1, 1, .1))
	Spr.ellipse(x + 118, y + 14, 12, 13, Color("#c9a26a"))
	Spr.ring(x + 118, y + 14, 12, Color("#3a2414"), 2)
	Spr.ring(x + 118, y + 14, 6, Color(.35, .24, .12, .6), 1.5)

# ---------------------------------------------------------------- Javali-Rei
static func boss(g: Game, T: int) -> void:
	var b: Dictionary = g.X.BOSS
	if b.is_empty() or b.done or b.st == "wait":
		return
	var fr := 0
	var shake_x := 0.0
	match b.st:
		"idle":
			fr = 4
		"paw":
			fr = 4
			shake_x = sin(T * 1.3) * 2
		"charge", "flee":
			fr = 5 if (T / 4) % 2 == 0 else 3
		"stun", "down":
			fr = 6
		"trot":
			fr = [0, 1, 2, 3][(T / 6) % 4]
		_:
			fr = 0
	var sc := 1.12
	Spr.ellipse(b.x, 502, 90, 12, Color(0, 0, 0, .3))
	Spr.save()
	Spr.translate(b.x + shake_x, b.y)
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

# ---------------------------------------------------------------- inimigos novos (desenhados por código)
static func bat(e: Dictionary, T: int) -> void:
	if not e.dead and e.get("st", 0) == 0 and Spr.novos.has("morcego"):
		Spr.save()
		Spr.translate(0, 40)
		Spr.novo("morcego", 0, 40, false)
		Spr.restore()
		return
	if not e.dead and Spr.novos.has("morcego"):
		Spr.save()
		Spr.translate(0, 18)
		Spr.novo("morcego", 1 + (T / 4) % 4, 44, false)
		Spr.restore()
		return
	var body := Color("#3b2b44")
	var wing := Color("#55406a")
	if e.dead:
		Spr.ellipse(0, 0, 12, 10, body)
		return
	if e.get("st", 0) == 0:
		# pendurado, de cabeça para baixo, enrolado nas asas
		Spr.seg(-4, -2, -4, 4, Color(.2, .15, .1), 2)
		Spr.seg(4, -2, 4, 4, Color(.2, .15, .1), 2)
		Spr.ellipse(0, 14, 11, 13, wing)
		Spr.ellipse(0, 26, 8, 6, body)
		Spr.poly(PackedVector2Array([Vector2(-7, 30), Vector2(-4, 38), Vector2(-1, 30)]), body)
		Spr.poly(PackedVector2Array([Vector2(1, 30), Vector2(4, 38), Vector2(7, 30)]), body)
		Spr.seg(-3, 24, -1, 24, Color(1, .9, .4, .8), 1.5)
		Spr.seg(1, 24, 3, 24, Color(1, .9, .4, .8), 1.5)
		return
	var f: float = sin(T * .55 + e.x)
	for sd in [-1, 1]:
		var tip := Vector2(sd * 30, -6 - f * 14)
		var pts := PackedVector2Array([Vector2(sd * 5, -3), Vector2(sd * 16, -12 - f * 8), tip, Vector2(sd * 22, 3 - f * 4), Vector2(sd * 15, 1), Vector2(sd * 9, 6)])
		Spr.poly(pts, wing)
		Spr.ci.draw_polyline(pts, Color(.15, .1, .2), 1.5, true)
	Spr.ellipse(0, 1, 9, 10, body)
	Spr.poly(PackedVector2Array([Vector2(-7, -6), Vector2(-5, -16), Vector2(-1, -8)]), body)
	Spr.poly(PackedVector2Array([Vector2(1, -8), Vector2(5, -16), Vector2(7, -6)]), body)
	Spr.circle(-3, -2, 2.2, Color(1, .88, .35))
	Spr.circle(3.5, -2, 2.2, Color(1, .88, .35))
	Spr.poly(PackedVector2Array([Vector2(-2, 4), Vector2(0, 7), Vector2(2, 4)]), Color(1, 1, 1))

static func spider(e: Dictionary, T: int) -> void:
	if Spr.novos.has("aranha"):
		if not e.dead:
			Spr.seg(0, e.top - e.y, 0, -8, Color(.9, .9, .9, .55), 1.2)
		Spr.save()
		Spr.translate(0, 16)
		Spr.novo("aranha", (T / 8) % 4 if e.get("st", 0) in [1, 3] else (T / 20) % 2, 36, false)
		Spr.restore()
		return
	var body := Color("#2a2233")
	if not e.dead:
		Spr.seg(0, e.top - e.y, 0, -8, Color(.9, .9, .9, .55), 1.2)
	var lw: float = sin(T * .3) * 3 if e.get("st", 0) in [1, 3] else 0.0
	for sd in [-1, 1]:
		for k in 4:
			var ay: float = -4 + k * 3.5
			var kx: float = sd * (12 + k * 1.5)
			var ky: float = ay - 9 + k * 2 + lw * (1 if k % 2 == 0 else -1)
			Spr.ci.draw_polyline(PackedVector2Array([Vector2(sd * 4, ay), Vector2(kx, ky), Vector2(sd * (17 + k * 2), ay + 9)]), body, 2, true)
	Spr.ellipse(0, 7, 11, 10, body)
	Spr.ellipse(0, -4, 7, 6, Color("#3a3045"))
	Spr.ellipse(-3, 5, 3, 2, Color(.6, .25, .7, .8))
	Spr.circle(-2.5, -5, 2, Color.WHITE)
	Spr.circle(2.5, -5, 2, Color.WHITE)
	Spr.circle(-2.5, -5, 1, Color.BLACK)
	Spr.circle(2.5, -5, 1, Color.BLACK)

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
	if not Spr.novo("pipoca", nf, 54, d.face < 0):
		if d.st == "dig":
			Spr.rotate(d.face * .25)
		Spr.scale(sc if d.face > 0 else -sc, sc * (1.0 + bob))
		Spr.A(fr, 0, 0, 1.0)
	Spr.restore()
	if d.carry:
		Spr.save()
		Spr.translate(x + d.face * 26, y - 30)
		Spr.rotate(.3 * d.face)
		Spr.A("drawing", 0, 0, .35)
		Spr.restore()
	if d.bark > 0:
		var k: float = d.bark / 30.0
		Spr.text("AU!", x + d.face * 28, y - 58 - (1.0 - k) * 8, 16, Color(1, 1, 1, k), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	if d.st == "tied":
		var p: Dictionary = g.player
		if abs(p.x + p.w / 2 - d.x) < 70 and abs(p.y + p.h - d.y) < 50:
			Spr.text("✦ SOLTAR", x, y - 70 + sin(T * .15) * 3, 16, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

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
	for pl in M.PLATES:
		var dd: float = pl.d * 4
		Spr.rr(pl.x - 4, pl.y - 2, pl.w + 8, 10, 4, Color(.25, .22, .2))
		Spr.rr(pl.x, pl.y - 8 + dd, pl.w, 10, 3, Color(.62, .58, .5) if not pl.on else Color(.95, .82, .45))
		Spr.rect(pl.x + 6, pl.y - 7 + dd, pl.w - 12, 2, Color(1, 1, 1, .25))
		if pl.on:
			Spr.glow(pl.x + pl.w / 2, pl.y - 4, 30, Color(1, .85, .4, .35))
	for gt in M.GATES:
		var lift: float = gt.open * (gt.h - 18)
		var y0: float = gt.y - lift
		var hh: float = gt.h
		Spr.rect(gt.x - 8, gt.y - 10, 6, gt.h + 10, Color("#4a3220"))
		Spr.rect(gt.x + gt.w + 2, gt.y - 10, 6, gt.h + 10, Color("#4a3220"))
		var by: float = max(y0, gt.y - 6)
		Spr.save()
		var col := Color("#9a7040")
		var ink := Color("#3a2414")
		var x: float = gt.x - 8
		while x < gt.x + gt.w + 8:
			Spr.rect(x - 1, y0, 9, hh + 1, ink)
			Spr.rect(x, y0, 7, hh, col)
			Spr.rect(x + 1, y0, 2, hh, Color(1, 1, 1, .12))
			Spr.poly(PackedVector2Array([Vector2(x - 1, y0), Vector2(x + 3.5, y0 - 10), Vector2(x + 8, y0)]), col)
			x += 9
		for yy in [y0 + 16, y0 + hh * .5, y0 + hh - 30]:
			Spr.rect(gt.x - 12, yy, gt.w + 24, 9, ink)
			Spr.rect(gt.x - 11, yy + 1, gt.w + 22, 7, Color("#6b4a2a"))
		Spr.restore()
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
		if c.dead:
			continue
		if c.get("snow"):
			WorldNature.snowball(c, T)
			continue
		Spr.rr(c.x, c.y, c.w, c.h, 5, Color("#8a6238"))
		Spr.rect(c.x + 5, c.y + 5, c.w - 10, c.h - 10, Color("#a57a48"))
		Spr.seg(c.x + 6, c.y + 6, c.x + c.w - 6, c.y + c.h - 6, Color("#6b4a2a"), 5)
		Spr.seg(c.x + c.w - 6, c.y + 6, c.x + 6, c.y + c.h - 6, Color("#6b4a2a"), 5)
		Spr.ci.draw_rect(Rect2(c.x, c.y, c.w, c.h), Color("#3a2414"), false, 3)
		if g.player.get("pushT", 0) > 0 and Game.hit(g.R(g.player.x - 6, g.player.y, g.player.w + 12, g.player.h), c):
			Spr.text("⇆", c.x + c.w / 2, c.y - 10, 16, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	for s in M.CRUMB:
		var shake: float = (sin(T * 1.7) * 2.0) if (s.ct > 0 and not s.fallen) else 0.0
		var yy: float = s.y + s.fy
		if s.fallen and s.fy > 400:
			continue
		var a: float = 1.0 if not s.fallen else clamp(1.0 - s.fy / 400.0, 0, 1)
		var wood := Color(.42, .29, .17, a) if not s.get("icy") else Color(.72, .86, 1, a * .9)
		if s.get("trestle") and not s.fallen:
			for lx in [s.x + 8, s.x + s.w - 16]:
				Spr.rect(lx, s.y + 10, 8, 700 - s.y, Color("#4a3220"))
		Spr.rr(s.x + shake, yy, s.w, 16, 6, wood)
		Spr.seg(s.x + 12 + shake, yy + 4, s.x + 30 + shake, yy + 12, Color(0, 0, 0, .45 * a), 1.5)
		Spr.seg(s.x + s.w - 20 + shake, yy + 3, s.x + s.w - 34 + shake, yy + 13, Color(0, 0, 0, .45 * a), 1.5)
