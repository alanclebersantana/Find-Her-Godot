extends CanvasLayer
class_name LightMap
## Escuridão e luzes num mapa de luz pequeno (1/4 da tela) multiplicado por cima do mundo.
## Substitui CanvasModulate + PointLight2D: no modo de compatibilidade cada PointLight2D redesenhava
## o cenário inteiro outra vez, e com 6–10 luzes o celular caía de quadros (o pulo ficava lento).

## uma luz: os mesmos campos que o código usava no PointLight2D
class Dot:
	var position := Vector2()
	var energy := 0.0
	var color := Color.WHITE
	var texture_scale := 1.0
	var rotation := 0.0
	var offset := Vector2()
	var texture: Texture2D
	var visible := true

const DIV := 4.0
var game: Game
var ambient := Color.WHITE
var dots: Array = []
var vp: SubViewport
var painter: Node2D
var show: TextureRect

func _init() -> void:
	layer = 1

func _ready() -> void:
	vp = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(vp)
	painter = _Painter.new()
	painter.lm = self
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	painter.material = am
	vp.add_child(painter)
	show = TextureRect.new()
	show.texture = vp.get_texture()
	show.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	show.stretch_mode = TextureRect.STRETCH_SCALE
	show.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mm := CanvasItemMaterial.new()
	mm.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	show.material = mm
	add_child(show)

func dot(c: Color, r: float, tex: Texture2D) -> Dot:
	var d := Dot.new()
	d.color = c
	d.texture = tex
	d.texture_scale = r * 2 / 256.0
	dots.append(d)
	return d

func clear() -> void:
	dots.clear()

func _process(_d: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	# de dia não há o que escurecer: nem desenha (economiza a passada)
	var on: bool = ambient.r < .995 or ambient.g < .995 or ambient.b < .995
	show.visible = on
	if not on:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var sz := Vector2i(int(ceil(vs.x / DIV)), int(ceil(vs.y / DIV)))
	if vp.size != sz:
		vp.size = sz
	show.position = Vector2.ZERO
	show.size = vs
	painter.queue_redraw()

class _Painter extends Node2D:
	var lm
	func _draw() -> void:
		var g: Game = lm.game
		var sz: Vector2 = Vector2(lm.vp.size)
		draw_rect(Rect2(Vector2.ZERO, sz), lm.ambient)
		if g == null or g.camera == null:
			return
		var z: float = g.camera.zoom.x
		var cp: Vector2 = g.camera.position
		var k: float = z / DIV
		for d in lm.dots:
			if not d.visible or d.energy <= .01 or d.texture == null:
				continue
			var tw: float = d.texture.get_width() * d.texture_scale
			var th: float = d.texture.get_height() * d.texture_scale
			var sp: Vector2 = (d.position - cp) * k
			var rad: float = max(tw, th) * k
			if sp.x < -rad - abs(d.offset.x) * k or sp.y < -rad or sp.x > sz.x + rad + abs(d.offset.x) * k or sp.y > sz.y + rad:
				continue
			var c: Color = d.color * d.energy
			c.a = 1.0
			draw_set_transform(sp, d.rotation, Vector2(k * d.texture_scale, k * d.texture_scale))
			var w: float = d.texture.get_width()
			var h: float = d.texture.get_height()
			draw_texture_rect(d.texture, Rect2(d.offset / d.texture_scale - Vector2(w, h) / 2, Vector2(w, h)), false, c)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
