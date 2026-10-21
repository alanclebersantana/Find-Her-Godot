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
	var sc := 2.1
	var a: float = f.al * (clamp(1.0 - f.t / 160.0, 0, 1) if f.st == "down" else 1.0)
	var tint := Color(1, .55, .5) if f.red > 0 and (T / 3) % 2 == 0 else Color(.78, .9, .95)
	Spr.save()
	Spr.translate(f.x, f.y)
	if f.st == "down":
		Spr.rotate(PI * min(1.0, f.t / 40.0))
	Spr.scale(f.dir * sc, sc)
	Spr.ci.draw_texture_rect_region(Spr.tex.bagre, Rect2(-61, -38, 122, 76), Rect2(fr * 122, 0, 122, 76), Color(tint.r, tint.g, tint.b, Spr.alpha * a))
	# bigodes do bagre
	var wv := sin(T * .1) * 3
	var wc := Color(.2, .18, .08, a)
	Spr.line(PackedVector2Array([Vector2(44, 8), Vector2(62, 16 + wv), Vector2(78, 12 + wv * 1.5)]), wc, 2.2)
	Spr.line(PackedVector2Array([Vector2(44, 12), Vector2(58, 26 - wv), Vector2(70, 34 - wv)]), wc, 2.2)
	Spr.line(PackedVector2Array([Vector2(40, 14), Vector2(50, 30 + wv), Vector2(56, 40 + wv)]), wc, 1.8)
	# boca aberta (sugando)
	if f.mouth > 0:
		Spr.ellipse(50, 8, 9 * f.mouth, 11 * f.mouth, Color(.08, .05, .04, a))
	Spr.restore()
	_crown(f.x + f.dir * 10, f.y - 72, 1.4 * a + .01)
	# escamas que brilham (pontos fracos)
	var pts: Array = K.scale_pts()
	for i in 4:
		if not f.scales[i]:
			continue
		var p: Vector2 = pts[i]
		var weak: bool = f.st == "tired"
		var k: float = (1.0 if weak else .25) * a
		if weak:
			Spr.glow(p.x, p.y, 26 + sin(T * .3 + i) * 4, Color(.55, 1, 1, .55))
		Spr.ellipse(p.x, p.y, 9, 7, Color(.6, .95, 1, k))
		Spr.ellipse(p.x - 2, p.y - 2, 3, 2, Color(1, 1, 1, k))
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
