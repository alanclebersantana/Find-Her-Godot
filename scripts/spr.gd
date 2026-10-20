extends Node
## Biblioteca de desenho: atlas de peças + pilha de transformações (save/restore/translate/rotate/scale),
## parecida com o canvas 2D da versão HTML, para portar o desenho quase 1:1.

var tex := {}            # nome -> Texture2D
var AR := {}             # peça -> [x,y,w,h,ax,ay,atlas]
var ci: CanvasItem
var M := Transform2D.IDENTITY
var stack: Array[Transform2D] = []
var alpha := 1.0
var astack: Array[float] = []
var glow_tex: Texture2D
var font: Font
var font_i: Font
var font_b: Font
var font_title: Font

func _ready() -> void:
	for k in ["atlas1", "atlas2"]:
		tex[k] = load("res://assets/sprites/%s.png" % k)
	for k in ["pai", "pai2", "javali", "chao", "tronco", "galho", "filha"]:
		tex[k] = load("res://assets/sprites/%s.png" % k)
	for k in ["bosque", "tarde", "pantano", "noite"]:
		tex["bg_" + k] = load("res://assets/bg/%s.jpg" % k)
	var j = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/atlas.json"))
	for n in j.atlas1:
		var r = j.atlas1[n]
		AR[n] = [r[0], r[1], r[2], r[3], r[4], r[5], 0]
	for n in j.atlas2:
		var r = j.atlas2[n]
		AR[n] = [r[0], r[1], r[2], r[3], r[4], r[5], 1]
	# brilho radial (substitui os gradientes radiais do canvas)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(.5, .5)
	gt.fill_to = Vector2(1, .5)
	gt.width = 128
	gt.height = 128
	glow_tex = gt
	font = load("res://assets/fonts/Lora-Regular.woff2")
	font_i = load("res://assets/fonts/Lora-Italic.woff2")
	font_b = load("res://assets/fonts/Lora-Bold.woff2")
	font_title = load("res://assets/fonts/Cinzel-Bold.woff2")

func atlas_tex(r) -> Texture2D:
	return tex.atlas2 if r[6] == 1 else tex.atlas1

func has(n: String) -> bool:
	return AR.has(n)

# ---------- pilha de transformações ----------
func begin(c: CanvasItem) -> void:
	ci = c
	M = Transform2D.IDENTITY
	stack.clear()
	astack.clear()
	alpha = 1.0
	ci.draw_set_transform_matrix(M)

func save() -> void:
	stack.push_back(M)
	astack.push_back(alpha)

func restore() -> void:
	if stack.size() > 0:
		M = stack.pop_back()
		alpha = astack.pop_back()
	ci.draw_set_transform_matrix(M)

func translate(x: float, y: float) -> void:
	M = M * Transform2D(0, Vector2(x, y))
	ci.draw_set_transform_matrix(M)

func rotate(a: float) -> void:
	M = M * Transform2D(a, Vector2.ZERO)
	ci.draw_set_transform_matrix(M)

func scale(sx: float, sy: float) -> void:
	M = M * Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO)
	ci.draw_set_transform_matrix(M)

# ---------- peças do atlas ----------
## Desenha a peça n com a âncora em (x,y)
func A(n: String, x: float, y: float, sc: float = 1.0, flip: bool = false, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null:
		return
	save()
	translate(x, y)
	scale(-sc if flip else sc, sc)
	ci.draw_texture_rect_region(atlas_tex(r), Rect2(-r[4], -r[5], r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, alpha * al))
	restore()

## Peça esticada num retângulo
func AB(n: String, x: float, y: float, w: float, h: float, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null:
		return
	ci.draw_texture_rect_region(atlas_tex(r), Rect2(x, y, w, h), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, alpha * al))

## Peça com base no chão (centro x, base y) e largura w
func ABb(n: String, cx: float, by: float, w: float, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null:
		return
	var h: float = w * r[3] / r[2]
	AB(n, cx - w / 2, by - h, w, h, al)

## Faixa repetida na horizontal, alinhada em ox, recortada entre x0 e x1
func strip_at(n: String, ox: float, x0: float, x1: float, y: float, h: float, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null or x1 <= x0:
		return
	var t := atlas_tex(r)
	var tw: float = r[2] * h / r[3] - 1
	var xx: float = ox + floor((x0 - ox) / tw) * tw
	while xx < x1:
		var a: float = max(xx, x0)
		var b: float = min(xx + tw + 1, x1)
		if b > a:
			var u0: float = (a - xx) / (tw + 1) * r[2]
			var u1: float = (b - xx) / (tw + 1) * r[2]
			ci.draw_texture_rect_region(t, Rect2(a, y, b - a, h), Rect2(r[0] + u0, r[1], u1 - u0, r[3]), Color(1, 1, 1, alpha * al))
		xx += tw

## Faixa repetida na vertical (escadas, redes)
func strip_v(n: String, x: float, y: float, w: float, h: float, al: float = 1.0) -> void:
	var r = AR.get(n)
	if r == null:
		return
	var t := atlas_tex(r)
	var th: float = w * r[3] / r[2] - 1
	var yy := y
	while yy < y + h:
		var b: float = min(yy + th + 1, y + h)
		var v: float = (b - yy) / (th + 1) * r[3]
		ci.draw_texture_rect_region(t, Rect2(x, yy, w, b - yy), Rect2(r[0], r[1], r[2], v), Color(1, 1, 1, alpha * al))
		yy += th

## Textura (ou recorte dela) num retângulo
func img(t: Texture2D, x: float, y: float, w: float, h: float, src: Rect2 = Rect2(), al: float = 1.0) -> void:
	if src.size == Vector2.ZERO:
		ci.draw_texture_rect(t, Rect2(x, y, w, h), false, Color(1, 1, 1, alpha * al))
	else:
		ci.draw_texture_rect_region(t, Rect2(x, y, w, h), src, Color(1, 1, 1, alpha * al))

## Quadro de uma folha de sprites (cw x ch) com âncora
func frame(t: Texture2D, fr: int, cw: float, ch: float, ax: float, ay: float, x: float, y: float, sc: float, flip: bool = false, al: float = 1.0) -> void:
	save()
	translate(x, y)
	scale(-sc if flip else sc, sc)
	ci.draw_texture_rect_region(t, Rect2(-ax, -ay, cw, ch), Rect2(fr * cw, 0, cw, ch), Color(1, 1, 1, alpha * al))
	restore()

# ---------- formas ----------
func col(c: Color, a: float = 1.0) -> Color:
	return Color(c.r, c.g, c.b, c.a * a * alpha)

func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), col(c))

func circle(x: float, y: float, r: float, c: Color) -> void:
	ci.draw_circle(Vector2(x, y), r, col(c))

func ring(x: float, y: float, r: float, c: Color, w: float = 2.0, a0: float = 0.0, a1: float = TAU) -> void:
	ci.draw_arc(Vector2(x, y), r, a0, a1, 24, col(c), w, true)

func ellipse(x: float, y: float, rx: float, ry: float, c: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var p := Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		pts.push_back(Vector2(x, y) + p)
	ci.draw_colored_polygon(pts, col(c))

func poly(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col(c))

func line(pts: PackedVector2Array, c: Color, w: float = 2.0) -> void:
	ci.draw_polyline(pts, col(c), w, true)

func seg(x0: float, y0: float, x1: float, y1: float, c: Color, w: float = 2.0) -> void:
	ci.draw_line(Vector2(x0, y0), Vector2(x1, y1), col(c), w, true)

func rr(x: float, y: float, w: float, h: float, r: float, c: Color) -> void:
	r = min(r, min(w, h) / 2)
	var pts := PackedVector2Array()
	var cs = [[x + w - r, y + r, -PI / 2], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2], [x + r, y + r, PI]]
	for cc in cs:
		for i in 6:
			var a: float = cc[2] + PI / 2 * i / 5.0
			pts.push_back(Vector2(cc[0] + cos(a) * r, cc[1] + sin(a) * r))
	ci.draw_colored_polygon(pts, col(c))

func glow(x: float, y: float, r: float, c: Color) -> void:
	ci.draw_texture_rect(glow_tex, Rect2(x - r, y - r, r * 2, r * 2), false, col(c))

func vgrad(x: float, y: float, w: float, h: float, c0: Color, c1: Color) -> void:
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	ci.draw_polygon(pts, PackedColorArray([col(c0), col(c0), col(c1), col(c1)]))

func hgrad(x: float, y: float, w: float, h: float, c0: Color, c1: Color) -> void:
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	ci.draw_polygon(pts, PackedColorArray([col(c0), col(c1), col(c1), col(c0)]))

func text(s: String, x: float, y: float, size: int, c: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, f: Font = null, outline: int = 0, oc: Color = Color(0, 0, 0, .8)) -> void:
	var ff: Font = f if f else font
	var w := -1.0
	var px := x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		var sz := ff.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		px = x - sz.x / 2
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		var sz2 := ff.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		px = x - sz2.x
	if outline > 0:
		ci.draw_string_outline(ff, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, outline, col(oc))
	ci.draw_string(ff, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, col(c))

func hexc(h: String, a: float = 1.0) -> Color:
	var c := Color(h)
	c.a = a
	return c
