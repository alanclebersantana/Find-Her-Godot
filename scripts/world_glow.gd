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
		var b := sin(T * .1 + c.x * .05) * 3
		Spr.A("pen_" + GameData.PEN_LIST[int(c.ci) % 6], c.x, c.y + b, .62)
	for c in g.CLK:
		if not c.got:
			Spr.A("hourglass", c.x, c.y + 16 + sin(T * .08 + c.x) * 3, .48)
	for d in g.DRWS:
		if not d.got:
			Spr.glow(d.x, d.y, 34, Color(1, .94, .78, .45))
			Spr.A("drawing", d.x, d.y + sin(T * .06) * 3, .6)
	for it in g.ITEMS:
		if it.got:
			continue
		var b2 := sin(T * .08 + it.x) * 3
		Spr.glow(it.x, it.y + b2, 30, Color(1, .94, .74, .5))
		Spr.A("it_" + it.id, it.x, it.y + b2, .6)
	for c in g.CLUES:
		if c.got:
			continue
		var b3 := sin(T * .07 + c.x) * 3
		Spr.glow(c.x, c.y + b3, 36, Color(.67, .86, 1, .6))
		Spr.A("cl_%d" % int(c.id), c.x, c.y + b3, .55)
		Spr.text("?", c.x + 17, c.y + b3 - 14, 14, Color("#e8f4ff"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)
	for s in g.SPECS:
		if s.got:
			continue
		var b4 := sin(T * .09 + s.x) * 4
		Spr.glow(s.x, s.y + b4, 30 + sin(T * .2) * 3, Color(1, 1, 1, .4))
		Spr.A("pen_" + s.c, s.x, s.y + b4, 1.05)
		if T % 10 == 0:
			g.PARTS.append({"x": s.x + (randf() - .5) * 20, "y": s.y + b4, "vx": 0, "vy": -.6, "life": 20, "col": GameData.PEN_COL[s.c]})
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
