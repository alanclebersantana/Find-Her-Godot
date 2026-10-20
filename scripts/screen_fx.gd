extends Node2D
## Efeitos de tela: cor do trecho, chuva, relâmpago e o "íris" ao entrar/sair de esconderijos.

var game: Game
var rain: Array = []

func _ready() -> void:
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
	if game == null or not game.L:
		return
	var vs := get_viewport_rect().size
	var tint: String = game.AMB.get("tint", "")
	if tint != "" and tint != null:
		draw_rect(Rect2(Vector2.ZERO, vs), css(tint))
	var r: float = game.AMB.rain
	if game.L.has("under") and game.player.y > game.L.under:
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
	if game.lightning > 0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(.9, .94, 1, game.lightning / 14.0))
	if game.iris_t > 0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, game.iris_t / 30.0))
