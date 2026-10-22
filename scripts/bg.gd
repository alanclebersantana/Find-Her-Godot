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
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("bg", __t)

func __draw_raw() -> void:
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
	for k in keys:
		_sky(k, ws[k], w, oy)

static func hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

## o céu vivo por cima da pintura: nuvens andando, a tarde caindo, estrelas piscando, a lua com halo
## e uma névoa de distância na base (separa o fundo do caminho do Tomé)
func _sky(k: String, al: float, w: float, oy: float) -> void:
	var H: float = game.H
	var t := float(game.T)
	match k:
		"bosque", "neve":
			# nuvens fofas em duas alturas, cada uma no seu passo
			for i in 5:
				var sp: float = .05 + hh(i, 1) * .06
				var cw: float = 110 + hh(i, 2) * 130
				var span: float = w + cw * 2 + 300
				var cx: float = fposmod(hh(i, 3) * span - t * sp - game.rcam * .03, span) - cw
				var cy: float = 26 + hh(i, 4) * H * .1 + oy * .2
				var ca: float = (.42 if k == "bosque" else .5) * al
				_cloud(cx, cy, cw, Color(1, 1, 1, ca))
		"tarde":
			# o sol vai baixando: o céu esquenta e escurece aos poucos até o pântano
			var u: float = clamp((game.player.x - 3350.0) / (14700.0 - 3350.0), 0, 1)
			Spr.vgrad(0, 0, w, H * .7, Color(.45, .12, .25, .3 * u * al), Color(.9, .35, .15, .12 * u * al))
		"noite":
			# halo respirando em volta da lua pintada no fundo (a lua fica em 878,90 na pintura)
			var t3: Texture2D = Spr.tex["bg_noite"]
			var sc3: float = GL / t3.get_height()
			var tw3: float = t3.get_width() * sc3
			var x3: float = fposmod(-game.rcam * PX, tw3 - 1) - (tw3 - 1)
			while x3 < w:
				Spr.glow(x3 + 878 * sc3, oy + 90 * sc3, 90 + sin(t * .02) * 8, Color(.8, .86, 1, .3 * al))
				x3 += tw3 - 1
	# névoa de distância na base do fundo
	var fc: Color = {"bosque": Color(.86, .94, .82), "tarde": Color(1, .78, .5), "pantano": Color(.55, .65, .6),
		"noite": Color(.2, .25, .45), "neve": Color(.92, .95, 1)}.get(k, Color(.9, .9, .9))
	Spr.vgrad(0, H * .5, w, H * .5, Color(fc.r, fc.g, fc.b, 0), Color(fc.r, fc.g, fc.b, .32 * al))

func _cloud(x: float, y: float, cw: float, c: Color) -> void:
	# contorno único (sem sobreposição de transparências): bolotas em cima, base reta e arredondada
	var pts := PackedVector2Array()
	var base: float = y + cw * .07
	var n := 26
	for i in n + 1:
		var u := float(i) / n
		var top := 0.0
		for j in 5:
			var cu: float = .12 + j * .19
			var r: float = .13 + .1 * sin((j / 4.0) * PI)
			var d: float = (u - cu) / r
			if abs(d) < 1:
				top = max(top, r * sqrt(1 - d * d) + .02 * (j % 2))
		var end: float = sin(u * PI)
		pts.push_back(Vector2(x + u * cw, base - cw * top * .9 * (.4 + .6 * sqrt(end))))
	for i in range(n - 1, 0, -1):
		var u2 := float(i) / n
		pts.push_back(Vector2(x + u2 * cw, base + cw * .03 * sin(u2 * PI)))
	Spr.poly(pts, c)
	# sombrinha azulada na base
	Spr.ellipse(x + cw * .5, base, cw * .42, cw * .03, Color(.7, .78, .92, c.a * .5))


const LAYER_PX := [.04, .16, .3, .48]
## brilho de cada camada: a mais perto fica mais escura para o Tomé e os objetos se destacarem
const LAYER_SH := [1.0, .96, .86, .58]

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
		var m: float = LAYER_SH[min(i, 3)]
		var mc := Color(m, m, m * 1.04, Spr.alpha * al)
		while x < w:
			Spr.ci.draw_texture_rect(t, Rect2(x, y, tw, lh), false, mc)
			x += tw - 1

func _layer(k: String, ox: float, oy: float, w: float, bh: float, al: float) -> void:
	if Spr.tex.has("bgl_" + k):
		_layers(k, w, al)
		return
	var t: Texture2D = Spr.tex["bg_" + k]
	if k == "bosque" or k == "neve":
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
