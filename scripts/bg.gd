extends Node2D
## Fundo em paralaxe: um cenário para cada trecho (manhã, tarde, pântano, noite),
## trocando suavemente conforme o Tomé avança.

var game: Game
const PX := .35
const GL := 600.0

func _process(_d: float) -> void:
	if game and game.L:
		position = Vector2(game.rcam, game.rcam_y)
	queue_redraw()

func _draw() -> void:
	if game == null or not game.L:
		return
	Spr.begin(self)
	var w := game.W + 4
	var ox := -game.rcam * PX
	var oy: float = -(game.rcam_y - game.L.top) * PX
	var bh: float = game.H + max(0.0, (game.L.bottom - game.L.top) - game.H) * PX
	var ws := game.section_weights()
	var first := true
	# o de maior peso primeiro (opaco), depois o outro por cima com transparência
	var keys := ws.keys()
	keys.sort_custom(func(a, b): return ws[a] > ws[b])
	for k in keys:
		var al: float = 1.0 if first else ws[k]
		first = false
		_layer(k, ox, oy, w, bh, al)

const LAYER_PX := [.04, .16, .3, .48]

## cenário em camadas (quando as artes novas existem): cada camada anda numa velocidade
func _layers(k: String, w: float, al: float) -> void:
	var ls: Array = Spr.tex["bgl_" + k]
	var H: float = game.H
	for i in ls.size():
		var t: Texture2D = ls[i]
		var f: float = LAYER_PX[min(i, 3)]
		var lh: float = H * (1.12 + i * .04)
		var sc: float = lh / t.get_height()
		var tw: float = t.get_width() * sc
		var y: float = H - lh + clamp(-(game.rcam_y - 140.0) * f * .35, -60.0, 140.0)
		var x: float = fposmod(-game.rcam * f, tw - 1) - (tw - 1)
		while x < w:
			Spr.img(t, x, y, tw, lh, Rect2(), al)
			x += tw - 1

func _layer(k: String, ox: float, oy: float, w: float, bh: float, al: float) -> void:
	if Spr.tex.has("bgl_" + k):
		_layers(k, w, al)
		return
	var t: Texture2D = Spr.tex["bg_" + k]
	if k == "bosque":
		var sc := bh / t.get_height()
		var tw := t.get_width() * sc
		var x := fposmod(ox, tw - 1) - (tw - 1)
		while x < w:
			Spr.img(t, x, oy, tw, bh, Rect2(), al)
			x += tw - 1
	elif k == "tarde":
		var bandh := 430.0
		var sc2 := bandh / t.get_height()
		var tw2 := t.get_width() * sc2
		Spr.vgrad(0, oy - 200, w, GL - bandh + 240, Color(.93, .69, .38, al), Color(.96, .81, .55, al))
		Spr.rect(0, oy + GL - 10, w, bh, Color(.29, .17, .08, al))
		var x2 := fposmod(ox, tw2 - 1) - (tw2 - 1)
		while x2 < w:
			Spr.img(t, x2, oy + GL - bandh + 30, tw2, bandh, Rect2(), al)
			x2 += tw2 - 1
		Spr.vgrad(0, oy + GL - bandh + 30, w, 80, Color(.96, .81, .55, al), Color(.96, .81, .55, 0))
	else:
		var sc3 := GL / t.get_height()
		var tw3 := t.get_width() * sc3
		var base := Color("#0d1020") if k == "noite" else Color("#1c2622")
		base.a = al
		Spr.rect(0, oy - 200, w, bh + 400, base)
		var x3 := fposmod(ox, tw3 - 1) - (tw3 - 1)
		while x3 < w:
			Spr.img(t, x3, oy, tw3, GL, Rect2(), al)
			x3 += tw3 - 1
		Spr.vgrad(0, oy + GL - 60, w, 60, Color(base.r, base.g, base.b, 0), base)
