extends Node2D
## Cenário fixo da fase (chão, árvores, casas, barranco...). Cada pedaço de 1024 px é um nó separado,
## desenhado uma vez só; o Godot só desenha os pedaços que aparecem na tela.

var game: Game
var x0 := 0.0
var x1 := 0.0
const EARTH := Color("#2a1a0e")
const CAVE := Color("#0d0a06")

func _draw() -> void:
	var L := game.L
	Spr.begin(self)
	if L.has("under"):
		Spr.rect(x0, L.under, x1 - x0, L.bottom - L.under + 200, EARTH)
	for pit in L.get("pits", []):
		if pit[1] < x0 or pit[0] > x1:
			continue
		Spr.vgrad(pit[0], 480, pit[1] - pit[0], 200, Color(.03, .02, .04, .0), Color(.02, .015, .03, 1))
		Spr.rect(pit[0], 680, pit[1] - pit[0], L.bottom - 480, Color(.02, .015, .03))
	for c in L.get("caves", []):
		if c.x + c.w < x0 or c.x > x1:
			continue
		Spr.rect(c.x, c.y, c.w, c.h, CAVE)
	for s in L.solids:
		var pad := 140.0
		if s.x + s.get("w", 0) + pad < x0 or s.x - pad > x1:
			continue
		match s.t:
			"ground": ground(s)
			"plat": plat(s)
			"branch": branch(s)
			"trunk": trunk(s)
			"dirt": Spr.rect(s.x, s.y, s.w, s.h, EARTH)
			"fakewall":
				Spr.rect(s.x, s.y, s.w, s.h, EARTH)
				Spr.seg(s.x + 4, s.y + 10, s.x + 14, s.y + 30, Color(0, 0, 0, .35), 1.5)
				Spr.seg(s.x + 14, s.y + 30, s.x + 6, s.y + 52, Color(0, 0, 0, .35), 1.5)
			"cabin": cabin(s)
			"root": root_log(s)
			"treehouse": treehouse(s)
			"hollow": Spr.AB("o_hollow", s.x - 22, s.y + s.h + 4 - 92, 154, 92)
			"cliff": cliff(s)
			"log":
				var w: float = s.w + 24
				Spr.AB("sw_log", s.x - 12, s.y - 12, w, w * 165 / 373)
			"deadtree": dead_tree(s)
			"damwall": planks(s, true)
			"wall": planks(s, false)
			"stone": stone(s)
			"hill": hill(s)
			"shed": shed(s)
			"beam": beam(s)
			"cart": Spr.AB("mi_cart", s.x - 8, s.y + s.h - 84, s.w + 16, 84)

# ---------- peças ----------
func tile_h(t: Texture2D, x0_: float, x1_: float, y: float, src: Rect2 = Rect2()) -> void:
	var sr := src if src.size != Vector2.ZERO else Rect2(Vector2.ZERO, t.get_size())
	var tw := sr.size.x - 1
	var x := x0_
	while x < x1_:
		var w: float = min(tw + 1, x1_ - x)
		Spr.img(t, x, y, w, sr.size.y, Rect2(sr.position.x, sr.position.y, w, sr.size.y))
		x += tw

func ground(s: Dictionary) -> void:
	var t: Texture2D = Spr.tex.chao
	var x_a: float = max(s.x, x0 - 4)
	var x_b: float = min(s.x + s.w, x1 + 4)
	if x_b <= x_a:
		return
	# alinhado ao início do bloco para não "pular" entre pedaços
	var tw: float = t.get_width() - 1
	var start: float = s.x + floor((x_a - s.x) / tw) * tw
	var x := start
	while x < x_b:
		var w: float = min(tw + 1, s.x + s.w - x)
		Spr.img(t, x, s.y - 28, w, t.get_height(), Rect2(0, 0, w, t.get_height()))
		x += tw
	Spr.rect(x_a, s.y - 30 + t.get_height(), x_b - x_a, s.h, Color("#34200f"))

func plat(s: Dictionary) -> void:
	if s.get("crumble"):
		return
	if s.get("trestle"):
		var wood := Color("#4a3220")
		for lx in [s.x + 8, s.x + s.w - 16]:
			Spr.rect(lx, s.y + 10, 8, 700 - s.y, wood)
		Spr.seg(s.x + 12, s.y + 30, s.x + s.w - 12, s.y + 120, wood, 5)
		Spr.seg(s.x + s.w - 12, s.y + 30, s.x + 12, s.y + 120, wood, 5)
	Spr.rr(s.x, s.y, s.w, 16, 6, Color("#6b4a2a"))
	Spr.rect(s.x + 6, s.y + 2, s.w - 12, 3, Color(1, 1, 1, .12))
	if s.get("hatch"):
		return
	Spr.seg(s.x + 10, s.y + 16, s.x + 4, s.y + 40, Color(0, 0, 0, .35), 2)
	Spr.seg(s.x + s.w - 10, s.y + 16, s.x + s.w - 4, s.y + 40, Color(0, 0, 0, .35), 2)

func branch(s: Dictionary) -> void:
	Spr.img(Spr.tex.galho, s.x - 12, s.y - 14, s.w + 24, 60)

func trunk(s: Dictionary) -> void:
	# o tronco entra na terra e as raízes se espalham num montinho de terra e grama
	Spr.img(Spr.tex.tronco, s.x - s.w * .75, s.y - 10, s.w * 2.5, s.h + 28)
	_root_mound(s.x + s.w / 2, s.y + s.h, s.w)

func _root_mound(cx: float, gy: float, w: float) -> void:
	Spr.ellipse(cx, gy + 4, w * 1.35, 12, Color("#4a3220"))
	for k in 5:
		var a: float = (k - 2) * .45
		var rx: float = cx + (k - 2) * w * .32
		Spr.poly(PackedVector2Array([Vector2(rx - 9, gy - 2), Vector2(rx + sin(a) * 26, gy + 9), Vector2(rx + 9, gy - 2)]), Color("#5e4028"))
	for k in 7:
		var gx: float = cx - w * 1.2 + k * w * .4
		for j in 3:
			Spr.poly(PackedVector2Array([Vector2(gx + j * 4 - 3, gy + 3), Vector2(gx + j * 4 + (j - 1) * 2, gy - 9 - (k % 3) * 3), Vector2(gx + j * 4 + 3, gy + 3)]), Color("#5d8f34"))

func cabin(s: Dictionary) -> void:
	Spr.AB("o_cabin", s.x - 15, s.y + s.h - 221, 330, 221)

func treehouse(s: Dictionary) -> void:
	var r = Spr.AR.o_treehouse
	var w := 280.0
	var hh: float = w * r[3] / r[2]
	Spr.AB("o_treehouse", s.x + s.w / 2 - w / 2, s.y + s.h + 8 - hh, w, hh)

func root_log(s: Dictionary) -> void:
	var x: float = s.x
	var y: float = s.y
	var w: float = s.w
	var h: float = s.h
	var r := w / 6
	Spr.rect(x + 6, y + 20, w - 12, h - 30, Color("#3a2414"))
	var rows = [[3, y + h - r - 4], [3, y + h - r * 3 - 6], [2, y + h - r * 5 - 8]]
	for k in 3:
		var n: int = rows[k][0]
		var cy: float = rows[k][1]
		for i in n:
			var cx: float = x + r + (r if k == 2 else 0.0) + i * r * 2
			Spr.circle(cx, cy, r, Color("#7a5532"))
			Spr.ring(cx, cy, r, Color("#3a2414"), 3)
			Spr.circle(cx, cy, r * .72, Color("#c9a26a"))
			var q := .2
			while q < .7:
				Spr.ring(cx, cy, r * q, Color(.35, .24, .12, .6), 1.5)
				q += .18
	# presa por cordas que sobem até o alto (é por isso que fica suspensa e só passa abaixado)
	_hang_ropes(x + w * .22, x + w * .78, y, h)
	# sombra no chão embaixo da pilha suspensa
	Spr.ellipse(x + w / 2, y + h + 24, w * .55, 6, Color(0, 0, 0, .3))

## cordas (ou correntes) grossas subindo até sair da tela, amarradas em volta da peça, com ganchos de ferro
func _hang_ropes(xa: float, xb: float, y: float, h: float, chain: bool = false) -> void:
	var top: float = y - 900
	for rx in [xa, xb]:
		if chain:
			var yy: float = top
			while yy < y:
				Spr.ring(rx, yy + 6, 5, Color("#6b6560"), 2.5)
				yy += 10
		else:
			Spr.rect(rx - 3, top, 6, y - top + 6, Color("#a8875a"))
			var yy2: float = top
			while yy2 < y:
				Spr.seg(rx - 3, yy2, rx + 3, yy2 + 5, Color("#7a5f3c"), 1.5)
				yy2 += 8
		# gancho
		Spr.ring(rx, y - 2, 7, Color("#5f5a55"), 3, PI * .1, PI * 1.6)
	# amarras em volta da peça
	for f in [.18, .82]:
		var by: float = y + h * f
		Spr.rect(xa - 30, by - 3, xb - xa + 60, 6, Color("#a8875a" if not chain else "#6b6560"))
		Spr.seg(xa - 30, by - 3, xb + 30, by + 3, Color(0, 0, 0, .25), 1)

func cliff(s: Dictionary) -> void:
	var t: Texture2D = Spr.tex.chao
	Spr.hgrad(s.x, s.y, s.w, s.h, Color("#6a5a4a"), Color("#4a3e32"))
	var tp := 50.0
	var th: float = t.get_height()
	var yy: float = s.y - 28 + th - 14
	while yy < s.y + s.h:
		var hh: float = min(th - tp, s.y + s.h - yy)
		var x: float = s.x
		while x < s.x + s.w:
			var w: float = min(t.get_width(), s.x + s.w - x)
			Spr.img(t, x, yy, w, hh, Rect2(0, tp, w, hh))
			x += t.get_width() - 1
		yy += th - tp - 14
	tile_h(t, s.x, s.x + s.w, s.y - 28)
	Spr.hgrad(s.x, s.y, 60, s.h, Color(0, 0, 0, .35), Color(0, 0, 0, 0))
	var pts = [[.08, .3], [.35, .55], [.7, .25], [.55, .85], [.15, .8], [.9, .65]]
	for k in pts.size():
		Spr.A("o_rocks", s.x + s.w * pts[k][0], s.y + s.h * pts[k][1], .9 + (k % 3) * .15, k % 2 == 1, .8)

func dead_tree(s: Dictionary) -> void:
	var p := PackedVector2Array([Vector2(s.x, s.y + s.h), Vector2(s.x + 6, s.y + 40), Vector2(s.x - 30, s.y - 10), Vector2(s.x + 10, s.y + 20),
		Vector2(s.x + 20, s.y - 30), Vector2(s.x + 30, s.y + 20), Vector2(s.x + s.w, s.y + 60), Vector2(s.x + s.w + 10, s.y + s.h)])
	Spr.poly(p, Color("#5a5048"))
	var y: float = s.y + 60
	while y < s.y + s.h:
		Spr.seg(s.x + 8, y, s.x + s.w - 4, y + 8, Color(0, 0, 0, .3), 2)
		y += 24
	y = s.y + 40
	while y < s.y + s.h:
		Spr.ellipse(s.x + s.w / 2, y, 14, 5, Color(.47, .59, .35, .6))
		y += 50

func planks(s: Dictionary, dark: bool) -> void:
	Spr.rect(s.x, s.y, s.w, s.h, Color("#4a3420") if dark else Color("#6b4a2a"))
	var x: float = s.x + 12
	while x < s.x + s.w:
		Spr.seg(x, s.y, x, s.y + s.h, Color(0, 0, 0, .35), 2)
		x += 12
	var y: float = s.y + 30
	while y < s.y + s.h:
		Spr.rect(s.x - 2, y, s.w + 4, 8, Color("#5a5a62"))
		y += 90

func stone(s: Dictionary) -> void:
	var rw: float = s.w + 16
	var rh: float = rw * .82
	if s.h <= rh + 12:
		Spr.rr(s.x + 4, s.y + 10, s.w - 8, s.h - 10, 8, Color("#3a3a30"))
		Spr.AB("o_rocks", s.x - 8, s.y - 10, rw, min(s.h + 10, rh))
		Spr.rect(s.x, s.y + 20, s.w, s.h - 20, Color(.08, .12, .1, .35))
		return
	# coluna alta: pedras empilhadas de tamanhos variados, com musgo e cipós (dá vontade de se agarrar)
	var h := hash(int(s.x) * 31 + int(s.y))
	Spr.rr(s.x + 6, s.y + 14, s.w - 12, s.h - 14, 10, Color("#2e2e26"))
	var ys: Array = []
	var y: float = s.y - 10
	var k := 0
	while y < s.y + s.h - rh * .45:
		ys.append([y, k])
		y += rh * (.5 + ((h >> k) & 3) * .04)
		k += 1
	ys.reverse()
	for e in ys:
		var kk: int = e[1]
		var sc: float = .9 + ((h >> (kk + 3)) & 3) * .07
		var w2: float = rw * sc
		var jx: float = (((h >> (kk * 2)) & 7) - 3.5) * 1.6
		var bot: float = min(e[0] + rh * sc, s.y + s.h + 6)
		Spr.AB("o_rocks", s.x + s.w / 2 - w2 / 2 + jx, e[0], w2, bot - e[0])
		# musgo no topo de cada pedra
		for m in 4:
			Spr.ellipse(s.x + s.w / 2 + jx + (m - 1.5) * w2 * .2, e[0] + 7 + (m % 2) * 3, 9, 4, Color(.36, .5, .2, .85))
	# sombra para assentar a coluna no chão
	Spr.rect(s.x, s.y + s.h - 26, s.w, 26, Color(0, 0, 0, .22))
	# cipós pendurados
	for v in 2:
		var vx: float = s.x + (8.0 if v == 0 else s.w - 10)
		var vl: float = s.h * (.45 + v * .2)
		var pts := PackedVector2Array()
		for j in 12:
			var u := j / 11.0
			pts.push_back(Vector2(vx + sin(u * 5.0 + v) * 4, s.y + 4 + u * vl))
		Spr.line(pts, Color("#3f6a2a"), 3)
		for j in range(1, 11, 2):
			var p: Vector2 = pts[j]
			Spr.ellipse(p.x + (5 if j % 4 == 1 else -5), p.y, 6, 3, Color("#5c8d38"), .5 if j % 4 == 1 else -.5)

func hill(s: Dictionary) -> void:
	var pts := PackedVector2Array()
	var a := Vector2(s.x - 80, s.y + s.h)
	pts.push_back(a)
	for i in 21:
		var t := i / 20.0
		# duas curvas suaves até o topo e de volta
		var p: Vector2
		if t < .5:
			var u := t * 2
			p = _quad(Vector2(s.x - 80, s.y + s.h), Vector2(s.x + s.w * .2, s.y + 60), Vector2(s.x + s.w / 2, s.y + 40), u)
		else:
			var u2 := (t - .5) * 2
			p = _quad(Vector2(s.x + s.w / 2, s.y + 40), Vector2(s.x + s.w * .85, s.y + 60), Vector2(s.x + s.w + 80, s.y + s.h), u2)
		pts.push_back(p)
	Spr.poly(pts, Color("#1e2a1e"))
	Spr.vgrad(s.x, s.y + 200, s.w, s.h - 200, Color("#1e2a1e"), Color("#2a2018"))
	Spr.rect(s.x, s.y + s.h, s.w, 120, Color("#0a0806"))
	var wood := Color("#5a3d22")
	Spr.rect(s.x - 14, s.y + s.h - 10, 22, 130, wood)
	Spr.rect(s.x - 24, s.y + s.h - 20, 110, 18, wood)
	Spr.rect(s.x + s.w - 8, s.y + s.h - 10, 22, 130, wood)
	Spr.rect(s.x + s.w - 90, s.y + s.h - 20, 110, 18, wood)

func _quad(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)

func shed(s: Dictionary) -> void:
	Spr.rect(s.x + 20, s.y + 20, s.w - 40, 100, Color("#3a2a1a"))
	Spr.poly(PackedVector2Array([Vector2(s.x - 20, s.y + 20), Vector2(s.x + s.w / 2, s.y - 40), Vector2(s.x + s.w + 20, s.y + 20)]), Color("#5a3d22"))
	Spr.rect(s.x, s.y, s.w, s.h, Color("#6b4a2a"))
	var x: float = s.x + 20
	while x < s.x + s.w:
		Spr.rect(x, s.y + 30, 3, 90, Color(0, 0, 0, .3))
		x += 30

func beam(s: Dictionary) -> void:
	# viga baixa de escoramento da mina: só passa abaixado
	_hang_ropes(s.x + 10, s.x + s.w - 10, s.y, s.h, true)
	planks(s, true)
	Spr.rect(s.x - 24, s.y - 6, s.w + 48, 14, Color("#5a3d22"))
	var y: float = s.y + s.h - 10
	var x: float = s.x
	while x < s.x + s.w:
		Spr.rect(x, y, 10, 8, Color(.85, .7, .2, .85))
		Spr.rect(x + 10, y, 10, 8, Color(.1, .08, .05, .85))
		x += 20
