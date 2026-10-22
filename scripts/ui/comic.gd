extends Control
## Quadrinho curto: apresentação dos chefes (dois quadros, ~5 s) e reações do Tomé na primeira vez
## que encontra algo novo (um quadro, ~3 s). Arte pintada em assets/comic/<id>.jpg. Toque pula.

signal finished

const DATA := {
	"cipo": {"img": ["cipo"], "txt": "Cipós! Se eu balançar direitinho, chego do outro lado."},
	"mergulho": {"img": ["mergulho"], "txt": "Água funda... respira fundo, Tomé."},
	"neve": {"img": ["neve"], "txt": "Brrr! Que frio... aguenta firme, Isis, estou chegando!"},
	"pipoca": {"img": ["pipoca"], "txt": "Pipoca! Agora somos dois procurando a Isis."},
	"cavalo": {"img": ["cavalo"], "txt": "Calma, amigão... você me leva até a mina?"},
	"mina": {"img": ["mina"], "txt": "Escuro demais... ainda bem que eu trouxe a lanterna."},
	"toxico": {"img": ["toxico"], "txt": "Eca! Essa água verde é veneno. Nada de cair aí!"},
	"javali": {"img": ["javali_a", "javali_b"], "title": "JAVALI-REI", "txt": "O terror do bosque! Preciso desviar das investidas dele..."},
	"gaviao": {"img": ["gaviao_a", "gaviao_b"], "title": "GAVIÃO-REI", "txt": "O senhor das copas! Longe da sombra dele, Tomé!"},
	"bagre": {"img": ["bagre_a", "bagre_b"], "title": "BAGRE-REI", "txt": "O dono do lago... e eu aqui embaixo d'água!"},
	"urso": {"img": ["urso_a", "urso_b"], "title": "URSO-PARDO-REI", "txt": "O guardião da neve! Cuidado com a patada!"},
	"vargas": {"img": ["vargas_a", "vargas_b"], "title": "ADEMAR VARGAS", "txt": "Vargas! Devolve a minha filha!"},
	"bola": {"img": ["bola_a", "bola_b"], "title": "CORRA, TOMÉ!", "txt": "Que barulho é esse?... Uma pedra gigante! Corre!"},
	"aviao": {"img": ["aviao_a", "aviao_b"], "title": "UM AVIÃO!", "txt": "Um biplano antigo! Daqui de cima eu chego rapidinho na mina!"},
	"jangada": {"img": ["jangada"], "txt": "Segura firme, Tomé... essa correnteza é forte!"},
	"colmeia": {"img": ["colmeia_a", "colmeia_b"], "title": "COLMEIA!", "txt": "Se encostar na colmeia, o enxame vem atrás. Mergulhe na água para despistar as abelhas!"},
}

var id := ""
var t := 0.0
var dur := 3.0
var texs: Array = []
var leaving := -1.0
var auto := DisplayServer.get_name() == "headless"

func _init(cid: String = "cipo") -> void:
	id = cid

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var d: Dictionary = DATA.get(id, DATA.cipo)
	for n in d.img:
		var p := "res://assets/comic/%s.jpg" % n
		if ResourceLoader.exists(p):
			texs.append(load(p))
	dur = 5.0 if d.img.size() > 1 else 3.0
	Save.setv("comic", id, true)
	if texs.is_empty() or auto:
		_end.call_deferred()
	Audio.play("unlock", -10)

func _process(dlt: float) -> void:
	t += dlt
	if leaving >= 0:
		leaving += dlt
		if leaving > .25:
			_end()
	elif t >= dur:
		leaving = 0.0
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		if t > .35 and leaving < 0:
			leaving = 0.0
		accept_event()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and t > .35 and leaving < 0:
		leaving = 0.0
		get_viewport().set_input_as_handled()

func _end() -> void:
	if is_queued_for_deletion():
		return
	finished.emit()
	queue_free()

## quadro com moldura branca, contorno e sombra, entrando com um "pulo"
func _panel(tex: Texture2D, cx: float, cy: float, side: float, k: float, rot: float) -> void:
	if k <= 0.0:
		return
	var e: float = 1.0 + sin(min(k, 1.0) * PI) * .08 if k < 1.0 else 1.0
	var s: float = side * min(1.0, k * 1.6) * e
	Spr.save()
	Spr.translate(cx, cy)
	Spr.rotate(rot)
	Spr.rr(-s / 2 + 8, -s / 2 + 10, s, s, 6, Color(0, 0, 0, .45))
	Spr.rr(-s / 2 - 7, -s / 2 - 7, s + 14, s + 14, 6, Color(.98, .96, .9))
	Spr.ci.draw_texture_rect(tex, Rect2(-s / 2, -s / 2, s, s), false)
	Spr.ci.draw_rect(Rect2(-s / 2, -s / 2, s, s), Color(.08, .06, .04), false, 3.0)
	Spr.restore()

func _draw() -> void:
	if texs.is_empty():
		return
	Spr.begin(self)
	var W := size.x
	var H := size.y
	var fade: float = clamp(t / .2, 0, 1) * (1.0 - clamp(leaving / .25, 0, 1) if leaving >= 0 else 1.0)
	Spr.alpha = fade
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, .6 * fade))
	var d: Dictionary = DATA.get(id, DATA.cipo)
	var cap_y: float
	if texs.size() == 1:
		var side: float = min(H * .66, W * .42)
		_panel(texs[0], W / 2, H * .44, side, t / .35, -.025)
		cap_y = H * .44 + side / 2 + 26
	else:
		var side2: float = min(H * .6, W * .36)
		var gap: float = side2 * .08
		_panel(texs[0], W / 2 - side2 / 2 - gap, H * .47, side2, t / .35, -.03)
		_panel(texs[1], W / 2 + side2 / 2 + gap, H * .47 + 10, side2, (t - 1.1) / .35, .03)
		cap_y = H * .47 + side2 / 2 + 30
		# nome do chefe em letras grandes
		var ta: float = clamp((t - .2) / .3, 0, 1)
		var sc: float = 1.0 + (1.0 - ta) * .6
		Spr.save()
		Spr.translate(W / 2, H * .47 - side2 / 2 - 22)
		Spr.scale(sc, sc)
		Spr.text(d.get("title", ""), 0, 0, 44, Color(1, .84, .3, ta), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_title, 8, Color(.12, .05, .02, .95 * ta))
		Spr.restore()
	# legenda em caixa de quadrinho
	var ca: float = clamp((t - (.5 if texs.size() == 1 else 1.6)) / .25, 0, 1)
	if ca > 0:
		var txt: String = d.txt
		var fs := 19
		var tw: float = Spr.font_i.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bw: float = min(W - 40, tw + 40)
		var by: float = min(cap_y, H - 54)
		Spr.rr(W / 2 - bw / 2 + 4, by + 4, bw, 40, 6, Color(0, 0, 0, .4 * ca))
		Spr.rr(W / 2 - bw / 2, by, bw, 40, 6, Color(1, .95, .78, ca))
		draw_rect(Rect2(W / 2 - bw / 2, by, bw, 40), Color(.1, .07, .04, ca), false, 2.5)
		Spr.text(txt, W / 2, by + 27, fs, Color(.16, .1, .05, ca), HORIZONTAL_ALIGNMENT_CENTER, Spr.font_i)
	if t > .8 and leaving < 0:
		Spr.text("toque para continuar ▸", W - 20, H - 16, 14, Color(1, .9, .7, .55 + .3 * sin(t * 4)), HORIZONTAL_ALIGNMENT_RIGHT, Spr.font_b)
	Spr.alpha = 1.0
