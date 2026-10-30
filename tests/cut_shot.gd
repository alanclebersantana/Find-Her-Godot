extends SceneTree
## foto de um quadro de uma cena: CUT=<id> IDX=<quadro> TT=<segundos>
var c
var n := 0
func _initialize() -> void:
	c = load("res://scripts/ui/cutscene.gd").new(OS.get_environment("CUT"))
	c.auto = false
	root.add_child(c)
	c.size = Vector2(1280, 720)

func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		c.idx = int(OS.get_environment("IDX"))
		c.t = float(OS.get_environment("TT"))
		c.fade = 0.0
	if n == 6:
		var img: Image = root.get_texture().get_image()
		img.save_png(OS.get_environment("OUT"))
		return true
	return false
