extends Control
class_name RestScene
## Grande fogueira no fim de cada período: o Tomé se aquece, olha os desenhos que achou
## e, no fundo, em tom de sépia, lembra de um momento com a Isis.
##   1 desenhando na varanda · 2 pega-pega no quintal · 3 pulando nas poças com a lanterna
##   4 o boneco de neve ganhando o gorro verde do Tomé

var n := 1
var t := 0.0
var drawings := 0
var memory: Control

const SEPIA := """
shader_type canvas_item;
uniform float fade = 1.0;
void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(.3, .59, .11));
	vec3 s = vec3(g) * vec3(1.08, .88, .62) + vec3(.06, .03, .0);
	COLOR = vec4(mix(c.rgb, s, .9), c.a * fade);
}
"""

func setup(period: int, found: int) -> void:
	n = clamp(period, 1, 4)
	drawings = found
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	memory = _Memory.new()
	memory.scene = self
	var sh := Shader.new()
	sh.code = SEPIA
	var m := ShaderMaterial.new()
	m.shader = sh
	memory.material = m
	memory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(memory)

func _process(d: float) -> void:
	t += d * 60.0
	var vs := get_viewport_rect().size
	var mw: float = min(vs.x * .5, 560.0)
	var mh: float = mw * .44
	memory.position = Vector2(vs.x / 2 - mw / 2, vs.y * .04)
	memory.size = Vector2(mw, mh)
	(memory.material as ShaderMaterial).set_shader_parameter("fade", clamp((t - 20) / 70.0, 0.0, 1.0))
	queue_redraw()
	memory.queue_redraw()

func _draw() -> void:
	Spr.begin(self)
	var vs := get_viewport_rect().size
	# noite quente em volta da fogueira
	Spr.vgrad(0, 0, vs.x, vs.y, Color("#120c08"), Color("#2a160a"))
	var fl: float = .85 + sin(t * .31) * .08 + sin(t * .73) * .05
	var fx: float = vs.x * .5 + 40
	var fy: float = vs.y * .72
	Spr.glow(fx, fy - 40, 420 * fl, Color(1, .55, .2, .32))
	Spr.glow(fx, fy - 30, 180 * fl, Color(1, .75, .35, .45))
	# chão
	Spr.ellipse(fx - 40, fy + 6, 300, 28, Color(.18, .1, .05))
	# o Tomé se aquecendo (de lado para o fogo)
	Spr.frame(Spr.tex.pai, 0, 130, 160, 65, 156, fx - 130, fy + 4, .8, false)
	# a fogueira grande
	Spr.A("o_fire_on", fx, fy + 4, 1.6)
	for i in 6:
		var u: float = fmod(t * .012 + i / 6.0, 1.0)
		Spr.circle(fx + sin(i * 2.1 + t * .05) * 30 * u, fy - 40 - u * 220, 3 * (1.0 - u) + .5, Color(1, .7, .3, 1.0 - u))
	# os desenhos achados, apoiados no chão ao lado
	for i in drawings:
		Spr.save()
		Spr.translate(fx + 150 + i * 46, fy - 26 - (i % 2) * 6)
		Spr.rotate(-.18 + i * .16)
		Spr.A("drawing", 0, 0, 1.0)
		Spr.restore()
	# moldura da lembrança
	var r := Rect2(memory.position, memory.size)
	var a: float = clamp((t - 20) / 70.0, 0.0, 1.0)
	Spr.rr(r.position.x - 10, r.position.y - 10, r.size.x + 20, r.size.y + 20, 22, Color(.92, .8, .58, .16 * a))
	Spr.glow(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2, r.size.x * .7, Color(1, .85, .6, .1 * a))

class _Memory extends Control:
	var scene
	func _draw() -> void:
		Spr.begin(self)
		var w: float = size.x
		var h: float = size.y
		var t: float = scene.t
		clip_contents = true
		# céu e chão da lembrança
		Spr.vgrad(0, 0, w, h, Color("#cfe3f2"), Color("#f2ead8"))
		match scene.n:
			1: _porch(w, h, t)
			2: _tag(w, h, t)
			3: _puddles(w, h, t)
			4: _snowman(w, h, t)
		# bordas esfumaçadas
		for i in 6:
			var k: float = i / 6.0
			Spr.ci.draw_rect(Rect2(i * 4, i * 4, w - i * 8, h - i * 8), Color(.1, .06, .03, .18 * (1.0 - k)), false, 4)

	func _lia(fr: int, x: float, by: float, hgt: float, flip: bool = false) -> void:
		var t2: Texture2D = Spr.tex.filha
		var fw: float = t2.get_width() / 4.0
		var fh: float = t2.get_height()
		var s: float = hgt / fh
		Spr.save()
		Spr.translate(x, by)
		Spr.scale(-s if flip else s, s)
		Spr.ci.draw_texture_rect_region(t2, Rect2(-fw / 2, -fh, fw, fh), Rect2(fr * fw, 0, fw, fh))
		Spr.restore()

	func _ground(w: float, h: float, c: Color) -> void:
		Spr.rect(0, h * .78, w, h * .22, c)

	func _porch(w: float, h: float, t: float) -> void:
		Spr.circle(w * .85, h * .2, 26, Color(1, .95, .7))
		_ground(w, h, Color("#9bb36a"))
		Spr.AB("o_cabin", w * .08, h * .08, w * .62, h * .78)
		Spr.A("lia_draw", w * .5, h * .74, .9)
		# rabiscos aparecendo no papel
		var k: int = int(t / 20) % 6
		for i in k:
			Spr.seg(w * .5 + 8 + i * 4, h * .70, w * .5 + 12 + i * 4, h * .68, Color(.8, .2, .2), 2)
		Spr.text("♥", w * .58, h * .56 - fmod(t * .3, 30), 18, Color(.9, .3, .3, 1.0 - fmod(t * .3, 30) / 30.0), HORIZONTAL_ALIGNMENT_CENTER)

	func _tag(w: float, h: float, t: float) -> void:
		_ground(w, h, Color("#9bb36a"))
		Spr.img(Spr.tex.tronco, w * .78, h * .05, 70, h * .76)
		Spr.ellipse(w * .82, h * .08, 110, 60, Color("#6f9a4a"))
		var lx: float = w * .5 + sin(t * .03) * w * .3
		var dir: float = cos(t * .03)
		var tx: float = lx - sign(dir) * 90
		_lia(2 if int(t / 12) % 2 == 0 else 1, lx, h * .82 - abs(sin(t * .2)) * 10, h * .36, dir < 0)
		Spr.frame(Spr.tex.pai, 1 + int(t / 8) % 4, 130, 160, 65, 156, tx, h * .83, .36, dir < 0)
		Spr.text("hihi!", lx, h * .3, 15, Color(.4, .25, .2), HORIZONTAL_ALIGNMENT_CENTER)

	func _puddles(w: float, h: float, t: float) -> void:
		Spr.vgrad(0, 0, w, h * .8, Color("#8fa3b5"), Color("#c9d3dc"))
		_ground(w, h, Color("#7d8a6a"))
		for i in 3:
			Spr.ellipse(w * (.25 + i * .25), h * .86, 52, 9, Color(.55, .7, .85))
		for i in 30:
			var rx: float = fmod(i * 97.0 + t * 2.0, w)
			var ry: float = fmod(i * 53.0 + t * 7.0, h * .8)
			Spr.seg(rx, ry, rx - 3, ry + 12, Color(.35, .45, .6, .6), 1.5)
		var j: float = abs(sin(t * .07))
		var lx: float = w * .5
		_lia(2, lx, h * .86 - j * 40, h * .36)
		if j < .15:
			for k in 6:
				Spr.circle(lx + (k - 2.5) * 12, h * .84 - k % 3 * 6, 4, Color(.6, .75, .9))
		# o pai com a lanterna acesa
		Spr.frame(Spr.tex.pai, 0, 130, 160, 65, 156, w * .22, h * .87, .36, false)
		Spr.glow(w * .27, h * .62, 60, Color(1, .85, .5, .5))

	func _snowman(w: float, h: float, t: float) -> void:
		Spr.vgrad(0, 0, w, h * .8, Color("#c6d6e6"), Color("#eef2f6"))
		Spr.rect(0, h * .78, w, h * .22, Color(.95, .96, 1))
		var sx: float = w * .58
		var hat: bool = t > 150
		WorldNature.snowman(sx, h * .86, h / 300.0, hat)
		if not hat:
			# o gorro voando das mãos dela até a cabeça do boneco
			var u: float = clamp((t - 90) / 60.0, 0.0, 1.0)
			var bx: float = lerpf(w * .36, sx, u)
			var by: float = lerpf(h * .5, h * .86 - 130 * h / 300.0, u) - sin(u * PI) * 30
			WorldNature.beanie(bx, by, h / 300.0)
		_lia(3, w * .34, h * .86, h * .36)
		for i in 24:
			var fx: float = fmod(i * 71.0 + sin(t * .02 + i) * 20, w)
			var fy: float = fmod(i * 43.0 + t * 1.2, h)
			Spr.circle(fx, fy, 2.2, Color(1, 1, 1, .9))
