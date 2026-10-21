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
	var g := game
	if g == null or not g.L or not g.running and g.T == 0:
		return
	if g.TW and g.TW.zone != null:
		return
	var vs := get_viewport_rect().size
	var cam: float = g.rcam * PAR
	var under: bool = g.L.has("under") and g.player.y > g.L.under + 60
	var song: String = g.AMB.get("song", "manha")
	var dark: float = g.AMB.dark
	var base := Color(.07, .13, .05)
	match song:
		"tarde": base = Color(.14, .08, .04)
		"chuva": base = Color(.04, .09, .07)
		"noite", "perseguicao", "tunel": base = Color(.02, .03, .06)
	if under:
		base = Color(.05, .035, .025)
	var col := base.lerp(Color(0, 0, 0), dark * .5)
	col.a = .93
	var wind: float = g.AMB.get("wind", 0.0)
	var t := float(g.T)
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
	var nleaves := 0 if under else (26 if wind > 0 else (10 if song in ["tarde", "manha"] else 5))
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
