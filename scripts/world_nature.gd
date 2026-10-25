extends RefCounted
class_name WorldNature
## Desenho dos trechos novos: pinheiros, casas da vila com neve, lampião e boneco de neve (fixos);
## lamaçal com sanguessugas, corda esticada, bolhas, capacete, arpão, bolas de neve, buracos de
## água gelada, esquilos, corvos, piranhas, e o cavalo.

const INK := Color("#2a1a0e")
## faixa do pedaço de cenário que está desenhando (peças largas se cortam nela)
static var clip_x0 := -1e9
static var clip_x1 := 1e9

# ---------------------------------------------------------------- cenário fixo (world_static)
static func decor(d: Dictionary) -> void:
	var s: float = d.get("s", 1.0)
	match d.k:
		"pine":
			pine(d.x, d.y, s, float(d.get("lean", 0.0)), d.get("fl", 0) == 1, int(d.get("v", 0)))
		"lookout":
			lookout(d.x, d.y)
		"house1", "house2":
			var n: String = "v_house1" if d.k == "house1" else "v_house2"
			var w: float = 210 * s
			Spr.ellipse(d.x, d.y + 2, w * .55, 10, Color(0, 0, 0, .25))
			# casas são só cenário (sólidas, sem transparência)
			Spr.ABb(n, d.x, d.y + 6, w)
			# neve de verdade cobrindo o telhado: acompanha o contorno de cima da casa (lido da arte)
			var r = Spr.AR[n]
			var k: float = w / r[2]
			var line: PackedFloat32Array = _roof_line(n)
			var left: float = d.x - w / 2
			var base: float = d.y + 6 - r[3] * k
			var tp := PackedVector2Array()
			var bp := PackedVector2Array()
			for i in line.size():
				var sx: float = left + i * 3 * k
				var ty: float = base + line[i] * k
				var fluff: float = 2.5 + 1.5 * sin(sx * .21) + 1.2 * sin(sx * .07)
				tp.push_back(Vector2(sx, ty - fluff))
				bp.push_back(Vector2(sx, ty + 7 + 2.5 * sin(sx * .13 + 1.0)))
			var sp := PackedVector2Array(tp)
			for i in range(bp.size() - 1, -1, -1):
				sp.push_back(bp[i])
			Spr.poly(sp, Color(.96, .97, 1))
			Spr.line(bp, Color(.72, .8, .92, .8), 2)
			# pingentes nas beiradas mais baixas do telhado
			for side in [0, 1]:
				var lo_i := 0
				var lo_y := -1e9
				var rng: Array = range(0, line.size() / 3) if side == 0 else range(line.size() * 2 / 3, line.size())
				for i in rng:
					if line[i] > lo_y and line[i] < r[3] * .75:
						lo_y = line[i]
						lo_i = i
				for q in 4:
					var qi: int = clamp(lo_i + (q - 2) * 3 * (1 if side == 0 else -1), 0, line.size() - 1)
					var ix: float = left + qi * 3 * k
					var iy: float = base + line[qi] * k + 6
					var ln: float = 8 + (q * 7 % 5) * 3
					Spr.poly(PackedVector2Array([Vector2(ix - 3, iy), Vector2(ix, iy + ln), Vector2(ix + 3, iy)]), Color(.85, .95, 1, .95))
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
			_roots(d.x, d.y, s)
		"tracks", "paws":
			pass   # desenhado na camada de cima (tracks), por cima do chão
		"bearden":
			# a toca do Urso-Rei: encosta de pedra nevada com a caverna escura (fundo da arena)
			if Spr.has("p_bearden"):
				# cada pedaço do cenário desenha só a sua faixa (senão o pedaço seguinte cobre os blocos de gelo)
				var r: Array = Spr.AR["p_bearden"]
				var w: float = 860 * s
				var hgt: float = w * r[3] / r[2]
				var left: float = d.x - w / 2
				var va: float = max(left, clip_x0)
				var vb: float = min(left + w, clip_x1)
				if vb > va:
					var t: Texture2D = Spr.atlas_tex(r)
					var su: float = (va - left) / w
					var sv: float = (vb - left) / w
					var dst := Rect2(va, d.y + 8 - hgt, vb - va, hgt)
					var src := Rect2(r[0] + r[2] * su, r[1], r[2] * (sv - su), r[3])
					# mais escura e com um véu frio por cima (menos detalhe e contraste): a pintura da toca
					# fica no mesmo peso do resto do cenário, como uma encosta um pouco atrás do caminho
					Spr.ci.draw_texture_rect_region(t, dst, src, Color(.66, .7, .8, Spr.alpha))
					Spr.ci.draw_texture_rect_region(Spr.sil(t), dst, src, Color(.5, .57, .72, .3 * Spr.alpha))
			else:
				Spr.ellipse(d.x, d.y, 360 * s, 190 * s, Color("#5d6878"))
				Spr.ellipse(d.x, d.y - 150 * s, 300 * s, 60 * s, Color(.93, .95, 1))
				Spr.ellipse(d.x, d.y - 10, 90 * s, 110 * s, Color("#141820"))
		"logpile":
			Spr.ellipse(d.x, d.y + 2, 70 * s, 7, Color(0, 0, 0, .2))
			WorldVehicles._hlog(d.x - 64 * s, d.x + 60 * s, d.y - 18 * s, 18 * s)
			WorldVehicles._hlog(d.x - 40 * s, d.x + 50 * s, d.y - 34 * s, 16 * s)
			Spr.ellipse(d.x - 6, d.y - 36 * s, 40 * s, 5, Color(.95, .97, 1))

## linha de cima da arte (o contorno do telhado), a cada 3 px, para a neve assentar certinho
static var _roofs := {}
static func _roof_line(n: String) -> PackedFloat32Array:
	if _roofs.has(n):
		return _roofs[n]
	var r = Spr.AR[n]
	var im: Image = Spr.atlas_tex(r).get_image()
	if im.is_compressed():
		im.decompress()
	var out := PackedFloat32Array()
	var x := 0
	while x < int(r[2]):
		var y := 0
		while y < int(r[3]) and im.get_pixel(int(r[0]) + x, int(r[1]) + y).a < .5:
			y += 1
		out.push_back(float(y))
		x += 3
	_roofs[n] = out
	return out

## objeto pintado (assets/sprites/p_<nome>.png), com a base no ponto (x, y) e a altura dada
static func prop(n: String, x: float, y: float, h: float, flip: bool = false, a: float = 1.0) -> void:
	var k := "p_" + n
	if not Spr.tex.has(k):
		Spr.late(k)
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

## árvore do cenário plantada no chão de baixo, na frente de um paredão onde o Tomé anda em cima:
## fica na camada da frente (o Tomé passa por trás dela)
static func is_front(L: Dictionary, d: Dictionary) -> bool:
	if d.has("_front"):
		return d._front
	var f := false
	if d.get("k", "") in ["pine", "snowtree", "tree"]:
		for s in L.solids:
			if s.get("deco") or not str(s.get("t", "")) in ["cliff", "stone", "dirt", "ground"]:
				continue
			if s.x + 10 < d.x and d.x < s.x + s.w - 10 and s.y < d.y - 40 and abs(s.y + s.get("h", 0) - d.y) < 24:
				f = true
	d._front = f
	return f

## árvores da camada da frente (desenhadas depois do Tomé)
static func front_decor(g: Game) -> void:
	for d in g.L.get("decor", []):
		if d.x < g.cam - 300 or d.x > g.cam + g.W + 300:
			continue
		if is_front(g.L, d):
			decor(d)

## pinheiro do cenário. Para não repetir o mesmo: inclinado (lean), espelhado (fl) e variações —
## v=1 com um galho quebrado caído na neve e o toco no tronco, v=2 mais fino e alto
static func pine(x: float, y: float, s: float, lean: float = 0.0, fl: bool = false, v: int = 0) -> void:
	if lean == 0.0 and not fl and v == 0:
		prop("pinheiro", x, y + 4, 330 * s)
		_roots(x, y, s)
		return
	Spr.save()
	Spr.translate(x, y + 4)
	Spr.rotate(lean)
	Spr.scale((-1.0 if fl else 1.0) * (.8 if v == 2 else 1.0), 1.1 if v == 2 else 1.0)
	prop("pinheiro", 0, 0, 330 * s)
	if v == 1:
		# toco do galho que quebrou (lasca clara) no meio do tronco
		var ty: float = -330 * s * .42
		Spr.poly(PackedVector2Array([Vector2(4 * s, ty - 5 * s), Vector2(26 * s, ty - 9 * s), Vector2(24 * s, ty + 1 * s), Vector2(4 * s, ty + 6 * s)]), Color("#5a3a20"))
		Spr.poly(PackedVector2Array([Vector2(24 * s, ty - 9 * s), Vector2(30 * s, ty - 4 * s), Vector2(24 * s, ty + 1 * s)]), Color("#d9b27a"))
	Spr.restore()
	_roots(x, y, s)
	if v == 1:
		# o galho quebrado caído na neve, ao lado
		Spr.P("galhoneve2", x + (-1.0 if fl else 1.0) * 70 * s, y + 6, 110 * s, fl, .1)

## mirante no alto da subida: cerquinha de madeira com neve e uma luneta num tripé
static func lookout(x: float, y: float) -> void:
	Spr.ellipse(x, y + 2, 90, 6, Color(0, 0, 0, .15))
	for px in [x - 64.0, x - 4.0, x + 56.0]:
		Spr.PR("stake", px - 5, y - 58, 11, 62, Color(.85, .8, .75))
		Spr.ellipse(px + .5, y - 58, 7, 3, Color(.97, .98, 1))
	WorldVehicles._hlog(x - 70, x + 64, y - 50, 8)
	WorldVehicles._hlog(x - 70, x + 64, y - 28, 7)
	Spr.ellipse(x - 3, y - 51, 66, 3.5, Color(.97, .98, 1))
	# luneta de latão no tripé, apontando para o vale
	var tx: float = x + 98
	for dx in [-14.0, 0.0, 14.0]:
		Spr.seg(tx, y - 40, tx + dx, y, Color("#4e331d"), 3)
	Spr.save()
	Spr.translate(tx, y - 42)
	Spr.rotate(-.22)
	Spr.rr(-14, -5, 34, 10, 4, Color("#b8893a"))
	Spr.rr(18, -6.5, 10, 13, 3, Color("#8a6224"))
	Spr.rect(-10, -4, 26, 2, Color(1, .9, .6, .6))
	Spr.restore()

## raízes e um montinho de neve na base: a árvore fica plantada no chão (sem parecer flutuar)
static func _roots(x: float, y: float, s: float) -> void:
	for r in [-1.0, -.4, .45, 1.0]:
		Spr.poly(PackedVector2Array([Vector2(x + r * 6 * s, y - 10 * s), Vector2(x + r * 30 * s, y + 3), Vector2(x + r * 6 * s, y + 3)]), Color("#4e331d"))
	Spr.ellipse(x, y + 1, 34 * s, 6, Color(.95, .97, 1))
	Spr.ellipse(x - 8 * s, y - 2, 20 * s, 4, Color(1, 1, 1))

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

## pegadas grandes do urso na neve (almofada + 4 dedos), indo e voltando da toca
static func paws(d: Dictionary) -> void:
	var w: float = d.get("w", 600)
	var fx: float = d.x + 10
	var n := 0
	var c := Color(.48, .54, .66, .7)
	while fx < d.x + w:
		var fy: float = d.y - 2 + (n % 2) * 5
		Spr.ellipse(fx, fy, 9, 3.4, c)
		for t in 4:
			Spr.ellipse(fx - 8 + t * 5.3, fy - 5.5 - abs(t - 1.5) * -.6, 2.4, 1.6, c)
		fx += 64
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
		elif d.k == "paws" and d.x < x1 and d.x + d.get("w", 600) > x0:
			paws(d)
	# corda esticada entre dois postes
	for b in NT.BARS:
		if b.x0 > x1 or b.x1 < x0:
			continue
		for px in ([] if b.get("clothes") else [b.x0 - 14, b.x1 + 6]):
			Spr.rect(px, b.y - 30, 12, 1150 - b.y, Color("#5a3d22"))
			Spr.rect(px + 2, b.y - 30, 3, 1150 - b.y, Color(1, 1, 1, .08))
			Spr.ellipse(px + 6, b.y - 30, 9, 4, Color("#7a5532"))
		var pts := PackedVector2Array()
		var p: Dictionary = g.player
		var pcx: float = p.x + p.w / 2 if p.get("bar") == b else -9999.0
		for k in 41:
			var u := k / 40.0
			var xx: float = lerpf(b.x0 - 8, b.x1 + 12, u)
			pts.push_back(Vector2(xx, NT.bar_y(b, xx)))
		Spr.ci.draw_polyline(pts, Color("#3a2414"), 6, true)
		Spr.ci.draw_polyline(pts, Color("#c9a26a"), 3.5, true)
		if b.get("clothes"):
			# varal da vila: roupas penduradas balançando (onde o Tomé segura, elas saem do caminho)
			var cols := [Color("#c94a3a"), Color("#e8e0c8"), Color("#4a7ab0"), Color("#d8a83a"), Color("#6a9a4a")]
			for k in range(2, 40, 5):
				var q: Vector2 = pts[k]
				if abs(q.x - pcx) < 40:
					continue
				var sw: float = sin(g.T * .05 + q.x * .1) * .12
				var c: Color = cols[int(abs(q.x)) % cols.size()]
				Spr.save()
				Spr.translate(q.x, q.y + 1)
				Spr.rotate(sw)
				if int(abs(q.x) / 3.0) % 2 == 0:
					# camisa
					Spr.poly(PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(16, 10), Vector2(10, 10), Vector2(10, 28), Vector2(-10, 28), Vector2(-10, 10), Vector2(-16, 10)]), c)
				else:
					# meia ou pano
					Spr.rect(-6, 0, 12, 22, c)
				Spr.rect(-2, -2, 4, 4, Color("#8a6a42"))
				Spr.restore()
	# buracos de água gelada
	for h in NT.HOLES:
		if h.x > x1 or h.x + h.w < x0:
			continue
		if not h.filled:
			# água gelada mortal: paredes de gelo irregulares, água escura ondulando e margens de neve fofa
			var wpts := PackedVector2Array()
			var wx: float = h.x + 4
			while wx <= h.x + h.w - 4:
				wpts.push_back(Vector2(wx, h.y + 8 + sin(T * .05 + wx * .05) * 1.6 + sin(T * .031 - wx * .09) * 1.0))
				wx += 8
			var surf := PackedVector2Array(wpts)
			wpts.push_back(Vector2(h.x + h.w - 4, h.y + 140))
			wpts.push_back(Vector2(h.x + 4, h.y + 140))
			var wcols := PackedColorArray()
			for i in wpts.size():
				wcols.push_back(Color(.07, .12, .17) if i < surf.size() else Color(.01, .02, .04))
			Spr.ci.draw_polygon(wpts, wcols)
			Spr.line(surf, Color(.55, .68, .8, .6), 2)
			for side in [0, 1]:
				var e: float = h.x if side == 0 else h.x + h.w
				var dir: float = 1.0 if side == 0 else -1.0
				var wp := PackedVector2Array([Vector2(e - dir * 2, h.y)])
				var wy: float = h.y
				while wy <= h.y + 140:
					wp.push_back(Vector2(e + dir * (16 + 10 * sin(wy * .09 + e) + 6 * sin(wy * .27 + e) + max(0.0, 18.0 - (wy - h.y) * .3)), wy))
					wy += 10
				wp.push_back(Vector2(e - dir * 2, h.y + 140))
				Spr.poly(wp, Color(.3, .42, .58))
				# gelo claro na parte de cima da parede
				var wp2 := PackedVector2Array([Vector2(e - dir * 2, h.y)])
				for q in 6:
					var qy: float = h.y + q * 6
					wp2.push_back(Vector2(e + dir * (22 - q * 2.5 + 4 * sin(qy * .3 + e)), qy))
				wp2.push_back(Vector2(e - dir * 2, h.y + 30))
				Spr.poly(wp2, Color(.7, .85, .97))
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
			# margens de neve arredondadas cobrindo a quina do buraco
			for side in [0, 1]:
				var ex: float = h.x if side == 0 else h.x + h.w
				Spr.ellipse(ex, h.y + 2, 26, 11, Color(.8, .87, .97))
				Spr.ellipse(ex - (2 if side == 0 else -2), h.y - 1, 22, 8, Color(.97, .98, 1))
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
	_flows(NT, T, x0, x1)
	for o in NT.ULEV:
		if o.x > x1 + 900 or o.x < x0 - 900:
			continue
		var gt = NT._gate_of(o)
		if gt != null:
			_chain(o, gt, T, x0, x1)
			if float(gt.x) < x1 and float(gt.x) + gt.w > x0:
				_ugrate(gt, T)
		if o.x > x0 - 60 and o.x < x1 + 60:
			_ulever(o, T)
	for o in NT.CHESTS:
		if o.x > x0 - 60 and o.x < x1 + 60:
			_chest(o, T)

## correnteza: fios de água clara correndo, folhinhas e bolhinhas arrastadas, mais forte no meio
static func _flows(NT: Nature, T: int, x0: float, x1: float) -> void:
	for f in NT.FLOWS:
		if f.x > x1 or f.x + f.w < x0:
			continue
		var h: float = float(f.y1) - float(f.y0)
		var sp: float = float(f.vx) * 2.2
		for k in 22:
			var ln: float = 26 + _bh(k, 21) * 40
			var fx: float = float(f.x) + fposmod(T * sp * (.8 + _bh(k, 22) * .5) + k * 131.0, float(f.w) + ln) - ln
			var fy: float = float(f.y0) + 10 + _bh(k, 23) * (h - 20) + sin(T * .05 + k) * 3.0
			if fx + ln < x0 or fx > x1:
				continue
			var e: float = clamp(min(fx - f.x, f.x + f.w - fx - ln) / 60.0, 0.0, 1.0)
			var mid: float = 1.0 - abs((fy - f.y0) / h - .5) * 1.4
			var al: float = .5 * e * mid
			if al <= .01:
				continue
			var pts := PackedVector2Array()
			for q in 5:
				var u: float = q / 4.0
				pts.push_back(Vector2(fx + u * ln, fy + sin(u * 4.0 + T * .1 + k) * 2.0))
			Spr.line(pts, Color(.85, .97, 1, al), 2.2)
			Spr.circle(pts[4].x, pts[4].y, 1.6, Color(1, 1, 1, al))
		# folhinhas e sujeira levadas pela água
		for k in 7:
			var fx2: float = float(f.x) + fposmod(T * sp * 1.1 + k * 173.0, float(f.w))
			var fy2: float = float(f.y0) + 18 + _bh(k, 24) * (h - 36) + sin(T * .07 + k * 2.0) * 8.0
			if fx2 < x0 or fx2 > x1:
				continue
			var e2: float = clamp(min(fx2 - f.x, f.x + f.w - fx2) / 60.0, 0.0, 1.0)
			if k % 2 == 0:
				Spr.ellipse(fx2, fy2, 5, 2, Color(.45, .55, .25, .7 * e2), T * .08 + k)
			else:
				Spr.ring(fx2, fy2, 2.5, Color(.85, .95, 1, .55 * e2), 1.0)

## grade de ferro que fecha a saída do mergulho: sobe para dentro da pedra quando a alavanca desce
static func _ugrate(s: Dictionary, T: int) -> void:
	var op: float = float(s.get("open", 0.0))
	var top: float = float(s.y)
	var bot: float = float(s.y) + float(s.h) - op * (float(s.h) - 6)
	if bot <= top + 2:
		return
	var sh: float = sin(T * .9) * .8 if op > 0.0 and op < 1.0 else 0.0
	var gx: float = float(s.x) + sh
	# sombra na pedra e as barras redondas (escuro, luz do lado esquerdo, ferrugem e limo)
	Spr.rect(gx - 3, top, s.w + 6, bot - top, Color(0, 0, 0, .18))
	for k in 4:
		var bx: float = gx + 2 + k * (float(s.w) - 4) / 3.0
		Spr.rect(bx - 3.6, top, 7.2, bot - top, Color("#1a1816"))
		Spr.rect(bx - 2.4, top, 2.2, bot - top, Color("#7a7670"))
		Spr.rect(bx + .4, top, 1.8, bot - top, Color("#3a3634"))
		# pontas afiadas embaixo
		Spr.poly(PackedVector2Array([Vector2(bx - 3.6, bot - 1), Vector2(bx + 3.6, bot - 1), Vector2(bx, bot + 9)]), Color("#2a2826"))
	var cy: float = bot - 30.0
	while cy > top + 8:
		Spr.rr(gx - 4, cy - 3, s.w + 8, 7, 3, Color("#2a2624"))
		Spr.rect(gx - 3, cy - 2, s.w + 6, 1.6, Color("#7a746c"))
		Spr.circle(gx + 4, cy + 2, 2.2, Color(.55, .3, .15, .7))
		cy -= 72.0
	# limo pendurado balançando
	for k in 3:
		var lx: float = gx + 4 + k * 9
		var ly: float = bot - 50 - k * 60
		if ly < top + 10:
			continue
		var sw: float = sin(T * .06 + k * 1.7) * 3.0
		Spr.line(PackedVector2Array([Vector2(lx, ly), Vector2(lx + sw * .5, ly + 10), Vector2(lx + sw, ly + 20)]), Color(.35, .5, .22, .8), 2.0)

## corrente que sai da alavanca, corre pelo fundo e sobe até a grade (mostra que uma puxa a outra)
static func _chain(o: Dictionary, gt: Dictionary, T: int, x0: float, x1: float) -> void:
	var ax: float = float(o.x) + 8
	var ay: float = float(o.y) - 8
	var bx: float = float(gt.x) - 6
	var by: float = float(o.y) - 6
	var tight: float = clamp(float(o.t) / 24.0, 0.0, 1.0) if o.on else 0.0
	var x: float = max(ax, x0 - 20)
	var xe: float = min(bx, x1 + 20)
	var k := int((x - ax) / 9.0)
	x = ax + k * 9.0
	while x < xe:
		var u: float = (x - ax) / max(1.0, bx - ax)
		var y: float = lerpf(ay, by, u) + 3.0 * (1.0 - tight) * (sin(x * .02) * .5 + .5) - tight * 2.0
		if k % 2 == 0:
			Spr.ellipse(x, y, 5, 2.6, Color("#2a2622"))
			Spr.ellipse(x, y, 3.6, 1.4, Color("#6a625a"))
		else:
			Spr.rect(x - 1.5, y - 3, 3, 6, Color("#3a3430"))
		x += 9.0
		k += 1
	# o pé da grade: a corrente sobe pela parede até a barra de baixo
	if bx > x0 - 20 and bx < x1 + 20:
		var gy0: float = by
		var gy1: float = float(gt.y) + float(gt.h) - float(gt.get("open", 0.0)) * (float(gt.h) - 6) - 10
		var y2: float = gy0
		while y2 > gy1:
			Spr.ellipse(bx, y2, 2.4, 4.5, Color("#2a2622"))
			Spr.ellipse(bx, y2, 1.2, 3.2, Color("#6a625a"))
			y2 -= 9.0
		Spr.circle(bx, by, 4.5, Color("#3a3430"))
		Spr.circle(bx - 1, by - 1, 1.6, Color("#8a827a"))

## alavanca no fundo: base de pedra com limo, eixo de ferro e cabo de madeira com argola
static func _ulever(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var u: float = clamp(float(o.t) / 18.0, 0.0, 1.0) if o.on else 0.0
	var e: float = u * u * (3.0 - 2.0 * u)
	var ang: float = lerpf(-.75, .75, e) + (sin(T * .05) * .03 if not o.on else 0.0)
	if not o.on:
		Spr.glow(x, y - 30, 46 + sin(T * .1) * 4, Color(1, .9, .55, .22))
	# cabo
	var hl: float = 52.0
	var tip := Vector2(x + sin(ang) * hl, y - 14 - cos(ang) * hl)
	Spr.seg(x, y - 14, tip.x, tip.y, Color("#24160c"), 8)
	Spr.seg(x, y - 14, tip.x, tip.y, Color("#8a5a32"), 5)
	Spr.seg(x - 1.5, y - 16, tip.x - 1.5, tip.y - 1, Color("#c08a54"), 1.6)
	Spr.circle(tip.x, tip.y, 7, Color("#24160c"))
	Spr.circle(tip.x, tip.y, 5.4, Color("#a87a4a"))
	Spr.circle(tip.x - 1.5, tip.y - 1.5, 1.8, Color(1, 1, 1, .4))
	# base de pedra
	Spr.ellipse(x, y - 4, 26, 12, Color("#24201c"))
	Spr.ellipse(x, y - 6, 24, 10, Color("#6a6a60"))
	Spr.ellipse(x - 6, y - 10, 12, 4, Color(1, 1, 1, .15))
	Spr.ellipse(x + 8, y - 13, 10, 3.5, Color(.36, .5, .22, .85))
	Spr.circle(x, y - 14, 5, Color("#24201c"))
	Spr.circle(x, y - 14, 3.4, Color("#8a8070"))
	# setinha de dica antes de puxar
	if not o.on and (T / 24) % 2 == 0:
		Spr.text("▼", x, y - 92 + sin(T * .1) * 3, 16, Color(1, .92, .6, .85), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 3)

## baú no fundo: madeira escura com cintas de ouro; aberto, a tampa vira para trás e brilha
static func _chest(o: Dictionary, T: int) -> void:
	var x: float = o.x
	var y: float = o.y
	var w := 46.0
	var h := 26.0
	Spr.ellipse(x, y + 1, 28, 5, Color(0, 0, 0, .3))
	if not o.got:
		Spr.glow(x, y - 16, 40 + sin(T * .08) * 4, Color(1, .85, .4, .25))
	# caixa
	Spr.rr(x - w / 2 - 1.5, y - h - 1.5, w + 3, h + 3, 4, Color("#24160c"))
	Spr.rr(x - w / 2, y - h, w, h, 3, Color("#7a4a26"))
	Spr.rect(x - w / 2 + 2, y - h + 3, w - 4, 2, Color(1, .9, .7, .18))
	for k in 3:
		Spr.seg(x - w / 2 + 3, y - h + 8 + k * 6, x + w / 2 - 3, y - h + 8 + k * 6, Color("#4a2a14"), 1.0)
	for cx in [x - w / 2 + 6, x + w / 2 - 6]:
		Spr.rect(cx - 2.5, y - h, 5, h, Color("#d8a83a"))
		Spr.rect(cx - 2.5, y - h, 1.6, h, Color("#ffe28a"))
	# limo e um caramujo no canto
	Spr.ellipse(x - w / 2 + 6, y - 2, 9, 3, Color(.32, .48, .2, .8))
	Spr.circle(x + w / 2 - 4, y - h + 4, 3, Color("#c89060"))
	if not o.got:
		# tampa fechada (meia-lua) com fechadura
		var lid := PackedVector2Array()
		for i in 9:
			var a: float = PI + i / 8.0 * PI
			lid.push_back(Vector2(x + cos(a) * (w / 2 + 1), y - h + sin(a) * 12))
		Spr.poly(lid, Color("#24160c"))
		var lid2 := PackedVector2Array()
		for i in 9:
			var a: float = PI + i / 8.0 * PI
			lid2.push_back(Vector2(x + cos(a) * (w / 2 - 1), y - h + 1 + sin(a) * 10.5))
		Spr.poly(lid2, Color("#8a5430"))
		Spr.seg(x - w / 2 + 6, y - h - 2, x - 6, y - h - 9, Color(1, .9, .7, .25), 2)
		Spr.rect(x - 3.5, y - h - 4, 7, 9, Color("#d8a83a"))
		Spr.circle(x, y - h, 1.4, Color("#24160c"))
		# brilho que passeia
		var sx: float = x - w / 2 + fposmod(T * 1.2, w + 60)
		if sx < x + w / 2:
			Spr.seg(sx, y - h + 2, sx + 6, y - 3, Color(1, 1, .85, .35), 2)
	else:
		# aberto: tampa para trás, luz dourada saindo e bolhas subindo
		var u: float = clamp(float(o.t) / 14.0, 0.0, 1.0)
		Spr.rect(x - w / 2 + 3, y - h + 1, w - 6, 5, Color("#24140a"))
		Spr.glow(x, y - h - 4, 30 * u + 10, Color(1, .85, .4, .35 * (1.0 - min(1.0, float(o.t) / 240.0) * .6)))
		Spr.save()
		Spr.translate(x, y - h)
		Spr.rotate(-1.9 * u)
		Spr.rr(-w / 2 - 1, -12, w + 2, 12, 5, Color("#24160c"))
		Spr.rr(-w / 2 + 1, -10.5, w - 2, 9.5, 4, Color("#8a5430"))
		Spr.restore()


## lamaçal (na camada da frente: o Tomé afunda nele)
## Lama grossa com relevo (montinhos que respiram devagar), brilho molhado nas cristas, veios e
## gravetos/pedrinhas presos, limo verde boiando, bolhas que incham e estouram, e as sanguessugas.
static func bog_top(b: Dictionary, x: float, T: int) -> float:
	var u: float = clamp((x - b.x) / b.w, 0.0, 1.0)
	var endk: float = pow(abs(u - .5) * 2.0, 6.0)
	# relevo fixo (montes e vales) + o "respirar" lento da lama
	var hump: float = sin(x * .013 + 1.3) * 5.0 + sin(x * .031 + .4) * 3.0 + sin(x * .071) * 1.2
	return b.y - 3 + hump + sin(x * .04 + T * .02) * 1.6 + sin(x * .11 - T * .03) * .8 + endk * 10

static func _bh(x: float, k: int) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

static func draw_bogs(g: Game, T: int) -> void:
	var NT: Nature = g.NT
	if NT == null:
		return
	var x0: float = g.cam - 120
	var x1: float = g.cam + g.W + 120
	for b in NT.BOGS:
		if b.x > x1 or b.x + b.w < x0:
			continue
		var bx0: float = max(float(b.x), x0)
		var bx1: float = min(float(b.x + b.w), x1)
		# corpo: crista clara, vale escuro, e escurecendo para o fundo
		var top := PackedVector2Array()
		var xx: float = bx0
		while xx <= bx1 + .1:
			top.push_back(Vector2(xx, bog_top(b, xx, T)))
			xx += 10
		if top[top.size() - 1].x < bx1:
			top.push_back(Vector2(bx1, bog_top(b, bx1, T)))
		var body := PackedVector2Array(top)
		body.push_back(Vector2(bx1, b.y + 140))
		body.push_back(Vector2(bx0, b.y + 140))
		var cols := PackedColorArray()
		for q in top:
			var crest: float = clamp((b.y + 2 - q.y) / 9.0, 0.0, 1.0)
			cols.push_back(Color("#4e3a1e").lerp(Color("#80663c"), crest))
		cols.push_back(Color("#1c140a"))
		cols.push_back(Color("#1c140a"))
		Spr.ci.draw_polygon(body, cols)
		# faixa logo abaixo da superfície (lama mais mole, um pouco mais clara) e veios escuros
		var band := PackedVector2Array(top)
		for i in range(top.size() - 1, -1, -1):
			band.push_back(top[i] + Vector2(0, 16 + sin(top[i].x * .05) * 4))
		Spr.poly(band, Color(.42, .31, .16, .45))
		var vx: float = bx0 - fposmod(bx0, 46.0)
		while vx < bx1:
			var r := _bh(vx, 1)
			if vx > b.x + 20 and vx < b.x + b.w - 40 and r < .7:
				var vy: float = bog_top(b, vx, 0) + 22 + r * 70
				var ln: float = 24 + _bh(vx, 2) * 40
				var pts := PackedVector2Array()
				for k in 5:
					var u: float = k / 4.0
					pts.push_back(Vector2(vx + u * ln, vy + sin(u * PI + r * 6.0) * 3.0))
				Spr.line(pts, Color(.08, .05, .02, .3), 2.0)
				Spr.line(pts, Color(.75, .6, .35, .1), 1.0)
			vx += 46
		# coisas presas na lama: pedrinhas, gravetos e folhas mortas (fixas, pela posição)
		var ox: float = bx0 - fposmod(bx0, 37.0)
		while ox < bx1:
			if ox > b.x + 16 and ox < b.x + b.w - 16:
				var r2 := _bh(ox, 3)
				var oy: float = bog_top(b, ox, T) + 3 + _bh(ox, 4) * 5
				if r2 < .22:
					Spr.ellipse(ox, oy + 1, 4.5, 2.6, Color("#2a2016"))
					Spr.ellipse(ox - .5, oy, 3.8, 2.0, Color("#7d7462"))
					Spr.ellipse(ox - 1.5, oy - .8, 1.4, .7, Color(1, 1, 1, .35))
				elif r2 < .38:
					var a: float = (_bh(ox, 5) - .5) * .9
					Spr.seg(ox - cos(a) * 12, oy - sin(a) * 12, ox + cos(a) * 12, oy + sin(a) * 12, Color("#2a1a0c"), 3.0)
					Spr.seg(ox - cos(a) * 11, oy - sin(a) * 11 - 1, ox + cos(a) * 10, oy + sin(a) * 10 - 1, Color("#8a6a42"), 1.2)
				elif r2 < .5:
					Spr.ellipse(ox, oy, 6, 2.6, Color("#5a5a24"), (_bh(ox, 6) - .5) * .8)
					Spr.seg(ox - 5, oy, ox + 5, oy, Color("#33300f"), 1.0)
			ox += 37
		# limo verde boiando nos vales
		var lx: float = bx0 - fposmod(bx0, 120.0) + 40
		while lx < bx1:
			if lx > b.x + 40 and lx < b.x + b.w - 40 and _bh(lx, 7) < .55:
				var ly: float = bog_top(b, lx, T) + 1.5
				var lw: float = 18 + _bh(lx, 8) * 22
				Spr.ellipse(lx, ly, lw, 3.2, Color(.36, .46, .16, .55))
				Spr.ellipse(lx - lw * .3, ly - .6, lw * .45, 1.6, Color(.55, .66, .25, .5))
				Spr.circle(lx + lw * .5, ly, 2.2, Color(.42, .54, .2, .6))
			elif lx > b.x + 40 and lx < b.x + b.w - 40 and _bh(lx, 7) > .8:
				# poça d'água parada no vale, refletindo o céu
				var py: float = bog_top(b, lx, T) + 2.0
				Spr.ellipse(lx, py, 16, 2.6, Color(.62, .72, .68, .5))
				Spr.seg(lx - 10, py - .6, lx + 4, py - .6, Color(1, 1, 1, .35), 1.0)
			lx += 120
		# brilho molhado nas cristas (luz de cima, à esquerda)
		for i in range(1, top.size() - 1):
			var q: Vector2 = top[i]
			if q.y < b.y - 2 and top[i + 1].y >= q.y - .5 and int(q.x / 10.0) % 3 != 0:
				Spr.seg(q.x - 6, q.y + 2.2, q.x + 4, q.y + 1.8, Color(1, .95, .78, .3), 1.6)
		Spr.line(top, Color(.2, .14, .07, .55), 2.0)
		Spr.line(top, Color(.9, .78, .52, .32), 1.0)
		# beiradas: a lama sobe um pouco no barranco
		for side in [0, 1]:
			var ex: float = b.x if side == 0 else b.x + b.w
			if ex < x0 - 40 or ex > x1 + 40:
				continue
			var dir: float = 1.0 if side == 0 else -1.0
			Spr.poly(PackedVector2Array([Vector2(ex - dir * 14, b.y - 2), Vector2(ex + dir * 6, b.y - 7), Vector2(ex + dir * 30, b.y + 4), Vector2(ex + dir * 30, b.y + 20), Vector2(ex - dir * 14, b.y + 12)]), Color("#5a4426"))
			Spr.seg(ex - dir * 10, b.y - 3, ex + dir * 10, b.y - 6, Color(1, .92, .7, .25), 1.5)
		# bolhas de gás: incham devagar, estouram com um anel e respingos, e nascem em outro lugar
		for k in 9:
			var per: float = 110.0 + _bh(k, 9) * 90.0
			var ph: float = fposmod(T + _bh(k, 10) * per, per)
			var cyc: int = int((T + _bh(k, 10) * per) / per)
			var bx: float = b.x + 40 + _bh(cyc * 13 + k, 11) * (b.w - 80)
			if bx < x0 or bx > x1:
				continue
			var by: float = bog_top(b, bx, T)
			var big: float = 4.0 + _bh(cyc * 7 + k, 12) * 7.0
			var grow: float = ph / (per * .8)
			if grow < 1.0:
				var r3: float = big * grow
				if r3 > 1.0:
					Spr.ellipse(bx, by + 1, r3 + 1.5, r3 * .35 + .8, Color(.12, .08, .04, .5))
					Spr.ellipse(bx, by - r3 * .45, r3, r3 * .75, Color("#6e5634"))
					Spr.ring(bx, by - r3 * .45, r3, Color(.2, .14, .07, .7), 1.0, PI, TAU)
					Spr.circle(bx - r3 * .35, by - r3 * .85, max(.8, r3 * .22), Color(1, .95, .8, .55))
			else:
				var u2: float = (grow - 1.0) / .25
				Spr.ring(bx, by - 1, big * (1.0 + u2 * 1.6), Color(.9, .78, .5, .45 * (1.0 - u2)), 1.3)
				for d in 3:
					var dx: float = (d - 1) * big * .9 * u2
					var dy: float = -sin(u2 * PI) * (6 + d * 3)
					Spr.circle(bx + dx, by - 2 + dy, 1.6 * (1.0 - u2 * .5), Color("#5a4428"))
		# sanguessugas se contorcendo para fora da lama
		var x: float = b.x + 24
		var i := 0
		while x < b.x + b.w - 10:
			if i % 3 == 0 and x > x0 - 20 and x < x1 + 20:
				var t: float = fmod(T * .018 + i * .37, 1.0)
				var sy: float = bog_top(b, x, T) + 2
				var hgt: float = sin(t * PI) * 30
				var sw: float = sin(T * .2 + i) * 5
				if hgt < 10:
					# entrando/saindo da lama: só a pontinha e um anel na lama
					Spr.ellipse(x + sw * .3, sy - hgt * .3, 6, 2.0 + hgt * .3, Color("#1e1610"))
					Spr.ring(x, sy, 7 + (10 - hgt), Color(.15, .1, .05, .3), 1.2)
				else:
					# corpo de minhoca grossa e mole: curva em S que se estica, afina na ponta e brilha molhado
					var body2 := PackedVector2Array()
					for q in 8:
						var u3: float = q / 7.0
						body2.push_back(Vector2(x + sw * u3 + sin(u3 * 3.2 + T * .15 + i) * 4.0 * u3, sy - hgt * u3))
					Spr.ellipse(x, sy - 1, 10, 3, Color("#2e2212"))
					Spr.line(body2, Color("#120c06"), 9.0)
					Spr.line(body2, Color("#3c3020"), 6.5)
					# listras do corpo
					for q in range(1, 7):
						var c2: Vector2 = body2[q]
						Spr.seg(c2.x - 3, c2.y + .5, c2.x + 3, c2.y - .5, Color(.12, .08, .04, .55), 1.0)
					var hl2 := PackedVector2Array()
					for q in range(1, 7):
						hl2.push_back(body2[q] + Vector2(-1.8, 0))
					Spr.line(hl2, Color(.85, .8, .6, .3), 1.4)
					# cabeça com a ventosa e o olhinho vermelho (é inimigo)
					var hd: Vector2 = body2[7]
					Spr.circle(hd.x, hd.y, 4.2, Color("#120c06"))
					Spr.circle(hd.x, hd.y, 3.2, Color("#4a3a26"))
					Spr.ring(hd.x, hd.y - 1, 2.2, Color(.75, .3, .25, .9), 1.2, PI, TAU)
					Spr.circle(hd.x + 1.6, hd.y + 1, 1.3, Color(1, .3, .22))
					# lama escorrendo de volta
					if int(T / 4 + i) % 3 == 0:
						Spr.circle(body2[3].x + 3, body2[3].y + 4, 1.4, Color("#3a2a16"))
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
			if Spr.has("p_snowpile"):
				# monte de neve pintado (esticado na altura do barranco)
				Spr.PR("snowpile", s.x - 52, s.y - 14, s.w + 104, s.h + 18)
			else:
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
	var running: bool = not e.dead and e.get("st", 0) == 0
	if running:
		Spr.frame_mix(Spr.tex.esquilo, e.get("run", 0.0), 4, 0, 130, 110, 65, 108, 0, 0, .6)
		return
	if e.dead:
		fr = 5
	elif e.get("st", 0) == 2:
		fr = 4
	elif e.get("st", 0) == 1:
		fr = 3
	# maior e de cor forte (inimigo), diferente dos bichinhos do cenário
	Spr.frame(Spr.tex.esquilo, fr, 130, 110, 65, 108, 0, 0, .6)

static func crow(e: Dictionary, T: int) -> void:
	if e.dead:
		var ck: Texture2D = Spr.opt("crow_ko")
		if ck:
			Spr.save()
			Spr.scale(.74, .74)
			Spr.trect(ck, Rect2(-ck.get_width() * .5, -ck.get_height() * .5, ck.get_width(), ck.get_height()))
			Spr.restore()
		else:
			Spr.A("crow_dead", 0, 0, .5)
		return
	# mergulho (descendo): pose pintada de asas recolhidas
	var cd: Texture2D = Spr.opt("crow_dive")
	if cd and e.get("st", 0) == 1 and e.get("t", 0) < 28:
		Spr.save()
		Spr.scale(.74, .74)
		Spr.trect(cd, Rect2(-cd.get_width() * .5, -cd.get_height() * .5 - 10, cd.get_width(), cd.get_height()))
		Spr.restore()
		return
	# corvo grande (bem maior que os tucanos do cenário); batendo asas rápido antes do mergulho
	var fs: int = 3 if e.get("st", 0) == 5 else 5
	if Spr.tex.has("en_crow2"):
		# (a fase de cada corvo é fixa: antes dependia do x e as asas aceleravam ou travavam conforme ele voava)
		Spr.frame_mix(Spr.tex.en_crow2, T / float(fs) + float(int(e.get("x0", 0.0) * .37) % 4), 4, 0, 170, 130, 85, 65, 0, -8, .74)
	else:
		Spr.A_cycle("crow", ["crow0", "crow1", "crow2"], T / 4.0, 0, -8, .74)

static func piranha(e: Dictionary, T: int) -> void:
	WorldExtras._pc("piranha%d" % (1 if (not e.dead and (T / 10) % 3 == 0) else 0), 0, 0, 46)

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
	# galope em 6 quadros (0-5), pulo (6) e parado (7)
	if st == "jump":
		return 6
	if run <= .05:
		return 7
	return int(floor(g * 6.0)) % 6

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
	var hdst := Rect2(x - float(m.ax) * s, y - float(m.ay) * s, cw * s, ch * s)
	if fr < 6:
		# galope com quadros intermediários (x4)
		Spr.region_mix(Spr.tex.cavalo, hdst, cw, ch, [0, 1, 2, 3, 4, 5], g * 6.0, Color(1, 1, 1, Spr.alpha))
	else:
		Spr.ci.draw_texture_rect_region(Spr.tex.cavalo, hdst, Rect2(fr * cw, 0, cw, ch), Color(1, 1, 1, Spr.alpha))
	if st == "trapped":
		# arame farpado enrolado nas patas
		for k in 3:
			var wy: float = y - 14 - k * 9
			Spr.seg(x - 50, wy, x + 40, wy + 4, Color(.55, .55, .58), 1.6)
			for j in 6:
				var bx: float = x - 44 + j * 15
				Spr.seg(bx - 3, wy - 3, bx + 3, wy + 4, Color(.4, .4, .44), 1.4)
		Spr.text("!", x + 50, y - 150 + sin(T * .2) * 3, 26, Color("#ffecaa"), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b, 4)
