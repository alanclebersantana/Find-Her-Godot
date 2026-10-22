extends Node2D
## Efeitos de tela: cor do trecho, chuva, relâmpago e o "íris" ao entrar/sair de esconderijos.

var game: Game
var rain: Array = []

var vign: GradientTexture2D
func _ready() -> void:
	# vinheta: bordas um pouco mais escuras, centro limpo
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.add_point(.62, Color(0, 0, 0, 0))
	gr.set_color(gr.get_point_count() - 1, Color(0, 0, 0, 1))
	vign = GradientTexture2D.new()
	vign.gradient = gr
	vign.fill = GradientTexture2D.FILL_RADIAL
	vign.fill_from = Vector2(.5, .5)
	vign.fill_to = Vector2(1.08, .5)
	vign.width = 256
	vign.height = 144
	for i in 160:
		rain.append({"x": randf() * 1400, "y": randf() * 540, "v": 12 + randf() * 8})

func _process(_d: float) -> void:
	queue_redraw()

static func css(s: String) -> Color:
	# "rgba(r,g,b,a)" -> Color
	var m := s.replace("rgba(", "").replace("rgb(", "").replace(")", "").split(",")
	if m.size() < 3:
		return Color(0, 0, 0, 0)
	return Color(float(m[0]) / 255.0, float(m[1]) / 255.0, float(m[2]) / 255.0, float(m[3]) if m.size() > 3 else 1.0)

func _draw() -> void:
	var __t := Time.get_ticks_usec()
	__draw_raw()
	Spr.pt("fx", __t)

func __draw_raw() -> void:
	if game == null or not game.L:
		return
	var vs := get_viewport_rect().size
	var tint: String = game.AMB.get("tint", "")
	if tint != "" and tint != null:
		draw_rect(Rect2(Vector2.ZERO, vs), css(tint))
	var r: float = game.AMB.rain
	if game.indoors():
		r = 0.0
	if r > .05 and game.running:
		var n := int(rain.size() * r)
		for i in n:
			var d: Dictionary = rain[i]
			d.y += d.v
			d.x -= d.v * .25
			if d.y > vs.y:
				d.y = -10
				d.x = randf() * (vs.x + 100)
			if d.x < -20:
				d.x += vs.x + 40
			draw_line(Vector2(d.x, d.y), Vector2(d.x + 3, d.y - 14), Color(.78, .84, .9, .45), 1.3)
	if not game.low_fx:
		_vignette(vs)
	if game.lightning > 0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(.9, .94, 1, game.lightning / 14.0))
	# transição em círculo (íris), como nos desenhos antigos: fecha no Tomé quando ele cai e abre de novo
	var p: Dictionary = game.player
	var z: float = game.camera.zoom.x if game.camera else 1.0
	var pc := Vector2((p.x + p.w / 2 - game.rcam) * z, (p.y + p.h / 2 - game.rcam_y) * z)
	var maxr: float = vs.length()
	var ir := -1.0
	if p.dyingT > 0:
		var u: float = clamp((p.dyingT - 4) / 40.0, 0.0, 1.0)
		ir = maxr * u * u
	elif game.iris_t > 0:
		var u2: float = 1.0 - game.iris_t / 30.0
		ir = maxr * u2 * u2
	if ir >= 0 and ir < maxr:
		var wide: float = maxr * 2.0
		draw_arc(pc, ir + wide / 2.0, 0, TAU, 72, Color(0, 0, 0), wide, true)
		if ir > 2:
			draw_arc(pc, ir + 2, 0, TAU, 72, Color(.1, .07, .04, .6), 4, true)

## vinheta só nas bordas: um anel de elipses (o centro não é desenhado, sai bem mais barato que
## uma imagem por cima da tela inteira)
func _vignette(vs: Vector2) -> void:
	var c := vs / 2
	var n := 40
	var ri := c * .7
	var ro := c * 1.5
	var a0 := Color(0, 0, 0, 0)
	var a1 := Color(0, 0, 0, .32)
	for i in n:
		var t0: float = TAU * i / n
		var t1: float = TAU * (i + 1) / n
		var d0 := Vector2(cos(t0), sin(t0))
		var d1 := Vector2(cos(t1), sin(t1))
		draw_polygon(PackedVector2Array([c + d0 * ri, c + d1 * ri, c + d1 * ro, c + d0 * ro]),
			PackedColorArray([a0, a0, a1, a1]))
