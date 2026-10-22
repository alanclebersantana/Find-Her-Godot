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
	if not VH.SL.is_empty():
		_sled_world(g, VH, T)

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
	elif VH.mode == "sled":
		var rot2: float = -.06 + clamp(VH.vy * .02, -.12, .12)
		if VH.stumble > 0:
			rot2 += sin(T * .8) * .12
		Spr.save()
		Spr.translate(VH.hx, VH.hy)
		Spr.rotate(rot2)
		_sled(0, 0)
		Spr.A("pai_crouch", -2, -10, .56)
		if g.X.DOG.get("st", "") == "ride":
			Spr.save()
			Spr.translate(-26, -10)
			Spr.scale(.26, .26)
			Spr.A("dog0", 0, 0, 1)
			Spr.restore()
		Spr.restore()
		# linhas de velocidade
		for k in 4:
			var ly: float = VH.hy - 14 - k * 11
			Spr.seg(VH.hx - 40 - k * 6, ly, VH.hx - 40 - VH.spd * 6 - k * 6, ly, Color(1, 1, 1, .45), 2)
	elif VH.mode == "plane":
		dog_on_board = g.X.DOG.get("st", "") == "ride"
		_plane_fly(VH.hx, VH.hy, VH.tilt, T, VH.phase == "taxi" or VH.phase == "land")
	Spr.alpha = 1.0

## trenó de madeira com esquis curvos
static func _sled(x: float, y: float) -> void:
	Spr.ellipse(x, y + 1, 34, 4, Color(0, 0, 0, .2))
	var run := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		run.push_back(Vector2(x - 32 + u * 64, y - 2 - (pow(max(0.0, u - .8) / .2, 2) * 12)))
	Spr.line(run, Color("#5a3a20"), 4)
	Spr.rr(x - 30, y - 16, 58, 9, 4, Color("#8a5a2e"))
	Spr.rr(x - 28, y - 15, 54, 3, 2, Color(1, 1, 1, .15))
	for k in 3:
		Spr.seg(x - 20 + k * 20, y - 8, x - 20 + k * 20, y - 2, Color("#5a3a20"), 3)
	Spr.seg(x + 26, y - 16, x + 34, y - 26, Color("#c9a26a"), 2)

## o que fica pelo caminho do trenó e o trenó parado no alto
static func _sled_world(g: Game, VH: Vehicles, T: int) -> void:
	var SL: Dictionary = VH.SL
	if SL.is_empty() or float(SL.x1) < g.cam - 200 or float(SL.x) > g.cam + g.W + 200:
		return
	var gy: float = float(SL.y)
	var obs: Array = VH.OBS if VH.mode == "sled" else SL.get("obs", [])
	for o in obs:
		match o.k:
			"mound":
				Spr.ellipse(o.x, gy - 6, 30, 14, Color(.82, .88, .97))
				Spr.ellipse(o.x - 3, gy - 9, 25, 11, Color(.97, .98, 1))
			"rock":
				Spr.AB("o_rocks", o.x - 26, gy - 34, 52, 38)
				Spr.ellipse(o.x, gy - 30, 18, 5, Color(.97, .98, 1))
			"log":
				Spr.rr(o.x - 36, gy - 20, 72, 20, 10, Color("#6b4626"))
				Spr.rr(o.x - 36, gy - 20, 72, 7, 5, Color("#8a5e34"))
				Spr.ellipse(o.x + 34, gy - 10, 5, 10, Color("#c9a26a"))
				Spr.ellipse(o.x, gy - 21, 30, 4, Color(.97, .98, 1))
	# monte de neve no fim (onde o trenó para)
	Spr.ellipse(float(SL.x1) + 30, gy - 8, 46, 20, Color(.82, .88, .97))
	Spr.ellipse(float(SL.x1) + 26, gy - 12, 40, 16, Color(.97, .98, 1))
	if VH.mode != "sled" and not VH.sled_done:
		_sled(float(SL.x), gy)
		var p: Dictionary = g.player
		if abs(p.x + p.w / 2 - float(SL.x)) < 120 and (T / 20) % 2 == 0:
			Spr.text("✦ TRENÓ", float(SL.x), gy - 60 + sin(T * .15) * 3, 16, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	elif VH.sled_done and VH.mode != "sled":
		_sled(float(SL.x1) - 10, gy)

static func _raft(x: float, y: float) -> void:
	# toras pintadas amarradas (vistas de lado): a madeira comprida e as pontas cortadas
	_hlog(x - 40, x + 40, y - 9, 16)
	for k in 5:
		Spr.P("logend%d" % (k % 3), x - 32 + k * 16, y + 8, 17)
	for k in 2:
		Spr.rect(x - 24 + k * 44, y - 10, 5, 17, Color("#c9a26a"))
		Spr.seg(x - 24 + k * 44, y - 10, x - 19 + k * 44, y + 6, Color("#7a5a32"), 1.2)

## tora pintada deitada de xa a xb (centro em y, grossura h)
static func _hlog(xa: float, xb: float, y: float, h: float) -> void:
	Spr.save()
	Spr.translate(xa, y + h / 2)
	Spr.rotate(-PI / 2)
	Spr.PR("log", 0, 0, h, xb - xa)
	Spr.restore()

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
			# correnteza: fios de espuma curvos de tamanhos diferentes descendo o rio
			for k in int((sb - sa) / 38) + 1:
				var fx: float = sa + fposmod(k * 38.0 - T * (4.0 + (k % 3)), sb - sa + 1)
				var fy: float = wl + 6 + (k % 4) * 8
				var fl: float = 14 + fmod(k * 7.3, 16.0)
				var fa: float = .25 + .25 * sin(k * 1.7 + T * .03)
				Spr.line(PackedVector2Array([Vector2(fx, fy), Vector2(fx + fl * .5, fy - 2), Vector2(fx + fl, fy)]), Color(.85, .95, 1, fa), 2)
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
			Spr.P("rock2", f - 18, top + 8, 44)
		# as margens
		_bank(float(RA.x0), 470, 1.0)
		_bank(float(RA.x1), 470, -1.0)
	# obstáculos (os do passeio, ou os do mapa enquanto ninguém está na jangada)
	var obs: Array = VH.OBS if VH.mode == "raft" else RA.get("obs", [])
	for o in obs:
		if o.x < g.cam - 260 or o.x > g.cam + g.W + 260:
			continue
		var oy: float = VH.water_y(o.x)
		match o.k:
			"rock":
				# pedra pintada saindo da água, com espuma batendo
				Spr.P("rock1", o.x + 30, oy + 12, 66)
				Spr.rect(o.x - 6, oy + 3, 74, 10, Color(.31, .56, .69, .85))
				for k in 3:
					var fa: float = fposmod(T * .05 + k * .33, 1.0)
					Spr.ellipse(o.x + 2 - fa * 16, oy + 2, 8 + fa * 10, 3, Color(1, 1, 1, .55 * (1.0 - fa)))
			"log":
				var bob: float = sin(T * .1 + o.x) * 2
				_hlog(o.x + 4, o.x + 78, oy - 8 + bob, 20)
				Spr.P("logend0", o.x + 79, oy + 2 + bob, 20)
				Spr.ellipse(o.x + 40, oy + 3, 42, 4, Color(1, 1, 1, .35))
			"branch":
				pass
			"lowbranch":
				# árvore morta inclinada da margem, com um galho grosso baixo por cima do rio
				Spr.save()
				Spr.translate(o.x + 175, oy + 30)
				Spr.rotate(-.3)
				Spr.img(Spr.tex.tronco, -24, -330, 48, 340)
				Spr.restore()
				# galho grosso descendo da árvore até a altura do Tomé
				Spr.save()
				Spr.translate(o.x + 134, oy - 106)
				Spr.rotate(-.3)
				Spr.PR("log", -160, -12, 166, 24, Color(.82, .78, .74))
				Spr.restore()
				# galhinhos secos pendurados até a altura do Tomé
				for k in 5:
					var tx: float = o.x + 6 + k * 22
					var ty: float = oy - 80 + k * 6
					Spr.seg(tx, ty - 8, tx - 6, ty + 30 - k * 4, Color("#3e2a18"), 2.5)
					Spr.seg(tx - 4, ty + 10, tx + 6, ty + 24 - k * 3, Color("#3e2a18"), 1.6)
			"trunk":
				# tronco caído atravessado sobre o rio, com musgo e fios pendurados
				Spr.P("rock0", o.x - 30, oy + 10, 58)
				Spr.P("rock2", o.x + 166, oy + 10, 54)
				Spr.rect(o.x - 64, oy + 3, 260, 8, Color(.31, .56, .69, .85))
				Spr.seg(o.x - 30, oy - 46, o.x - 34, oy - 2, Color("#4e331d"), 6)
				Spr.seg(o.x + 160, oy - 46, o.x + 168, oy - 2, Color("#4e331d"), 6)
				_hlog(o.x - 40, o.x + 170, oy - 64, 36)
				Spr.P("logend1", o.x + 170, oy - 44, 36)
				for k in 7:
					var mx: float = o.x - 24 + k * 30
					Spr.ellipse(mx, oy - 82, 14, 5, Color("#4f7a34"))
					if k % 2 == 0:
						Spr.seg(mx, oy - 48, mx + sin(T * .05 + k) * 3, oy - 34 - (k % 3) * 4, Color(.3, .45, .2, .8), 1.5)
			"bridge":
				# ponte velha e baixa: tábuas sobre dois postes, corrimão de corda
				for px in [o.x - 24.0, o.x + 182.0]:
					Spr.PR("stake", px - 7, oy - 120, 14, 140, Color(.85, .8, .75))
				Spr.rr(o.x - 34, oy - 66, 236, 20, 4, Color("#6b4626"))
				Spr.rr(o.x - 34, oy - 66, 236, 6, 3, Color("#8a5e34"))
				var pk: float = o.x - 30
				while pk < o.x + 198:
					Spr.seg(pk, oy - 64, pk, oy - 47, Color("#3e2a18"), 1.5)
					pk += 18 + fmod(pk * .37, 6.0)
				var rail := PackedVector2Array()
				for k in 13:
					var u: float = k / 12.0
					rail.push_back(Vector2(lerpf(o.x - 24, o.x + 182, u), oy - 112 + sin(u * PI) * 16))
				Spr.line(rail, Color("#7a5a32"), 3)
				Spr.line(rail, Color("#c9a26a"), 1.4)
			"net":
				# rede de pesca esticada entre dois postes, boias de cortiça embaixo
				var sw: float = sin(T * .05 + o.x) * 3
				for px in [o.x - 14.0, o.x + 124.0]:
					Spr.PR("stake", px - 7, oy - 160, 14, 180, Color(.85, .8, .75))
				Spr.seg(o.x - 14, oy - 136, o.x + 124, oy - 136, Color("#c9a26a"), 2.5)
				var xa: float = o.x - 8
				while xa <= o.x + 118:
					Spr.seg(xa, oy - 134, xa + 14 + sw, oy - 46, Color(.85, .8, .65, .65), 1.2)
					Spr.seg(xa + 14, oy - 134, xa + sw, oy - 46, Color(.85, .8, .65, .65), 1.2)
					xa += 14
				Spr.seg(o.x - 10 + sw, oy - 46, o.x + 120 + sw, oy - 46, Color("#c9a26a"), 2)
				for k in 6:
					Spr.ellipse(o.x - 2 + k * 22 + sw, oy - 45, 6, 4, Color("#e08a3a"))
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
		# aviso de longe: plaquinha na borda da tela na altura do que vem aí
		for o in VH.OBS:
			var ahead: float = o.x - (g.cam + g.W)
			if ahead > -40 and ahead < 1000 and not o.hit and o.get("st", "") != "gone":
				var wy: float = o.y + (o.h * .5 if o.k == "cloud" else (20.0 if o.k == "flock" else 0.0))
				if o.k == "hawk" and o.has("ty"):
					wy = o.ty
				var wa: float = clamp(1.0 - ahead / 1000.0, .35, 1.0)
				var wx: float = g.cam + g.W - 34
				Spr.circle(wx, wy, 17, Color(0, 0, 0, .35 * wa))
				Spr.ring(wx, wy, 17, Color(1, .35, .2, wa), 3)
				Spr.text("!", wx, wy + 9, 24, Color(1, .4, .25, wa), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 4, Color(0, 0, 0, .7 * wa))
				Spr.poly(PackedVector2Array([Vector2(wx + 20, wy - 7), Vector2(wx + 30, wy), Vector2(wx + 20, wy + 7)]), Color(1, .4, .25, wa))
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
