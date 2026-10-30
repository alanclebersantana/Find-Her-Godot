extends RefCounted
class_name WorldEp3
## Desenho dos chefes do Episódio 3 (Ep3Bosses): enguia de cristal, salamandra de fogo (com as caixas
## d'água e as correntes nos balcões) e o guardião de ferro, mais bolas de fogo e ondas de choque.

static func draw(g: Game, T: int) -> void:
	if g.K == null or g.K.B3 == null or g.K.B3.B.is_empty():
		return
	var B3: Ep3Bosses = g.K.B3
	for b in B3.B:
		if float(b.x1) < g.cam - 400 or float(b.x0) > g.cam + g.W + 400:
			continue
		match b.id:
			"enguia":
				_eel(g, B3, b, T)
			"salamandra":
				_tanks(g, B3, b, T)
				_sal(g, B3, b, T)
			"guardiao":
				_gua(g, B3, b, T)
	for s in B3.SHOTS:
		if s.k == "fire":
			Spr.glow(s.x, s.y, 46, Color(1, .5, .1, .55))
			Spr.circle(s.x, s.y, 15, Color("#1a0a04"))
			Spr.circle(s.x, s.y, 12, Color("#ff7a1a"))
			Spr.circle(s.x - s.vx * .6, s.y - s.vy * .6, 7, Color("#ffd76a"))
		else:
			# onda de choque: uma lombada de terra e pedrinhas correndo pelo chão
			var d: float = sign(s.vx)
			var pts := PackedVector2Array()
			for i in 13:
				var u: float = i / 12.0
				pts.append(Vector2(s.x - 26 * d + u * 52 * d, s.y - sin(u * PI) * (30 + 4 * sin(T * .6))))
			pts.append(Vector2(s.x + 26 * d, s.y + 2))
			pts.append(Vector2(s.x - 26 * d, s.y + 2))
			Spr.poly(pts, Color("#1a120c"))
			var inner := PackedVector2Array()
			for i in 13:
				var u2: float = i / 12.0
				inner.append(Vector2(s.x - 22 * d + u2 * 44 * d, s.y - sin(u2 * PI) * 24))
			inner.append(Vector2(s.x + 22 * d, s.y))
			inner.append(Vector2(s.x - 22 * d, s.y))
			Spr.poly(inner, Color("#8a6a4a"))

## desenho virado para o lado (a arte olha para a direita)
static func _img(n: String, cx: float, by: float, k: float, dir: float, ax: float = .5, tint: Color = Color(1, 1, 1), al: float = 1.0, rot: float = 0.0, ay: float = 1.0) -> void:
	var t: Texture2D = Spr.opt(n)
	if t == null:
		return
	var w: float = t.get_width() * k
	var h: float = t.get_height() * k
	Spr.save()
	Spr.translate(cx, by)
	if rot != 0.0:
		Spr.rotate(rot)
	Spr.scale(dir, 1)
	Spr.ci.draw_texture_rect(t, Rect2(-ax * w, -ay * h, w, h), false, Color(tint.r, tint.g, tint.b, tint.a * al * Spr.alpha))
	Spr.restore()

static func _stars(x: float, y: float, T: int) -> void:
	for i in 3:
		var a := T * .15 + TAU * i / 3.0
		Spr.text("★", x + cos(a) * 34, y + sin(a) * 8, 16, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

static func _tint(b: Dictionary, T: int) -> Color:
	var c := Color(1, .5, .45) if b.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1)
	return c * Polish.fury(int(b.hp))

# ---------------------------------------------------------------- enguia
static func _eel(g: Game, B3: Ep3Bosses, b: Dictionary, T: int) -> void:
	var k := Ep3Bosses.K_EEL
	var surf: float = float(b.surf)
	var tint := _tint(b, T)
	var d: float = float(b.dir)
	match b.st:
		"wait", "intro", "swim", "fight0", "warn":
			if b.st == "wait" and not b.active:
				# esperando: só um vulto brilhando debaixo d'água, de vez em quando
				if (T / 90) % 3 != 0:
					return
			# nadando debaixo d'água: vulto azulado e um rastro de bolhas
			var sx: float = b.x if b.st != "wait" else float(b.home) + sin(T * .01) * 300.0
			_img("b3_eel_0", sx, surf + 64 + sin(T * .08) * 3, k * .9, d if b.st != "wait" else (1.0 if cos(T * .01) > 0 else -1.0), .5, Color(.6, 1, 1), .38)
			Spr.glow(sx, surf + 26, 80, Color(.5, 1, 1, .12))
			if b.st == "warn":
				var tx: float = float(b.tx)
				var pul: float = .5 + .5 * sin(T * .5)
				Spr.glow(tx, surf, 90, Color(.6, 1, 1, .25 + .2 * pul))
				Spr.ellipse(tx, surf + 1, 46 + 8 * pul, 6, Color(.85, 1, 1, .6))
				if (T / 8) % 2 == 0:
					Spr.text("!", tx, float(b.ptop) - 70, 30, Color("#bff6ff"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
		"leap":
			var ang: float = float(b.get("ang", 0.0))
			var rot: float = ang if d > 0 else ang - PI
			_img("b3_eel_1", b.x, b.y, k * .72, d, .55, tint, 1.0, rot, .5)
			Spr.glow(b.x, b.y, 70, Color(.6, 1, 1, .25))
		"stun", "hurt":
			_img("b3_eel_2", b.x, float(b.ptop) + 8, k * .92, d, .5, tint)
			if b.st == "stun":
				_stars(b.x, float(b.ptop) - 110, T)
				if (T / 10) % 2 == 0:
					Spr.text("!", b.x, float(b.ptop) - 140, 26, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
		"dive":
			_img("b3_eel_2", b.x, b.y + 8, k * .92, d, .5, tint, clamp(1.0 - (b.y - float(b.ptop)) / 90.0, 0.0, 1.0))
		"down", "gone":
			# de barriga para cima, boiando na cisterna
			var by: float = surf + 26 + sin(T * .05) * 2
			_img("b3_eel_3", b.x, by, k, d, .5, Color(1, 1, 1), .9)
	if b.st in ["swim", "warn", "fight0"] and T % 12 == 0:
		Polish.part("drop", b.x + randf_range(-30, 30), surf - 1, 0, -randf_range(.5, 1.2), 18, Color(.85, 1, 1, .7))

# ---------------------------------------------------------------- salamandra
static func _sal_frame(n: int, cx: float, by: float, dir: float, tint: Color, al: float = 1.0) -> void:
	var t: Texture2D = Spr.opt("b3_sal_%d" % n)
	if t == null:
		return
	var k := Ep3Bosses.K_SAL
	# alinha o focinho de todos os quadros: o corpo não pula ao trocar de quadro
	var snout: float = Ep3Bosses.SAL_SNOUT[n]
	var ax: float = (snout - 236.0) / t.get_width()
	_img("b3_sal_%d" % n, cx, by, k, dir, ax, tint, al)

static func _sal(g: Game, B3: Ep3Bosses, b: Dictionary, T: int) -> void:
	var tint := _tint(b, T)
	var d: float = float(b.dir)
	var by: float = float(b.y) + 4
	var fire: bool = b.st in ["wait", "intro", "fight0", "walk", "breath", "hurt", "flee"]
	if fire:
		Spr.glow(b.x, b.y - 70, 170, Color(1, .45, .1, .22 + .06 * sin(T * .3)))
	Spr.ellipse(b.x, b.y + 2, 130, 10, Color(0, 0, 0, .35))
	match b.st:
		"wait", "intro", "fight0", "walk", "flee":
			var f: int = [0, 3][(T / (6 if b.st == "flee" else 12)) % 2]
			if b.st in ["walk", "flee"]:
				by += -abs(sin(T * .26)) * 3
			_sal_frame(f, b.x, by, d, tint)
		"breath":
			var f2: int = 1 if b.t > 10 else 0
			_sal_frame(f2, b.x, by, d, tint)
			if b.t < 34:
				var m: Vector2 = B3.sal_mouth(b)
				Spr.glow(m.x, m.y, 30 + b.t, Color(1, .7, .2, .5))
		"cool":
			var f3: int = [2, 4][(T / 20) % 2]
			_sal_frame(f3, b.x, by, d, tint)
			_stars(b.x + d * 90, b.y - 150, T)
		"relight":
			# o fogo voltando: pisca entre cinza e vermelha
			_sal_frame(0 if (b.t / 4) % 2 == 0 else 2, b.x, by, d, tint)
		"hurt":
			_sal_frame(0, b.x, by, d, tint)
		"down", "gone":
			_sal_frame(5, b.x, by, d, Color(1, 1, 1))

static func _tanks(g: Game, B3: Ep3Bosses, b: Dictionary, T: int) -> void:
	var near: Dictionary = B3.near_lever()
	var ceil_y: float = float(b.get("ceil", -200))
	for t in B3.TANKS:
		var x: float = float(t.x)
		var y: float = float(t.y)
		# correntes do teto até a caixa
		for cx in [x - 44, x + 44]:
			var cy: float = ceil_y
			while cy < y - 96:
				Spr.ring(cx, cy + 6, 4, Color("#2a2420"), 3)
				cy += 11
		# a caixa d'água (tonel de madeira com aros de ferro); vira um pouco ao despejar
		var tilt: float = 0.0
		if t.st == "pour":
			tilt = .35 * clamp(t.t / 8.0, 0.0, 1.0) * clamp((56.0 - t.t) / 10.0, 0.0, 1.0)
		Spr.save()
		Spr.translate(x, y - 50)
		Spr.rotate(tilt)
		Spr.rr(-60, -50, 120, 100, 10, Color("#120c08"))
		Spr.rr(-55, -45, 110, 90, 8, Color("#7a5232"))
		for i in 4:
			Spr.rect(-50 + i * 28, -45, 3, 90, Color("#5e3e24"))
		for ry in [-34, 0, 30]:
			Spr.rect(-58, ry, 116, 7, Color("#3a3a40"))
			Spr.rect(-58, ry, 116, 2, Color("#6a6a74"))
		# o nível da água (vista pela tampa aberta)
		var lvl: float = 1.0
		if t.st == "pour":
			lvl = 1.0 - clamp(t.t / 46.0, 0.0, 1.0)
		elif t.st == "fill":
			lvl = clamp(t.t / 220.0, 0.0, 1.0)
		Spr.rr(-50, -52, 100, 10, 4, Color("#120c08"))
		Spr.rr(-46, -50, 92 * lvl, 6, 3, Color("#7fd0ff"))
		Spr.restore()
		if B3.water_on(t):
			# o jorro até o chão
			var top: float = y
			var bot: float = float(b.y)
			Spr.rect(x - 40, top, 80, bot - top, Color(.55, .8, 1, .55))
			Spr.rect(x - 26, top, 52, bot - top, Color(.75, .92, 1, .45))
			for i in 6:
				var sy: float = top + fmod(T * 14.0 + i * 50.0, bot - top)
				Spr.rect(x - 30 + i * 11, sy, 3, 26, Color(1, 1, 1, .6))
			Spr.ellipse(x, bot - 4, 70, 12, Color(.8, .95, 1, .6))
		# a corrente de puxar, no balcão
		var lx: float = float(t.lever)
		var py: float = float(t.py)
		Spr.seg(lx, py - 70, x - 50, y - 70, Color("#2a2420"), 3)
		Spr.rect(lx - 4, py - 76, 8, 76, Color("#3a2a1a"))
		Spr.circle(lx, py - 78, 7, Color("#1a120c"))
		Spr.circle(lx, py - 78, 5, Color("#c09a4a"))
		var ready: bool = t.st == "full"
		if ready and b.active and not b.done:
			Spr.glow(lx, py - 60, 26, Color(1, .9, .5, .25 + .15 * sin(T * .2)))
		if not near.is_empty() and near == t:
			var lbl: String = "✦ PUXE A CORRENTE" if ready else "enchendo..."
			Spr.text(lbl, lx, py - 104 + sin(T * .15) * 3, 18, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)

# ---------------------------------------------------------------- guardião
static func _gua(g: Game, B3: Ep3Bosses, b: Dictionary, T: int) -> void:
	var k := Ep3Bosses.K_GUA
	var tint := _tint(b, T)
	var d: float = float(b.dir)
	var by: float = float(b.y) + 4
	if b.st not in ["down", "gone"]:
		Spr.ellipse(b.x, b.y + 2, 90, 10, Color(0, 0, 0, .4))
	match b.st:
		"wait", "intro", "fight0":
			_img("b3_gua_0", b.x, by, k, d, .5, tint)
		"walk":
			var f: int = (T / 16) % 2
			_img("b3_gua_%d" % f, b.x, by, k, d, .5, tint)
		"raise":
			# ergue o corpo e o olho fica vermelho (aviso)
			_img("b3_gua_0", b.x, by - min(b.t, 12.0), k, d, .5, tint)
			Spr.glow(b.x + d * 26, b.y - 240, 40 + 10 * sin(T * .6), Color(1, .15, .1, .6))
		"slam", "stuck":
			_img("b3_gua_2", b.x, by, k, d, .5, tint)
			if b.st == "stuck":
				_stars(b.x, b.y - 260, T)
				if (T / 10) % 2 == 0:
					Spr.text("⛏", b.x - d * 40, b.y - 300, 26, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
		"hurt":
			_img("b3_gua_3", b.x, by, k, d, .5, tint)
		"down", "gone":
			_img("b3_gua_4", b.x, by, k, d, .5, Color(1, 1, 1))
