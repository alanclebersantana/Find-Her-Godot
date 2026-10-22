extends Node2D
## Camada acima da escuridão: lápis, objetos, pistas e desenhos brilham mesmo à noite.
## Também desenha o que fica na frente do Tomé (água do brejo e moitas).

var game: Game

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("glow", __t)

func __draw_raw() -> void:
	if game == null or not game.L:
		return
	var g := game
	var T := g.T
	var x0 := g.cam - 60
	var x1 := g.cam + g.W + 60
	Spr.begin(self)
	# beiradas dos buracos aparecem mesmo no escuro: borda clara e pedrinhas soltas
	for pit in g.L.get("pits", []):
		if pit[1] < x0 or pit[0] > x1:
			continue
		var pa: float = pit[0]
		var pb: float = pit[1]
		var k: float = .55 + .15 * sin(T * .05)
		# o vão fica bem mais escuro que o chão em volta
		Spr.vgrad(pa, 500, pb - pa, 120, Color(0, 0, 0, .55), Color(0, 0, 0, .85))
		Spr.rect(pa, 620, pb - pa, 600, Color(0, 0, 0, .85))
		for e in [pa, pb]:
			Spr.rect(e - 3, 498, 6, 46, Color(.75, .7, .6, .35 * k))
		Spr.seg(pa - 30, 499, pa, 499, Color(.95, .9, .75, .85 * k), 3)
		Spr.seg(pb, 499, pb + 30, 499, Color(.95, .9, .75, .85 * k), 3)
		for i in 3:
			Spr.circle(pa + 6 + i * 7, 512 + i * 9, 2.5, Color(.7, .62, .5, .5 * k))
			Spr.circle(pb - 6 - i * 7, 514 + i * 8, 2.5, Color(.7, .62, .5, .5 * k))
	for sh in g.L.get("shafts", []):
		if sh[1] < x0 or sh[0] > x1:
			continue
		var qa: float = sh[0]
		var qb: float = sh[1]
		var qy: float = sh[2]
		var q: float = .55 + .15 * sin(T * .05)
		Spr.vgrad(qa, qy, qb - qa, 120, Color(0, 0, 0, .55), Color(0, 0, 0, .9))
		Spr.rect(qa, qy + 120, qb - qa, 600, Color(0, 0, 0, .9))
		Spr.seg(qa - 30, qy - 1, qa, qy - 1, Color(.95, .9, .75, .85 * q), 3)
		Spr.seg(qb, qy - 1, qb + 30, qy - 1, Color(.95, .9, .75, .85 * q), 3)
		for e in [qa, qb]:
			Spr.rect(e - 3, qy - 2, 6, 46, Color(.75, .7, .6, .35 * q))
	for c in g.coins_near(x0, x1):
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
		if not d.got and not d.get("hidden"):
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
		var depth: float = max(30, s.y0 + s.h - s.y)
		# água tóxica (verde ácido): aqui o Tomé afunda — bem diferente da água azul onde dá para nadar
		_water(g, a, b5, s.y, depth, Color(.42, .86, .16, .9), Color(.08, .26, .04, .97), T, false, 0.0, "s%d" % g.SWAMP.find(s), s.x, s.x + s.w)
		Spr.rect(a, s.y - 8, b5 - a, depth + 8, Color(.02, .03, .08, g.AMB.dark * .45))
		Spr.rect(a, s.y - 2, b5 - a, 4, Color(.75, 1, .35, .7))
		# bolhas tóxicas subindo e estourando, e um vapor fraco por cima
		var bx: float = floor(a / 46.0) * 46.0
		while bx < b5:
			var ph: float = fmod(T * .011 + bx * .0131, 1.0)
			var px: float = bx + sin(bx * .7) * 14
			if px > a and px < b5:
				var r: float = 3.0 + fmod(bx * .37, 4.0)
				if ph < .8:
					var by: float = s.y + 40 - ph / .8 * 40
					Spr.circle(px, by, r, Color(.6, 1, .3, .55))
					Spr.ring(px, by, r, Color(.85, 1, .55, .8), 1.2)
				else:
					var u: float = (ph - .8) / .2
					Spr.ring(px, s.y - 2, r + u * 9, Color(.8, 1, .45, .8 * (1.0 - u)), 1.5)
					Spr.glow(px, s.y - 4, 16, Color(.55, 1, .25, .35 * (1.0 - u)))
				var vy: float = s.y - 8 - fmod(T * .4 + bx, 40.0)
				Spr.ellipse(px + 10, vy, 14, 5, Color(.6, .95, .4, .1))
			bx += 46.0
		if g.AMB.rain > .3:
			for k in 6:
				var rx: float = a + fmod(T * 13 + k * 97, b5 - a)
				var rr := 4 + (T + k * 5) % 12
				Spr.ci.draw_arc(Vector2(rx, s.y + 2), rr, 0, TAU, 16, Color(.86, .92, .86, .5), 1.2)
	_projectiles(g, T)
	_extras(g, T)
	# cogumelos gigantes brilham no escuro, e vaga-lumes mostram o caminho
	if g.TR:
		for o in g.TR.T:
			if o.k == "giant" and o.x > x0 - 200 and o.x < x1 + 200:
				var gc := Color(o.get("c", "#6a5acd"))
				Spr.glow(o.x, o.cap + 4, o.w * .7, Color(gc.r, gc.g, gc.b, .22 + .06 * sin(T * .05 + o.x)))
				for d in [[-.3, -.15, .07], [.05, -.22, .08], [.3, -.1, .06]]:
					Spr.circle(o.x + d[0] * o.w, o.cap + 8 + d[1] * o.w, d[2] * o.w * .6, Color(.85, 1, .95, .35))
	for ff in g.L.get("fireflies", []):
		if ff[1] < x0 or ff[0] > x1:
			continue
		for k in 26:
			var fx: float = ff[0] + fposmod(k * 137.0 + sin(T * .01 + k) * 60.0, ff[1] - ff[0])
			var fy: float = ff[2] + fposmod(k * 71.0, 360.0) + sin(T * .03 + k * 1.3) * 18
			var on: float = .5 + .5 * sin(T * .09 + k * 2.1)
			Spr.glow(fx, fy, 12, Color(.75, 1, .4, .3 * on))
			Spr.circle(fx, fy, 2, Color(.9, 1, .6, .9 * on))
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

## Sistemas novos que brilham ou ficam na frente: facho, raio dos espelhos, lápis dourado, água,
## bolhas, ondinhas, mariposas, vaga-lumes e a "tampa" das salas secretas ainda não achadas.
func _extras(g: Game, T: int) -> void:
	var X: Extras = g.X
	var p: Dictionary = g.player
	var dark: float = g.AMB.dark
	# lápis dourado
	if not X.GOLD.is_empty() and not X.GOLD.got:
		var gy: float = X.GOLD.y + sin(T * .07) * 3
		Spr.glow(X.GOLD.x, gy, 46 + sin(T * .15) * 5, Color(1, .85, .35, .55))
		Spr.save()
		Spr.translate(X.GOLD.x, gy)
		Spr.rotate(-.5)
		Spr.A("pen_gold", 0, 0, 1.1)
		Spr.restore()
		if T % 8 == 0:
			g.PARTS.append({"x": X.GOLD.x + (randf() - .5) * 26, "y": gy + (randf() - .5) * 20, "vx": 0, "vy": -.5, "life": 22, "col": Color("#ffe27a")})
	# água (na frente do Tomé)
	for w in X.WATER:
		if w.x > g.cam + g.W or w.x + w.w < g.cam:
			continue
		# tinge de leve: o Tomé e os peixes continuam bem visíveis debaixo d'água
		_water(g, max(w.x, g.cam - 40), min(w.x + w.w, g.cam + g.W + 40), w.y, w.h, Color(.24, .52, .6, .26), Color(.04, .14, .22, .4), T, false, 0.0, "w%d" % X.WATER.find(w), w.x, w.x + w.w)
		Spr.rect(w.x, w.y, w.w, w.h, Color(.02, .03, .08, dark * .25))
	WorldKings.draw_fish(g, T)
	WorldNature.draw_bogs(g, T)
	for b in X.BUB:
		Spr.ring(b.x, b.y, 2 + b.t * .02, Color(.85, .95, 1, .7), 1.2)
	for r in X.RIP:
		var a: float = 1.0 - r.t / 50.0
		Spr.ci.draw_arc(Vector2(r.x, r.y), (4 + r.t * .7) * r.s, 0, TAU, 20, Color(.85, .95, .9, .45 * a), 1.2)
	# facho da lanterna
	if X.focus:
		var o := X.lamp()
		var f: float = p.face
		var L := Extras.BEAM_LEN
		var spread: float = tan(Extras.BEAM_ANG) * L
		var cone := PackedVector2Array([o, Vector2(o.x + f * L, o.y - spread), Vector2(o.x + f * L, o.y + spread)])
		var ca := .16 + dark * .22
		Spr.ci.draw_polygon(cone, PackedColorArray([Color(1, .92, .65, ca + .15), Color(1, .9, .6, 0), Color(1, .9, .6, 0)]))
		var core := PackedVector2Array([o, Vector2(o.x + f * L * .8, o.y - spread * .35), Vector2(o.x + f * L * .8, o.y + spread * .35)])
		Spr.ci.draw_polygon(core, PackedColorArray([Color(1, .95, .75, ca + .2), Color(1, .95, .7, 0), Color(1, .95, .7, 0)]))
		Spr.glow(o.x, o.y, 26, Color(1, .9, .6, .6))
	if X.BEAM.size() >= 2:
		var pl := PackedVector2Array(X.BEAM)
		Spr.ci.draw_polyline(pl, Color(1, .9, .55, .35), 9, true)
		Spr.ci.draw_polyline(pl, Color(1, .97, .8, .95), 3, true)
		Spr.glow(X.BEAM[X.BEAM.size() - 1].x, X.BEAM[X.BEAM.size() - 1].y, 22, Color(1, .95, .7, .7))
	for c in X.CRYSTALS:
		if c.on or c.charge > 0:
			Spr.glow(c.x, c.y, 30 + c.charge * .5, Color(.6, .85, 1, .25 + c.charge / 120.0))
	# mariposas em volta da lanterna
	if g.lantern_lit and dark > .35:
		var o2 := X.lamp()
		for m in X.MOTHS:
			var mx: float = o2.x + cos(m.a) * m.r
			var my: float = o2.y + sin(m.a * 1.3) * m.r * .6 - 6
			var fl: float = abs(sin(m.ph))
			Spr.ellipse(mx - 2.5, my, 3.5 * fl + .5, 2.5, Color(.92, .88, .78, .85))
			Spr.ellipse(mx + 2.5, my, 3.5 * fl + .5, 2.5, Color(.92, .88, .78, .85))
			Spr.circle(mx, my, 1.2, Color(.5, .45, .4))
	# vaga-lumes (fogem da lanterna)
	for ff in X.FIRE:
		var bl: float = .45 + .55 * max(0.0, sin(ff.ph))
		Spr.glow(ff.x, ff.y, 9, Color(.85, 1, .45, .5 * bl * (.4 + dark)))
		Spr.circle(ff.x, ff.y, 1.6, Color(1, 1, .7, bl))
	# salas secretas ainda tampadas
	var mod := Color(1, 1, 1).lerp(Color(.035, .05, .1), clamp(dark, 0, 1) * .97)
	for sc in X.SECRETS:
		if sc.a > 0:
			Spr.rect(sc.x - 2, sc.y - 2, sc.w + 4, sc.h + 4, Color(.165 * mod.r, .102 * mod.g, .055 * mod.b, sc.a))

## Carvão em brasa (Vargas) e torrões de terra (toupeira): grandes, brilhando, com sombra no chão.
func _projectiles(g: Game, T: int) -> void:
	for c in g.COAL:
		var dirt: bool = c.get("k", "") == "dirt"
		var gy: float = c.get("gy", -1.0)
		if gy > 0 and gy > c.y:
			var k: float = clamp(1.0 - (gy - c.y) / 300.0, .25, 1.0)
			Spr.ellipse(c.x, gy - 1, 14 * k, 4 * k, Color(.8, .15, .05, .45 * k) if not dirt and c.get("k", "") != "acorn" else Color(0, 0, 0, .35 * k))
		if c.get("k", "") == "acorn":
			Spr.save()
			Spr.translate(c.x, c.y)
			Spr.rotate(c.rot)
			Spr.ellipse(0, 2, 6, 7, Color("#9a6a32"))
			Spr.ellipse(0, -4, 7, 3.5, Color("#5a3a1a"))
			Spr.seg(0, -7, 1, -10, Color("#5a3a1a"), 1.5)
			Spr.ellipse(-2, 1, 1.5, 3, Color(1, 1, 1, .35))
			Spr.restore()
			continue
		if dirt:
			Spr.save()
			Spr.translate(c.x, c.y)
			Spr.rotate(c.rot)
			Spr.poly(PackedVector2Array([Vector2(-10, -4), Vector2(-4, -10), Vector2(7, -8), Vector2(10, 2), Vector2(3, 10), Vector2(-9, 6)]), Color("#6b4a2a"))
			Spr.poly(PackedVector2Array([Vector2(-4, -7), Vector2(4, -6), Vector2(0, -1)]), Color("#9a7448"))
			Spr.restore()
			continue
		var fl: float = .8 + sin(T * .6 + c.x) * .2
		Spr.glow(c.x, c.y, 34 * fl, Color(1, .45, .1, .55))
		Spr.save()
		Spr.translate(c.x, c.y)
		Spr.rotate(c.rot)
		Spr.scale(1.5, 1.5)
		Spr.poly(PackedVector2Array([Vector2(-8, -3), Vector2(-3, -8), Vector2(6, -6), Vector2(8, 2), Vector2(2, 8), Vector2(-7, 5)]), Color(.16, .12, .12))
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(-5, -2), Vector2(0, 1), Vector2(4, -3)]), Color(1, .6, .15, fl), 1.6, true)
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(-2, 5), Vector2(1, 2), Vector2(5, 4)]), Color(1, .45, .1, fl), 1.4, true)
		Spr.restore()

## água parada com cara de água: degradê pela profundidade, faixas de luz (cáusticas) perto da superfície,
## superfície brilhante com ondinhas, reflexo da lanterna e bolhas / lentilha-d'água
func _water(g: Game, a: float, b: float, y: float, depth: float, c0: Color, c1: Color, T: int, swamp: bool, ox: float = 0.0, key: String = "", bx0: float = 0.0, bx1: float = 0.0) -> void:
	var w: float = b - a
	var mid := c0.lerp(c1, .45)
	# superfície com ondas de verdade (molas) + um balanço suave constante
	var wb: Dictionary = {}
	if key != "" and g.WV:
		wb = g.WV.body(key, bx0, bx1, y)
	var top := PackedVector2Array()
	var hi := PackedVector2Array()
	var x2: float = floor(a / 8.0) * 8.0
	var ys: Array = []
	while x2 <= b + 8.1:
		var xx: float = clamp(x2, a, b)
		var oy: float = sin(xx * .045 + T * .07) * 1.6 + sin(xx * .11 - T * .05) * .7
		if not wb.is_empty():
			oy += g.WV.height(wb, xx)
		top.push_back(Vector2(xx, y + oy))
		ys.append(oy)
		x2 += 8
	# corpo d'água: faixa de cima acompanha a onda, o resto em degradê
	var d1: float = min(depth, 70.0)
	var band := top.duplicate()
	band.push_back(Vector2(b, y + 12))
	band.push_back(Vector2(a, y + 12))
	Spr.poly(band, c0)
	Spr.vgrad(a, y + 12, w, max(0.0, d1 - 12), c0, mid)
	if depth > d1:
		Spr.vgrad(a, y + d1, w, depth - d1, mid, c1)
	if swamp and Spr.has("sw_water"):
		Spr.strip_at("sw_water", ox, a, b, y - 6, min(70.0, depth + 6), .92)
	# faixas de luz que ondulam logo abaixo da superfície
	for k in 3:
		var pts := PackedVector2Array()
		var x := a
		var yy: float = y + 12 + k * 13
		while x <= b + 0.1:
			pts.push_back(Vector2(x, yy + sin(x * (.035 + k * .01) + T * (.035 + k * .012) + k * 2.0) * 3.5))
			x += 12
		Spr.line(pts, Color(1, 1, .9, .07 - k * .015), 6 - k)
	# linha da superfície, brilho na crista das ondas e espuma onde a água está agitada
	for i in top.size():
		hi.push_back(top[i] + Vector2(0, -1.5))
	Spr.line(top, Color(.72, .86, .8, .7) if swamp else Color(.78, .95, 1, .75), 3)
	Spr.line(hi, Color(1, 1, 1, .35), 1)
	for i in range(1, top.size() - 1):
		var crest: float = ys[i] - (ys[i - 1] + ys[i + 1]) * .5
		if crest < -1.2:
			Spr.ellipse(top[i].x, top[i].y - 1, 6, 2, Color(1, 1, 1, clamp(-crest * .25, 0, .75)))
	# pontinhos de espuma na superfície
	for k in int(w / 40.0):
		var fx: float = a + fmod(k * 53.7 + T * .2 * (1 + k % 3), w)
		Spr.circle(fx, y + 2 + sin(T * .05 + k) * 1.2, 1.4, Color(1, 1, 1, .35))
	# reflexo da lanterna quando o Tomé está perto
	var p: Dictionary = g.player
	var px: float = p.x + p.w / 2
	if g.lantern_lit and px > a - 60 and px < b + 60 and abs(p.y + p.h - y) < 140:
		var rx: float = clamp(px + p.face * 10, a, b)
		var al: float = .35 * (1.0 - abs(p.y + p.h - y) / 140.0)
		for k in 4:
			Spr.ellipse(rx + sin(T * .1 + k) * 3, y + 6 + k * 7, 14 - k * 2.5, 2, Color(1, .85, .5, al * (1.0 - k * .2)))
	if swamp:
		# lentilha-d'água e folhinhas boiando
		for k in int(w / 55.0):
			var lx: float = a + fmod(k * 71.3 + sin(T * .01 + k) * 6, w)
			Spr.ellipse(lx, y + 1 + sin(T * .06 + k) * 1.2, 4 + k % 3, 1.6, Color(.45, .62, .25, .85))
	else:
		# bolhas subindo
		for k in int(w / 70.0) + 1:
			var bx: float = a + fmod(k * 97.1, w)
			var ph: float = fmod(T * .6 + k * 37.0, depth)
			Spr.ring(bx + sin(ph * .1 + k) * 3, y + depth - ph, 1.5 + ph * .01, Color(.85, .95, 1, .45 * (ph / depth)), 1.0)
