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
		"snowtree":
			prop("arvore_neve", d.x, d.y + 4, 300 * s)
		"tracks":
			pass   # desenhado na camada de cima (tracks), por cima do chão

## objeto pintado (assets/sprites/p_<nome>.png), com a base no ponto (x, y) e a altura dada
static func prop(n: String, x: float, y: float, h: float, flip: bool = false, a: float = 1.0) -> void:
	var k := "p_" + n
	if not Spr.tex.has(k):
		Spr.tex[k] = load("res://assets/sprites/%s.png" % k)
	var t: Texture2D = Spr.tex[k]
	var w: float = h * t.get_width() / t.get_height()
	if flip:
		Spr.save()
		Spr.translate(x, y)
		Spr.scale(-1, 1)
		Spr.ci.draw_texture_rect(t, Rect2(-w / 2, -h, w, h), false, Color(1, 1, 1, Spr.alpha * a))
		Spr.restore()
	else:
		Spr.ci.draw_texture_rect(t, Rect2(x - w / 2, y - h, w, h), false, Color(1, 1, 1, Spr.alpha * a))

static func pine(x: float, y: float, s: float) -> void:
	prop("pinheiro", x, y + 4, 330 * s)

static func snowman(x: float, y: float, s: float, hat: bool) -> void:
	Spr.ellipse(x, y + 2, 40 * s, 8 * s, Color(0, 0, 0, .2))
	prop("boneco", x, y + 4, 150 * s)
	if hat:
		beanie(x - 2 * s, y - 128 * s, s)

## o gorro verde do Tomé (com pompom); (x, y) = meio da aba
static func beanie(x: float, y: float, s: float) -> void:
	prop("gorro", x, y + 12 * s, 40 * s)


## marcas das rodas do carrinho e pegadas na neve (por cima do chão)
static func tracks(d: Dictionary) -> void:
	var w: float = d.get("w", 800)
	for k in 2:
		var ty: float = d.y - 3 + k * 5
		Spr.seg(d.x, ty, d.x + w, ty + 2, Color(.55, .62, .74, .8), 3)
	var fx: float = d.x + 20
	var n := 0
	while fx < d.x + w:
		Spr.ellipse(fx, d.y - 1 + (n % 2) * 4, 6, 2.5, Color(.5, .56, .68, .75))
		fx += 46
		n += 1

# ---------------------------------------------------------------- dinâmico (world_dyn)
static func draw(g: Game, T: int) -> void:
	var NT: Nature = g.NT
	if NT == null:
		return
	var x0: float = g.cam - 120
	var x1: float = g.cam + g.W + 120
	for d in g.L.get("decor", []):
		if d.k == "tracks" and d.x < x1 and d.x + d.get("w", 800) > x0:
			tracks(d)
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
	prop("capacete", x, y + 2 * s, 48 * s)

static func snowball(c: Dictionary, T: int) -> void:
	var r: float = c.w / 2
	var cx: float = c.x + r
	var cy: float = c.y + r
	Spr.ellipse(cx, c.y + c.h + 1, r * .9, 4, Color(0, 0, 0, .2))
	# gira enquanto rola
	Spr.save()
	Spr.translate(cx, cy)
	Spr.rotate(c.x / max(8.0, r))
	prop("bola_neve", 0, r * 1.02, r * 2.04)
	Spr.restore()

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
	# arte: 0-3 correndo, 4 bote, 5 nocauteado (olhando para a direita; o chamador já espelha)
	if not Spr.tex.has("esquilo"):
		Spr.tex["esquilo"] = load("res://assets/sprites/esquilo.png")
	var fr: int = int(e.get("run", 0.0)) % 4
	if e.dead:
		fr = 5
	elif e.get("st", 0) == 2:
		fr = 4
	elif e.get("st", 0) == 1:
		fr = 3
	var s := .5
	Spr.ci.draw_texture_rect_region(Spr.tex.esquilo, Rect2(-65 * s, -108 * s, 130 * s, 110 * s), Rect2(fr * 130, 0, 130, 110), Color(1, 1, 1, Spr.alpha))

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
## cavalo desenhado (arte em assets/sprites/cavalo.png; âncoras em assets/data/art_meta.json)
static var HM: Dictionary = {}
const HORSE_SC := .8

static func _hm() -> Dictionary:
	if HM.is_empty():
		var f := FileAccess.open("res://assets/data/art_meta.json", FileAccess.READ)
		HM = JSON.parse_string(f.get_as_text()).cavalo
		if not Spr.tex.has("cavalo"):
			Spr.tex["cavalo"] = load("res://assets/sprites/cavalo.png")
	return HM

## quadro do cavalo: 0-3 galope, 4 pulo, 5 parado
static func horse_frame(g: float, run: float, st: String) -> int:
	if st == "jump":
		return 4
	if run <= .05:
		return 5
	return int(floor(g * 4.0)) % 4

## altura da sela acima do chão (negativa), para pôr o Tomé montado
static func horse_seat(fr: int) -> float:
	var m := _hm()
	return (float(m.seat[fr][1]) - float(m.ay)) * HORSE_SC

static func horse(x: float, y: float, g: float, run: float, st: String, T: int) -> void:
	var m := _hm()
	var fr := horse_frame(g, run, st)
	var s := HORSE_SC
	var cw: float = m.w
	var ch: float = m.h
	Spr.ellipse(x, y + 2, 64, 8, Color(0, 0, 0, .25 if st != "jump" else .12))
	Spr.ci.draw_texture_rect_region(Spr.tex.cavalo, Rect2(x - float(m.ax) * s, y - float(m.ay) * s, cw * s, ch * s),
		Rect2(fr * cw, 0, cw, ch), Color(1, 1, 1, Spr.alpha))
	if st == "trapped":
		# arame farpado enrolado nas patas
		for k in 3:
			var wy: float = y - 14 - k * 9
			Spr.seg(x - 50, wy, x + 40, wy + 4, Color(.55, .55, .58), 1.6)
			for j in 6:
				var bx: float = x - 44 + j * 15
				Spr.seg(bx - 3, wy - 3, bx + 3, wy + 4, Color(.4, .4, .44), 1.4)
		Spr.text("!", x + 50, y - 150 + sin(T * .2) * 3, 26, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
