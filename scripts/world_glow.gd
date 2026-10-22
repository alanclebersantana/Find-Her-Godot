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
		_pit_rim(pa, 499, 1.0, k)
		_pit_rim(pb, 499, -1.0, k)
	for sh in g.L.get("shafts", []):
		if sh[1] < x0 or sh[0] > x1:
			continue
		var qa: float = sh[0]
		var qb: float = sh[1]
		var qy: float = sh[2]
		var q: float = .55 + .15 * sin(T * .05)
		Spr.vgrad(qa, qy, qb - qa, 120, Color(0, 0, 0, .55), Color(0, 0, 0, .9))
		Spr.rect(qa, qy + 120, qb - qa, 600, Color(0, 0, 0, .9))
		_pit_rim(qa, qy - 1, 1.0, q)
		_pit_rim(qb, qy - 1, -1.0, q)
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
			if c.get("mag", false):
				# rastro colorido voando para o Tomé
				var pc: Color = GameData.PEN_COL[GameData.PEN_LIST[int(c.ci) % 6]]
				Spr.glow(c.x, c.y, 16, Color(pc.r, pc.g, pc.b, .5))
				b = 0.0
			Spr.save()
			Spr.translate(c.x, c.y + b)
			Spr.rotate(sin(T * .03 + c.x * .013) * .45)
			Spr.A(pen, 0, 0, .62)
			Spr.restore()
			# brilho em cruz passando de vez em quando
			var gt: int = (T + int(c.ci) * 37) % 150
			if gt < 12:
				var gk: float = sin(gt / 12.0 * PI)
				var gx: float = c.x + 3
				var gy: float = c.y + b - 9
				Spr.seg(gx - 8 * gk, gy, gx + 8 * gk, gy, Color(1, 1, .9, .9 * gk), 1.6)
				Spr.seg(gx, gy - 8 * gk, gx, gy + 8 * gk, Color(1, 1, .9, .9 * gk), 1.6)
				Spr.glow(gx, gy, 9, Color(1, 1, .8, .6 * gk))
	for c in g.CLK:
		if not c.got:
			if c.ry > 0:
				Spr.glow(c.x, c.ry - 18, 26, Color(.75, .88, 1, .35 + sin(T * .08) * .15))
				Spr.ellipse(c.x, c.ry - 1, 12, 3, Color(0, 0, 0, .28))
				Spr.A("hourglass", c.x, c.ry, .48)
			else:
				Spr.A("hourglass", c.x, c.y + 16 + sin(T * .08 + c.x) * 3, .48)
	for c in g.OIL:
		if not c.got:
			_oil(c, T, g.lantern_lit)
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
		if not s.get("fumes"):
			_shade_under(s.y + depth, Color(.02, .03, .08, g.AMB.dark * .45))
		if s.get("fumes"):
			# fundo do lago: leito de lama irregular com pedrinhas (nada de linha reta)
			var bed := PackedVector2Array()
			var bx2: float = a
			var by0: float = s.y0 + s.h
			while bx2 <= b5 + 12:
				var u2: float = clamp((bx2 - s.x) / max(1.0, float(s.w)), 0.0, 1.0)
				var dip: float = sin(u2 * PI) * 26.0
				bed.push_back(Vector2(min(bx2, b5), by0 - 34 + 26 - dip + 5 * sin(bx2 * .07) + 3 * sin(bx2 * .19)))
				bx2 += 12
			bed.push_back(Vector2(b5, by0 + 4))
			bed.push_back(Vector2(a, by0 + 4))
			Spr.poly(bed, Color("#2e2410"))
			var pk: float = floor(a / 46.0) * 46.0
			while pk < b5:
				if pk > s.x + 12 and pk < s.x + s.w - 12 and WorldExtras.h(pk, 7) > .55:
					Spr.P("peb%d" % (int(pk) % 3), pk, by0 - 6 - sin(clamp((pk - s.x) / float(s.w), 0, 1) * PI) * 18, 16, false, 0.0, Color(.55, .65, .4))
				pk += 46
			# vapor de veneno subindo (não deixa planar por cima)
			for k in 7:
				var fx: float = s.x + fposmod(k * 53.0 + T * .3, max(20.0, s.w - 20)) + 10
				var u: float = fposmod(T * .006 + k * .37, 1.0)
				var fy: float = s.y - u * 170.0
				var fa: float = sin(u * PI) * .22
				Spr.circle(fx + sin(T * .03 + k) * 10, fy, 10 + u * 22, Color(.55, .95, .3, fa))
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
	# manivela: aviso e barrinha de quanto a porta já subiu (por cima do escuro da mina)
	for c in g.CRANKS:
		if not c.done and g.near_crank() == c:
			Spr.text("↻ GIRE A MANIVELA", float(c.x), float(c.y) - 120 + sin(T * .15) * 3, 18, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
			Spr.rr(float(c.x) - 30, float(c.y) - 104, 60, 8, 4, Color(0, 0, 0, .55))
			Spr.rr(float(c.x) - 29, float(c.y) - 103, 58 * float(c.turn), 6, 3, Color("#ffd27a"))
	for l in g.LOCKS:
		if l.get("crank") and not l.done and g.player.nearL == l and g.has_item(l.need):
			Spr.rr(float(l.x) - 10, float(l.y) - 40, 60, 8, 4, Color(0, 0, 0, .55))
			Spr.rr(float(l.x) - 9, float(l.y) - 39, 58 * float(l.turn), 6, 3, Color("#ffd27a"))
	# cogumelos gigantes brilham no escuro, e vaga-lumes mostram o caminho
	if g.TR:
		for o in g.TR.T:
			if o.k == "giant" and o.x > x0 - 200 and o.x < x1 + 200:
				var gc := Color(o.get("c", "#6a5acd"))
				if not o.has("to"):
					gc = gc.darkened(.4)
				Spr.glow(o.x, o.cap + 4, o.w * .7, Color(gc.r, gc.g, gc.b, (.22 if o.has("to") else .1) + .06 * sin(T * .05 + o.x)))
				if o.has("to"):
					WorldTraps.giant_arc(o, T)
				for d in [[-.3, -.15, .07], [.05, -.22, .08], [.3, -.1, .06]]:
					Spr.circle(o.x + d[0] * o.w, o.cap + 8 + d[1] * o.w, d[2] * o.w * .6, Color(.85, 1, .95, .35))
	# no túnel: gotas pingando do teto e poeira dançando na luz da lanterna
	var tn: Array = g.L.get("tunnel", [])
	if tn.size() >= 2 and float(tn[1]) > x0 and float(tn[0]) < x1:
		for k in 9:
			var dx: float = float(tn[0]) + fposmod(k * 433.0 + 97.0, float(tn[1]) - float(tn[0]))
			if dx < x0 or dx > x1:
				continue
			var per: float = 90.0 + k * 13
			var ph: float = fposmod(T + k * 37.0, per)
			if ph < 30:
				# gota se formando
				Spr.ellipse(dx, 382 + ph * .1, 2 + ph * .05, 2.5 + ph * .08, Color(.6, .75, .85, .7))
			elif ph < 55:
				var fy: float = 385 + pow((ph - 30) / 25.0, 2) * 115
				Spr.ellipse(dx, fy, 1.8, 3.5, Color(.7, .85, .95, .8))
			elif ph < 70:
				var u: float = (ph - 55) / 15.0
				Spr.ring(dx, 499, 3 + u * 12, Color(.7, .85, .95, .6 * (1.0 - u)), 1.2)
	if g.indoors() or g.AMB.dark > .45:
		var pl: Dictionary = g.player
		var lx: float = pl.x + pl.w / 2 + pl.face * 16
		var ly: float = pl.y + pl.h * .4
		for k in 16:
			var ang: float = k * 2.4 + T * (.004 + k * .0007)
			var rad: float = 30 + fposmod(k * 17.0, 70.0) + sin(T * .01 + k) * 10
			var mx: float = lx + cos(ang) * rad + pl.face * 30
			var my: float = ly + sin(ang * 1.3) * rad * .6 - 10
			var a: float = clamp(1.0 - rad / 110.0, 0, 1) * (.4 + .3 * sin(T * .07 + k))
			Spr.circle(mx, my, 1.2, Color(1, .92, .7, a))
	# lembranças escondidas: pedra rachada atrás de uma moita; quebrada, mostra a lembrança brilhando
	if g.X:
		for r in g.X.RELICS:
			if r.x < x0 - 80 or r.x > x1 + 80:
				continue
			if not r.broken:
				Spr.ellipse(r.x, r.y + 1, 26, 5, Color(0, 0, 0, .3))
				Spr.AB("o_rocks", r.x - 30, r.y - 44, 60, 48)
				Spr.seg(r.x - 6, r.y - 34, r.x + 2, r.y - 20, Color(.1, .08, .06, .9), 2)
				Spr.seg(r.x + 2, r.y - 20, r.x - 4, r.y - 8, Color(.1, .08, .06, .9), 2)
				Spr.seg(r.x + 2, r.y - 20, r.x + 12, r.y - 14, Color(.1, .08, .06, .9), 1.6)
				if (T + int(r.x)) % 160 < 10:
					Spr.glow(r.x + 2, r.y - 22, 12, Color(1, .9, .6, .6))
			elif not r.got:
				var by: float = r.y - 20 + sin(T * .08) * 3
				Spr.glow(r.x, by, 34, Color(1, .85, .55, .5))
				Spr.circle(r.x, by, 8, Color("#f0c060"))
				Spr.ring(r.x, by, 8, Color("#8a5a20"), 2)
				Spr.circle(r.x - 2, by - 2, 2.5, Color(1, 1, 1, .7))
			# moita na frente (fica transparente quando o Tomé chega perto)
			var near_r: bool = abs(g.player.x + g.player.w / 2 - r.x) < 70 and abs(g.player.y + g.player.h - r.y) < 80
			Spr.AB("o_bush", r.x - 70 + 24, r.y - 74, 110, 76, .3 if near_r else 1.0)
	# enchente tóxica subindo na gruta
	if g.EV and not g.EV.FL.is_empty() and g.EV.FL.st in ["warn", "rise", "fall"]:
		var F: Dictionary = g.EV.FL
		var fa: float = max(float(F.x0), x0)
		var fb: float = min(float(F.x1), x1)
		if fb > fa:
			_water(g, fa, fb, F.level, float(F.y0) + 20 - F.level, Color(.42, .86, .16, .9), Color(.08, .26, .04, .97), T, true, 0.0, "flood", float(F.x0), float(F.x1))
			if F.st == "warn" and T % 6 < 3:
				Spr.text("⚠", g.player.x + g.player.w / 2, g.player.y - 30, 30, Color(.7, 1, .3), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 5, Color(0, 0, 0, .8))
	# janelas acesas das casas da vila: a luz de dentro tremula como lamparina
	for d in g.L.get("decor", []):
		if not d.k in ["house1", "house2"] or d.x < x0 - 200 or d.x > x1 + 200:
			continue
		var r = Spr.AR["v_" + d.k]
		var k: float = 210.0 * d.get("s", 1.0) / r[2]
		var wins: Array = [[35, 107], [62, 107], [110, 100], [160, 100], [42, 167], [65, 167]] if d.k == "house1" else [[37, 107], [67, 107], [117, 102], [169, 102], [155, 55], [51, 165], [169, 170]]
		for i in wins.size():
			var wx: float = d.x + (wins[i][0] - r[2] / 2.0) * k
			var wy: float = d.y + 6 - (r[3] - wins[i][1]) * k
			var fl: float = .7 + .3 * sin(T * .13 + i * 2.1) * sin(T * .07 + i)
			Spr.glow(wx, wy, 26, Color(1, .78, .35, .32 * fl))
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
		# a moita treme quando o Tomé passa por dentro e solta folhinhas
		var wob: float = sin(T * .5) * .04 if (near and abs(p.vx) > .5) else 0.0
		Spr.save()
		Spr.translate(bsh.x + bsh.w / 2, bsh.y + bsh.h)
		Spr.rotate(wob)
		Spr.AB("o_bush_gold", -bsh.w / 2 - 20, -84, bsh.w + 40, 84, .35 if near else 1.0)
		Spr.restore()
		if near and abs(p.vx) > .5 and T % 6 == 0:
			g.PARTS.append({"x": bsh.x + randf() * bsh.w, "y": bsh.y + bsh.h - 60 - randf() * 20, "vx": randf_range(-1, 1), "vy": -randf_range(.5, 1.5), "life": 26, "col": Color(.5, .62, .2, .9)})

## beirada do buraco que aparece até no escuro: contorno claro seguindo a terra que desmorona e
## pedrinhas soltas caindo da borda
func _pit_rim(e: float, y: float, dir: float, k: float) -> void:
	# beira do buraco: musgo e cogumelinhos que brilham sozinhos (dá para ver a borda mesmo no
	# escuro), vaga-lumes em volta e, lá no fundo, uma claridade fraca dando noção da altura
	var dark: float = clamp(game.AMB.dark, 0, 1)
	var a: float = clamp(dark * 1.4, .25, 1.0)
	var t := float(game.T)
	Spr.ellipse(e - dir * 16, y + 1, 18, 3, Color(.45, 1, .75, .35 * a))
	Spr.glow(e - dir * 14, y - 4, 26, Color(.4, .95, 1, .22 * a + .05 * sin(t * .05 + e)))
	Spr.P("mush1", e - dir * 9, y + 2, 13, dir < 0, 0.0, Color(.75, 1.3, 1.5, a))
	Spr.P("mush3", e - dir * 26, y + 2, 17, dir > 0, 0.0, Color(.75, 1.25, 1.45, a))
	for i in 3:
		var ph: float = t * .03 + i * 2.1 + e
		var fx: float = e + dir * (6 + 14 * sin(ph))
		var fy: float = y - 20 + 12 * cos(ph * 1.3)
		var tw: float = .5 + .5 * sin(t * .2 + i)
		Spr.glow(fx, fy, 7, Color(1, 1, .5, .45 * a * tw))
		Spr.circle(fx, fy, 1.4, Color(1, 1, .7, .9 * a * tw))
	# claridade fraca no fundo
	Spr.glow(e + dir * 50, y + 150, 60, Color(.35, .6, .9, .07 * a))

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
		_shade_under(w.y + w.h, Color(.02, .03, .08, dark * .25))
	WorldLake.front(g, T)
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
			# torrão de terra (pedrinha pintada em tom de terra)
			Spr.P("peb1", 0, 9, 22, false, 0.0, Color(.72, .52, .34))
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
## a linha de cima (com as ondas) da última água desenhada
var last_top := PackedVector2Array()

## escurece a água do jeito da superfície (sem faixa reta acima das ondas)
func _shade_under(bottom: float, c: Color) -> void:
	if last_top.size() < 2 or c.a <= 0.0:
		return
	var pts := last_top.duplicate()
	pts.push_back(Vector2(last_top[last_top.size() - 1].x, bottom))
	pts.push_back(Vector2(last_top[0].x, bottom))
	Spr.poly(pts, c)

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
		# balanço constante (três ondas cruzando) — a água nunca fica parada
		var oy: float = WorldLake.wave_off(g, wb, xx, T, swamp or key.begins_with("s"))
		top.push_back(Vector2(xx, y + oy))
		ys.append(oy)
		x2 += 8
	last_top = top
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
	if swamp or key.begins_with("s"):
		# água tóxica: brilho verde pulsando na superfície (perigo bem visível)
		Spr.line(top, Color(.75, 1, .3, .18 + .1 * sin(T * .07)), 9)
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
	if not swamp and not key.begins_with("s") and depth > 40:
		# luz dançando no fundo (cáusticas) e fachos de luz entrando na água
		var rk: float = floor(a / 90.0) * 90.0
		while rk < b:
			var ra: float = .045 + .03 * sin(T * .02 + rk * .01)
			var r0: float = rk + 30 + sin(T * .01 + rk) * 10
			if r0 > a and r0 < b - 20:
				Spr.ci.draw_polygon(PackedVector2Array([Vector2(r0, y + 6), Vector2(r0 + 20, y + 6), Vector2(r0 + 46, y + min(depth, 160.0)), Vector2(r0 + 18, y + min(depth, 160.0))]),
					PackedColorArray([Color(1, 1, .9, ra), Color(1, 1, .9, ra), Color(1, 1, .9, 0), Color(1, 1, .9, 0)]))
			rk += 90
	# reflexo do céu: faixas claras e largas logo abaixo da superfície, ondulando devagar
	if not swamp:
		for k in 2:
			var rw: float = w * .35
			var rx2: float = a + fposmod(k * w * .5 + T * .15 * (k + 1), w + rw) - rw * .5
			Spr.ellipse(clamp(rx2, a + rw * .4, b - rw * .4), y + 7 + k * 6, min(rw, w * .45) * .5, 3, Color(1, 1, 1, .08))
	# margens: barranco arredondado cobrindo a quina, faixa de lama, juncos, pedras molhadas e folhas;
	# a lama e a espuma da beira sobem e descem junto com a onda daquele ponto
	for side in [0, 1]:
		var ex: float = bx0 if side == 0 else bx1
		if bx1 - bx0 < 60 or ex < a - 70 or ex > b + 70:
			continue
		var bi: int = clamp(int((clamp(ex, a, b) - top[0].x) / 8.0), 0, top.size() - 1)
		var soy: float = top[bi].y - y
		_bank(ex, y, 1.0 if side == 0 else -1.0, swamp or key.begins_with("s"), T, min(depth, 120.0), soy)
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


## margem de um corpo d'água: terra arredondada descendo para dentro da água (sem quina reta),
## faixa de lama molhada, pedras brilhando, juncos e uma vitória-régia
func _bank(e: float, y: float, dir: float, toxic: bool, T: int, depth: float, soy: float = 0.0) -> void:
	# barranco com a textura da terra (raízes e pedrinhas), seguindo a curva e escurecendo para o fundo
	var t: Texture2D = preload("res://scripts/world_static.gd").gtex(game, e)
	var ts := t.get_size()
	var tint := Color(1, 1, 1) if not toxic else Color(.85, .95, .7)
	var pts := PackedVector2Array([Vector2(e - dir * 4, y - 4)])
	var edge := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		var p := Vector2(e + dir * (4 + sin(u * PI * .5) * 26 + sin(u * 9.0 + e) * 3), y - 4 + u * depth)
		pts.push_back(p)
		edge.push_back(p)
	pts.push_back(Vector2(e - dir * 4, y + depth))
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var ub: float = fposmod(e * .37, 80.0)
	for q in pts:
		uvs.push_back(Vector2((ub + 20 + (q.x - e) * dir) / ts.x, clamp((60.0 + (q.y - y + 4) * .75) / ts.y, 0, 1)))
		var dk: float = lerpf(.95, .45, clamp((q.y - y) / max(depth, 1.0), 0, 1))
		cols.push_back(Color(tint.r * dk, tint.g * dk, tint.b * dk))
	Spr.ci.draw_polygon(pts, cols, uvs, t)
	# contorno escuro da beira e a linha de lama molhada que sobe e desce com a onda
	Spr.line(edge, Color(.12, .08, .05, .7), 2)
	var wl: float = y + soy
	var mud := PackedVector2Array()
	for i in 7:
		var u2 := i / 6.0
		var yy: float = wl - 3 + u2 * 12
		var ex2: float = e + dir * (4 + sin(clamp((yy - y + 4) / max(depth, 1.0), 0, 1) * PI * .5) * 26)
		mud.push_back(Vector2(ex2 + dir * 1, yy))
	Spr.line(mud, Color("#2a1c10") if not toxic else Color("#28301a"), 6)
	Spr.line(mud, Color(1, 1, 1, .16), 1.5)
	var fo: float = .35 + .25 * sin(T * .09 + e)
	Spr.ellipse(e + dir * 30, wl + 1, 12, 2.2, Color(1, 1, 1, fo))
	Spr.ellipse(e + dir * 42, wl + 2, 6, 1.5, Color(1, 1, 1, fo * .7))
	# pedrinhas pintadas e molhadas na beira
	for k in 3:
		var rx: float = e + dir * (6 + k * 11)
		var ry: float = wl + 6 + k * 4
		Spr.P("peb%d" % (k % 3), rx, ry, 14 - k * 2, dir < 0, 0.0, Color(.85, .9, .95))
	# juncos pintados balançando
	for k in 3:
		var jx: float = e - dir * (2 + k * 8)
		var sw: float = sin(T * .04 + jx) * 3
		Spr.P("cat_open" if k != 1 else "cat_bud", jx, y + 3, 15 + fmod(abs(jx) * .7, 8.0), dir < 0, sw, Color(.95, 1, .9) if not toxic else Color(.85, .95, .6))
	# vitória-régia boiando perto da margem
	if not toxic:
		var lx: float = e + dir * 52
		var ly: float = wl + 1
		Spr.ellipse(lx, ly, 14, 4, Color("#4f8a3a"))
		Spr.poly(PackedVector2Array([Vector2(lx, ly), Vector2(lx + 12, ly - 2), Vector2(lx + 12, ly + 2)]), Color(.2, .35, .4, .8))
		Spr.circle(lx - 4, ly - 2, 2.5, Color(1, .8, .9))

## frasco de óleo (lanterna acesa) ou pote de vaga-lumes (lanterna apagada), pousado no chão
func _oil(c: Dictionary, T: int, lit: bool) -> void:
	var by: float = c.ry if c.ry > 0 else c.y + 16
	var pul: float = .6 + sin(T * .09 + c.x) * .25
	if lit:
		Spr.glow(c.x, by - 16, 34, Color(1, .78, .35, .45 * pul))
		Spr.ellipse(c.x, by - 1, 10, 3, Color(0, 0, 0, .3))
		Spr.A("it_oleo", c.x, by - 15, .5)
	else:
		Spr.glow(c.x, by - 14, 36, Color(.7, 1, .4, .5 * pul))
		Spr.ellipse(c.x, by - 1, 10, 3, Color(0, 0, 0, .3))
		# pote de vidro com tampa de pano e vaga-lumes dentro
		Spr.rr(c.x - 9, by - 26, 18, 25, 5, Color(.75, .9, .85, .28))
		Spr.rect(c.x - 7, by - 30, 14, 5, Color(.55, .38, .22, 1))
		Spr.seg(c.x - 8, by - 26, c.x + 8, by - 26, Color(.35, .22, .12, 1), 1.6)
		for k in 5:
			var fx: float = c.x + sin(T * .05 + k * 2.1) * 6
			var fy: float = by - 13 + cos(T * .043 + k * 1.7) * 8
			Spr.circle(fx, fy, 1.6, Color(.9, 1, .5, .6 + .4 * sin(T * .2 + k)))
		Spr.ring(c.x, by - 13, 11, Color(.85, 1, .9, .35), 1.2)
	if T % 16 == 0:
		game.PARTS.append({"x": c.x + (randf() - .5) * 14, "y": by - 22, "vx": 0, "vy": -.4, "life": 26, "col": Color(1, .85, .45) if lit else Color(.8, 1, .5)})
