extends Node2D
## Camada da frente (entre o mundo e o HUD): silhuetas de capim, samambaias, galhos e pedras
## passando mais rápido que o cenário (paralaxe), folhas voando e a neblina do clima.

var game: Game
var leaves: Array = []
var fog: Array = []
const PAR := 1.45     # a camada da frente anda 45% mais rápido que o mundo

func _ready() -> void:
	for i in 26:
		leaves.append({"x": randf() * 1400, "y": randf() * 540, "vx": 0.0, "vy": 0.0, "r": randf() * TAU, "vr": 0.0, "s": .7 + randf() * .6, "c": randi() % 3})
	for i in 7:
		fog.append({"x": randf() * 1600, "y": 150 + randf() * 330, "w": 420 + randf() * 420, "h": 140 + randf() * 120, "v": .15 + randf() * .3, "a": .5 + randf() * .5})

func _process(_d: float) -> void:
	queue_redraw()

static func hh(x: float, k: int = 0) -> float:
	var v := sin(x * 12.9898 + k * 78.233) * 43758.5453
	return v - floor(v)

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("front", __t)

func __draw_raw() -> void:
	var g := game
	if g == null or not g.L or not g.running and g.T == 0:
		return
	var vs := get_viewport_rect().size
	var cam: float = g.rcam * PAR
	var under: bool = (g.L.has("under") and g.player.y > g.L.under + 60) or g.indoors()
	var song: String = g.AMB.get("song", "manha")
	var dark: float = g.AMB.dark
	var base := Color(.07, .13, .05)
	match song:
		"tarde": base = Color(.14, .08, .04)
		"chuva": base = Color(.04, .09, .07)
		"noite", "perseguicao", "tunel": base = Color(.02, .03, .06)
	if under:
		base = Color(.05, .035, .025)
	var snow: float = g.AMB.get("snow", 0.0)
	if snow > 0:
		base = base.lerp(Color(.55, .62, .78), snow)
	var col := base.lerp(Color(0, 0, 0), dark * .5)
	col.a = .93
	var wind: float = g.AMB.get("wind", 0.0)
	var t := float(g.T)
	# sombras de nuvens passando devagar pelo chão (só de dia, ao ar livre)
	if not under and dark < .15 and song in ["manha", "tarde", "tema"] and g.AMB.rain < .2:
		for i in 3:
			var cw: float = 700 + hh(i * 1.0, 6) * 500
			var span: float = vs.x + cw * 2
			var cx: float = fposmod(hh(i * 1.0, 7) * span - t * (.35 + i * .12) - g.rcam * .9, span) - cw
			draw_texture_rect(Spr.glow_tex, Rect2(cx, vs.y * .25 + hh(i * 1.0, 8) * vs.y * .3, cw, vs.y * .8), false, Color(0, .02, .08, .13))
	# silhuetas só na borda de baixo: capim e samambaias, translúcidos e "desfocados" (várias cópias suaves)
	if not under:
		var step := 300.0
		var i0 := int(floor(cam / step)) - 2
		var i1 := int(floor((cam + vs.x) / step)) + 2
		for i in range(i0, i1):
			var r := hh(i * 1.0, 1)
			if r < .62:
				continue
			var x: float = i * step + hh(i * 1.0, 2) * 120 - cam
			var kind := int(hh(i * 1.0, 3) * 2)
			var sway: float = sin(t * (.02 + wind * .04) + i) * (2 + wind * 8)
			for b in 3:
				var cb := col
				cb.a = [.16, .2, .34][b]
				var off: float = [3.0, -3.0, 0.0][b]
				if kind == 0:
					_grass(x + off, vs.y + abs(off), cb, sway, i)
				else:
					_fern(x + off, vs.y + abs(off), cb, sway, i)
	# folhas voando (sempre algumas; muitas com vento; nenhuma debaixo da terra)
	var nleaves := 0 if under else (26 if wind > 0 or snow > .3 else (10 if song in ["tarde", "manha"] else 5))
	for k in nleaves:
		var l: Dictionary = leaves[k]
		l.vx = lerpf(l.vx, -1.2 - wind * 5.5 + sin(t * .01 + k) * .8, .02)
		l.vy = lerpf(l.vy, .6 + sin(t * .05 + k * 2.0) * .9, .05)
		l.vr = sin(t * .03 + k) * .08
		l.x += l.vx - (g.rcam - g.prev_cam) * .3
		l.y += l.vy
		l.r += l.vr
		if l.x < -40:
			l.x = vs.x + 30
			l.y = randf() * vs.y * .7
		if l.x > vs.x + 60:
			l.x = -30
		if l.y > vs.y + 20:
			l.y = -20
			l.x = randf() * vs.x
		if snow > .3:
			# flocos de neve caindo devagar — só nos momentos em que está nevando
			var fall: float = g.AMB.get("snowfall", snow)
			l.y += .5 + l.s * .6 + fall * .6
			if k >= int(26 * fall):
				continue
			var fs: float = 2.0 + l.s * 2.4
			draw_circle(Vector2(l.x, l.y), fs, Color(1, 1, 1, .85 * fall))
			draw_circle(Vector2(fmod(l.x + 517.0, vs.x), fmod(l.y + 233.0, vs.y)), fs * .7, Color(1, 1, 1, .6 * fall))
			continue
		var lc: Color = [Color(.42, .6, .2), Color(.75, .5, .15), Color(.6, .3, .12)][l.c]
		if song in ["noite", "perseguicao", "tunel"]:
			lc = lc.darkened(.65)
		_leaf(l.x, l.y, l.r, l.s, lc)
	# neblina
	var fa: float = g.AMB.get("fog", 0.0)
	if fa > 0:
		var fc := Color(.85, .88, .9).lerp(Color(.35, .4, .55), dark)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(fc.r, fc.g, fc.b, .2 * fa))
		for f in fog:
			f.x -= f.v + (g.rcam - g.prev_cam) * .5
			if f.x + f.w < -100:
				f.x = vs.x + 50
			if f.x > vs.x + 400:
				f.x = -f.w
			draw_texture_rect(Spr.glow_tex, Rect2(f.x, f.y - g.rcam_y * .05, f.w, f.h), false, Color(fc.r, fc.g, fc.b, .6 * f.a * fa))

func _leaf(x: float, y: float, r: float, s: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 8.0
		var p := Vector2(cos(a) * 7 * s, sin(a) * 3 * s * (1.0 + .4 * cos(a)))
		pts.push_back(Vector2(x, y) + p.rotated(r))
	draw_colored_polygon(pts, c)
	draw_line(Vector2(x, y) + Vector2(-7 * s, 0).rotated(r), Vector2(x, y) + Vector2(7 * s, 0).rotated(r), c.darkened(.4), 1)

func _grass(x: float, by: float, c: Color, sway: float, seed_i: int) -> void:
	for k in 9:
		var bx: float = x + k * 9 - 40
		var h: float = 36 + hh(seed_i * 10.0 + k, 4) * 58
		var lean: float = sway * (h / 100.0) + (k - 4) * 3
		var pts := PackedVector2Array([Vector2(bx - 5, by + 4), Vector2(bx + lean * .5, by - h * .55), Vector2(bx + lean, by - h), Vector2(bx + 5, by + 4)])
		draw_colored_polygon(pts, c)

func _fern(x: float, by: float, c: Color, sway: float, seed_i: int) -> void:
	for k in 5:
		var a: float = -PI / 2 + (k - 2) * .42 + sway * .01
		var L: float = 55 + hh(seed_i * 3.0 + k, 5) * 50
		var pts := PackedVector2Array()
		var tip := Vector2(x, by) + Vector2(cos(a), sin(a)) * L
		for j in 8:
			var u := j / 7.0
			var p := Vector2(x, by).lerp(tip, u)
			var n := Vector2(-sin(a), cos(a)) * (1.0 - u) * 16 * sin(u * PI + .3)
			pts.push_back(p + n)
		for j in range(7, -1, -1):
			var u2 := j / 7.0
			var p2 := Vector2(x, by).lerp(tip, u2)
			var n2 := Vector2(-sin(a), cos(a)) * (1.0 - u2) * 16 * sin(u2 * PI + .3)
			pts.push_back(p2 - n2)
		draw_colored_polygon(pts, c)
