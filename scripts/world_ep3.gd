extends RefCounted
class_name WorldEp3
## Desenho dos chefes do Episódio 3 (Ep3Bosses): enguia de cristal, salamandra de fogo (com as caixas
## d'água e as correntes nos balcões) e o guardião de ferro, mais bolas de fogo e ondas de choque.

static func draw(g: Game, T: int) -> void:
	if g.L.has("vargasSpawn"):
		_bridge(g, T)
	if g.L.has("isisTrain"):
		_train_inside(g, T)
	if g.L.has("isisBrake"):
		_brake(g, T)
	for w in g.L.get("water", []):
		if w.get("zap") and float(w.x) < g.cam + g.W + 200 and float(w.x) + float(w.w) > g.cam - 200:
			_zap_fx(w, T)
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
			"vargas":
				_vargas(g, B3, b, T)
	for s in B3.SHOTS:
		if s.k == "barrel":
			if s.t < 0:
				continue
			Spr.save()
			Spr.translate(s.x, s.y - 22)
			Spr.rotate(float(s.get("rot", 0.0)))
			Spr.circle(0, 0, 24, Color("#1a120c"))
			Spr.circle(0, 0, 20, Color("#8a5a2a"))
			Spr.rect(-20, -3, 40, 6, Color("#3a3a40"))
			Spr.rect(-3, -20, 6, 40, Color("#6a4424"))
			Spr.circle(0, 0, 6, Color("#3a3a40"))
			Spr.restore()
			continue
		if s.k == "coal":
			Spr.circle(s.x, s.y, 11, Color("#0c0a0a"))
			Spr.circle(s.x - 3, s.y - 3, 7, Color("#2a2626"))
			Spr.circle(s.x - 4, s.y - 4, 2, Color(.6, .6, .65))
			continue
		if s.k == "patch" or s.k == "flame":
			var lf: float = clamp(1.0 - (s.t - float(s.get("life", 60)) + 30.0) / 30.0, 0.0, 1.0)
			var gr: float = clamp(s.t / 10.0, 0.0, 1.0)
			Spr.glow(s.x, s.y - 10, 60, Color(1, .45, .1, .4 * lf * gr))
			for j in 4:
				var fh: float = (18 + 10 * sin(T * .4 + j * 1.7 + s.x)) * gr * lf
				var fx: float = s.x - 27 + j * 18
				Spr.poly(PackedVector2Array([Vector2(fx - 10, s.y), Vector2(fx + 10, s.y), Vector2(fx + sin(T * .3 + j) * 3, s.y - fh)]), Color(1, .45, .1, .9 * lf))
				Spr.poly(PackedVector2Array([Vector2(fx - 5, s.y), Vector2(fx + 5, s.y), Vector2(fx, s.y - fh * .6)]), Color(1, .85, .35, .9 * lf))
			continue
		if s.k == "rock":
			var bgy: float = float(B3.boss("guardiao").get("y", 500))
			if s.t <= 0:
				# aviso: sombra no chão e poeirinha caindo
				var sk: float = clamp(1.0 + s.t / 40.0, 0.2, 1.0)
				Spr.ellipse(s.x, bgy + 1, 10 + 16 * sk, 4, Color(0, 0, 0, .3 + .3 * sk))
				if T % 6 == 0:
					Polish.part("drop", s.x + randf_range(-10, 10), bgy - 400, 0, 2, 30, Color(.6, .55, .5, .7))
			else:
				Spr.circle(s.x, s.y, 20, Color("#1a120c"))
				Spr.circle(s.x, s.y, 16, Color("#7a6a5a"))
				Spr.circle(s.x - 5, s.y - 5, 6, Color("#9a8a7a"))
			continue
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

## os vagões parados em cima da ponte, ao amanhecer (a luta com o Vargas): vagões pintados (do mesmo trem
## da estação), o vagão de carvão aberto e a locomotiva com a Isis trancada na cabine
static func _bridge(g: Game, T: int) -> void:
	var br: Dictionary = g.L.get("bridge", {})
	if br.is_empty():
		return
	var x0: float = float(br.x0)
	var ry: float = float(br.y)
	var wl: float = float(br.wl)
	var ci: int = int(br.coal)
	if x0 + wl * 6 < g.cam - 300 or x0 - 600 > g.cam + g.W + 300:
		return
	var vt: Texture2D = Spr.opt("vagao3")
	var bt: Texture2D = Spr.opt("vagao3_base")
	var tr: Texture2D = Spr.opt("trem3")
	var k: float = wl / 380.0                 # escala da pintura (o vagão tem ~380 px de engate a engate)
	var top: float = ry - 12.0 * k            # o teto curvo fica na linha do chão do Tomé
	var vh: float = 251.0 * k
	var rails: float = top + vh - 8.0
	# a ponte de cavaletes de madeira e o rio lá embaixo
	var bx0: float = x0 - 700
	var bx1: float = x0 + wl * 6 + 700
	Spr.rect(bx0, rails + 4, bx1 - bx0, 16, Color("#2a1a10"))
	Spr.rect(bx0, rails + 6, bx1 - bx0, 9, Color("#6a4424"))
	Spr.rect(bx0, rails, bx1 - bx0, 5, Color("#3a3a40"))
	var tx: float = floor(bx0 / 150.0) * 150.0
	while tx < bx1:
		for d in [[0, 75], [150, 75]]:
			Spr.seg(tx + d[0], rails + 20, tx + d[1], rails + 330, Color("#2a1a10"), 8)
			Spr.seg(tx + d[0], rails + 20, tx + d[1], rails + 330, Color("#6a4424"), 4)
		Spr.seg(tx, rails + 120, tx + 150, rails + 120, Color("#2a1a10"), 6)
		Spr.seg(tx, rails + 120, tx + 150, rails + 120, Color("#5a3a20"), 3)
		tx += 150.0
	# os vagões de passageiros (0..ci-1), o vagão de carvão (ci) e a locomotiva
	for i in ci:
		var wx: float = x0 + i * wl - 5.0 * k
		if vt:
			Spr.ci.draw_texture_rect(vt, Rect2(wx, top, 390.0 * k, vh), false, Color(1, 1, 1, Spr.alpha))
	var cx: float = x0 + ci * wl - 5.0 * k
	if bt:
		Spr.ci.draw_texture_rect(bt, Rect2(cx, top + vh - 41.0 * k, 390.0 * k, 41.0 * k), false, Color(1, 1, 1, Spr.alpha))
	# o vagão de carvão: caixa de ferro aberta, cheia de carvão
	var cb: float = top + vh - 38.0 * k
	var ct: float = ry + 34.0
	Spr.rr(cx + 30 * k, ct, 330 * k, cb - ct, 6, Color("#1a1612"))
	Spr.rr(cx + 30 * k + 4, ct + 4, 330 * k - 8, cb - ct - 8, 4, Color("#4a4e56"))
	for r in 3:
		Spr.rect(cx + 30 * k + 4, ct + 18 + r * (cb - ct - 30) / 2.0, 330 * k - 8, 4, Color("#2a2e34"))
	for q in 12:
		Spr.circle(cx + 50 * k + q * 26 * k, ct + 4 + sin(q * 2.3) * 5, 17 * k + (q % 3) * 3, Color("#141218"))
	# a locomotiva (pintura do mesmo trem), com a Isis na janela da cabine
	if tr:
		var lx: float = x0 + (ci + 1) * wl - 20.0 * k
		var lw: float = 450.0 * k
		var src := Rect2(750, 0, 450, 371)
		var lh: float = 371.0 * k
		Spr.ci.draw_texture_rect_region(tr, Rect2(lx, top + vh - lh, lw, lh), src, Color(1, 1, 1, Spr.alpha))
		# a cabine: o maquinista fugiu; a Isis trancada lá dentro, espiando pela janela
		var oy: float = top + vh - lh
		isis_peek(Rect2(lx + 48 * k, oy + 166 * k, 32 * k, 52 * k), T)
		Spr.rect(lx + 86 * k, oy + 166 * k, 26 * k, 50 * k, Color("#2a1a12"))
		Spr.rect(lx + 86 * k, oy + 166 * k, 26 * k, 50 * k, Color(1, .75, .4, .35))
		# a fumaça parada subindo devagar
		for pf in 4:
			var u: float = fmod(T * .4 + pf * 50.0, 200.0) / 200.0
			Spr.circle(lx + lw * .72 - u * 40, top + vh - lh * .8 - u * 160, 14 + u * 26, Color(.95, .93, .9, .45 * (1.0 - u)))
	# luz do amanhecer batendo nos vagões
	Spr.glow(x0 + wl * 2, ry - 100, 700, Color(1, .7, .45, .07))

## a Isis espiando por uma janela (rosto e mãos no vidro), enquadrada no retângulo da janela
static func isis_peek(r: Rect2, T: int) -> void:
	Spr.rect(r.position.x, r.position.y, r.size.x, r.size.y, Color("#3a2414"))
	Spr.rect(r.position.x, r.position.y, r.size.x, r.size.y, Color(1, .78, .45, .55))
	var t: Texture2D = Spr.opt("isis_scared")
	if t:
		var src := Rect2(12, 0, 52, 52)
		var w: float = r.size.x * 1.05
		var hh: float = w * src.size.y / src.size.x
		var bob: float = sin(T * .08) * .8
		var dst := Rect2(r.position.x + (r.size.x - w) / 2, r.end.y - hh + 2 + bob, w, hh)
		# recorta no vidro (não passa da moldura)
		if dst.position.y < r.position.y:
			var cut: float = (r.position.y - dst.position.y) / hh
			src = Rect2(src.position.x, src.position.y + src.size.y * cut, src.size.x, src.size.y * (1.0 - cut))
			dst = Rect2(dst.position.x, r.position.y, dst.size.x, dst.size.y * (1.0 - cut))
		Spr.ci.draw_texture_rect_region(t, dst, src, Color(1, 1, 1, Spr.alpha))
	# o reflexo do vidro e a travessa da janela por cima
	Spr.rect(r.position.x, r.position.y + r.size.y * .42, r.size.x, maxf(1.5, r.size.y * .06), Color("#3a2414"))
	Spr.poly(PackedVector2Array([r.position, r.position + Vector2(r.size.x * .35, 0), r.position + Vector2(0, r.size.y * .3)]), Color(1, 1, 1, .18))

## dentro do trem: assoalho, teto, paredes do fim e as pilhas de malas (desenho leve, só o que está na tela)
static func _train_inside(g: Game, T: int) -> void:
	var it: Dictionary = g.L.isisTrain
	var cx0: float = g.cam - 40
	var cx1: float = g.cam + g.W + 40
	if float(it.x1) < cx0 or float(it.x0) > cx1:
		return
	var cy0: float = g.cam_y - 20
	for so in g.SOL:
		var t: String = str(so.get("t", ""))
		if not t in ["tremchao", "tremteto", "tremparede", "malas"]:
			continue
		var x0: float = maxf(float(so.x), cx0)
		var x1: float = minf(float(so.x) + float(so.w), cx1)
		if x1 <= x0:
			continue
		var y0: float = float(so.y)
		var y1: float = y0 + float(so.h)
		match t:
			"tremchao":
				Spr.rect(x0, y0, x1 - x0, y1 - y0, Color("#2a180c"))
				Spr.rect(x0, y0, x1 - x0, 10, Color("#6a4224"))
				Spr.rect(x0, y0 + 10, x1 - x0, 3, Color("#1a0e06"))
				var px: float = floor(x0 / 70.0) * 70.0
				while px < x1:
					Spr.rect(px, y0 + 1, 2, 9, Color("#3a2414"))
					px += 70.0
				# o trem balança: um friso de luz que corre pelo assoalho
				Spr.rect(x0, y0 + 2, x1 - x0, 2, Color(1, .8, .5, .12 + .05 * sin(T * .1)))
			"tremteto":
				var ty0: float = maxf(y0, cy0)
				Spr.rect(x0, ty0, x1 - x0, y1 - ty0, Color("#1e1208"))
				Spr.rect(x0, y1 - 22, x1 - x0, 22, Color("#4a2e18"))
				Spr.rect(x0, y1 - 4, x1 - x0, 4, Color("#c8a050"))
				var bx: float = floor(x0 / 250.0) * 250.0
				while bx < x1:
					Spr.rect(bx, y1 - 40, 14, 40, Color("#2a180c"))
					bx += 250.0
			"tremparede":
				Spr.rect(x0, y0, x1 - x0, y1 - y0, Color("#2a180c"))
				Spr.rect(x0 + 4, y0 + 10, maxf(0.0, x1 - x0 - 8), y1 - y0 - 20, Color("#5a3820"))
			"malas":
				# malas empilhadas até o teto, presas com correias (o vão de baixo fica livre)
				var cols := [Color("#8a4a2a"), Color("#6a5a3a"), Color("#7a2e22"), Color("#4a5a6a"), Color("#9a7a4a")]
				var yy: float = y1
				var row := 0
				while yy > y0 + 4:
					var hh: float = 34.0 + float((row * 7) % 3) * 6.0
					var xx: float = float(so.x) + float((row * 13) % 17) - 8.0
					var k := 0
					while xx < float(so.x) + float(so.w) - 10:
						var ww: float = 44.0 + float((row * 5 + k * 11) % 4) * 8.0
						ww = minf(ww, float(so.x) + float(so.w) - xx)
						var c: Color = cols[(row * 3 + k) % cols.size()]
						Spr.rr(xx, yy - hh, ww - 2, hh - 2, 5, Color("#1a0e06"))
						Spr.rr(xx + 3, yy - hh + 3, ww - 8, hh - 8, 4, c)
						Spr.rect(xx + ww * .45, yy - hh + 3, 4, hh - 8, Color(0, 0, 0, .25))
						xx += ww
						k += 1
					yy -= hh
					row += 1
				Spr.rect(float(so.x) + 20, y0, 6, y1 - y0, Color("#3a2414"))
				Spr.rect(float(so.x) + float(so.w) - 26, y0, 6, y1 - y0, Color("#3a2414"))

## a alavanca do freio na cabine da locomotiva (trecho da Isis no trem)
static func _brake(g: Game, T: int) -> void:
	var x: float = float(g.L.isisBrake.x)
	if x < g.cam - 200 or x > g.cam + g.W + 200:
		return
	var gy: float = float(g.L.isisBrake.y)
	var pulled: bool = g.brakeT >= 0 or (g.player and not g.player.get("isis"))
	# a fornalha da locomotiva brilhando atrás
	Spr.glow(x + 90, gy - 70, 120, Color(1, .5, .15, .25 + .05 * sin(T * .3)))
	Spr.rr(x + 50, gy - 120, 90, 120, 8, Color("#1a120c"))
	Spr.rr(x + 60, gy - 90, 70, 60, 30, Color(1, .45, .12, .9))
	# a base e a alavanca
	Spr.rr(x - 16, gy - 26, 32, 26, 4, Color("#1a120c"))
	Spr.rr(x - 12, gy - 22, 24, 20, 3, Color("#5a5e66"))
	var ang: float = -.5 if not pulled else .7
	Spr.save()
	Spr.translate(x, gy - 18)
	Spr.rotate(ang)
	Spr.rect(-4, -76, 8, 76, Color("#1a120c"))
	Spr.rect(-2, -74, 4, 72, Color("#a8241c"))
	Spr.circle(0, -78, 9, Color("#1a120c"))
	Spr.circle(0, -78, 6, Color("#e8c050"))
	Spr.restore()
	Spr.text("FREIO", x, gy - 110, 14, Color("#ffd76a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	if g.near_brake():
		Spr.text("✦", x, gy - 132 + sin(T * .2) * 4, 22, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
	if g.brakeT >= 0 and T % 3 == 0:
		Polish.part("drop", x + randf_range(-200, 200), gy + 4, randf_range(-3, 3), -randf_range(1, 4), 18, Color(1, .8, .3))

# ---------------------------------------------------------------- Vargas
static func _vargas(g: Game, B3: Ep3Bosses, b: Dictionary, T: int) -> void:
	var t: Texture2D = Spr.opt("vargas_boss")
	var tint := _tint(b, T)
	var d: float = float(b.dir)
	var fr := 0
	var bob := 0.0
	match b.st:
		"wait", "intro", "fight0", "idle":
			fr = 0
			bob = sin(T * .08) * 1.5
		"barrel", "coal":
			fr = 2 if b.t > 8 else 0
		"lamp":
			fr = 0
		"charge":
			fr = 3
			if b.t > 30:
				bob = -abs(sin(T * .5)) * 4
		"tired":
			fr = 4
		"hurt":
			fr = 4
		"down", "gone":
			fr = 5
	var by: float = float(b.y) + 4 + bob
	if b.st not in ["down", "gone"]:
		Spr.ellipse(b.x, float(b.get("y0", b.y)) + 2, 40, 6, Color(0, 0, 0, .3))
	if t != null:
		var s: float = Ep3Bosses.VG_H / 280.0
		Spr.save()
		Spr.translate(b.x, by)
		if b.st == "hurt":
			Spr.rotate(-d * .12)
		Spr.scale(s * d, s)
		Spr.ci.draw_texture_rect_region(t, Rect2(-150, -296, 300, 300), Rect2(fr * 300, 0, 300, 300), Color(tint.r, tint.g, tint.b, Spr.alpha))
		Spr.restore()
	# a lâmpada do capacete acendendo (aviso do clarão)
	var lamp := Vector2(b.x + d * 14, by - Ep3Bosses.VG_H * .86)
	if b.st == "lamp":
		var lt: int = int(b.get("lampT", 40))
		var k: float = clamp(float(b.t) / lt, 0.0, 1.0)
		if b.t < lt:
			Spr.glow(lamp.x, lamp.y, 30 + 90 * k, Color(1, .95, .6, .35 + .4 * k))
			if (T / 6) % 2 == 0:
				Spr.text("✦!", lamp.x, lamp.y - 46, 26, Color("#fff2a0"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
		elif b.t < lt + 14:
			Spr.glow(lamp.x, lamp.y, 420, Color(1, 1, .85, .7))
		if b.get("def", false):
			var p: Dictionary = g.player
			Spr.glow(p.x + p.w / 2 + p.face * 20, p.y + 20, 120, Color(1, .9, .5, .5))
	if b.st == "tired":
		_stars(b.x, by - Ep3Bosses.VG_H - 14, T)
		if (T / 10) % 2 == 0 and b.t >= 0:
			Spr.text("!", b.x, by - Ep3Bosses.VG_H - 46, 24, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
	if b.st == "charge" and b.t < 30:
		Spr.text("!", b.x, by - Ep3Bosses.VG_H - 30, 30, Color("#ff7a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
	# o clarão: o Tomé cego (tela branca que vai sumindo)
	if B3.blindT > 0:
		var a: float = clamp(B3.blindT / 60.0, 0.0, 1.0) * .88
		Spr.rect(g.cam - 50, g.cam_y - 50, g.W + 100, g.H + 100, Color(1, 1, .92, a))

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
## desenha só as partes do desenho que caem nos vãos de água (debaixo d'água ela passa POR TRÁS dos pilares)
static func _img_gaps(n: String, cx: float, by: float, k: float, dir: float, gaps: Array, tint: Color, al: float) -> void:
	var t: Texture2D = Spr.opt(n)
	if t == null:
		return
	var w: float = t.get_width() * k
	var h: float = t.get_height() * k
	Spr.save()
	Spr.translate(cx, by)
	Spr.scale(dir, 1)
	for gp in gaps:
		var l0: float = (float(gp[0]) - cx) * dir
		var l1: float = (float(gp[1]) - cx) * dir
		if l0 > l1:
			var tt: float = l0
			l0 = l1
			l1 = tt
		l0 = max(l0, -.5 * w)
		l1 = min(l1, .5 * w)
		if l1 - l0 < 1:
			continue
		var u0: float = (l0 + .5 * w) / w
		var u1: float = (l1 + .5 * w) / w
		Spr.ci.draw_texture_rect_region(t, Rect2(l0, -h, l1 - l0, h), Rect2(u0 * t.get_width(), 0, (u1 - u0) * t.get_width(), t.get_height()),
			Color(tint.r, tint.g, tint.b, tint.a * al * Spr.alpha))
	Spr.restore()

## o corpo esticado do vão (na água) até a cabeça (bote / dentes presos na pedra)
static func _eel_reach(b: Dictionary, surf: float, tint: Color, wob: float) -> void:
	var base := Vector2(b.x, surf + 26)
	var head := Vector2(float(b.hx), float(b.hy))
	var v: Vector2 = head - base
	var dist: float = max(40.0, v.length())
	var d: float = 1.0 if v.x >= 0 else -1.0
	var ang: float = v.angle() + wob
	var rot: float = ang if d > 0 else ang - PI
	var kk: float = clamp((dist + 24.0) / (909.0 * .92), .16, .62)
	_img("b3_eel_1", head.x, head.y, kk, d, .92, tint, 1.0, rot, .5)
	Spr.glow(head.x, head.y, 60, Color(.6, 1, 1, .22))

static func _eel(g: Game, B3: Ep3Bosses, b: Dictionary, T: int) -> void:
	var k := Ep3Bosses.K_EEL
	var surf: float = float(b.surf)
	var tint := _tint(b, T)
	var d: float = float(b.dir)
	var gaps: Array = B3._gaps(b)
	# a água proibida: faíscas elétricas correndo pela superfície e a placa
	if not b.done or b.st == "down":
		var wx0: float = float(b.get("wx0", b.x0))
		var wx1: float = float(b.get("wx1", b.x1))
		for i in 6:
			var ph: int = (T + i * 37) % 70
			if ph > 14:
				continue
			var gp: Array = gaps[(i * 3 + T / 70) % gaps.size()]
			var zx: float = lerpf(float(gp[0]) + 10, float(gp[1]) - 10, fmod(i * .37 + T * .0013 * (i + 1), 1.0))
			var zz := PackedVector2Array()
			for j in 6:
				zz.append(Vector2(zx - 18 + j * 7, surf - 2 - (j % 2) * 8 - randf() * 3))
			Spr.ci.draw_polyline(zz, Color(.75, 1, 1, .9 * (1.0 - ph / 15.0)), 2.0)
			Spr.glow(zx, surf - 4, 26, Color(.6, 1, 1, .3 * (1.0 - ph / 15.0)))
		if wx1 > wx0 and b.has("sign"):
			var sg: Array = b.sign
			_zap_sign(float(sg[0]), float(sg[1]), T)
	match b.st:
		"wait", "intro", "swim", "fight0":
			if b.st == "wait" and not b.active:
				if (T / 90) % 3 != 0:
					return
			var sx: float = b.x if b.st != "wait" else float(b.home) + sin(T * .01) * 300.0
			var sd: float = d if b.st != "wait" else (1.0 if cos(T * .01) > 0 else -1.0)
			# debaixo d'água: só aparece nos vãos entre os pilares
			_img_gaps("b3_eel_0", sx, surf + 64 + sin(T * .08) * 3, k * .9, sd, gaps, Color(.6, 1, 1), .42)
		"warn":
			var pul: float = .5 + .5 * sin(T * .55)
			_img_gaps("b3_eel_0", b.x, b.y + 70, k * .9, d, gaps, tint, .95)
			# a crista acende: o aviso do bote
			Spr.glow(float(b.hx), float(b.hy), 70 + 20 * pul, Color(.6, 1, 1, .3 + .3 * pul))
			Spr.glow(b.x, surf, 90, Color(.6, 1, 1, .18 + .15 * pul))
			if (T / 7) % 2 == 0:
				Spr.text("!", B3._pc(b, int(b.tp)), float(b.ptop) - 74, 30, Color("#bff6ff"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
		"lunge":
			_eel_reach(b, surf, tint, 0.0)
		"stuck", "hurt":
			var wob: float = sin(T * .6) * .06 if b.st == "stuck" else 0.0
			_eel_reach(b, surf, tint, wob)
			if b.st == "stuck":
				_stars(float(b.hx), float(b.hy) - 50, T)
				if (T / 10) % 2 == 0 and int(b.get("hits_now", 0)) == 0:
					Spr.text("!", float(b.hx), float(b.hy) - 84, 26, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
		"dive":
			if float(b.hy) < surf + 30:
				_eel_reach(b, surf, tint, 0.0)
		"down", "gone":
			var by: float = surf + 26 + sin(T * .05) * 2
			_img("b3_eel_3", b.x, by, k, d, .5, Color(1, 1, 1), .9)
	if b.st in ["swim", "warn", "fight0"] and T % 12 == 0:
		Polish.part("drop", b.x + randf_range(-30, 30), surf - 1, 0, -randf_range(.5, 1.2), 18, Color(.85, 1, 1, .7))

## a água que dá choque: faíscas correndo pela superfície entre os pilares, e a placa
static func _zap_fx(w: Dictionary, T: int) -> void:
	var surf: float = float(w.y)
	var gaps: Array = []
	var a: float = float(w.x)
	for px0 in w.get("pillars", []):
		gaps.append([a, float(px0)])
		a = float(px0) + float(w.get("pw", 90))
	gaps.append([a, float(w.x) + float(w.w)])
	for i in 6:
		var ph: int = (T + i * 37) % 70
		if ph > 14:
			continue
		var gp: Array = gaps[(i * 3 + T / 70) % gaps.size()]
		var zx: float = lerpf(float(gp[0]) + 10, float(gp[1]) - 10, fmod(i * .37 + T * .0013 * (i + 1), 1.0))
		var zz := PackedVector2Array()
		for j in 6:
			zz.append(Vector2(zx - 18 + j * 7, surf - 2 - (j % 2) * 8 - randf() * 3))
		Spr.ci.draw_polyline(zz, Color(.75, 1, 1, .9 * (1.0 - ph / 15.0)), 2.0)
		Spr.glow(zx, surf - 4, 26, Color(.6, 1, 1, .3 * (1.0 - ph / 15.0)))
	if w.has("sign"):
		var sg: Array = w.sign
		_zap_sign(float(sg[0]), float(sg[1]), T)

## placa na beira da cisterna: NÃO ENTRE NA ÁGUA
static func _zap_sign(x: float, y: float, T: int) -> void:
	Spr.rect(x - 3, y - 70, 6, 70, Color("#1a120c"))
	Spr.rect(x - 1, y - 68, 2, 68, Color("#7a5232"))
	Spr.rr(x - 82, y - 118, 164, 54, 6, Color("#1a120c"))
	Spr.rr(x - 78, y - 114, 156, 46, 4, Color("#f2d24a"))
	var zz := PackedVector2Array([Vector2(x - 68, y - 104), Vector2(x - 60, y - 92), Vector2(x - 66, y - 90), Vector2(x - 56, y - 76)])
	Spr.ci.draw_polyline(zz, Color("#1a120c"), 3.0)
	Spr.text("NÃO ENTRE NA ÁGUA", x + 8, y - 96, 13, Color("#1a120c"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
	Spr.text("DÁ CHOQUE!", x + 8, y - 78, 15, Color("#b0201a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)

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
	var fire: bool = b.st in ["wait", "intro", "fight0", "walk", "breath", "hurt", "flee", "flare"]
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
		"flare":
			# ergue a cabeça; o balcão de cima esquenta (aviso) e a coluna de fogo sobe
			_sal_frame(1 if b.t > 20 else 0, b.x, by, d, tint)
			var fx: float = float(b.flx)
			var top: float = float(b.y) - 420
			if b.t < 34:
				var pk: float = .5 + .5 * sin(T * .6)
				Spr.glow(fx, float(b.y) - 160, 70 + b.t * 2, Color(1, .45, .1, .2 + .25 * pk))
				if (T / 6) % 2 == 0:
					Spr.text("!", fx, float(b.y) - 230, 30, Color("#ffb04a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
			elif b.t < 70:
				var w: float = 40 + 8 * sin(T * .7)
				Spr.glow(fx, float(b.y) - 200, 160, Color(1, .5, .1, .45))
				Spr.rr(fx - w, top, w * 2, float(b.y) - top, w, Color(1, .4, .08, .75))
				Spr.rr(fx - w * .5, top + 20, w, float(b.y) - top - 20, w * .5, Color(1, .85, .35, .85))
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
