extends Node2D
## Cenário fixo da fase (chão, árvores, casas, barranco...). Cada pedaço de 1024 px é um nó separado,
## desenhado uma vez só; o Godot só desenha os pedaços que aparecem na tela.

var game: Game
var x0 := 0.0
var x1 := 0.0
const EARTH := Color("#2a1a0e")
const CAVE := Color("#0d0a06")

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	_draw_raw()
	Spr.pt("static", __t)

func _draw_raw() -> void:
	var L := game.L
	Spr.begin(self)
	if L.has("under"):
		Spr.rect(x0, L.under, x1 - x0, L.bottom - L.under + 200, EARTH)
	# fossos e cavernas: cada pedaço do cenário desenha só a sua faixa [x0, x1]; senão o fundo da
	# caverna do pedaço seguinte cobre as pedras e plataformas desenhadas pelo anterior
	for pit in L.get("pits", []):
		if pit[1] < x0 or pit[0] > x1:
			continue
		var pa: float = max(float(pit[0]), x0)
		var pb: float = min(float(pit[1]), x1)
		Spr.vgrad(pa, 480, pb - pa, 200, Color(.03, .02, .04, .0), Color(.02, .015, .03, 1))
		Spr.rect(pa, 680, pb - pa, L.bottom - 480, Color(.02, .015, .03))
		# paredes de terra do buraco (dá para ver a profundidade)
		if pit[0] >= x0 and pit[0] < x1:
			Spr.hgrad(pit[0], 500, 26, 260, Color("#4a3220"), Color(.03, .02, .02, 0))
		if pit[1] > x0 and pit[1] <= x1:
			Spr.hgrad(pit[1] - 26, 500, 26, 260, Color(.03, .02, .02, 0), Color("#4a3220"))
	for c in L.get("caves", []):
		if c.x + c.w < x0 or c.x > x1:
			continue
		var ca: float = max(float(c.x), x0)
		var cb: float = min(float(c.x + c.w), x1)
		if c.get("ice"):
			# caverna de gelo: azul escuro com pingentes no teto
			Spr.vgrad(ca, c.y, cb - ca, c.h, Color("#3a5a7a"), Color("#16263a"))
			var ix: float = c.x + 14
			while ix < c.x + c.w - 14:
				if ix >= x0 and ix < x1:
					var ln: float = 10 + fmod(ix * 1.37, 22.0)
					Spr.poly(PackedVector2Array([Vector2(ix - 6, c.y), Vector2(ix, c.y + ln), Vector2(ix + 6, c.y)]), Color(.8, .92, 1, .85))
				ix += 30
		elif c.get("wet"):
			# fundo de lago: azul-esverdeado escuro, com pedras no fundo
			Spr.vgrad(ca, c.y, cb - ca, c.h, Color("#2a5a66"), Color("#0c1e28"))
			var rx: float = c.x + 30
			while rx < c.x + c.w - 30:
				if rx >= x0 and rx < x1:
					Spr.ellipse(rx, c.y + c.h - 6, 26 + fmod(rx * .7, 18.0), 9, Color("#16303a"))
				rx += 90
		else:
			Spr.rect(ca, c.y, cb - ca, c.h, CAVE)
	# vãos no chão dos túneis (embaixo dos cavaletes da mina): fundo escuro e paredes de terra
	for sh in L.get("shafts", []):
		if sh[1] < x0 or sh[0] > x1:
			continue
		var sa: float = max(float(sh[0]), x0)
		var sb: float = min(float(sh[1]), x1)
		var sy: float = sh[2]
		Spr.vgrad(sa, sy - 6, sb - sa, 160, Color(.03, .02, .02), Color(0, 0, 0))
		Spr.rect(sa, sy + 150, sb - sa, L.bottom - sy, Color(0, 0, 0))
		if sh[0] >= x0 and sh[0] < x1:
			Spr.hgrad(sh[0], sy, 22, 200, Color("#4a3220"), Color(0, 0, 0, 0))
		if sh[1] > x0 and sh[1] <= x1:
			Spr.hgrad(sh[1] - 22, sy, 22, 200, Color(0, 0, 0, 0), Color("#4a3220"))
	for d in L.get("decor", []):
		if d.x + 160 < x0 or d.x - 160 > x1:
			continue
		WorldNature.decor(d)
	for s in L.solids:
		var pad := 140.0
		if s.x + s.get("w", 0) + pad < x0 or s.x - pad > x1:
			continue
		# morros e paredões grandes: só o pedaço onde eles começam desenha (os pedaços seguintes
		# desenham por cima o que fica na frente; antes o morro cobria o carrinho da mina)
		if s.t in ["hill", "cliff"] and (s.x < x0 or s.x >= x1):
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
			"cart":
				if s.get("sprite"):
					Spr.ABb(s.sprite, s.x + s.w / 2, s.y + s.h + 4, s.w + 20)
					Spr.ellipse(s.x + s.w / 2, s.y + 6, s.w * .45, 6, Color(.96, .97, 1))
				else:
					Spr.AB("mi_cart", s.x - 8, s.y + s.h - 84, s.w + 16, 84)
			"ice":
				Spr.rr(s.x, s.y, s.w, s.h + 4, 5, Color(.72, .88, 1, .9))
				Spr.rect(s.x + 6, s.y + 2, s.w - 12, 2, Color(1, 1, 1, .8))
				var ix: float = s.x + 20
				while ix < s.x + s.w - 20:
					Spr.seg(ix, s.y + 4, ix + 14, s.y + s.h, Color(1, 1, 1, .5), 1.2)
					ix += 46

# ---------- peças ----------
func tile_h(t: Texture2D, x0_: float, x1_: float, y: float, src: Rect2 = Rect2()) -> void:
	var sr := src if src.size != Vector2.ZERO else Rect2(Vector2.ZERO, t.get_size())
	var tw := sr.size.x - 1
	var x := x0_
	while x < x1_:
		var w: float = min(tw + 1, x1_ - x)
		Spr.img(t, x, y, w, sr.size.y, Rect2(sr.position.x, sr.position.y, w, sr.size.y))
		x += tw

## ponta do chão sem vizinho do lado: desenhada com contorno arredondado (sem quina de caixa)
func _open_end(s: Dictionary, right: bool) -> bool:
	var key := "_or" if right else "_ol"
	if s.has(key):
		return s[key]
	var open := true
	var ex: float = s.x + s.w if right else s.x
	for o in game.L.solids:
		if o == s or not o.t in ["ground", "dirt", "cliff", "hill"]:
			continue
		if o.y <= s.y + 2 and o.y + o.get("h", 0) > s.y + 4 and ex >= o.x - 1 and ex <= o.x + o.get("w", 0) + 1:
			open = false
			break
	s[key] = open
	return open

const ROUND := 22.0
## a textura do chão emendada duas vezes (a ponta pode cair na divisa entre dois ladrilhos)
static var _c2: Texture2D
func _chao2(t: Texture2D, tw: float) -> Texture2D:
	if _c2 == null:
		var im: Image = t.get_image()
		if im.is_compressed():
			im.decompress()
		var w: int = im.get_width()
		var out := Image.create(int(tw) + w, im.get_height(), false, im.get_format())
		out.blit_rect(im, Rect2i(0, 0, w, im.get_height()), Vector2i(0, 0))
		out.blit_rect(im, Rect2i(0, 0, w, im.get_height()), Vector2i(int(tw), 0))
		_c2 = ImageTexture.create_from_image(out)
	return _c2
func ground(s: Dictionary) -> void:
	var t: Texture2D = Spr.tex.chao
	var x_a: float = max(s.x, x0 - 4)
	var x_b: float = min(s.x + s.w, x1 + 4)
	if x_b <= x_a:
		return
	var ol: bool = _open_end(s, false) and s.w > 60
	var orr: bool = _open_end(s, true) and s.w > 60
	# as pontas abertas ficam por conta do contorno arredondado
	var cut_a: float = s.x + (ROUND if ol else 0.0)
	var cut_b: float = s.x + s.w - (ROUND if orr else 0.0)
	# alinhado ao início do bloco para não "pular" entre pedaços
	var tw: float = t.get_width() - 1
	var start: float = s.x + floor((x_a - s.x) / tw) * tw
	var x := start
	# nada passa do fundo do bloco (senão a terra cobre a caverna que fica embaixo)
	var th: float = min(float(t.get_height()), s.h + 28.0)
	while x < x_b:
		var xa2: float = max(x, cut_a)
		var xb2: float = min(x + tw + 1, cut_b)
		if xb2 > xa2:
			Spr.img(t, xa2, s.y - 28, xb2 - xa2, th, Rect2(xa2 - x, 0, xb2 - xa2, th))
		x += tw
	var fy: float = s.y - 30 + t.get_height()
	if s.y + s.h > fy:
		Spr.rect(max(x_a, cut_a), fy, min(x_b, cut_b) - max(x_a, cut_a), s.y + s.h - fy, Color("#34200f"))
	if ol and s.x >= x0 - ROUND and s.x < x1:
		_ground_end(s, t, tw, false)
	if orr and s.x + s.w > x0 and s.x + s.w <= x1 + ROUND:
		_ground_end(s, t, tw, true)
	if s.get("snow"):
		_snow_top(x_a + (8.0 if ol and x_a <= s.x else 0.0), x_b - (8.0 if orr and x_b >= s.x + s.w else 0.0), s.y)
	_ground_deco(s)

## o "clima" do trecho em x (para escolher os enfeites do chão)
func _theme_at(x: float) -> String:
	var th := "manha"
	for sc in game.L.get("sections", []):
		if sc.x <= x:
			th = "neve" if sc.get("bg", "") == "neve" else sc.get("song", "manha")
	return th

static func hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

## enfeites pequenos em cima do chão: flores, pedrinhas, folhas secas, poças, montinhos de neve
## e raízes saindo da beira. Tudo fixo (sorteado pela posição), desenhado uma vez só.
func _ground_deco(s: Dictionary) -> void:
	if s.w < 120:
		return
	var y: float = s.y
	var th := _theme_at(s.x + s.w / 2)
	var under: bool = game.L.has("under") and y > game.L.under
	var gx: float = s.x + 40 + fposmod(-(s.x + 40), 58.0)
	while gx < s.x + s.w - 40:
		if gx >= x0 and gx < x1:
			var r := hh(gx, 11)
			if r < .5 and not _covered(gx, y):
				var kind := int(hh(gx, 12) * 100)
				if s.get("snow") or th == "neve":
					if kind < 45:
						_snow_mound(gx, y)
					elif kind < 70:
						_pebbles(gx, y, Color(.55, .58, .64))
				elif under or th in ["noite", "perseguicao", "tunel"]:
					if kind < 55:
						_pebbles(gx, y, Color(.36, .32, .3))
					elif kind < 75:
						_tiny_mush(gx, y)
				elif th == "chuva":
					if kind < 30:
						_puddle(gx, y)
					elif kind < 60:
						_pebbles(gx, y, Color(.38, .4, .36))
					elif kind < 75:
						_leaves(gx, y, [Color(.36, .42, .2), Color(.3, .32, .18)])
				elif th == "tarde":
					if kind < 45:
						_leaves(gx, y, [Color(.86, .5, .16), Color(.72, .32, .12), Color(.9, .7, .2)])
					elif kind < 65:
						_flower(gx, y, Color(1, .82, .3))
					elif kind < 85:
						_pebbles(gx, y, Color(.55, .48, .4))
				else:
					if kind < 50:
						_flower(gx, y, [Color(1, .55, .7), Color(1, .95, .55), Color(.98, .98, 1), Color(.6, .7, 1)][int(hh(gx, 13) * 4)])
					elif kind < 75:
						_pebbles(gx, y, Color(.58, .55, .5))
		gx += 58
	# raízes saindo da beira do barranco (embaixo da grama)
	if not s.get("snow") and not under:
		var rx: float = s.x + 70 + fposmod(-(s.x + 70), 170.0)
		while rx < s.x + s.w - 70:
			if rx >= x0 and rx < x1 and hh(rx, 14) < .45:
				_root_curl(rx, y + 14 + hh(rx, 15) * 10)
			rx += 170

## não enfeita onde tem outra coisa em cima do chão (parede, caixa fixa, pedra...)
func _covered(x: float, y: float) -> bool:
	for o in game.L.solids:
		if o.t in ["ground", "dirt", "cliff", "hill"]:
			continue
		if x > o.x - 14 and x < o.x + o.get("w", 0) + 14 and y > o.y - 4 and y < o.y + o.get("h", 0) + 30:
			return true
	return false

func _flower(x: float, y: float, c: Color) -> void:
	for k in 2:
		var fx: float = x + k * 9 - 4
		var hgt: float = 10 + hh(fx, 16) * 8
		var tip := Vector2(fx + (hh(fx, 17) - .5) * 5, y - hgt)
		Spr.seg(fx, y, tip.x, tip.y, Color(.25, .45, .16), 1.6)
		Spr.ellipse(fx + 3, y - hgt * .45, 3.5, 1.6, Color(.32, .55, .2), -.5)
		for j in 5:
			var a := TAU * j / 5.0 + hh(fx, 18)
			Spr.circle(tip.x + cos(a) * 2.8, tip.y + sin(a) * 2.8, 2.3, c)
		Spr.circle(tip.x, tip.y, 1.6, Color(.95, .7, .15) if c.b > .5 or c.g < .8 else Color(.85, .45, .1))

func _pebbles(x: float, y: float, c: Color) -> void:
	for k in 3:
		var px: float = x + (k - 1) * 8 + hh(x + k, 19) * 4
		var rw: float = 3 + hh(x + k, 20) * 3.5
		Spr.ellipse(px, y - rw * .45 + 1, rw, rw * .65, c.darkened(.15 * k))
		Spr.circle(px - rw * .3, y - rw * .7 + 1, rw * .25, Color(1, 1, 1, .35))

func _leaves(x: float, y: float, cs: Array) -> void:
	for k in 4:
		var lx: float = x + (hh(x + k, 21) - .5) * 30
		var c: Color = cs[int(hh(x + k, 22) * cs.size()) % cs.size()]
		Spr.ellipse(lx, y - 1.5, 5, 2, c, (hh(x + k, 23) - .5) * .8)
		Spr.seg(lx - 4, y - 1.5, lx + 4, y - 1.5, c.darkened(.35), 1)

func _puddle(x: float, y: float) -> void:
	var w: float = 18 + hh(x, 24) * 16
	Spr.ellipse(x, y + 1, w, 3.5, Color(.16, .24, .26, .9))
	Spr.ellipse(x - w * .2, y + .5, w * .45, 1.2, Color(.7, .85, .9, .55))

func _snow_mound(x: float, y: float) -> void:
	var w: float = 14 + hh(x, 25) * 14
	Spr.ellipse(x, y - 3, w, 6 + w * .18, Color(.8, .87, .97))
	Spr.ellipse(x - 2, y - 5, w * .85, 4.5 + w * .15, Color(.97, .98, 1))
	Spr.ellipse(x - w * .35, y - 8 - w * .1, w * .25, 1.5, Color(1, 1, 1))

func _tiny_mush(x: float, y: float) -> void:
	for k in 2:
		var mx: float = x + k * 8
		var hgt: float = 6 + k * 3
		Spr.rect(mx - 1, y - hgt, 2, hgt, Color(.85, .8, .7))
		Spr.ellipse(mx, y - hgt, 4.5 - k, 2.5, Color(.45, .6, .9))
		Spr.circle(mx - 1, y - hgt - 1, .8, Color(.85, .95, 1))

func _root_curl(x: float, y: float) -> void:
	var pts := PackedVector2Array()
	var dir: float = 1.0 if hh(x, 26) > .5 else -1.0
	for i in 9:
		var u := i / 8.0
		pts.push_back(Vector2(x + dir * (u * 16 + sin(u * 5.0) * 4), y + u * 14 + u * u * 6))
	Spr.line(pts, Color(.24, .15, .08), 3.2)
	Spr.line(pts, Color(.45, .3, .16), 1.4)

## a ponta: a textura do chão num polígono com a quina de cima arredondada, a parede um pouco
## irregular, sombra na borda e um tufo de grama caindo por cima
func _ground_end(s: Dictionary, t: Texture2D, tw: float, right: bool) -> void:
	var e: float = s.x + s.w if right else s.x
	var inner: float = e - ROUND if right else e + ROUND
	var top: float = s.y - 10
	var fy: float = s.y - 30 + t.get_height()
	var bot: float = s.y + min(s.h, 900.0)
	var tile_x: float = s.x + floor((min(inner, e) - s.x) / tw) * tw
	var t2: Texture2D = _chao2(t, tw)
	var seed_v: float = e * .013
	var inset := func(y: float) -> float:
		var r := ROUND - 4
		var c: float = 0.0
		if y < s.y + r:
			var dy: float = (s.y + r) - y
			c = r - sqrt(max(0.0, r * r - dy * dy))
		var wob: float = 2.5 * sin(y * .09 + seed_v) + 1.5 * sin(y * .23 + seed_v * 3.0)
		var bc: float = 0.0
		if s.h < 300 and y > bot - r:
			var dy2: float = y - (bot - r)
			bc = r - sqrt(max(0.0, r * r - dy2 * dy2))
		return clamp(c + 2.0 + wob + bc, 0.0, ROUND - 1)
	# parte de cima: a textura do chão (grama + terra com raízes); embaixo, terra lisa
	var y_tex: float = min(fy, bot)
	_end_band(top, y_tex, 8.0, inner, e, right, inset, t2, tile_x, s.y - 28, Color(1, 1, 1), Color(.86, .83, .8))
	if bot > y_tex + 1:
		_end_band(y_tex, bot, 30.0, inner, e, right, inset, null, 0, 0, Color("#34200f"), Color("#2a190b"))
	# tufo de grama arredondando a quina de cima
	var gx: float = e - 6.0 if right else e + 6.0
	var gc := Color(.36, .58, .2)
	if s.get("snow"):
		Spr.ellipse(gx, s.y - 3, 15, 7, Color(.96, .98, 1))
	else:
		Spr.ellipse(gx, s.y - 1, 13, 6, gc.darkened(.15))
		Spr.ellipse(gx + (2 if right else -2), s.y - 4, 9, 4, gc)
	# pedrinhas soltas na parede
	for k in 2:
		var py: float = s.y + 30 + k * 34
		if py < bot - 10:
			var px: float = (e - 6.0 - k * 3) if right else (e + 6.0 + k * 3)
			Spr.ellipse(px, py, 4, 3, Color(.45, .36, .28, .8))

## uma faixa da ponta: lado de dentro reto, lado de fora pelo contorno (inset)
func _end_band(ya: float, yb: float, stp: float, inner: float, e: float, right: bool, inset: Callable,
		tex: Texture2D, tile_x: float, ty: float, c_in: Color, c_out: Color) -> void:
	var ys: Array = []
	var yy: float = ya
	while yy < yb:
		ys.append(yy)
		yy += stp
	ys.append(yb)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for y in ys:
		pts.push_back(Vector2(inner, y))
		cols.push_back(c_in)
	for i in range(ys.size() - 1, -1, -1):
		var ins: float = inset.call(ys[i])
		pts.push_back(Vector2(e - ins if right else e + ins, ys[i]))
		cols.push_back(c_out)
	if tex == null:
		Spr.ci.draw_polygon(pts, cols)
		return
	var uvs := PackedVector2Array()
	var tw: float = tex.get_width()
	var th: float = tex.get_height()
	for p in pts:
		uvs.push_back(Vector2(clamp((p.x - tile_x) / tw, 0.0, 1.0), clamp((p.y - ty) / th, 0.0, 1.0)))
	Spr.ci.draw_polygon(pts, cols, uvs, tex)

## camada de neve por cima do chão (com bordas fofas)
func _snow_top(xa: float, xb: float, y: float) -> void:
	Spr.rect(xa, y - 6, xb - xa, 14, Color(.95, .97, 1))
	Spr.rect(xa, y + 6, xb - xa, 4, Color(.78, .85, .96))
	var x: float = floor(xa / 26.0) * 26.0
	while x < xb:
		var hgt: float = 4 + fmod(x * 7.31, 5.0)
		Spr.ellipse(x + 13, y - 5, 16, hgt, Color(.97, .98, 1))
		x += 26

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
	# presa por cordas que sobem até o alto e dão a volta no feixe de toras (por isso fica suspensa)
	var ptop: float = y + h - r * 6 - 8
	_hang_ropes(x + w * .22, x + w * .78, ptop, 0.0)
	_wrap(x - 3, ptop - 2, w + 6, y + h - ptop + 2, r, false)
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


## laço de corda (ou corrente) dando a volta inteira na peça, com nós onde as cordas de cima chegam
func _wrap(x: float, y: float, w: float, h: float, rad: float, chain: bool) -> void:
	var pts := PackedVector2Array()
	var rr: float = min(rad, min(w, h) / 2.0)
	var corners := [[x + w - rr, y + rr, -PI / 2], [x + w - rr, y + h - rr, 0.0], [x + rr, y + h - rr, PI / 2], [x + rr, y + rr, PI]]
	for c in corners:
		for k in 7:
			var a: float = c[2] + k / 6.0 * PI / 2
			pts.push_back(Vector2(c[0] + cos(a) * rr, c[1] + sin(a) * rr))
	pts.push_back(pts[0])
	if chain:
		Spr.line(pts, Color("#3a3632"), 7)
		Spr.line(pts, Color("#6b6560"), 4)
	else:
		Spr.line(pts, Color("#5a4428"), 8)
		Spr.line(pts, Color("#a8875a"), 5)
		for i in range(0, pts.size() - 1, 2):
			Spr.circle(pts[i].x, pts[i].y, 1.2, Color("#7a5f3c"))
	for kx in [x + w * .22 + 3, x + w * .78 - 3]:
		Spr.circle(kx, y, 6, Color("#8a6a40") if not chain else Color("#4a4642"))
		Spr.ring(kx, y, 6, Color("#4a3420"), 1.5)

## número "aleatório" fixo para cada posição (o cenário não muda entre quadros)
func snow_cliff(s: Dictionary) -> void:
	Spr.vgrad(s.x, s.y, s.w, s.h, Color("#b9c6da"), Color("#6f7e98"))
	var y: float = s.y + 34
	var k := 0
	while y < s.y + s.h - 10:
		var off: float = fmod(k * 53.0, 60.0)
		var x: float = s.x + off
		while x < s.x + s.w - 30:
			Spr.rr(x, y, 52 + fmod(x * .37, 30.0), 26, 9, Color(.52, .6, .74, .55))
			Spr.seg(x + 6, y + 24, x + 46, y + 24, Color(.3, .36, .48, .5), 2)
			x += 74
		y += 38
		k += 1
	Spr.hgrad(s.x, s.y, 40, s.h, Color(0, 0, 0, .25), Color(0, 0, 0, 0))
	Spr.ci.draw_rect(Rect2(s.x, s.y, s.w, s.h), Color(.25, .3, .42, .8), false, 2)
	_snow_top(s.x, s.x + s.w, s.y)
	if s.get("overhang"):
		Spr.rect(s.x, s.y + s.h - 16, s.w, 16, Color(.85, .93, 1))
		var ix: float = s.x + 8
		var n := 0
		while ix < s.x + s.w - 8:
			var L2: float = 14 + (n * 37 % 5) * 6
			Spr.poly(PackedVector2Array([Vector2(ix - 6, s.y + s.h), Vector2(ix, s.y + s.h + L2), Vector2(ix + 6, s.y + s.h)]), Color(.85, .95, 1, .95))
			ix += 22
			n += 1

func cliff(s: Dictionary) -> void:
	if s.get("snow"):
		snow_cliff(s)
		return
	var t: Texture2D = Spr.tex.chao
	# rocha maciça: blocos de pedra encaixados, sem faixas de grama por dentro (grama só no topo)
	Spr.vgrad(s.x, s.y, s.w, s.h, Color("#6e5c48"), Color("#3e3226"))
	var yy: float = s.y + 30
	var row := 0
	while yy < s.y + s.h - 8:
		var bh: float = 28.0 + fmod(row * 17.0, 26.0)
		var x: float = s.x - fmod(row * 41.0, 50.0)
		var i := 0
		while x < s.x + s.w:
			var bw: float = 44.0 + fmod((row * 7 + i * 11) * 5.3, 70.0)
			var xa: float = max(x, s.x)
			var xb: float = min(x + bw - 4, s.x + s.w)
			var hb: float = min(bh - 4, s.y + s.h - yy)
			if xb - xa > 8 and hb > 6:
				var shade: float = fmod((row * 5 + i * 3) * 1.0, 4.0) * .025
				var jy: float = fmod((row * 3 + i * 7) * 1.7, 6.0) - 3.0
				Spr.rr(xa, yy + jy, xb - xa, hb - abs(jy), 12, Color(.47 + shade, .39 + shade, .31 + shade))
				Spr.rect(xa + 4, yy + 3, xb - xa - 8, 3, Color(1, 1, 1, .07))
				Spr.rect(xa + 3, yy + hb - 5, xb - xa - 6, 4, Color(0, 0, 0, .18))
			x += bw
			i += 1
		yy += bh
		row += 1
	tile_h(t, s.x, s.x + s.w, s.y - 28)
	Spr.hgrad(s.x, s.y, 60, s.h, Color(0, 0, 0, .35), Color(0, 0, 0, 0))

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

## bloco de gelo (as "pedras" da neve)
func ice_block(s: Dictionary) -> void:
	var x: float = s.x
	var y: float = s.y
	var w: float = s.w
	var h: float = s.h
	Spr.rect(x + 4, y + h - 6, w - 8, 8, Color(0, 0, 0, .18))
	Spr.vgrad(x, y, w, h, Color(.78, .92, 1, .96), Color(.46, .68, .88, .96))
	# faces: brilho em cima, sombra do lado
	Spr.rect(x, y, w, 6, Color(.96, .99, 1, .95))
	Spr.rect(x + w - 8, y + 6, 8, h - 6, Color(.3, .5, .72, .35))
	Spr.ci.draw_rect(Rect2(x, y, w, h), Color(.22, .38, .58), false, 2.5)
	# rachaduras e reflexos
	var k := hash(int(x)) % 7
	Spr.seg(x + w * .3, y + 8, x + w * .45, y + h * .45, Color(1, 1, 1, .7), 1.5)
	Spr.seg(x + w * .45, y + h * .45, x + w * .35, y + h * .8, Color(1, 1, 1, .5), 1.2)
	Spr.seg(x + w * (.6 + k * .03), y + h * .2, x + w * .75, y + h * .55, Color(.25, .45, .65, .6), 1.2)
	Spr.seg(x + 6, y + 12, x + 6, y + h * .5, Color(1, 1, 1, .55), 3)
	# neve por cima
	Spr.rr(x - 3, y - 5, w + 6, 10, 5, Color(.97, .98, 1))

func stone(s: Dictionary) -> void:
	if s.get("ice"):
		ice_block(s)
		return
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
	_hang_ropes(s.x + 10, s.x + s.w - 10, s.y - 6, 0.0, true)
	planks(s, true)
	Spr.rect(s.x - 24, s.y - 6, s.w + 48, 14, Color("#5a3d22"))
	# cada corrente dá a volta na trave de cima
	for rx in [s.x + 10, s.x + s.w - 10]:
		_wrap(rx - 9, s.y - 10, 18, 22, 6, true)
	var y: float = s.y + s.h - 10
	var x: float = s.x
	while x < s.x + s.w:
		Spr.rect(x, y, 10, 8, Color(.85, .7, .2, .85))
		Spr.rect(x + 10, y, 10, 8, Color(.1, .08, .05, .85))
		x += 20
