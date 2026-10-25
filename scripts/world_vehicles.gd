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
		if VH.is_cart():
			_cart_world(g, VH, T)
			if VH.mode == "sled":
				_cart_track(g, VH, T)
		else:
			_sled_world(g, VH, T)
			if VH.mode == "sled":
				_sled_track(g, VH, T)

## o veículo com o Tomé (no lugar do desenho normal do Tomé)
## inclinação do trenó/carrinho suavizada (sem estalar quando a rampa muda ou ele sai do chão)
static var _sang_s := 0.0
static func _tilt(target: float) -> float:
	# só anda no 1º desenho depois de cada passo (a 90/120 Hz suavizava mais rápido e tremia)
	if Polish.FRESH:
		_sang_s = lerpf(_sang_s, target, .22)
	return _sang_s

static func rider(g: Game, T: int) -> void:
	var VH: Vehicles = g.VH
	var p: Dictionary = g.player
	# acabou de se machucar: pisca com um brilho (sem ficar transparente)
	var blink: bool = p.iframe > 0 and (T / 5) % 2 == 0
	if VH.mode == "raft":
		var bob: float = sin(T * .15) * 1.5 if VH.hy >= VH.water_y(VH.hx) - 1 else 0.0
		var rot: float = clamp(VH.vy * .02, -.15, .15)
		if VH.stumble > 0:
			rot += sin(T * .8) * .1
		Spr.save()
		Spr.translate(VH.hx, VH.hy + bob)
		Spr.rotate(rot)
		_raft(0, 0)
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
		Spr.restore()
	elif VH.mode == "sled":
		# o Pipoca vem correndo atrás, pela trilha
		if g.X.DOG.get("st", "") == "ride":
			var du: float = VH.su - 90.0 - sin(T * .02) * 20.0
			Spr.save()
			Spr.translate(VH.sled_tx0() + du, VH.sled_y(du) + 1)
			Spr.translate(0, -abs(sin(T * .35)) * 4)
			Spr.scale(.36, .36)
			WorldExtras._dog_frame("dog%d" % ((T / 4) % 4), sin(T * .5) * .2)
			Spr.restore()
		if VH.is_cart():
			_cart_rider(g, VH, p, T)
			return
		var st: Texture2D = Spr.opt("sled_tome")
		var fr := 0
		var on_g: bool = VH.hy >= VH.sled_y(VH.su) - 1
		if p.dyingT > 0:
			fr = 4
		elif not on_g:
			fr = 3
		elif VH.duck:
			fr = 2
		elif VH.lean or VH.spd > 7.5:
			fr = 1
		Spr.save()
		Spr.translate(VH.hx, VH.hy + 2)
		if p.dyingT > 0:
			Spr.rotate(-p.dyingT * .12)
		elif VH.crashT > 0:
			Spr.rotate(VH.sang + sin(VH.crashT * .5) * .25 * VH.crashT / 30.0)
		elif fr == 3:
			Spr.rotate(_tilt(VH.sang * .3))
		else:
			Spr.rotate(_tilt(VH.sang))
		if st:
			Spr.frame(st, fr, 260, 200, 130, 196, 0, 0, .56)
		else:
			_sled(0, 0)
			Spr.A("pai_crouch", -2, -10, .56)
		Spr.restore()
		# linhas de velocidade
		if VH.spd > 6.0:
			for k in 4:
				var ly: float = VH.hy - 14 - k * 11
				Spr.seg(VH.hx - 40 - k * 6, ly, VH.hx - 40 - VH.spd * 6 - k * 6, ly, Color(1, 1, 1, .12 * (VH.spd - 6.0)), 2)
	elif VH.mode == "plane" and VH.phase == "board" and VH.pb < 30:
		# embarque: o Tomé dá um pulinho até a cabine do avião parado
		WorldNature.prop("biplano", VH.hx, VH.hy + 2, 112)
		var u: float = clamp((VH.pb - 4) / 22.0, 0.0, 1.0)
		var tx: float = lerpf(VH.bx0, VH.hx + CABIN.x, u)
		var ty: float = lerpf(VH.by0, VH.hy + CABIN.y, u) - sin(u * PI) * 46.0
		Spr.frame(Spr.tex.pai, 0, 170, 160, 85, 156, tx, ty, .46, VH.bx0 > VH.hx + CABIN.x)
	elif VH.mode == "plane":
		dog_on_board = g.X.DOG.get("st", "") == "ride"
		var shake: float = sin(T * 1.7) * 1.2 if VH.phase == "board" else 0.0
		_plane_fly(VH.hx, VH.hy + shake, VH.tilt, T, VH.phase in ["taxi", "land", "board"])
	if blink:
		Spr.glow(VH.hx, VH.hy - 34, 58, Color(1, .95, .75, .45))
		Spr.glow(VH.hx, VH.hy - 34, 30, Color(1, 1, 1, .35))
	Spr.alpha = 1.0

## trenó de madeira com esquis curvos
static func _sled(x: float, y: float) -> void:
	if Spr.has("p_sledp"):
		Spr.ellipse(x, y + 1, 36, 4, Color(0, 0, 0, .2))
		Spr.P("sledp", x, y + 3, 84)
		return
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
	# monte de neve no fim (onde o trenó para)
	if Spr.has("p_snowpile"):
		Spr.P("snowpile", float(SL.x1) + 30, gy + 6, 120)
	else:
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
	if Spr.has("p_raft"):
		# jangada pintada: toras amarradas com corda e o remo
		Spr.P("raft", x, y + 14, 100)
		return
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
			"vinebranch":
				_vinebranch(o.x, oy, T)
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
				if Spr.has("p_net"):
					Spr.save()
					Spr.translate(o.x + 55, oy - 140)
					Spr.rotate(sw * .01)
					Spr.PR("net", -66, 0, 132, 98)
					Spr.restore()
					for k in 5:
						Spr.ellipse(o.x - 2 + k * 28 + sw, oy - 44, 6, 4, Color("#e08a3a"))
					continue
				var xa: float = o.x - 8
				while xa <= o.x + 118:
					Spr.seg(xa, oy - 134, xa + 14 + sw, oy - 46, Color(.85, .8, .65, .65), 1.2)
					Spr.seg(xa + 14, oy - 134, xa + sw, oy - 46, Color(.85, .8, .65, .65), 1.2)
					xa += 14
				Spr.seg(o.x - 10 + sw, oy - 46, o.x + 120 + sw, oy - 46, Color("#c9a26a"), 2)
				for k in 6:
					Spr.ellipse(o.x - 2 + k * 22 + sw, oy - 45, 6, 4, Color("#e08a3a"))
	# cerca na margem do fim (depois da corredeira não dá para voltar para a água)
	if VH.raft_done:
		var fx: float = float(RA.x1) - 4.0
		if fx > g.cam - 100 and fx < g.cam + g.W + 100:
			for k in 3:
				Spr.PR("stake", fx - 6 + k * 20, 446, 12, 58, Color(.85, .8, .75))
			_hlog(fx - 10, fx + 56, 458, 9)
			_hlog(fx - 10, fx + 56, 478, 9)
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
				Spr.seg(float(RA.x0) + 66, 504, rx - 40, wl2 - 8, Color("#c9a26a"), 2)
	# o cais de tábuas e o poste de amarrar na margem
	var dx0: float = float(RA.x0)
	if dx0 > g.cam - 260 and dx0 < g.cam + g.W + 100:
		if Spr.has("p_pier"):
			Spr.P("pier", dx0 + 4, 548, 140)
			Spr.P("dockpost", dx0 + 66, 566, 30)
		else:
			Spr.rect(dx0 - 12, 470, 8, 40, Color("#5a3d22"))

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
		var sw: float = sin(T * .05) * .2
		if Spr.has("p_windsock"):
			Spr.save()
			Spr.translate(r0 + 64, y + 2)
			Spr.rotate(sw * .1)
			Spr.P("windsock", 14, 0, 70)
			Spr.restore()
		else:
			_windsock_v(r0, y, sw)
		# placa pintada na beira do precipício
		Spr.PR("stake", edge - 42, y - 50, 9, 52, Color(.85, .8, .75))
		Spr.P("sign", edge - 38, y - 34, 70)
		Spr.text("PERIGO", edge - 40, y - 52, 11, Color("#ffe08a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3, Color(0, 0, 0, .7))
	_after_runway(g, VH, T)

static func _windsock_v(r0: float, y: float, sw: float) -> void:
		Spr.rect(r0 + 60, y - 90, 4, 90, Color("#6c7680"))
		Spr.save()
		Spr.translate(r0 + 64, y - 88)
		Spr.rotate(sw)
		Spr.poly(PackedVector2Array([Vector2(0, -8), Vector2(46, -4), Vector2(46, 4), Vector2(0, 8)]), Color("#f08030"))
		Spr.rect(14, -7, 8, 14, Color(1, 1, 1))
		Spr.rect(32, -5, 6, 10, Color(1, 1, 1))
		Spr.restore()

static func _after_runway(g: Game, VH: Vehicles, T: int) -> void:
	var PL: Dictionary = VH.PL
	var y: float = PL.y
	var edge: float = PL.edge
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

## onde o Tomé senta no avião (em relação ao ponto de apoio das rodas)
const CABIN := Vector2(-6, -40)

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
	if Spr.has("p_birdp0"):
		# passarinho pintado batendo as asas (voa para a esquerda, contra o avião)
		var fr: String = "birdp0" if (t / 5) % 2 == 0 else "birdp1"
		Spr.P(fr, x, y + 9, 34, true, 0.0, Color(1, 1, 1, .45) if hit else Color.WHITE)
		return
	var f: float = sin(t * .4) * 7
	var c := Color("#3a3a46") if not hit else Color(.5, .5, .55, .5)
	Spr.ellipse(x, y, 9, 5, c)
	Spr.seg(x - 2, y - 1, x - 14, y - 6 - f, c, 3)
	Spr.seg(x + 2, y - 1, x + 12, y - 6 - f, c, 3)
	Spr.poly(PackedVector2Array([Vector2(x - 9, y), Vector2(x - 15, y - 2), Vector2(x - 15, y + 3)]), c)
	Spr.circle(x + 7, y - 1, 1.2, Color(1, 1, 1))

static func _hawk(x: float, y: float, t: int, dive: bool, sweep: bool = false) -> void:
	if Spr.has("p_hawkp"):
		# gavião pintado (garras para a frente); bate as asas esticando a pintura
		var fl: float = sin(t * (.6 if sweep else .25))
		Spr.save()
		Spr.translate(x, y)
		Spr.rotate(-.35 if dive else fl * .06)
		Spr.scale(1.0, 1.0 + fl * .08)
		Spr.P("hawkp", 0, 30, 76)
		Spr.restore()
		return
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
	if Spr.has("p_stormcloud"):
		Spr.PR("stormcloud", x - w * .08, y - h * .15, w * 1.16, h * 1.2)
		if (T + int(x)) % 120 < 8:
			# raio pintado inteiro saindo de baixo da nuvem, com clarão
			var lx0: float = x + w * .5
			Spr.glow(lx0, y + h * 1.25, h * .9, Color(1, .95, .6, .35))
			Spr.P("bolt", lx0, y + h * 1.75, h * .45)
		for k in 6:
			var rx0: float = x + 16 + fmod(k * 41.0, w - 32)
			var ry0: float = y + h * .9 + fmod(T * 4.0 + k * 13.0, 50.0)
			Spr.seg(rx0, ry0, rx0 - 3, ry0 + 8, Color(.7, .8, .95, .5), 1.5)
		return
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

## a trilha do trenó: morro de neve comprido com ondulações, rampas, pinheiros e os obstáculos
static func _sled_track(g: Game, VH: Vehicles, T: int) -> void:
	var t0: float = VH.sled_tx0()
	var ln: float = float(VH.SL.get("len", 4650))
	var a: float = max(t0 - 400, g.cam - 80)
	var b: float = min(t0 + ln + 2400, g.cam + g.W + 80)
	if a >= b:
		return
	var bot: float = g.cam_y + g.H + 400
	# pinheiros atrás do morro (a base fica escondida pela neve)
	var tu: float = floor((a - t0) / 230.0) * 230.0
	while t0 + tu < b + 200:
		var jx: float = tu + fmod(abs(tu) * .37, 90.0)
		var sc: float = .45 + fmod(abs(tu) * .013, .35)
		WorldNature.prop("pinheiro", t0 + jx, VH.sled_y(jx) + 40, 330 * sc)
		tu += 230
	# galhos baixos (a árvore fica atrás do morro)
	for o in VH.OBS:
		if o.k == "branch" and o.x > a - 200 and o.x < b + 200:
			var oy: float = VH.sled_y(float(o.u))
			var hb: bool = o.hit and o.get("ft", -1) >= 0
			Spr.alpha = 1.0
			WorldNature.prop("arvore_neve", o.x + 150, oy + 70, 300, false, 1.0)
			# o galho baixo atravessa a pista na altura da cabeça (cai quando o trenó bate)
			var fall: float = 0.0
			if hb:
				fall = min(float(o.ft), 40.0)
				fall = fall * fall * .25
			if not hb or o.ft < 40:
				_snow_branch(o.x, oy - 58 + fall, T, hb)
				if not hb:
					# setinhas laranja descendo embaixo do galho: abaixe!
					for k in 2:
						var u2: float = fposmod(T * .025 + k * .5, 1.0)
						var ay2: float = oy - 44 + u2 * 26
						Spr.line(PackedVector2Array([Vector2(o.x - 12, ay2 - 11), Vector2(o.x + 5, ay2), Vector2(o.x + 22, ay2 - 11)]), Color(1, .5, .05, sin(u2 * PI)), 7)
	# corpo do morro: neve branca em cima, azulada para baixo
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var x: float = floor(a / 12.0) * 12.0
	while x <= b + 12:
		pts.push_back(Vector2(x, VH.sled_y(x - t0)))
		cols.push_back(Color(.97, .98, 1))
		x += 12
	var top := pts.duplicate()
	pts.push_back(Vector2(b + 12, bot))
	cols.push_back(Color(.6, .7, .86))
	pts.push_back(Vector2(a - 12, bot))
	cols.push_back(Color(.6, .7, .86))
	Spr.ci.draw_polygon(pts, cols)
	Spr.line(top, Color(1, 1, 1), 3)
	var sh := PackedVector2Array()
	for q in top:
		sh.push_back(q + Vector2(0, 9))
	Spr.line(sh, Color(.78, .86, .97, .8), 4)
	# marcas dos esquis atrás do trenó
	var mk := PackedVector2Array()
	var ux: float = max(a - t0, 0.0)
	while ux < VH.su - 20:
		mk.push_back(Vector2(t0 + ux, VH.sled_y(ux) + 3))
		ux += 16
	if mk.size() > 1:
		Spr.line(mk, Color(.65, .75, .9, .45), 2)
	# brilhinhos na neve
	var sx: float = floor(a / 53.0) * 53.0
	while sx < b:
		if (int(sx / 53.0) + T / 30) % 7 == 0:
			Spr.circle(sx, VH.sled_y(sx - t0) + 14 + fmod(sx, 20.0), 1.5, Color(1, 1, 1, .9))
		sx += 53
	# obstáculos
	for o in VH.OBS:
		if o.x < a - 120 or o.x > b + 120:
			continue
		var oy: float = VH.sled_y(float(o.u))
		var ft: int = o.get("ft", -1) if o.hit else -1
		# destaque forte no meio da neve branca: sombra escura + brilho colorido pulsando
		# (verde = pular, laranja = abaixar, as mesmas cores das placas)
		if not o.hit and o.k != "bump":
			var pul: float = .5 + .5 * sin(T * .15 + o.x)
			if o.k == "branch":
				Spr.glow(o.x + 5, oy - 62, 92, Color(1, .45, .05, .4 + .25 * pul))
			else:
				Spr.ellipse(o.x + (float(o.get("w", 0)) * .5), oy + 4, 46, 9, Color(.1, .12, .2, .35))
				Spr.glow(o.x + (float(o.get("w", 0)) * .5), oy - 18, 62, Color(.2, 1, .3, .22 + .18 * pul))
				# setinhas verdes subindo em cima do obstáculo
				for k in 2:
					var u: float = fposmod(T * .025 + k * .5, 1.0)
					var ay: float = oy - 50 - u * 40
					var ax: float = o.x + float(o.get("w", 0)) * .5
					Spr.line(PackedVector2Array([Vector2(ax - 12, ay + 9), Vector2(ax, ay), Vector2(ax + 12, ay + 9)]), Color(.25, .95, .35, sin(u * PI) * .95), 5)
		match o.k:
			"rock":
				if ft >= 0:
					# quebrou: sobram pedrinhas na neve
					for k in 4:
						Spr.P("peb%d" % (k % 3), o.x - 22 + k * 15, oy + 3, 14)
				else:
					Spr.P("rock0", o.x, oy + 8, 50)
					Spr.ellipse(o.x - 2, oy - 26, 15, 5, Color(.97, .98, 1))
			"log":
				if ft >= 0:
					# saiu rolando morro abaixo e sumiu
					if ft < 60:
						var lu: float = float(o.u) + 40 + ft * 11.0
						Spr.alpha = 1.0 - ft / 60.0
						Spr.save()
						Spr.translate(VH.sled_tx0() + lu, VH.sled_y(lu) - 11)
						Spr.rotate(ft * .35)
						Spr.P("logend0", 0, 11, 22)
						Spr.restore()
						Spr.alpha = 1.0
				else:
					_hlog(o.x - 32, o.x + 30, oy - 21, 22)
					Spr.P("logend0", o.x + 30, oy + 1, 22)
					Spr.ellipse(o.x, oy - 21, 28, 5, Color(.97, .98, 1))
			"bump":
				Spr.ellipse(o.x, oy + 2, 34, 12, Color(.88, .92, 1))
				Spr.ellipse(o.x - 3, oy - 1, 28, 9, Color(.98, .99, 1))
			"crack":
				var w: float = float(o.w)
				var cpts := PackedVector2Array([Vector2(o.x, oy), Vector2(o.x + w * .3, oy + 90), Vector2(o.x + w * .5, oy + 150), Vector2(o.x + w * .7, oy + 95), Vector2(o.x + w, VH.sled_y(float(o.u) + w)), Vector2(o.x + w, bot), Vector2(o.x, bot)])
				# fenda em V no gelo: azul escuro sumindo no fundo
				var cc := PackedColorArray()
				for q in cpts:
					cc.push_back(Color("#2a4a6e").lerp(Color("#04080f"), clamp((q.y - oy) / 150.0, 0, 1)))
				if not Spr.has("p_fenda"):
					Spr.ci.draw_polygon(cpts.slice(0, 5), cc.slice(0, 5))
				if Spr.has("p_fenda"):
					# fenda pintada: paredes de gelo azul com neve nas beiradas e pingentes
					var fk: float = (w + 4.0) / 174.0
					var fw: float = 660.0 * fk
					Spr.PR("fenda", o.x + w / 2.0 - fw * .5, oy - 42.0 * fk, fw, 688.0 * fk)
				else:
					# bordas de gelo rachado
					Spr.poly(PackedVector2Array([Vector2(o.x - 8, oy - 2), Vector2(o.x + 10, oy), Vector2(o.x + 4, oy + 30), Vector2(o.x - 8, oy + 40)]), Color(.75, .88, 1))
					var ey: float = VH.sled_y(float(o.u) + w)
					Spr.poly(PackedVector2Array([Vector2(o.x + w + 8, ey - 2), Vector2(o.x + w - 10, ey), Vector2(o.x + w - 4, ey + 30), Vector2(o.x + w + 8, ey + 40)]), Color(.75, .88, 1))
				# bandeirinha vermelha avisando antes da rachadura
				var fx: float = o.x - 170
				var fy: float = VH.sled_y(float(o.u) - 170)
				if Spr.has("p_flagred"):
					Spr.save()
					Spr.translate(fx, fy + 4)
					Spr.rotate(sin(T * .1) * .03)
					Spr.P("flagred", 0, 0, 44)
					Spr.restore()
				else:
					Spr.PR("stake", fx - 4, fy - 56, 8, 58, Color(.85, .8, .75))
					Spr.poly(PackedVector2Array([Vector2(fx + 3, fy - 56), Vector2(fx + 30, fy - 48 + sin(T * .2) * 3), Vector2(fx + 3, fy - 38)]), Color("#e0463a"))
	# placas antes de cada obstáculo: seta verde para cima (pular) ou laranja para baixo (abaixar)
	for o in VH.OBS:
		if o.k == "bump":
			continue
		var su0: float = float(o.u) - 260.0
		var sx0: float = t0 + su0
		if sx0 < a - 80 or sx0 > b + 80:
			continue
		_ground_sign(sx0, VH.sled_y(su0), o.k != "branch", T)
	# monte de neve no fim, onde o trenó para
	var ex: float = t0 + ln - 40
	var eyy: float = VH.sled_y(ln - 40)
	if Spr.has("p_snowpile"):
		Spr.P("snowpile", ex, eyy + 8, 170)
	else:
		Spr.ellipse(ex, eyy - 10, 70, 30, Color(.84, .9, 1))
		Spr.ellipse(ex - 6, eyy - 16, 60, 24, Color(.98, .99, 1))

## placa fincada na neve com a seta do que fazer (trenó)
static func _ground_sign(x: float, gy: float, up: bool, T: int) -> void:
	Spr.ellipse(x, gy + 2, 16, 4, Color(.7, .78, .9, .6))
	Spr.save()
	Spr.translate(x, gy + 6)
	Spr.rotate(sin(T * .04 + x) * .02 - .04)
	if Spr.has("p_signup"):
		Spr.P("signup" if up else "signdown", 0, 0, 60)
	else:
		# placa redonda de madeira com uma seta grande: verde para cima (pular), laranja para baixo (abaixar)
		Spr.PR("stake", -4, -62, 8, 64, Color(.85, .8, .75))
		Spr.circle(0, -80, 24, Color("#3a2414"))
		Spr.circle(0, -80, 21, Color("#c99a5e"))
		Spr.circle(0, -80, 17, Color("#fff6e2"))
		var c := Color("#2f9a3a") if up else Color("#e0701e")
		var d: float = -1.0 if up else 1.0
		var ar := PackedVector2Array([Vector2(0, -80 + d * 14), Vector2(-12, -80 + d * 1), Vector2(-5, -80 + d * 1), Vector2(-5, -80 - d * 13), Vector2(5, -80 - d * 13), Vector2(5, -80 + d * 1), Vector2(12, -80 + d * 1)])
		Spr.poly(ar, c)
		ar.push_back(ar[0])
		Spr.line(ar, Color(.15, .1, .05, .9), 1.5)
		Spr.ellipse(0, -103, 16, 4, Color(.97, .98, 1))
	Spr.restore()

## galho baixo de pinheiro coberto de neve com pingentes (trenó); y = linha do galho
static func _snow_branch(x: float, y: float, T: int, broken: bool) -> void:
	if Spr.has("p_galhoneve2"):
		Spr.P("galhoneve2", x + 6, y + 18, 156)
		return
	WorldNature.prop("galho_neve", x + 38, y + 96, 130, true)
	# pingentes de gelo pendurados até a altura da cabeça
	for k in 5:
		var ix: float = x - 34 + k * 16
		var ln: float = 10 + (k * 7 % 4) * 3
		Spr.poly(PackedVector2Array([Vector2(ix - 3, y + 4), Vector2(ix, y + 4 + ln), Vector2(ix + 3, y + 4)]), Color(.82, .93, 1, .95))

## plaquinha de madeira boiando na corredeira com a seta do que fazer
static func _float_sign(x: float, wy: float, up: bool, T: int) -> void:
	var bob: float = sin(T * .08 + x) * 2.0
	Spr.save()
	Spr.translate(x, wy + 4 + bob)
	Spr.rotate(sin(T * .05 + x) * .05)
	Spr.PR("stake", -4, -58, 8, 62, Color(.85, .8, .75))
	Spr.P("sign", 0, -30, 54)
	var c := Color("#3f8f3a") if up else Color("#d26a22")
	var d: float = -1.0 if up else 1.0
	Spr.poly(PackedVector2Array([Vector2(0, -60 + d * 14), Vector2(-12, -60 - d * 2), Vector2(-5, -60 - d * 2), Vector2(-5, -60 - d * 14), Vector2(5, -60 - d * 14), Vector2(5, -60 - d * 2), Vector2(12, -60 - d * 2)]), c)
	Spr.line(PackedVector2Array([Vector2(0, -60 + d * 14), Vector2(-12, -60 - d * 2), Vector2(-5, -60 - d * 2), Vector2(-5, -60 - d * 14), Vector2(5, -60 - d * 14), Vector2(5, -60 - d * 2), Vector2(12, -60 - d * 2), Vector2(0, -60 + d * 14)]), Color(.15, .1, .05, .9), 1.5)
	Spr.ellipse(0, 0, 14, 3, Color(1, 1, 1, .35))
	Spr.restore()

## galho grosso do pântano por cima do rio, com cipós e barbas de musgo até a altura da cabeça
static func _vinebranch(x: float, oy: float, T: int) -> void:
	# ilhota com o tronco da árvore à esquerda
	Spr.P("mossrock_l", x - 70, oy + 14, 90)
	Spr.ci.draw_texture_rect(Spr.tex.tronco, Rect2(x - 100, oy - 260, 60, 262), false, Color(.6, .62, .5))
	if Spr.has("p_galhorio"):
		var r: Array = Spr.AR["p_galhorio"]
		var w: float = 230.0
		var h: float = w * r[3] / r[2]
		# a ponta dos cipós fica na altura da cabeça do Tomé em pé (oy - 44)
		Spr.PR("galhorio", x - 70, oy - 44 - h, w, h)
	else:
		Spr.save()
		Spr.translate(x - 80, oy - 112)
		Spr.rotate(.04)
		Spr.PR("log", 0, -12, 24, 230, Color(.6, .62, .5))
		Spr.restore()
		for k in 9:
			var vx: float = x - 40 + k * 22
			var sw: float = sin(T * .04 + k) * 3.0
			var top: float = oy - 104
			Spr.line(PackedVector2Array([Vector2(vx, top), Vector2(vx + sw * .5, top + 30), Vector2(vx + sw, oy - 46 - (k % 3) * 4)]), Color("#4f7a34"), 2.5)
			Spr.ellipse(vx + sw, oy - 48 - (k % 3) * 4, 4, 6, Color("#6b8c3a"))


# ======================================================================
#  CARRINHO DE MINA (Episódio 2): o passeio do trenó nos trilhos, dentro da mina
# ======================================================================
static func _cart(x: float, y: float, w: float = 96.0) -> void:
	Spr.ellipse(x, y + 1, w * .42, 4, Color(0, 0, 0, .3))
	Spr.AB("mi_cart", x - w / 2, y - w * .72, w, w * .72)

static func _cart_world(g: Game, VH: Vehicles, T: int) -> void:
	var SL: Dictionary = VH.SL
	if float(SL.x1) < g.cam - 300 or float(SL.x) > g.cam + g.W + 300:
		return
	var gy: float = float(SL.y)
	if VH.mode != "sled" and not VH.sled_done:
		_cart(float(SL.x), gy)
		var p: Dictionary = g.player
		if abs(p.x + p.w / 2 - float(SL.x)) < 120 and (T / 20) % 2 == 0:
			Spr.text("✦ CARRINHO", float(SL.x), gy - 84 + sin(T * .15) * 3, 16, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	elif VH.sled_done and VH.mode != "sled":
		_cart(float(SL.x1) - 40, gy)

static func _cart_rider(g: Game, VH: Vehicles, p: Dictionary, T: int) -> void:
	var on_g: bool = VH.hy >= VH.sled_y(VH.su) - 1
	Spr.save()
	Spr.translate(VH.hx, VH.hy + 2)
	if p.dyingT > 0:
		Spr.rotate(-p.dyingT * .12)
	elif VH.crashT > 0:
		Spr.rotate(VH.sang + sin(VH.crashT * .5) * .25 * VH.crashT / 30.0)
	else:
		Spr.rotate(_tilt(VH.sang * (.3 if not on_g else 1.0)))
	# o Tomé dentro do carrinho (só a parte de cima aparece); abaixado some quase todo
	# (sacode de leve com os trilhos, mais quanto mais rápido)
	var jig: float = sin(T * .9) * clamp(VH.spd / 9.0, 0, 1) * .8 if on_g else 0.0
	if VH.duck:
		Spr.A("pai_crouch", -4, -44 + jig, .5)
	else:
		Spr.frame(Spr.tex.pai, 0, 170, 160, 85, 156, -4, -40 + jig, .46, false)
	_cart(0, 0, 100)
	Spr.restore()
	if VH.spd > 6.0:
		for k in 4:
			var ly: float = VH.hy - 14 - k * 11
			Spr.seg(VH.hx - 50 - k * 6, ly, VH.hx - 50 - VH.spd * 6 - k * 6, ly, Color(1, .85, .6, .1 * (VH.spd - 6.0)), 2)
	if p.iframe > 0 and (T / 5) % 2 == 0:
		Spr.glow(VH.hx, VH.hy - 34, 58, Color(1, .95, .75, .45))

const VG_PARK := 150.0     # o carrinho do Vargas para a esta distância do fim
const VG_DOOR := 40.0      # a porta de ferro fica depois do para-choque

## 0 = porta aberta ... 1 = fechada (a porta do fim dos trilhos)
static func _vg_door(VH: Vehicles, T: int) -> float:
	if VH.vg_t0 < 0:
		return 0.0
	return clamp(float(T - VH.vg_t0 - 112) / 20.0, 0.0, 1.0)

static func _vargas_run(g: Game, VH: Vehicles, T: int, t0: float, ln: float, a: float, b: float) -> void:
	var park: float = ln - VG_PARK
	var stop_u: float = ln - VH.VG_STOP
	var lead: float = VH.su + 560.0 + sin(T * .013) * 90.0
	var vu: float = lead
	if VH.vg_t0 >= 0:
		vu = park
	elif VH.su > stop_u - 1300.0:
		var k: float = clamp((VH.su - (stop_u - 1300.0)) / 1300.0, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		vu = min(lerpf(lead, park, k), park)
	var vx: float = t0 + vu
	var vy: float = VH.sled_y(vu)
	var el: int = T - VH.vg_t0 if VH.vg_t0 >= 0 else -1
	if vx > a - 300 and vx < b + 300:
		if el < 0:
			var f: int = (T / 5) % 2
			Spr.A("lia_scared", vx + 44, vy - 58, .5)
			Spr.A("vg_cart1" if f else "vg_cart2", vx, vy + 2, 1)
		else:
			# o carrinho vazio parado e o Vargas correndo até a porta com a Isis debaixo do braço
			_empty_cart(vx, vy)
			var dx: float = t0 + ln + VG_DOOR + 30
			var u: float = clamp(float(el - 12) / 96.0, 0.0, 1.0)
			if el < 112:
				var mx: float = lerpf(vx + 40, dx, u)
				var hop: float = -sin(clamp(el / 14.0, 0, 1) * PI) * 40.0 if el < 14 else 0.0
				var my: float = VH.sled_y(min(mx - t0, ln - 10)) + hop
				_vargas_walk(mx, my, T, el)
				if el == 4 and Polish.FRESH:
					Audio.play("jump", -6)
			if el == 116 and Polish.FRESH:
				Audio.play("door", -2, .6)
				g.shake = max(g.shake, 5)
				g.burst(dx, my_floor(VH, ln), 18, Color(.7, .65, .6))

static func _end_door(VH: Vehicles, T: int, x: float, gy: float) -> void:
	var h: float = 170.0
	var w: float = 92.0
	# batente de pedra
	Spr.rect(x - 22, gy - h - 26, w + 44, h + 26, Color("#3a3430"))
	Spr.rect(x - 22, gy - h - 26, w + 44, 6, Color("#5a524a"))
	# vão escuro
	Spr.rect(x, gy - h, w, h, Color("#060404"))
	var c: float = _vg_door(VH, T)
	# folha de ferro: aberta (de lado, estreita) até bater fechada
	var fw: float = lerpf(14.0, w, c)
	Spr.rect(x, gy - h, fw, h, Color("#4a4c52"))
	Spr.rect(x, gy - h, fw, 5, Color("#7a7c84"))
	for k in 4:
		Spr.rect(x, gy - h + 20 + k * 40, fw, 4, Color("#2e3034"))
	if c > .7:
		Spr.text("V", x + w / 2, gy - h / 2 + 12, 40, Color(.7, .7, .74, (c - .7) / .3), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 3, Color(0, 0, 0, .6))
		Spr.circle(x + w - 16, gy - h / 2, 6, Color("#8a8c92"))

static func my_floor(VH: Vehicles, ln: float) -> float:
	return VH.sled_y(ln - 10)

static func _empty_cart(x: float, y: float) -> void:
	# carrinho de ferro parado, vazio
	Spr.rr(x - 46, y - 46, 92, 36, 6, Color("#4a4a52"))
	Spr.rr(x - 46, y - 46, 92, 8, 4, Color("#6a6a74"))
	Spr.rect(x - 40, y - 34, 80, 2, Color(0, 0, 0, .3))
	for wx in [x - 26, x + 26]:
		Spr.circle(wx, y - 8, 9, Color("#222226"))
		Spr.circle(wx, y - 8, 4, Color("#77777e"))

## o Vargas a pé (capacete de mineiro com lampião, capote marrom) carregando a Isis
static func _vargas_walk(x: float, y: float, T: int, el: int) -> void:
	# o Vargas correndo (arte do Gemini) com a Isis debaixo do braço, esperneando
	Spr.ellipse(x, y + 1, 26, 5, Color(0, 0, 0, .35))
	# passadas: o corpo sobe e desce a cada passo
	var bob: float = -abs(sin(el * .35)) * 4.0
	Spr.sheet("vargas_pe", 5, 200, 200, x, y + 2 + bob, 124.0, false)
	Spr.save()
	Spr.translate(x + 2, y - 50 + bob)
	Spr.rotate(-.2 + sin(T * .5) * .1)
	Spr.sheet("isis2", 6, 150, 150, 0, 22, 70.0, false)
	Spr.restore()

static func _cart_track(g: Game, VH: Vehicles, T: int) -> void:
	var t0: float = VH.sled_tx0()
	var ln: float = float(VH.SL.get("len", 4650))
	var a: float = max(t0 - 600, g.cam - 80)
	var b: float = min(t0 + ln + 2400, g.cam + g.W + 80)
	if a >= b:
		return
	var bot: float = g.cam_y + g.H + 400
	var topc: float = g.cam_y - 200
	var ROCK := Color("#2a1d14")
	var ROCK2 := Color("#140d08")
	var WOOD := Color("#5a3a1e")
	# teto da galeria (rocha escura) acompanhando os trilhos, com pontas
	var ceil := PackedVector2Array([Vector2(a - 12, topc)])
	var x: float = floor(a / 24.0) * 24.0
	while x <= b + 24:
		var cy: float = VH.sled_y(x - t0) - 250 - 22 * WorldStatic_hh(floor(x / 24.0), 3)
		ceil.push_back(Vector2(x, cy))
		x += 24
	ceil.push_back(Vector2(b + 24, topc))
	Spr.poly(ceil, ROCK2)
	# escoras de madeira (dois postes e uma viga) a cada 320 px
	var su0: float = floor((a - t0) / 320.0) * 320.0
	while t0 + su0 < b + 100:
		var gy: float = VH.sled_y(su0)
		var px: float = t0 + su0
		Spr.rect(px - 52, gy - 240, 12, 240, WOOD)
		Spr.rect(px + 40, gy - 240, 12, 240, WOOD)
		Spr.rect(px - 60, gy - 246, 120, 14, Color("#6b4524"))
		Spr.seg(px - 46, gy - 234, px - 46, gy - 4, Color(0, 0, 0, .3), 2)
		if int(su0 / 320.0) % 2 == 0:
			# lampião pendurado na viga
			var sw: float = sin(T * .04 + su0) * 3
			Spr.seg(px, gy - 232, px + sw, gy - 205, Color(.2, .2, .2), 1.5)
			Spr.glow(px + sw, gy - 196, 70, Color(1, .7, .3, .35))
			Spr.circle(px + sw, gy - 198, 6, Color(1, .85, .45))
		su0 += 320
	# corpo de rocha embaixo dos trilhos
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	x = floor(a / 12.0) * 12.0
	while x <= b + 12:
		pts.push_back(Vector2(x, VH.sled_y(x - t0) + 6))
		cols.push_back(ROCK)
		x += 12
	var top := pts.duplicate()
	pts.push_back(Vector2(b + 12, bot))
	cols.push_back(ROCK2)
	pts.push_back(Vector2(a - 12, bot))
	cols.push_back(ROCK2)
	# os buracos nos trilhos cortam o chão (desenhados depois, por cima)
	Spr.ci.draw_polygon(pts, cols)
	# terra com pedras e pepitas (a textura do chão da mina), escurecendo para baixo
	var gt: Texture2D = Spr.tex.get("chao_mina", null)
	if gt:
		var tw: float = 64.0
		var cx: float = floor(a / tw) * tw
		var ts: Vector2 = gt.get_size()
		while cx < b + tw:
			var ya: float = VH.sled_y(cx - t0) + 4
			var yb: float = VH.sled_y(cx + tw - t0) + 4
			var u0: float = fposmod(cx, ts.x - tw) / ts.x
			var u1: float = u0 + tw / ts.x
			var row := 0
			var o: float = 0.0
			while ya + o < bot and row < 12:
				var m: float = clamp(.85 - row * .07, .25, .85)
				var c := Color(m, m * .95, m * .9)
				var hh_: float = 90.0 if row == 0 else 76.0
				var v0: float = (40.0 if row == 0 else 72.0) / ts.y
				var v1: float = v0 + hh_ / ts.y
				Spr.ci.draw_polygon(PackedVector2Array([Vector2(cx, ya + o), Vector2(cx + tw + 1, yb + o), Vector2(cx + tw + 1, yb + o + hh_), Vector2(cx, ya + o + hh_)]),
					PackedColorArray([c, c, c, c]), PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]), gt)
				o += hh_ - 1.0
				row += 1
			cx += tw
	# dormentes e trilhos
	var sx: float = floor(a / 26.0) * 26.0
	while sx < b:
		var sy: float = VH.sled_y(sx - t0)
		Spr.rect(sx - 8, sy - 3, 16, 7, Color("#4a3018"))
		sx += 26
	var rail := PackedVector2Array()
	for q in top:
		rail.push_back(q + Vector2(0, -9))
	Spr.line(rail, Color("#8a8a92"), 3)
	var rail2 := PackedVector2Array()
	for q in top:
		rail2.push_back(q + Vector2(0, -7))
	Spr.line(rail2, Color("#3a3a40"), 1.5)
	# obstáculos (o destaque verde/laranja é o mesmo do trenó)
	for o in VH.OBS:
		if o.x < a - 160 or o.x > b + 160:
			continue
		var oy: float = VH.sled_y(float(o.u))
		var ft: int = o.get("ft", -1) if o.hit else -1
		if not o.hit and o.k != "bump":
			var pul: float = .5 + .5 * sin(T * .15 + o.x)
			if o.k == "branch":
				Spr.glow(o.x + 5, oy - 62, 92, Color(1, .45, .05, .4 + .25 * pul))
			else:
				Spr.glow(o.x + (float(o.get("w", 0)) * .5), oy - 18, 62, Color(.2, 1, .3, .22 + .18 * pul))
				for k in 2:
					var u: float = fposmod(T * .025 + k * .5, 1.0)
					var ay: float = oy - 50 - u * 40
					var ax: float = o.x + float(o.get("w", 0)) * .5
					Spr.line(PackedVector2Array([Vector2(ax - 12, ay + 9), Vector2(ax, ay), Vector2(ax + 12, ay + 9)]), Color(.25, .95, .35, sin(u * PI) * .95), 5)
		match o.k:
			"rock":
				if ft >= 0:
					for k in 4:
						Spr.P("peb%d" % (k % 3), o.x - 22 + k * 15, oy + 3, 14, false, 0.0, Color(.6, .55, .5))
				else:
					Spr.P("rock0", o.x, oy + 8, 50, false, 0.0, Color(.62, .58, .55))
			"log":
				if ft < 0 or ft < 40:
					var dy: float = 0.0 if ft < 0 else ft * ft * .2
					Spr.save()
					Spr.translate(o.x, oy - 12 + dy)
					Spr.rotate(.08 if ft < 0 else ft * .1)
					Spr.rr(-34, -9, 68, 18, 5, Color("#6b4524"))
					Spr.rr(-34, -9, 68, 5, 3, Color("#8a5e34"))
					Spr.restore()
			"branch":
				# escora baixa do túnel: o teto de rocha desce até uma viga presa em dois esteios.
				# Não dá para pular por cima (a rocha vai até o teto): só passa abaixado (↓)
				var fall: float = 0.0
				if ft >= 0:
					fall = min(float(ft), 40.0)
					fall = fall * fall * .25
				var by: float = oy - 66
				# o teto baixo de rocha em cima da viga (fica no lugar mesmo depois da batida)
				var rk := PackedVector2Array([Vector2(o.x - 70, oy - 260), Vector2(o.x + 80, oy - 260), Vector2(o.x + 72, by - 30),
					Vector2(o.x + 50, by - 6), Vector2(o.x - 40, by - 6), Vector2(o.x - 62, by - 28)])
				Spr.poly(rk, Color("#2a1d14"))
				Spr.line(PackedVector2Array([Vector2(o.x - 62, by - 28), Vector2(o.x - 40, by - 6), Vector2(o.x + 50, by - 6), Vector2(o.x + 72, by - 30)]), Color("#4a3a2c"), 4)
				for k in 4:
					Spr.ellipse(o.x - 40 + k * 28, by - 16 - (k % 2) * 10, 10, 7, Color("#3a2c20"))
				# esteios dos dois lados do trilho
				for px in [o.x - 50, o.x + 48]:
					Spr.rect(px, by - 6, 12, oy - by + 6, Color("#4a3018"))
					Spr.rect(px + 2, by - 6, 3, oy - by + 6, Color(1, .85, .6, .15))
				if ft < 0 or ft < 40:
					Spr.save()
					Spr.translate(0, fall)
					Spr.rr(o.x - 56, by - 4, 122, 22, 4, Color("#6b4524"))
					# faixas de perigo amarelas e pretas na viga
					var stx: float = o.x - 52
					while stx < o.x + 60:
						Spr.poly(PackedVector2Array([Vector2(stx, by + 16), Vector2(stx + 8, by - 2), Vector2(stx + 16, by - 2), Vector2(stx + 8, by + 16)]), Color(1, .8, .1, .9))
						stx += 16
					Spr.restore()
				if ft < 0:
					# placa "ABAIXE" pendurada na viga e setas piscando para baixo
					var pul2: float = .55 + .45 * sin(T * .2)
					Spr.seg(o.x - 2, by + 18, o.x - 2, by + 26, Color("#222"), 2)
					Spr.rr(o.x - 34, by + 26, 64, 20, 4, Color(1, .82, .15, .95))
					Spr.text("↓ ABAIXE", o.x - 2, by + 41, 12, Color(.15, .1, .05), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
					for k in 2:
						var u2: float = fposmod(T * .025 + k * .5, 1.0)
						var ay2: float = oy - 150 + u2 * 30
						Spr.line(PackedVector2Array([Vector2(o.x - 210 - 14, ay2 - 12), Vector2(o.x - 210, ay2), Vector2(o.x - 210 + 14, ay2 - 12)]), Color(1, .6, .1, sin(u2 * PI) * pul2), 6)
					# placa de aviso antes da viga, num poste
					var wx: float = o.x - 210
					var wy: float = VH.sled_y(float(o.u) - 210)
					Spr.rect(wx - 3, wy - 92, 6, 92, Color("#4a3018"))
					Spr.poly(PackedVector2Array([Vector2(wx, wy - 120), Vector2(wx + 24, wy - 96), Vector2(wx, wy - 72), Vector2(wx - 24, wy - 96)]), Color(1, .8, .1))
					Spr.text("↓", wx, wy - 86, 22, Color(.1, .08, .05), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
			"crack":
				# trilho quebrado sobre um buraco escuro
				var w: float = float(o.w)
				var ey: float = VH.sled_y(float(o.u) + w)
				Spr.poly(PackedVector2Array([Vector2(o.x, oy - 12), Vector2(o.x + w, ey - 12), Vector2(o.x + w, bot), Vector2(o.x, bot)]), Color(0, 0, 0))
				Spr.seg(o.x - 2, oy - 9, o.x + 10, oy + 4, Color("#8a8a92"), 3)
				Spr.seg(o.x + w + 2, ey - 9, o.x + w - 10, ey + 6, Color("#8a8a92"), 3)
				# lampião vermelho de aviso antes do buraco
				var fx: float = o.x - 170
				var fy: float = VH.sled_y(float(o.u) - 170)
				Spr.rect(fx - 3, fy - 56, 6, 56, WOOD)
				Spr.glow(fx, fy - 62, 34, Color(1, .2, .1, .4 + .2 * sin(T * .2)))
				Spr.circle(fx, fy - 62, 6, Color(1, .3, .2))
	# o carrinho do Vargas, sempre um pouco à frente (com a Isis); perto do fim ele dispara,
	# para no fim dos trilhos, salta com a Isis e entra pela porta de ferro, que bate antes de o Tomé chegar
	if VH.SL.get("vargas") and VH.mode == "sled":
		_vargas_run(g, VH, T, t0, ln, a, b)
	# a porta de ferro no fim dos trilhos (o Vargas passa por ela e ela bate)
	if VH.SL.get("vargas"):
		_end_door(VH, T, t0 + ln + VG_DOOR, VH.sled_y(ln - 10))
	# para-choque de madeira no fim dos trilhos
	var ex: float = t0 + ln - 10
	var eyy: float = VH.sled_y(ln - 10)
	Spr.rect(ex, eyy - 46, 18, 46, WOOD)
	Spr.rect(ex - 6, eyy - 40, 30, 10, Color("#8a2a1a"))
