extends RefCounted
class_name WorldKings
## Desenho do Gavião-Rei e do Bagre-Rei.

static func _crown(x: float, y: float, s: float) -> void:
	var gold := Color("#e8b030")
	var pts := PackedVector2Array([Vector2(x - 14 * s, y), Vector2(x - 14 * s, y - 10 * s), Vector2(x - 7 * s, y - 4 * s),
		Vector2(x, y - 14 * s), Vector2(x + 7 * s, y - 4 * s), Vector2(x + 14 * s, y - 10 * s), Vector2(x + 14 * s, y)])
	Spr.poly(pts, gold)
	Spr.ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#5a3a10"), 2, true)
	Spr.circle(x, y - 5 * s, 2.6 * s, Color("#e0463a"))

static func draw(g: Game, T: int) -> void:
	var K: Kings = g.K
	if K == null:
		return
	_hawk(g, K, T)
	_bear(g, K, T)

## o bagre é desenhado na camada de cima (depois da água), para não sumir no fundo escuro
static func draw_fish(g: Game, T: int) -> void:
	if g.K:
		_fish(g, g.K, T)

static func _hawk(g: Game, K: Kings, T: int) -> void:
	var h: Dictionary = K.HAWK
	if h.is_empty() or h.done or h.st == "wait":
		return
	# sombra do mergulho no chão
	var sh := K.hawk_shadow()
	if sh.x > 0:
		var k: float = sh.y
		var pul: float = .8 + sin(T * .4) * .2
		Spr.ellipse(sh.x, h.gy + 2, 74 * k * pul, 15 * k, Color(0, 0, 0, .6 * k))
		Spr.ellipse(sh.x, h.gy + 2, 40 * k * pul, 8 * k, Color(0, 0, 0, .5 * k))
		Spr.ring(sh.x, h.gy - 1, 60 * k * pul, Color(1, .3, .2, .8 * k), 3, PI, TAU)
	var fr: int = (T / 5) % 3
	var sc := 1.5
	var rot := 0.0
	match h.st:
		"dive":
			fr = 1
			rot = .5 * (1 if h.tx > h.sx else -1)
		"stuck":
			fr = (T / 3) % 3
		"mark":
			fr = (T / 4) % 3
	var tint := Color(1, .5, .45) if h.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1)
	var y: float = h.y - (6 if h.st == "stuck" else 50)
	Spr.save()
	Spr.translate(h.x, y)
	Spr.rotate(rot)
	Spr.scale(h.dir * sc, sc)
	Spr.ci.draw_texture_rect_region(Spr.tex.gaviao, Rect2(-66, -96, 132, 124), Rect2(fr * 132, 0, 132, 124), Color(tint.r, tint.g, tint.b, Spr.alpha))
	Spr.restore()
	_crown(h.x + h.dir * 14, y - 112, 1.2)
	if h.st == "stuck":
		# garras presas na madeira
		for i in 3:
			Spr.seg(h.x - 10 + i * 10, h.gy - 4, h.x - 8 + i * 10, h.gy + 6, Color("#3a2414"), 3)
		if (T / 10) % 2 == 0:
			Spr.text("!", h.x, y - 150, 30, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
	if h.st == "flee":
		for i in 3:
			var a := T * .15 + TAU * i / 3.0
			Spr.text("★", h.x + cos(a) * 40, y - 120 + sin(a) * 10, 16, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

static func _fish(g: Game, K: Kings, T: int) -> void:
	var f: Dictionary = K.FISH
	if f.is_empty() or f.done and f.st != "down":
		return
	if f.st == "wait":
		return
	# lama revolvida
	if f.mud > .02:
		for i in 9:
			var mx: float = f.x0 + (f.x1 - f.x0) * (i + .5) / 9.0 + sin(T * .02 + i) * 30
			var my: float = f.y1 - 60 - (i % 3) * 70 + cos(T * .03 + i * 2) * 20
			Spr.circle(mx, my, 120 + (i % 2) * 40, Color(.32, .26, .14, .28 * f.mud))
	var fr: int = (T / 7) % 4
	match f.st:
		"suck":
			if f.mouth > .3:
				fr = 4
		"tired":
			fr = 5
		"down":
			fr = 6
	var a: float = f.al * (clamp(1.0 - f.t / 160.0, 0, 1) if f.st == "down" else 1.0)
	var tint := Color(1, .55, .5) if f.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1)
	Spr.save()
	Spr.translate(f.x, f.y)
	Spr.scale(f.dir, 1)
	Spr.ci.draw_texture_rect_region(Spr.tex.bagre, Rect2(-140, -80, 280, 160), Rect2(fr * 280, 0, 280, 160), Color(tint.r, tint.g, tint.b, Spr.alpha * a))
	Spr.restore()
	# escamas azuis = pontos fracos: brilham quando ele cansa; as que já caíram viram marca escura
	if f.st != "down":
		var pts: Array = K.scale_pts()
		for i in 4:
			var p: Vector2 = pts[i]
			if not f.scales[i]:
				Spr.ellipse(p.x, p.y, 7, 6, Color(.24, .22, .12, a))
				Spr.seg(p.x - 4, p.y - 3, p.x + 4, p.y + 3, Color(.08, .06, .03, a), 1.5)
			elif f.st == "tired":
				Spr.glow(p.x, p.y, 24 + sin(T * .3 + i) * 4, Color(.55, 1, 1, .6 * a))
				Spr.ellipse(p.x, p.y, 6, 5, Color(.75, 1, 1, a))
	# sucção: linhas de água entrando na boca
	if f.st == "suck" and f.t > 30:
		var mx2: float = f.x + f.dir * 118
		for i in 6:
			var u: float = fmod(T * .04 + i / 6.0, 1.0)
			var r: float = 160 * (1.0 - u)
			var ang: float = (i - 2.5) * .25
			Spr.seg(mx2 + f.dir * cos(ang) * r, f.y + sin(ang) * r, mx2 + f.dir * cos(ang) * (r - 26), f.y + sin(ang) * (r - 26), Color(.8, .95, 1, .5), 2)
	if f.st == "aim" and (T / 6) % 2 == 0:
		Spr.text("!", f.x, f.y - 100, 32, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)

## portões de pedra das arenas
static func gate(s: Dictionary, T: int) -> void:
	var y: float = s.y
	while y < s.y + s.h:
		var hh: float = min(46.0, s.y + s.h - y)
		Spr.rr(s.x - 8, y, s.w + 16, hh - 2, 10, Color("#5e5a52"))
		Spr.rect(s.x - 4, y + 4, s.w + 8, 6, Color(1, 1, 1, .1))
		y += 44

## Urso-Pardo-Rei (arte em assets/sprites/urso.png: 0-1 andando, 2 em pé, 3 patada, 4 tonto, 5 derrotado)
static func _bear(g: Game, K: Kings, T: int) -> void:
	var b: Dictionary = K.BEAR
	if b.is_empty() or b.done or b.st == "wait":
		return
	if not Spr.tex.has("urso"):
		Spr.tex["urso"] = load("res://assets/sprites/urso.png")
	var fr: int = int(b.anim * 2.0) % 2
	var rot := 0.0
	var dy := 0.0
	var warn := false
	match b.st:
		"rear", "rear2", "shake":
			fr = 2
			warn = b.st != "shake"
		"slam", "quake":
			fr = 3
		"dizzy":
			fr = 4
		"scrape":
			fr = int(T / 6) % 2
			rot = .12
			dy = 6
			warn = true
		"charge":
			fr = int(b.anim * 2.0) % 2
			rot = .16
			dy = 8
		"skid":
			fr = 0
			rot = -.1
		"backoff":
			if b.t >= 24:
				fr = 2
				warn = true
	var tint := Color(1, .55, .5) if b.red > 0 and (T / 3) % 2 == 0 else Color(1, 1, 1)
	var k: float = .35 + .25 * sin(T * .5)
	# avisos no chão: patada (à frente), tremor (dos dois lados)
	if b.st == "rear":
		var paw: Rect2 = K.bear_paw()
		Spr.ellipse(paw.position.x + paw.size.x / 2, b.gy + 1, paw.size.x / 2, 9, Color(1, .25, .15, k))
	if b.st == "rear2":
		Spr.ellipse(b.x, b.gy + 1, 300, 10, Color(1, .3, .15, k * .7))
	if b.st == "scrape":
		Spr.seg(b.x + b.dir * 100, b.gy - 2, b.x + b.dir * 420, b.gy - 2, Color(1, .3, .15, k), 5)
	Spr.ellipse(b.x, b.gy + 2, 100, 12, Color(0, 0, 0, .28))
	Spr.save()
	var sway: float = sin(T * .9) * 5.0 if b.st == "shake" else 0.0
	Spr.translate(b.x + sway, b.gy + 2 + b.get("hy", 0.0) + dy)
	if b.st in ["rear", "rear2"]:
		Spr.translate(0, -sin(min(1.0, b.t / 20.0) * PI * .5) * 6)
	Spr.scale(b.dir, 1)
	Spr.rotate(rot)
	Spr.ci.draw_texture_rect_region(Spr.tex.urso, Rect2(-140, -228, 280, 230), Rect2(fr * 280, 0, 280, 230), Color(tint.r, tint.g, tint.b, Spr.alpha))
	Spr.restore()
	# pata(s) erguida(s) brilhando antes de bater
	if b.st == "rear":
		Spr.glow(b.x + b.dir * 62, b.gy - 176, 34 + 6 * k, Color(1, .45, .2, .55 + .3 * k))
	if b.st == "rear2":
		for sd in [-1.0, 1.0]:
			Spr.glow(b.x + sd * 50, b.gy - 190, 32 + 6 * k, Color(1, .45, .2, .55 + .3 * k))
	if b.st == "charge":
		for i in 4:
			var ly: float = b.gy - 30 - i * 22
			Spr.seg(b.x - b.dir * (110 + i * 6), ly, b.x - b.dir * (170 + i * 10), ly, Color(1, 1, 1, .55), 3)
	# ondas do tremor: uma onda de neve correndo pelo chão
	for w in b.get("waves", []):
		var wx: float = w.x
		Spr.ellipse(wx, b.gy - 6, 26, 18, Color(.98, .99, 1, .95))
		Spr.ellipse(wx - w.d * 18, b.gy - 3, 18, 10, Color(.85, .92, 1, .9))
		Spr.ring(wx, b.gy - 8, 22, Color(1, .4, .2, .5), 2, PI, TAU)
		if T % 3 == 0:
			g.PARTS.append({"x": wx, "y": b.gy - 18, "vx": w.d * 1.0, "vy": -2.0, "life": 16, "col": Color(.97, .98, 1, .9)})
	# o galho tremendo antes do urso derrubar quem está nele
	var br = b.get("br")
	if b.st == "shake" and br != null:
		var tr: float = sin(T * 1.3) * 3.0
		for i in 3:
			var lx: float = br.x + br.w * (.2 + i * .3)
			Spr.seg(lx + tr, br.y - 10, lx - tr, br.y - 20, Color(1, 1, 1, .8), 2)
		if (T / 6) % 2 == 0:
			Spr.text("!", br.x + br.w * .5, br.y - 40, 26, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
	if b.st == "dizzy":
		for i in 3:
			var a := T * .12 + TAU * i / 3.0
			Spr.text("★", b.x + cos(a) * 34, b.gy - 150 + sin(a) * 8, 16, Color("#ffe27a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	if warn and (T / 6) % 2 == 0:
		Spr.text("!", b.x, b.gy - 240, 34, Color("#ff6a4a"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5)
