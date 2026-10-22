extends RefCounted
class_name WorldVehicles
## Desenho da corredeira (rio, quedas-d'água, jangada e obstáculos) e do biplano (pista, voo, pássaros,
## gaviões e nuvens de tempestade). Tudo por código, menos o avião (sprite pintado).

const OUT := Color("#2a1a0e")
static var dog_on_board := false

static func draw(g: Game, T: int) -> void:
	var VH: Vehicles = g.VH
	if VH == null:
		return
	if not VH.RA.is_empty():
		_river(g, VH, T)
	if not VH.PL.is_empty():
		_runway(g, VH, T)

## o veículo com o Tomé (no lugar do desenho normal do Tomé)
static func rider(g: Game, T: int) -> void:
	var VH: Vehicles = g.VH
	var p: Dictionary = g.player
	if p.iframe > 0 and (T / 4) % 2 == 0:
		Spr.alpha = .55
	if VH.mode == "raft":
		var bob: float = sin(T * .15) * 1.5 if VH.hy >= VH.water_y(VH.hx) - 1 else 0.0
		var rot: float = clamp(VH.vy * .02, -.15, .15)
		if VH.stumble > 0:
			rot += sin(T * .8) * .1
		Spr.save()
		Spr.translate(VH.hx, VH.hy + bob)
		Spr.rotate(rot)
		# o Tomé de pé com o remo (abaixado sob os galhos)
		if VH.duck:
			Spr.A("pai_crouch", 0, -6, .56)
		else:
			Spr.frame(Spr.tex.pai, 0, 170, 160, 85, 156, 0, -6, .46, false)
			var pa: float = sin(T * .12) * .5
			Spr.seg(-4 + cos(pa) * 18, -40 + sin(pa) * 6, -4 - cos(pa) * 26, -4 - sin(pa) * 4, Color("#7a5232"), 4)
			Spr.ellipse(-4 - cos(pa) * 28, -2 - sin(pa) * 4, 6, 10, Color("#8a5e34"), pa)
		if g.X.DOG.get("st", "") == "ride":
			Spr.save()
			Spr.translate(-22, -6)
			if not Spr.novo("pipoca", 6, 28):
				Spr.scale(.28, .28)
				Spr.A("dog0", 0, 0, 1)
			Spr.restore()
		_raft(0, 0)
		Spr.restore()
	elif VH.mode == "plane":
		dog_on_board = g.X.DOG.get("st", "") == "ride"
		_plane_fly(VH.hx, VH.hy, VH.tilt, T, VH.phase == "taxi" or VH.phase == "land")
	Spr.alpha = 1.0

static func _raft(x: float, y: float) -> void:
	for k in 5:
		var lx: float = x - 36 + k * 15
		Spr.rr(lx, y - 8, 14, 14, 6, Color("#7a5232").lightened(k % 2 * .08))
		Spr.ring(lx + 7, y - 1, 3, Color("#4e331d"), 1.5)
	Spr.rect(x - 38, y - 8, 76, 4, Color("#a07040"))
	for k in 2:
		Spr.rect(x - 24 + k * 44, y - 9, 5, 15, Color("#c9a26a"))

# ---------- rio ----------
static func _river(g: Game, VH: Vehicles, T: int) -> void:
	var RA: Dictionary = VH.RA
	var a: float = max(float(RA.x0), g.cam - 60)
	var b: float = min(float(RA.x1), g.cam + g.W + 60)
	if a < b:
		var bot: float = float(g.L.bottom) + 200
		# a água (em degraus, um por queda)
		var xs: Array = [float(RA.x0)]
		for f in RA.get("falls", []):
			xs.append(float(f))
		xs.append(float(RA.x1))
		for i in xs.size() - 1:
			var sa: float = max(a, xs[i])
			var sb: float = min(b, xs[i + 1])
			if sa >= sb:
				continue
			var wl: float = VH.water_y(xs[i] + 1)
			var wb: Dictionary = g.WV.body("r%d" % i, xs[i], xs[i + 1], wl)
			# superfície com ondas (molas) + correnteza
			var top := PackedVector2Array()
			var xx: float = floor(sa / 8.0) * 8.0
			while xx <= sb + 8.1:
				var cx: float = clamp(xx, sa, sb)
				top.push_back(Vector2(cx, wl - 3 + g.WV.height(wb, cx) + sin(cx * .06 - T * .2) * 2.2 + sin(cx * .023 - T * .09) * 2.0 + sin(cx * .15 + T * .17) * .8))
				xx += 8
			var band := top.duplicate()
			band.push_back(Vector2(sb, wl + 10))
			band.push_back(Vector2(sa, wl + 10))
			Spr.poly(band, Color("#4f8fb0"))
			Spr.vgrad(sa, wl + 10, sb - sa, 56, Color("#4f8fb0"), Color("#1d4a66"))
			Spr.rect(sa, wl + 66, sb - sa, bot - wl, Color("#10283a"))
			# espuma e correnteza
			for k in int((sb - sa) / 46) + 1:
				var fx: float = sa + fposmod(k * 46.0 - T * 5.0, sb - sa + 1)
				Spr.seg(fx, wl + 6 + (k % 3) * 9, fx + 22, wl + 6 + (k % 3) * 9, Color(.85, .95, 1, .45), 2)
			Spr.line(top, Color(.9, .97, 1, .75), 3)
		# quedas-d'água
		for f in RA.get("falls", []):
			if f < a - 80 or f > b + 80:
				continue
			var top: float = VH.water_y(f - 1)
			Spr.vgrad(f - 6, top - 6, 18, 56, Color(.95, .98, 1, .9), Color(.8, .9, 1, .3))
			for k in 5:
				var yy: float = top + fposmod(T * 4.0 + k * 11.0, 44.0)
				Spr.seg(f - 4 + k * 3, yy, f - 2 + k * 3, yy + 8, Color(1, 1, 1, .7), 2)
			for k in 4:
				Spr.circle(f + 8 + k * 9, top + 44 + sin(T * .2 + k) * 3, 7 - k, Color(1, 1, 1, .5))
			Spr.rr(f - 26, top - 30, 20, 34, 6, Color("#5a5a52"))
		# as margens
		_bank(float(RA.x0), 470, 1.0)
		_bank(float(RA.x1), 470, -1.0)
	# obstáculos (os do passeio, ou os do mapa enquanto ninguém está na jangada)
	var obs: Array = VH.OBS if VH.mode == "raft" else RA.get("obs", [])
	for o in obs:
		if o.x < g.cam - 200 or o.x > g.cam + g.W + 200:
			continue
		var oy: float = VH.water_y(o.x)
		match o.k:
			"rock":
				Spr.ellipse(o.x + 30, oy + 4, 36, 8, Color(1, 1, 1, .4))
				Spr.poly(PackedVector2Array([Vector2(o.x + 2, oy + 4), Vector2(o.x + 12, oy - 30), Vector2(o.x + 34, oy - 38), Vector2(o.x + 54, oy - 18), Vector2(o.x + 58, oy + 4)]), Color("#6b6a62"))
				Spr.poly(PackedVector2Array([Vector2(o.x + 14, oy - 26), Vector2(o.x + 34, oy - 34), Vector2(o.x + 40, oy - 20), Vector2(o.x + 20, oy - 14)]), Color("#837e70"))
			"log":
				var bob: float = sin(T * .1 + o.x) * 2
				Spr.rr(o.x + 4, oy - 18 + bob, 74, 20, 10, Color("#6b4626"))
				Spr.rr(o.x + 4, oy - 18 + bob, 74, 7, 5, Color("#8a5e34"))
				Spr.ellipse(o.x + 76, oy - 8 + bob, 5, 10, Color("#c9a26a"))
			"branch":
				Spr.rect(o.x + 90, oy - 220, 18, 240, Color("#4e331d"))
				Spr.rr(o.x - 4, oy - 108, 112, 16, 7, Color("#5a3d22"))
				for k in 5:
					Spr.ellipse(o.x + 8 + k * 20, oy - 112 + (k % 2) * 6, 14, 8, Color("#4f7a34"), k)
	# a jangada parada no cais
	if VH.mode != "raft":
		var rx: float = VH.RA.px
		if rx > g.cam - 120 and rx < g.cam + g.W + 120:
			var wl2: float = VH.water_y(rx)
			Spr.save()
			Spr.translate(rx, wl2 + sin(T * .08) * 1.5)
			_raft(0, 0)
			Spr.restore()
			if not VH.raft_done:
				Spr.seg(float(RA.x0) - 6, 488, rx - 30, wl2 - 6, Color("#c9a26a"), 2)
				Spr.rect(float(RA.x0) - 12, 470, 8, 40, Color("#5a3d22"))

## margem do rio: barranco de terra irregular com pedras, entrando na água
static func _bank(e: float, y0: float, dir: float) -> void:
	for b in [[Color("#5a3d26"), 0.0], [Color("#3c281a"), 70.0], [Color("#1e140c"), 150.0]]:
		var pts := PackedVector2Array([Vector2(e - dir * 2, y0 + b[1])])
		var y: float = y0 + b[1]
		while y <= y0 + b[1] + 100:
			pts.push_back(Vector2(e + dir * (16 + 8 * sin(y * .11 + e) + 5 * sin(y * .29 + e)), y))
			y += 10
		pts.push_back(Vector2(e - dir * 2, y0 + b[1] + 100))
		Spr.poly(pts, b[0])
	for k in 3:
		var rx: float = e + dir * (14 + k * 9)
		Spr.ellipse(rx, y0 + 22 + k * 5, 9 - k * 2, 6 - k, Color("#6b6a62"))
		Spr.ellipse(rx - 2, y0 + 19 + k * 5, 4 - k, 2, Color(1, 1, 1, .25))
	# juncos na beira
	for k in 4:
		var jx: float = e - dir * (6 + k * 7)
		var jh: float = 26 + fmod(jx * 1.3, 14.0)
		Spr.seg(jx, y0 + 4, jx + dir * 3, y0 + 4 - jh, Color("#4f7a34"), 2.5)
		if k % 2 == 0:
			Spr.rr(jx + dir * 3 - 2.5, y0 + 4 - jh - 2, 5, 12, 2.5, Color("#6b4626"))

## o vale visto do avião: colinas suaves ao longe, copas de árvore com contorno e um riozinho brilhando
static func _valley(a: float, b: float, bottom: float, T: int) -> void:
	var hills := PackedVector2Array()
	var x: float = floor(a / 20.0) * 20.0 - 20
	var x_end: float = b + 20
	while x <= x_end:
		hills.push_back(Vector2(x, 548 - 22 * sin(x * .0021) - 12 * sin(x * .0057 + 1.3)))
		x += 20
	var hp := PackedVector2Array(hills)
	hp.push_back(Vector2(x_end, 700))
	hp.push_back(Vector2(hills[0].x, 700))
	Spr.poly(hp, Color("#a9c49a"))
	Spr.line(hills, Color("#c4d8b4"), 2)
	# rio no fundo do vale
	var rv := PackedVector2Array()
	x = floor(a / 20.0) * 20.0 - 20
	while x <= x_end:
		rv.push_back(Vector2(x, 600 + 8 * sin(x * .004)))
		x += 20
	Spr.line(rv, Color("#9fd0e8"), 5)
	Spr.line(rv, Color(1, 1, 1, .4), 1.5)
	# duas fileiras de copas (a de trás mais clara), cada árvore um cacho de bolas
	for layer in [0, 1]:
		var step: float = 34.0 if layer == 0 else 42.0
		var base_y: float = 590.0 if layer == 0 else 628.0
		var tx: float = floor(a / step) * step - step
		while tx < b + step:
			var h1: float = WorldStatic_hh(tx + layer * 7.0, 1)
			var cx: float = tx + h1 * 10
			var r: float = (14 + h1 * 9) * (1.0 if layer == 0 else 1.3)
			var col := Color("#5b8a4c") if layer == 0 else Color("#3f6a36")
			col = col.lightened(h1 * .08)
			Spr.circle(cx, base_y - r * .4, r, col)
			Spr.circle(cx - r * .6, base_y - r * .1, r * .7, col.darkened(.06))
			Spr.circle(cx + r * .6, base_y - r * .05, r * .72, col.darkened(.03))
			Spr.circle(cx - r * .25, base_y - r * .75, r * .35, col.lightened(.12))
			tx += step
	Spr.vgrad(a, 640, b - a, 120, Color("#3f6a36"), Color("#2c4a28"))
	Spr.rect(a, 760, b - a, bottom - 560, Color("#2c4a28"))

static func WorldStatic_hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

# ---------- pista e voo ----------
static func _runway(g: Game, VH: Vehicles, T: int) -> void:
	var PL: Dictionary = VH.PL
	var y: float = PL.y
	var r0: float = PL.get("r0", float(PL.x) - 500)
	var edge: float = PL.edge
	if edge > g.cam - 200 and r0 < g.cam + g.W + 200:
		# faixa de terra batida e bandeirinhas
		Spr.rect(r0, y - 3, edge - r0, 6, Color("#b8a27a"))
		var fx: float = r0 + 40
		while fx < edge:
			Spr.rect(fx, y - 1, 26, 2, Color(1, 1, 1, .7))
			fx += 70
		# biruta
		Spr.rect(r0 + 60, y - 90, 4, 90, Color("#6c7680"))
		var sw: float = sin(T * .05) * .2
		Spr.save()
		Spr.translate(r0 + 64, y - 88)
		Spr.rotate(sw)
		Spr.poly(PackedVector2Array([Vector2(0, -8), Vector2(46, -4), Vector2(46, 4), Vector2(0, 8)]), Color("#f08030"))
		Spr.rect(14, -7, 8, 14, Color(1, 1, 1))
		Spr.rect(32, -5, 6, 10, Color(1, 1, 1))
		Spr.restore()
		# placa na beira do precipício
		Spr.rect(edge - 40, y - 46, 5, 46, Color("#5a3d22"))
		Spr.rr(edge - 62, y - 66, 50, 24, 4, Color("#8a5e34"))
		Spr.text("PERIGO", edge - 37, y - 50, 10, Color("#f0d070"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
	# o vale lá embaixo durante o voo
	var v0: float = edge
	var v1: float = PL.get("vend", PL.x1)
	var a: float = max(v0, g.cam - 50)
	var b: float = min(v1, g.cam + g.W + 50)
	if a < b:
		_valley(a, b, float(g.L.bottom), T)
	# os obstáculos do céu
	if VH.mode == "plane":
		for o in VH.OBS:
			if o.x < g.cam - 200 or o.x > g.cam + g.W + 300:
				continue
			match o.k:
				"flock":
					for i in int(o.get("n", 5)):
						_bird(o.x + (i % 3) * 34 - (i / 3) * 14, o.y + (i / 3) * 26 + (i % 3) * 6, T + i * 5, o.hit)
				"hawk":
					if o.st in ["warn", "dive"] and (T / 5) % 2 == 0:
						Spr.text("!", g.cam + g.W - 40, o.ty + 10, 34, Color("#ff5a3a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 6, Color(0, 0, 0, .8))
					if o.st != "gone":
						_hawk(o.x, o.y, T, o.st == "dive", o.st == "sweep")
				"cloud":
					_cloud(o, T)
	# o avião parado (na pista antes de decolar; na clareira depois do pouso)
	if VH.mode != "plane":
		var px: float = PL.px
		if px > g.cam - 260 and px < g.cam + g.W + 260:
			WorldNature.prop("biplano", px, PL.py + 2, 112)

static func _plane_fly(x: float, y: float, tilt: float, T: int, ground: bool) -> void:
	Spr.save()
	Spr.translate(x, y + 2)
	Spr.rotate(tilt)
	if not ground:
		Spr.translate(0, sin(T * .1) * 2)
	# o Pipoca vai na cabine, atrás do Tomé (só a cabeça aparece por cima da fuselagem)
	if dog_on_board:
		Spr.save()
		Spr.translate(-34, -60)
		Spr.rotate(-.08)
		if not Spr.novo("pipoca", 6, 30):
			Spr.scale(.3, .3)
			Spr.A("dog0", 0, 0, 1)
		Spr.restore()
	WorldNature.prop("biplano_voo", 0, 0, 120)
	Spr.restore()

static func _bird(x: float, y: float, t: int, hit: bool) -> void:
	var f: float = sin(t * .4) * 7
	var c := Color("#3a3a46") if not hit else Color(.5, .5, .55, .5)
	Spr.ellipse(x, y, 9, 5, c)
	Spr.seg(x - 2, y - 1, x - 14, y - 6 - f, c, 3)
	Spr.seg(x + 2, y - 1, x + 12, y - 6 - f, c, 3)
	Spr.poly(PackedVector2Array([Vector2(x - 9, y), Vector2(x - 15, y - 2), Vector2(x - 15, y + 3)]), c)
	Spr.circle(x + 7, y - 1, 1.2, Color(1, 1, 1))

static func _hawk(x: float, y: float, t: int, dive: bool, sweep: bool = false) -> void:
	var f: float = 0.0 if dive else sin(t * (.6 if sweep else .25)) * 10
	Spr.save()
	Spr.translate(x, y)
	if dive:
		Spr.rotate(.5)
	Spr.ellipse(0, 0, 20, 9, Color("#6b4a2e"))
	Spr.poly(PackedVector2Array([Vector2(-8, -2), Vector2(-30, -16 - f), Vector2(-4, -6)]), Color("#5a3d22"))
	Spr.poly(PackedVector2Array([Vector2(6, -2), Vector2(28, -16 - f), Vector2(12, -6)]), Color("#5a3d22"))
	Spr.circle(-16, -3, 7, Color("#f2ead8"))
	Spr.poly(PackedVector2Array([Vector2(-22, -4), Vector2(-28, -1), Vector2(-21, 0)]), Color("#f0b030"))
	Spr.circle(-17, -5, 1.6, Color(0, 0, 0))
	Spr.poly(PackedVector2Array([Vector2(18, 0), Vector2(30, -6), Vector2(30, 6)]), Color("#5a3d22"))
	Spr.restore()

static func _cloud(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var w: float = o.w
	var h: float = o.h
	var c := Color("#4a4f5e")
	for k in 6:
		var cx: float = x + w * (.12 + k * .15)
		var cy: float = y + h * (.45 + sin(k * 1.7) * .15)
		Spr.circle(cx, cy, h * (.32 + fmod(k * .37, .18)), c.lightened(k % 2 * .06))
	Spr.ellipse(x + w / 2, y + h * .7, w * .5, h * .22, c.darkened(.15))
	# raio piscando
	if (T + int(x)) % 120 < 8:
		var lx: float = x + w * .5
		Spr.line(PackedVector2Array([Vector2(lx, y + h * .7), Vector2(lx - 10, y + h), Vector2(lx + 4, y + h + 6), Vector2(lx - 8, y + h + 40)]), Color("#fff4a0"), 3)
	for k in 6:
		var rx: float = x + 16 + fmod(k * 41.0, w - 32)
		var ry: float = y + h * .8 + fmod(T * 4.0 + k * 13.0, 50.0)
		Spr.seg(rx, ry, rx - 3, ry + 8, Color(.7, .8, .95, .5), 1.5)
