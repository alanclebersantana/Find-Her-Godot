extends CanvasLayer
class_name Hud
## Tela: corações, barra de agarre (anel perto do Tomé), mira do gancho, joystick, os 4 botões,
## contadores, mensagens e a tela de abertura "ALL THE ABOVE · O Planeta dos Colossos".

var main
var view: Control
var f_title: Font
var f_bold: Font
var f_reg: Font
var msg_text := ""
var msg_t := 0.0
var red := 0.0
var title_a := 1.0

func _ready() -> void:
	layer = 10
	f_title = load("res://assets/fonts/Cinzel-Bold.woff2")
	f_bold = load("res://assets/fonts/Lora-Bold.woff2")
	f_reg = load("res://assets/fonts/Lora-Regular.woff2")
	view = Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	add_child(view)

func msg(t: String, secs: float = 3.0) -> void:
	msg_text = t
	msg_t = secs

func hurt_flash() -> void:
	red = .5

func _process(dt: float) -> void:
	msg_t = max(0.0, msg_t - dt)
	red = max(0.0, red - dt)
	if main and main.state == "play":
		title_a = max(0.0, title_a - dt * 1.5)
	view.queue_redraw()

func _txt(s: String, pos: Vector2, size: int, col: Color, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, outline := 5) -> void:
	var f := font if font else f_bold
	if outline > 0:
		view.draw_string_outline(f, pos, s, align, w, size, outline, Color(0.05, .04, .03, col.a * .85))
	view.draw_string(f, pos, s, align, w, size, col)

func _heart(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 30:
		var t := TAU * i / 30.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y) * r / 16.0)
	view.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	view.draw_polyline(pts, Color(.1, .05, .03, .9), 2.0, true)

func _draw_view() -> void:
	if main == null:
		return
	var s := view.size
	if main.state == "title" or title_a > 0.0:
		_draw_title(s)
		if main.state == "title":
			return
	var p: Player = main.player
	var inp: InputState = main.inp
	var cam: Camera3D = main.cam.cam
	# corações
	for i in p.max_hp:
		_heart(Vector2(36 + i * 34, 38), 14.0, Color("#e0463a") if i < p.hp else Color(.25, .2, .2, .7))
	# contadores
	var col: Colossus = main.colossus
	_txt("Peças deste colosso: %d/3" % (3 - col.pieces_left()), Vector2(0, 40), 20, Color("#ffe2a8"), f_bold, HORIZONTAL_ALIGNMENT_RIGHT, s.x - 24)
	_txt("Colossos adormecidos: %d/16" % main.asleep, Vector2(0, 68), 16, Color("#d8efe8"), f_reg, HORIZONTAL_ALIGNMENT_RIGHT, s.x - 24)
	# mira do gancho
	if p.aim and is_instance_valid(p.aim) and not cam.is_position_behind(p.aim.global_position):
		var sp := cam.unproject_position(p.aim.global_position)
		var kind: String = p.aim.get_meta("kind")
		var ac := Color(1, .85, .45) if kind == "tree" else (Color(1, .55, .3) if kind == "colossus" else Color(.6, 1, .9))
		var rr := 18.0 + sin(Time.get_ticks_msec() * .008) * 3.0
		view.draw_arc(sp, rr, 0, TAU, 32, ac, 3.0, true)
		for k in 4:
			var a := k * PI / 2.0 + PI / 4.0
			view.draw_line(sp + Vector2(cos(a), sin(a)) * (rr + 4), sp + Vector2(cos(a), sin(a)) * (rr + 12), ac, 3.0, true)
	# barra de agarre: anel ao lado do Tomé (aparece escalando ou quando não está cheia)
	if p.state == "climb" or p.stamina < .99:
		var pp := p.center() + Vector3(0, .6, 0)
		if not cam.is_position_behind(pp):
			var sc := cam.unproject_position(pp) + Vector2(46, -30)
			var st := clampf(p.stamina, 0.0, 1.0)
			var c := Color("#7fe08a").lerp(Color("#ff5a3a"), 1.0 - st)
			if st < .25 and int(Time.get_ticks_msec() / 120) % 2 == 0:
				c = Color(1, 1, 1)
			view.draw_circle(sc, 21, Color(0, 0, 0, .45))
			view.draw_arc(sc, 17, -PI / 2.0, -PI / 2.0 + TAU * st, 40, c, 6.0, true)
			if col.shaking() and p.state == "climb":
				_txt("SEGURE!", sc + Vector2(-34, -30), 16, Color("#ffd27a"), f_bold)
	# joystick
	var home := inp.stick_home()
	var stick_on := false
	for k in inp.touches:
		if inp.touches[k].role == "stick":
			stick_on = true
	var sc0 := inp.stick_center if stick_on else home
	view.draw_circle(sc0, inp.stick_radius, Color(1, 1, 1, .10))
	view.draw_arc(sc0, inp.stick_radius, 0, TAU, 48, Color(1, 1, 1, .35), 3.0, true)
	view.draw_circle(sc0 + inp.stick_vec * inp.stick_radius, 38, Color(1, 1, 1, .35 if stick_on else .22))
	# botões
	var br := inp.button_rects()
	for b in InputState.BUTTONS:
		var c0: Vector2 = br[b][0]
		var r: float = br[b][1]
		var on: bool = inp.held[b]
		var base: Color = {"hook": Color("#d98a3a"), "jump": Color("#4f9fd8"), "grab": Color("#6fbf5a"), "pick": Color("#c8c4bc")}[b]
		var avail := true
		if b == "hook":
			avail = p.aim != null
		view.draw_circle(c0, r, Color(base.r, base.g, base.b, (.75 if on else .42) * (1.0 if avail else .5)))
		view.draw_arc(c0, r, 0, TAU, 40, Color(1, 1, 1, .7 if on else .45), 3.0, true)
		_txt(InputState.LABEL[b], c0 + Vector2(-r, 6), int(clampf(r * .3, 13, 19)), Color(1, 1, 1, .95), f_bold, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 4)
	# mensagem
	if msg_t > 0.0 and msg_text != "":
		var a := clampf(msg_t, 0.0, 1.0)
		_txt(msg_text, Vector2(0, s.y * .22), 26, Color(1, .95, .82, a), f_bold, HORIZONTAL_ALIGNMENT_CENTER, s.x, 6)
	if red > 0.0:
		view.draw_rect(Rect2(Vector2.ZERO, s), Color(.8, 0, 0, red * .35))

func _draw_title(s: Vector2) -> void:
	var a := title_a if main.state == "play" else 1.0
	view.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, .03, .05, .25 * a))
	_txt("ALL THE ABOVE", Vector2(0, s.y * .30), int(clampf(s.x * .075, 48, 110)), Color(1, .93, .78, a), f_title, HORIZONTAL_ALIGNMENT_CENTER, s.x, 10)
	_txt("O Planeta dos Colossos", Vector2(0, s.y * .30 + clampf(s.x * .045, 30, 60)), int(clampf(s.x * .028, 22, 40)), Color(.85, .97, .93, a), f_bold, HORIZONTAL_ALIGNMENT_CENTER, s.x, 6)
	if main.state == "title":
		var blink := .55 + .45 * sin(Time.get_ticks_msec() * .004)
		_txt("Toque para começar", Vector2(0, s.y * .82), 24, Color(1, 1, 1, blink), f_bold, HORIZONTAL_ALIGNMENT_CENTER, s.x, 5)
		_txt("protótipo 1", Vector2(0, s.y * .82 + 32), 15, Color(1, 1, 1, .6), f_reg, HORIZONTAL_ALIGNMENT_CENTER, s.x, 3)
