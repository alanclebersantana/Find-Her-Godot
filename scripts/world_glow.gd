extends Node2D
## Camada acima da escuridão: lápis, objetos, pistas e desenhos brilham mesmo à noite.
## Também desenha o que fica na frente do Tomé (água do brejo e moitas).

var game: Game

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or not game.L:
		return
	var g := game
	var T := g.T
	var x0 := g.cam - 60
	var x1 := g.cam + g.W + 60
	Spr.begin(self)
	for c in g.COINS:
		if c.got or c.x < x0 or c.x > x1:
			continue
		var pen: String = "pen_" + GameData.PEN_LIST[int(c.ci) % 6]
		if c.ry > 0:
			# lápis caído no chão, cada um num ângulo
			var ang: float = 1.25 + (int(c.ci) * 37 % 40) / 100.0
			if int(c.ci) % 2 == 1:
				ang = -ang
			Spr.ellipse(c.x, c.ry - 1, 13, 2.5, Color(0, 0, 0, .25))
			Spr.save()
			Spr.translate(c.x, c.ry - 5)
			Spr.rotate(ang)
			Spr.A(pen, 0, 0, .62)
			Spr.restore()
			if (T + int(c.ci) * 23) % 140 < 8:
				Spr.glow(c.x + 6, c.ry - 7, 10, Color(1, 1, .85, .7))
		else:
			var b := sin(T * .1 + c.x * .05) * 3
			Spr.A(pen, c.x, c.y + b, .62)
	for c in g.CLK:
		if not c.got:
			if c.ry > 0:
				Spr.glow(c.x, c.ry - 18, 26, Color(.75, .88, 1, .35 + sin(T * .08) * .15))
				Spr.ellipse(c.x, c.ry - 1, 12, 3, Color(0, 0, 0, .28))
				Spr.A("hourglass", c.x, c.ry, .48)
			else:
				Spr.A("hourglass", c.x, c.y + 16 + sin(T * .08 + c.x) * 3, .48)
	for d in g.DRWS:
		if not d.got:
			Spr.glow(d.x, d.y, 34, Color(1, .94, .78, .45))
			Spr.save()
			Spr.translate(d.x, d.y + sin(T * .06) * 3)
			Spr.rotate(sin(T * .04 + d.x) * .12)
			Spr.A("drawing", 0, 0, .6)
			Spr.restore()
	for it in g.ITEMS:
		if it.got:
			continue
		_ground_obj("it_" + it.id, it, .6, Color(1, .94, .74, .5), false)
	for c in g.CLUES:
		if c.got:
			continue
		var flat: bool = int(c.id) in [2, 3, 4, 6]
		var cy: float = _ground_obj("cl_%d" % int(c.id), c, .55, Color(.67, .86, 1, .6), flat)
		Spr.text("?", c.x + 17, cy - 18 + sin(T * .12) * 2, 15, Color("#e8f4ff"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	for s in g.SPECS:
		if s.got:
			continue
		var b4 := sin(T * .09 + s.x) * 4
		var sy: float = s.y + b4 if s.ry < 0 else s.ry - 22 + b4 * .5
		Spr.glow(s.x, sy, 30 + sin(T * .2) * 3, Color(1, 1, 1, .4))
		Spr.A("pen_" + s.c, s.x, sy, 1.05)
		if T % 10 == 0:
			g.PARTS.append({"x": s.x + (randf() - .5) * 20, "y": sy, "vx": 0, "vy": -.6, "life": 20, "col": GameData.PEN_COL[s.c]})
	# água do brejo (na frente do pai: ele afunda nela)
	for s in g.SWAMP:
		var a: float = max(s.x, x0)
		var b5: float = min(s.x + s.w, x1)
		if b5 <= a:
			continue
		var depth: float = max(40, (s.y0 + 300) - s.y)
		Spr.vgrad(a, s.y + 50, b5 - a, depth, Color(.24, .32, .2, .82), Color(.08, .12, .09, .95))
		Spr.strip_at("sw_water", s.x, a, b5, s.y - 6, 70, .92)
		var pts := PackedVector2Array()
		var x := a
		while x <= b5:
			pts.push_back(Vector2(x, s.y + sin(x * .04 + T * .06) * 2))
			x += 10
		Spr.line(pts, Color(.7, .82, .63, .55), 2)
		# esta camada não escurece sozinha: acompanha a escuridão do trecho
		Spr.rect(a, s.y - 8, b5 - a, depth + 60, Color(.02, .03, .08, g.AMB.dark * .75))
		if g.AMB.rain > .3:
			for k in 6:
				var rx: float = a + fmod(T * 13 + k * 97, b5 - a)
				var rr := 4 + (T + k * 5) % 12
				Spr.ci.draw_arc(Vector2(rx, s.y + 2), rr, 0, TAU, 16, Color(.86, .92, .86, .5), 1.2)
	# moitas (escondem passagens)
	var p: Dictionary = g.player
	for bsh in g.BUSH:
		var near: bool = abs(p.x + p.w / 2 - (bsh.x + bsh.w / 2)) < bsh.w / 2 + 10 and abs(p.y + p.h - (bsh.y + bsh.h)) < bsh.h
		Spr.AB("o_bush_gold", bsh.x - 20, bsh.y + bsh.h - 84, bsh.w + 40, 84, .35 if near else 1.0)

## Objeto pousado no chão (com sombra e brilho suave); se não houver chão perto, flutua.
func _ground_obj(n: String, o: Dictionary, sc: float, glow: Color, flat: bool) -> float:
	var r = Spr.AR.get(n)
	if r == null:
		return o.y
	var T := game.T
	if o.ry < 0:
		var b := sin(T * .08 + o.x) * 3
		Spr.glow(o.x, o.y + b, 32, glow)
		Spr.A(n, o.x, o.y + b, sc)
		return o.y + b
	var h: float = r[3] * sc * (.5 if flat else 1.0)
	var cy: float = o.ry - h / 2 - 1
	var pulse := .55 + sin(T * .08 + o.x) * .25
	Spr.glow(o.x, cy, 30, Color(glow.r, glow.g, glow.b, glow.a * pulse))
	Spr.ellipse(o.x, o.ry - 1, r[2] * sc * .45, 3, Color(0, 0, 0, .28))
	Spr.save()
	Spr.translate(o.x, o.ry - 1)
	Spr.scale(1, .5 if flat else 1.0)
	Spr.A(n, 0, -r[3] * sc / 2, sc)
	Spr.restore()
	return cy
