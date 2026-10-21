extends RefCounted
class_name WorldNature
## Desenho dos trechos novos: pinheiros, casas da vila com neve, lampião e boneco de neve (fixos);
## lamaçal com sanguessugas, corda esticada, bolhas, capacete, arpão, bolas de neve, buracos de
## água gelada, esquilos, corvos, piranhas, e o cavalo.

const INK := Color("#2a1a0e")

# ---------------------------------------------------------------- cenário fixo (world_static)
static func decor(d: Dictionary) -> void:
	var s: float = d.get("s", 1.0)
	match d.k:
		"pine":
			pine(d.x, d.y, s)
		"house1", "house2":
			var n: String = "v_house1" if d.k == "house1" else "v_house2"
			var w: float = 210 * s
			Spr.ellipse(d.x, d.y + 2, w * .55, 10, Color(0, 0, 0, .25))
			# casas são só cenário: um pouco apagadas para não parecerem plataforma
			Spr.ABb(n, d.x, d.y + 6, w, .72)
			# neve no telhado de palha
			var r = Spr.AR[n]
			var hh: float = w * r[3] / r[2]
			var top: float = d.y + 6 - hh
			var pts := PackedVector2Array()
			for i in 13:
				var u := i / 12.0
				var yy: float = top + hh * .14 + abs(u - .5) * hh * .62
				pts.push_back(Vector2(d.x - w * .48 + u * w * .96, yy - 2 - sin(u * 31) * 2))
			for i in 13:
				var u2 := 1.0 - i / 12.0
				var yy2: float = top + hh * .14 + abs(u2 - .5) * hh * .62
				pts.push_back(Vector2(d.x - w * .48 + u2 * w * .96, yy2 + 10 + sin(u2 * 23) * 3))
			Spr.poly(pts, Color(.96, .97, 1, .75))
			for i in 7:
				var ix: float = d.x - w * .44 + i * w * .145
				Spr.poly(PackedVector2Array([Vector2(ix - 3, top + hh * .52), Vector2(ix, top + hh * .52 + 10 + (i % 3) * 5), Vector2(ix + 3, top + hh * .52)]), Color(.85, .93, 1, .9))
		"lamp":
			Spr.rect(d.x - 3, d.y - 110, 6, 110, Color("#3a2a1a"))
			Spr.rect(d.x - 12, d.y - 6, 24, 6, Color("#3a2a1a"))
			Spr.rr(d.x - 12, d.y - 132, 24, 24, 4, Color("#4a3a2a"))
			Spr.rect(d.x - 8, d.y - 128, 16, 16, Color("#ffd27a"))
			Spr.glow(d.x, d.y - 120, 60, Color(1, .8, .4, .35))
			Spr.ellipse(d.x, d.y - 134, 16, 5, Color(.96, .97, 1))
		"snowman":
			snowman(d.x, d.y, s, false)

static func pine(x: float, y: float, s: float) -> void:
	var trunk := Color("#4a3220")
	Spr.rect(x - 9 * s, y - 60 * s, 18 * s, 62 * s, trunk)
	var green := Color("#2f5a3a")
	var dark := Color("#22432b")
	for i in 4:
		var w: float = (120 - i * 24) * s
		var by: float = y - (40 + i * 62) * s
		var h: float = 96 * s
		Spr.poly(PackedVector2Array([Vector2(x - w / 2, by), Vector2(x, by - h), Vector2(x + w / 2, by)]), dark if i % 2 else green)
		Spr.ci.draw_polyline(PackedVector2Array([Vector2(x - w / 2, by), Vector2(x, by - h), Vector2(x + w / 2, by)]), INK, 2, true)
		# neve nos galhos
		Spr.poly(PackedVector2Array([Vector2(x - w * .34, by - h * .3), Vector2(x, by - h * .95), Vector2(x + w * .3, by - h * .32), Vector2(x + w * .1, by - h * .4), Vector2(x - w * .05, by - h * .28)]), Color(.96, .97, 1))
		Spr.ellipse(x - w * .36, by - 3, w * .14, 4 * s, Color(.96, .97, 1))
		Spr.ellipse(x + w * .34, by - 3, w * .12, 4 * s, Color(.96, .97, 1))

static func snowman(x: float, y: float, s: float, hat: bool) -> void:
	var white := Color(.97, .98, 1)
	var sh := Color(.78, .84, .95)
	Spr.ellipse(x, y + 2, 40 * s, 8 * s, Color(0, 0, 0, .2))
	for b in [[0, 34, 34], [-58, 25, 25], [-100, 18, 18]]:
		Spr.circle(x, y - b[1] * s + b[0] * s, b[2] * s, white)
		Spr.ring(x, y - b[1] * s + b[0] * s, b[2] * s, Color(.55, .62, .75), 2)
		Spr.ellipse(x + b[2] * s * .3, y - b[1] * s + b[0] * s + b[2] * s * .3, b[2] * s * .55, b[2] * s * .45, Color(sh.r, sh.g, sh.b, .5))
	var hy: float = y - 118 * s
	Spr.circle(x - 6 * s, hy, 2.4 * s, INK)
	Spr.circle(x + 6 * s, hy, 2.4 * s, INK)
	Spr.poly(PackedVector2Array([Vector2(x, hy + 4 * s), Vector2(x + 18 * s, hy + 7 * s), Vector2(x, hy + 9 * s)]), Color("#e8762a"))
	for i in 3:
		Spr.circle(x, y - (70 - i * 14) * s, 2.6 * s, INK)
	Spr.seg(x - 22 * s, y - 74 * s, x - 48 * s, y - 92 * s, Color("#5a3d22"), 3 * s)
	Spr.seg(x + 22 * s, y - 74 * s, x + 46 * s, y - 96 * s, Color("#5a3d22"), 3 * s)
	if hat:
		beanie(x, hy - 12 * s, s)

## o gorro verde do Tomé (com pompom)
static func beanie(x: float, y: float, s: float) -> void:
	var g1 := Color("#3f7a2e")
	var pts := PackedVector2Array([Vector2(x - 20 * s, y + 8 * s), Vector2(x - 16 * s, y - 10 * s), Vector2(x + 2 * s, y - 20 * s), Vector2(x + 18 * s, y - 10 * s), Vector2(x + 20 * s, y + 8 * s)])
	Spr.poly(pts, g1)
	Spr.ci.draw_polyline(pts, INK, 2, true)
	Spr.rr(x - 22 * s, y + 2 * s, 44 * s, 10 * s, 4 * s, Color("#2f5f22"))
	Spr.circle(x + 4 * s, y - 22 * s, 6 * s, Color(.97, .97, .95))

# ---------------------------------------------------------------- dinâmico (world_dyn)
static func draw(g: Game, T: int) -> void:
	var NT: Nature = g.NT
	if NT == null:
		return
	var x0: float = g.cam - 120
	var x1: float = g.cam + g.W + 120
	# corda esticada entre dois postes
	for b in NT.BARS:
		if b.x0 > x1 or b.x1 < x0:
			continue
		for px in [b.x0 - 14, b.x1 + 6]:
			Spr.rect(px, b.y - 30, 12, 1150 - b.y, Color("#5a3d22"))
			Spr.rect(px + 2, b.y - 30, 3, 1150 - b.y, Color(1, 1, 1, .08))
			Spr.ellipse(px + 6, b.y - 30, 9, 4, Color("#7a5532"))
		var sag := 10.0
		var pts := PackedVector2Array()
		var p: Dictionary = g.player
		var pcx: float = p.x + p.w / 2 if p.get("bar") == b else -9999.0
		for k in 41:
			var u := k / 40.0
			var xx: float = lerpf(b.x0 - 8, b.x1 + 12, u)
			var yy: float = b.y + sin(u * PI) * sag
			if pcx > -9000:
				yy += max(0.0, 1.0 - abs(xx - pcx) / 160.0) * 14
			pts.push_back(Vector2(xx, yy))
		Spr.ci.draw_polyline(pts, Color("#3a2414"), 6, true)
		Spr.ci.draw_polyline(pts, Color("#c9a26a"), 3.5, true)
	# buracos de água gelada
	for h in NT.HOLES:
		if h.x > x1 or h.x + h.w < x0:
			continue
		if not h.filled:
			# água gelada mortal: escura, quase preta, com placas de gelo rachadas e fumacinha de frio
			Spr.vgrad(h.x, h.y + 6, h.w, 134, Color(.07, .1, .14), Color(.01, .02, .04))
			Spr.rect(h.x, h.y + 6, h.w, 2, Color(.5, .6, .7, .5))
			var k := 0
			var px: float = h.x + 10
			while px < h.x + h.w - 30:
				var pw: float = 26 + fmod(px * .73, 22.0)
				var bob: float = sin(T * .04 + px) * 1.2
				var pts := PackedVector2Array([Vector2(px, h.y + 8 + bob), Vector2(px + pw * .4, h.y + 5 + bob), Vector2(px + pw, h.y + 8 + bob),
					Vector2(px + pw * .8, h.y + 13 + bob), Vector2(px + pw * .2, h.y + 13 + bob)])
				Spr.poly(pts, Color(.82, .92, 1, .92))
				Spr.seg(px + pw * .3, h.y + 7 + bob, px + pw * .55, h.y + 12 + bob, Color(.45, .58, .72), 1.2)
				px += pw + 14 + fmod(px * 1.3, 12.0)
				k += 1
			for v in 3:
				var vx: float = h.x + h.w * (.2 + v * .3) + sin(T * .02 + v) * 10
				var vy: float = h.y - fmod(T * .5 + v * 30.0, 50.0)
				Spr.ellipse(vx, vy, 16, 6, Color(.9, .95, 1, .18 * (1.0 - fmod(T * .5 + v * 30.0, 50.0) / 50.0)))
	# capacete e arpão
	for o in NT.GEAR:
		if o.got:
			continue
		var by: float = o.y + sin(T * .08) * 2
		Spr.glow(o.x, by - 16, 34, Color(1, .95, .7, .45))
		if o.id == "capacete":
			helmet(o.x, by, 1.0)
		else:
			Spr.A("crate_harpoon", o.x, by - 18, .62)
	# arpões
	for h in NT.HARP:
		var tail: float = h.x - sign(h.vx) * 26
		Spr.seg(tail, h.y, h.x, h.y, Color("#6b4a2a"), 3)
		Spr.poly(PackedVector2Array([Vector2(h.x + sign(h.vx) * 10, h.y), Vector2(h.x, h.y - 5), Vector2(h.x, h.y + 5)]), Color(.75, .78, .82))
		Spr.seg(h.sx, h.y + 2, tail, h.y, Color(.85, .8, .7, .35), 1)
	# corrente de bolhas (aberta depois do Bagre-Rei)
	if g.K and g.K.fish_done():
		for c in NT.CURRENTS:
			if c.x > x1 or c.x + c.w < x0:
				continue
			Spr.rect(c.x, c.y0, c.w, c.y1 - c.y0, Color(.7, .9, 1, .08 + sin(T * .1) * .03))
			for k in 10:
				var yy: float = c.y1 - fmod(T * 4.0 + k * 61.0, c.y1 - c.y0)
				Spr.ring(c.x + c.w * (.2 + (k % 5) * .15), yy, 4 + (k % 3) * 2, Color(.85, .95, 1, .7), 1.5)

## lamaçal (na camada da frente: o Tomé afunda nele)
static func draw_bogs(g: Game, T: int) -> void:
	var NT: Nature = g.NT
	if NT == null:
		return
	var x0: float = g.cam - 120
	var x1: float = g.cam + g.W + 120
	for b in NT.BOGS:
		if b.x > x1 or b.x + b.w < x0:
			continue
		Spr.rect(b.x, b.y + 8, b.w, 132, Color("#2e2414"))
		Spr.vgrad(b.x, b.y - 6, b.w, 22, Color("#7a6238"), Color("#3e3018"))
		Spr.rect(b.x, b.y - 6, b.w, 3, Color(.85, .75, .5, .5))
		var x: float = b.x + 24
		var i := 0
		while x < b.x + b.w - 10:
			var t: float = fmod(T * .018 + i * .37, 1.0)
			if i % 3 == 0:
				# sanguessuga se contorcendo para fora da lama
				var hgt: float = sin(t * PI) * 30
				var sw: float = sin(T * .2 + i) * 5
				var pts := PackedVector2Array([Vector2(x - 6, b.y), Vector2(x - 4 + sw * .5, b.y - hgt * .5), Vector2(x + sw, b.y - hgt), Vector2(x + 6 + sw, b.y - hgt + 4), Vector2(x + 4 + sw * .5, b.y - hgt * .5 + 4), Vector2(x + 6, b.y)])
				Spr.poly(pts, Color("#1e1610"))
				Spr.ci.draw_polyline(pts, Color("#5a3a2a"), 1.5, true)
				if hgt > 6:
					Spr.circle(x + sw + 2, b.y - hgt + 2, 1.8, Color(1, .35, .25))
			else:
				Spr.ring(x, b.y - 2, 4 + t * 12, Color(.9, .78, .5, .6 * (1.0 - t)), 1.5)
				Spr.circle(x + 8, b.y - 3 - sin(t * PI) * 4, 3 * (1.0 - t), Color("#5a4428"))
			x += 34 + (i % 4) * 8
			i += 1

static func helmet(x: float, y: float, s: float) -> void:
	var brass := Color("#c9902e")
	Spr.ellipse(x, y - 4 * s, 22 * s, 6 * s, Color("#7a5420"))
	Spr.circle(x, y - 24 * s, 20 * s, brass)
	Spr.ring(x, y - 24 * s, 20 * s, Color("#5a3a10"), 2)
	Spr.circle(x + 2 * s, y - 24 * s, 10 * s, Color(.55, .8, .95))
	Spr.ring(x + 2 * s, y - 24 * s, 10 * s, Color("#8a6a2a"), 3)
	Spr.ellipse(x + 5 * s, y - 28 * s, 3 * s, 2 * s, Color(1, 1, 1, .9))
	for a in [-1, 1]:
		Spr.circle(x + a * 17 * s, y - 24 * s, 4 * s, Color("#8a6a2a"))

static func snowball(c: Dictionary, T: int) -> void:
	var r: float = c.w / 2
	var cx: float = c.x + r
	var cy: float = c.y + r
	Spr.ellipse(cx, c.y + c.h + 1, r * .9, 4, Color(0, 0, 0, .2))
	Spr.circle(cx, cy, r, Color(.96, .97, 1))
	Spr.ring(cx, cy, r, Color(.58, .66, .8), 2)
	Spr.ellipse(cx + r * .25, cy + r * .3, r * .6, r * .5, Color(.8, .86, .96, .6))
	Spr.circle(cx - r * .35, cy - r * .35, r * .18, Color(1, 1, 1, .9))
	# marcas girando enquanto rola
	var a: float = c.x / max(8.0, r)
	for k in 3:
		var aa: float = a + k * TAU / 3.0
		Spr.circle(cx + cos(aa) * r * .55, cy + sin(aa) * r * .55, 2.2, Color(.6, .68, .8, .8))

## pedaços sólidos que aparecem durante o jogo
static func solid(s: Dictionary, T: int) -> void:
	match s.t:
		"snowfill":
			Spr.rr(s.x - 4, s.y - 4, s.w + 8, 22, 8, Color(.92, .96, 1))
			Spr.rect(s.x, s.y + 12, s.w, 18, Color(.7, .82, .95))
			for k in 5:
				Spr.seg(s.x + 20 + k * 50, s.y + 4, s.x + 34 + k * 50, s.y + 14, Color(.6, .72, .88), 1.5)
		"snowbank":
			var pts := PackedVector2Array([Vector2(s.x - 40, s.y + s.h), Vector2(s.x - 20, s.y + 40), Vector2(s.x + 6, s.y), Vector2(s.x + s.w + 10, s.y + 30), Vector2(s.x + s.w + 40, s.y + s.h)])
			Spr.poly(pts, Color(.93, .95, 1))
			Spr.ci.draw_polyline(pts, Color(.6, .68, .82), 2, true)
			# arame farpado
			for k in 3:
				var yy: float = s.y + 90 + k * 46
				Spr.seg(s.x - 70, yy, s.x + s.w + 10, yy + 6, Color(.35, .35, .38), 2)
				var xx: float = s.x - 66
				while xx < s.x + s.w:
					Spr.seg(xx - 4, yy - 4, xx + 4, yy + 4 + 1, Color(.3, .3, .32), 1.5)
					Spr.seg(xx - 4, yy + 4, xx + 4, yy - 4 + 1, Color(.3, .3, .32), 1.5)
					xx += 18
		"kinggate":
			WorldKings.gate(s, T)

# ---------------------------------------------------------------- bichos
static func squirrel(e: Dictionary, T: int) -> void:
	var brown := Color("#a0582a")
	var dark := Color("#6a3416")
	var throw: bool = e.get("st", 0) == 1
	var hop: float = abs(sin(T * .15 + e.x)) * 2.0
	# rabo grande
	var tail := PackedVector2Array([Vector2(-6, -8), Vector2(-22, -18), Vector2(-26, -36), Vector2(-16, -46), Vector2(-6, -38), Vector2(-12, -24), Vector2(-2, -14)])
	Spr.poly(tail, brown)
	Spr.ci.draw_polyline(tail + PackedVector2Array([tail[0]]), INK, 2, true)
	Spr.ellipse(-16, -36, 6, 8, Color("#c27a42"))
	# corpo e cabeça
	Spr.ellipse(0, -12 - hop, 11, 13, brown)
	Spr.ring(0, -12 - hop, 12, INK, 1.5, -.2, 4.2)
	Spr.ellipse(3, -8 - hop, 6, 8, Color("#e8c79a"))
	Spr.circle(4, -28 - hop, 9, brown)
	Spr.ring(4, -28 - hop, 9, INK, 1.5)
	Spr.poly(PackedVector2Array([Vector2(-1, -35 - hop), Vector2(1, -44 - hop), Vector2(5, -36 - hop)]), dark)
	Spr.circle(8, -30 - hop, 2, INK)
	Spr.circle(13, -26 - hop, 1.6, INK)
	# bolota na mão
	var ax: float = 12 if not throw else 4
	var ay: float = -14 - hop if not throw else -40
	Spr.ellipse(ax, ay, 4, 5, Color("#8a5a2a"))
	Spr.ellipse(ax, ay - 4, 5, 2.5, Color("#5a3a1a"))

static func crow(e: Dictionary, T: int) -> void:
	if e.dead:
		Spr.A("crow_dead", 0, 0, .5)
		return
	Spr.A("crow%d" % ((T / 4) % 3), 0, -6, .5)

static func piranha(e: Dictionary, T: int) -> void:
	if e.dead:
		Spr.A("piranha_dead", 0, 0, .48)
		return
	Spr.A("piranha%d" % ((T / 6) % 4), 0, 0, .48)

# ---------------------------------------------------------------- cavalo
## cavalo desenhado: corpo, pescoço, cabeça e quatro pernas num galope (g = fase do galope)
static func horse(x: float, y: float, g: float, run: float, st: String, T: int) -> void:
	var coat := Color("#8a5a34")
	var dark := Color("#5a3820")
	var mane := Color("#2e1e14")
	Spr.ellipse(x, y + 2, 56, 7, Color(0, 0, 0, .25))
	var bob: float = abs(sin(g * PI)) * 5 * run
	var by: float = y - 60 - bob
	# pernas (as de trás atrás do corpo)
	var legs := [[-30, 0.0], [-20, .5], [26, .25], [36, .75]]
	for i in 4:
		var lx: float = x + legs[i][0]
		var ph: float = (g + legs[i][1]) * TAU
		var sw: float = sin(ph) * 16 * run
		var lift: float = max(0.0, cos(ph)) * 12 * run
		var knee := Vector2(lx + sw * .5, by + 26 - lift * .5)
		var hoof := Vector2(lx + sw, y - lift)
		var c: Color = dark if i % 2 == 0 else coat
		Spr.seg(lx, by + 8, knee.x, knee.y, c, 9)
		Spr.seg(knee.x, knee.y, hoof.x, hoof.y - 4, c, 7)
		Spr.rect(hoof.x - 5, hoof.y - 6, 10, 6, Color("#2a1a10"))
	# rabo
	var tw: float = sin(T * .3) * 6 * (run + .3)
	Spr.line(PackedVector2Array([Vector2(x - 46, by - 6), Vector2(x - 62, by + 10 + tw), Vector2(x - 66, by + 34 + tw)]), mane, 8)
	# corpo
	Spr.ellipse(x, by, 50, 24, coat)
	var body := PackedVector2Array()
	for k in 25:
		var a := TAU * k / 24.0
		body.push_back(Vector2(x + cos(a) * 50, by + sin(a) * 24))
	Spr.ci.draw_polyline(body, INK, 2.5, true)
	Spr.ellipse(x + 6, by + 8, 34, 12, Color(1, 1, 1, .08))
	# pescoço e cabeça
	var hx: float = x + 44
	var hy: float = by - 34 + (sin(g * TAU) * 3 * run)
	var neck := PackedVector2Array([Vector2(x + 26, by - 14), Vector2(hx - 2, hy - 8), Vector2(hx + 14, hy + 2), Vector2(x + 44, by + 4)])
	Spr.poly(neck, coat)
	Spr.ci.draw_polyline(neck, INK, 2.5, true)
	var head := PackedVector2Array([Vector2(hx - 4, hy - 12), Vector2(hx + 10, hy - 16), Vector2(hx + 34, hy + 4), Vector2(hx + 32, hy + 14), Vector2(hx + 20, hy + 16), Vector2(hx + 2, hy + 6)])
	Spr.poly(head, coat)
	Spr.ci.draw_polyline(head + PackedVector2Array([head[0]]), INK, 2.5, true)
	Spr.poly(PackedVector2Array([Vector2(hx + 2, hy - 12), Vector2(hx + 4, hy - 26), Vector2(hx + 10, hy - 14)]), dark)
	Spr.circle(hx + 14, hy - 4, 2.6, INK)
	Spr.circle(hx + 30, hy + 9, 1.8, INK)
	# crina
	for k in 6:
		var u := k / 5.0
		var mx: float = lerpf(hx + 2, x + 24, u)
		var my: float = lerpf(hy - 12, by - 18, u)
		Spr.ellipse(mx - 4, my + 2 + sin(T * .3 + k) * 2 * run, 7, 4, mane, -.6)
	# rédeas e sela
	Spr.rr(x - 18, by - 26, 34, 12, 5, Color("#6b2a1a"))
	Spr.seg(x + 10, by - 22, hx + 26, hy + 8, Color("#3a2414"), 1.5)
	if st == "trapped":
		Spr.text("!", hx + 10, hy - 50 + sin(T * .2) * 3, 26, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
