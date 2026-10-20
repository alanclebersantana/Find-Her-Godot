extends Node
## Cena principal: monta o mundo, as camadas, o HUD, os controles de toque e as telas
## (início, abertura da fase, mochila, pista, placar, fim de jogo, pausa).

enum S { TITLE, INTRO, PLAY, BAG, CLUE, RESULTS, OVER, PAUSE }
var state := S.TITLE
var game: Game
var hud: Control
var glow_layer: CanvasLayer
var screen_layer: CanvasLayer
var hud_layer: CanvasLayer
var ui_layer: CanvasLayer
var modulate_node: CanvasModulate
var player_light: PointLight2D
var lights: Array = []
var touch: Array = []
var stick: Control
var top_buttons: HBoxContainer
var snd_btn: Button
var panel: Control = null
var bag_sel := ""
var theme_ui: Theme
var light_tex: Texture2D
const KEYMAP := {
	KEY_LEFT: "L", KEY_A: "L", KEY_RIGHT: "R", KEY_D: "R", KEY_UP: "U", KEY_W: "U", KEY_DOWN: "S", KEY_S: "S",
	KEY_SPACE: "J", KEY_Z: "J", KEY_K: "J", KEY_C: "P", KEY_F: "A", KEY_E: "A", KEY_X: "A", KEY_V: "A", KEY_R: "B",
}
const GOLD := Color("#e8d39a")
const INK := Color("#f0e4c8")

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0b0906"))
	Engine.physics_ticks_per_second = int(Save.getv("opt", "tps", 60))
	_make_theme()
	_make_light_tex()
	game = Game.new()
	game.name = "Game"
	add_child(game)
	game.clue_opened.connect(_on_clue)
	game.results_ready.connect(_on_results)
	game.game_over.connect(_on_over)
	game.level_won.connect(_on_results)
	glow_layer = CanvasLayer.new()
	glow_layer.layer = 1
	glow_layer.follow_viewport_enabled = true
	add_child(glow_layer)
	screen_layer = CanvasLayer.new()
	screen_layer.layer = 2
	add_child(screen_layer)
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 3
	add_child(hud_layer)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 4
	add_child(ui_layer)
	var fxn := preload("res://scripts/screen_fx.gd").new()
	fxn.game = game
	screen_layer.add_child(fxn)
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.game = game
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)
	_make_top_buttons()
	_make_touch()
	_show_hud(false)
	get_viewport().size_changed.connect(_layout)
	_layout()
	show_title()

# ======================================================================
#  MUNDO
# ======================================================================
func _build_world() -> void:
	for c in game.get_children():
		if c is Camera2D:
			continue
		c.queue_free()
	for c in glow_layer.get_children():
		c.queue_free()
	lights.clear()
	var bg := preload("res://scripts/bg.gd").new()
	bg.game = game
	bg.z_index = -10
	game.add_child(bg)
	var span: int = game.L.spanX
	var x := 0
	while x < span:
		var ch := preload("res://scripts/world_static.gd").new()
		ch.game = game
		ch.x0 = x
		ch.x1 = min(x + 1024, span)
		game.add_child(ch)
		x += 1024
	var dyn := preload("res://scripts/world_dyn.gd").new()
	dyn.game = game
	game.add_child(dyn)
	var gl := preload("res://scripts/world_glow.gd").new()
	gl.game = game
	glow_layer.add_child(gl)
	modulate_node = CanvasModulate.new()
	game.add_child(modulate_node)
	player_light = _light(Color(1, .86, .62), 210)
	for c in game.CHK:
		lights.append({"n": _light(Color(1, .7, .35), 140), "chk": c})
	for s in game.SPR:
		lights.append({"n": _light(Color(.45, .75, 1), 110), "pos": Vector2(s.x, s.y - 30)})
	lights.append({"n": _light(Color(1, .8, .5), 150), "pos": Vector2(game.DOOR.x + 30, game.DOOR.y + 20), "door": true})
	lights.append({"n": _light(Color(1, .85, .55), 100), "vil": true})

func _make_light_tex() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(.55, Color(1, 1, 1, .55))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(.5, .5)
	t.fill_to = Vector2(1, .5)
	t.width = 256
	t.height = 256
	light_tex = t

func _light(c: Color, r: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.color = c
	l.texture_scale = r * 2 / 256.0
	l.energy = 0
	game.add_child(l)
	return l

func _update_lights() -> void:
	var a: float = game.AMB.dark
	var dark: float = clamp(a, 0, 1)
	modulate_node.color = Color(1, 1, 1).lerp(Color(.035, .05, .1), dark * .97)
	var p: Dictionary = game.player
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2)
	var out: bool = game.L.has("lanternOutX") and not game.lantern_lit and pc.x > game.L.lanternOutX
	player_light.position = pc + Vector2(p.face * 6, -4)
	player_light.texture_scale = (110.0 if out else 230.0) * 2 / 256.0
	player_light.energy = dark * (1.15 + sin(game.T * .21) * .04)
	for l in lights:
		var n: PointLight2D = l.n
		if l.has("chk"):
			n.position = Vector2(l.chk.x, l.chk.y - 20)
			n.energy = dark * (1.1 + sin(game.T * .3 + l.chk.x) * .12) if l.chk.on else 0.0
		elif l.has("vil"):
			var v = game.VIL
			n.energy = dark * 1.2 if (v and v.go and not v.gone) else 0.0
			if v:
				n.position = Vector2(v.x - 41, v.y - 97)
		else:
			n.position = l.pos
			n.energy = dark * 1.1

func _process(_d: float) -> void:
	if game.L and game.running:
		var vs := get_viewport().get_visible_rect().size
		game.W = vs.x
		game.H = vs.y
		var sh := Vector2((randf() - .5) * game.shake, (randf() - .5) * game.shake)
		game.update_render_cam()
		if stick.mode == "analog" and stick.finger != -1:
			game.axis_x = stick.axis
		game.camera.position = Vector2(round(game.rcam), round(game.rcam_y)) + sh
		_update_lights()
		var under: bool = game.L.has("under") and game.player.y > game.L.under
		Audio.set_rain(game.AMB.rain * (.35 if under else 1.0) if state == S.PLAY else 0.0)
		var song: String = game.AMB.song
		var px: float = game.player.x
		if px > 8700 and px < 9420 and game.player.y < 760:
			song = "tunel"
		if state == S.PLAY:
			Audio.set_song(song)

func _physics_process(_d: float) -> void:
	if state == S.PLAY:
		game.step()

# ======================================================================
#  ENTRADA (teclado, controle e toque)
# ======================================================================
func _set_key(k: String, down: bool) -> void:
	if down and not game.keys.get(k, false):
		game.keys[k + "p"] = true
	game.keys[k] = down

func _clear_keys() -> void:
	game.keys.clear()

func _input(e: InputEvent) -> void:
	if e is InputEventKey and not e.echo:
		if e.pressed and (e.keycode == KEY_ESCAPE or e.keycode == KEY_P):
			_toggle_pause()
			return
		if e.pressed and e.keycode in [KEY_M, KEY_I, KEY_TAB]:
			if state == S.PLAY:
				open_bag()
			elif state == S.BAG:
				close_panel()
			return
		if e.pressed and e.keycode in [KEY_ENTER, KEY_KP_ENTER] and panel and panel.has_meta("ok"):
			panel.get_meta("ok").call()
			return
		if KEYMAP.has(e.keycode):
			game.axis_x = 1.0
			_set_key(KEYMAP[e.keycode], e.pressed)
	elif e is InputEventJoypadButton:
		var m := {JOY_BUTTON_A: "J", JOY_BUTTON_X: "A", JOY_BUTTON_B: "P", JOY_BUTTON_DPAD_LEFT: "L", JOY_BUTTON_DPAD_RIGHT: "R", JOY_BUTTON_DPAD_UP: "U", JOY_BUTTON_DPAD_DOWN: "S", JOY_BUTTON_BACK: "B"}
		if e.button_index == JOY_BUTTON_Y and e.pressed:
			if state == S.PLAY:
				open_bag()
			elif state == S.BAG:
				close_panel()
		elif e.button_index == JOY_BUTTON_START and e.pressed:
			_toggle_pause()
		elif m.has(e.button_index):
			_set_key(m[e.button_index], e.pressed)
	elif e is InputEventJoypadMotion:
		if e.axis == JOY_AXIS_LEFT_X:
			_set_key("L", e.axis_value < -.3)
			_set_key("R", e.axis_value > .3)
			game.axis_x = clamp(abs(e.axis_value) * 1.25, .4, 1.0)
		elif e.axis == JOY_AXIS_LEFT_Y:
			_set_key("U", e.axis_value < -.55)
			_set_key("S", e.axis_value > .55)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == S.PLAY:
			_toggle_pause()
		elif state in [S.BAG, S.CLUE, S.PAUSE]:
			close_panel()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_clear_keys()
		if state == S.PLAY:
			_toggle_pause()

# ---------- botões de toque ----------
func _make_touch() -> void:
	stick = preload("res://scripts/ui/touch_stick.gd").new()
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick.mode = Save.getv("opt", "stick", "dpad")
	stick.changed.connect(_on_stick)
	hud_layer.add_child(stick)
	var defs = [["J", "btn_jump", 112], ["A", "btn_use", 90]]
	for d in defs:
		var b := TouchScreenButton.new()
		var t: Texture2D = load("res://assets/ui/%s.png" % d[1])
		b.texture_normal = t
		var sc: float = d[2] / float(t.get_width())
		b.scale = Vector2(sc, sc)
		var sh := CircleShape2D.new()
		sh.radius = t.get_width() * .62
		b.shape = sh
		b.shape_centered = true
		b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
		b.modulate = Color(1, 1, 1, .85)
		var k: String = d[0]
		b.pressed.connect(func(): _set_key(k, true))
		b.released.connect(func(): _set_key(k, false))
		b.set_meta("k", k)
		b.set_meta("size", d[2])
		hud_layer.add_child(b)
		touch.append(b)

func _on_stick(st: Dictionary) -> void:
	for k in st:
		_set_key(k, st[k])
	game.axis_x = stick.axis if stick.mode == "analog" else 1.0

func _stick_label() -> String:
	return "Controle: " + ("analógico" if Save.getv("opt", "stick", "dpad") == "analog" else "direcional (8 direções)")

func _toggle_stick() -> void:
	var m := "dpad" if Save.getv("opt", "stick", "dpad") == "analog" else "analog"
	Save.setv("opt", "stick", m)
	stick.set_mode(m)

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	for b in touch:
		var k: String = b.get_meta("k")
		var s: float = b.get_meta("size")
		var pos := Vector2.ZERO
		match k:
			"J": pos = Vector2(vs.x - 18 - s, vs.y - 34 - s)
			"A": pos = Vector2(vs.x - 18 - 108 - 22 - s, vs.y - 52 - s)
		b.position = pos

func _make_top_buttons() -> void:
	top_buttons = HBoxContainer.new()
	top_buttons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_buttons.position = Vector2(-262, 90)
	top_buttons.add_theme_constant_override("separation", 8)
	hud_layer.add_child(top_buttons)
	var bag := TextureButton.new()
	bag.texture_normal = load("res://assets/ui/btn_bag.png")
	bag.ignore_texture_size = true
	bag.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bag.custom_minimum_size = Vector2(56, 56)
	bag.pressed.connect(open_bag)
	top_buttons.add_child(bag)
	snd_btn = _small_btn("🔊" if Audio.on else "🔇", func():
		Audio.set_on(not Audio.on)
		snd_btn.text = "🔊" if Audio.on else "🔇")
	top_buttons.add_child(snd_btn)
	var rb := TextureButton.new()
	rb.texture_normal = load("res://assets/ui/pad_B.png")
	rb.ignore_texture_size = true
	rb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	rb.custom_minimum_size = Vector2(52, 52)
	rb.tooltip_text = "Voltar à última fogueira"
	rb.pressed.connect(func(): game.keys["Bp"] = true)
	top_buttons.add_child(rb)
	var pb := _small_btn("II", _toggle_pause)
	top_buttons.add_child(pb)

func _small_btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _show_hud(v: bool) -> void:
	hud.visible = v
	top_buttons.visible = v
	for b in touch:
		b.visible = v
	stick.visible = v
	if not v:
		stick._release()

# ======================================================================
#  TELAS
# ======================================================================
func _make_theme() -> void:
	theme_ui = Theme.new()
	theme_ui.default_font = Spr.font
	theme_ui.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(.08, .06, .04, .85)
	sb.border_color = Color(.61, .51, .32, .8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var sbh := sb.duplicate()
	sbh.bg_color = Color(.2, .15, .08, .95)
	sbh.border_color = GOLD
	var sbp := sbh.duplicate()
	sbp.bg_color = Color(.3, .22, .1, 1)
	for st in ["normal", "focus"]:
		theme_ui.set_stylebox(st, "Button", sb)
	theme_ui.set_stylebox("hover", "Button", sbh)
	theme_ui.set_stylebox("pressed", "Button", sbp)
	theme_ui.set_color("font_color", "Button", GOLD)
	theme_ui.set_color("font_hover_color", "Button", Color("#fff1c8"))
	theme_ui.set_color("font_color", "Label", INK)
	theme_ui.set_font("font", "Button", Spr.font_b)
	theme_ui.set_font_size("font_size", "Button", 18)
	hud_layer_theme_later()

func hud_layer_theme_later() -> void:
	call_deferred("_apply_hud_theme")

func _apply_hud_theme() -> void:
	if top_buttons:
		top_buttons.theme = theme_ui

func close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null
	if state in [S.BAG, S.CLUE, S.PAUSE]:
		state = S.PLAY
		_show_hud(true)
	_clear_keys()

func _overlay(dim: float = .78) -> VBoxContainer:
	if panel:
		panel.queue_free()
	var root := Control.new()
	root.theme = theme_ui
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cc.custom_minimum_size = get_viewport().get_visible_rect().size
	sc.add_child(cc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	cc.add_child(vb)
	ui_layer.add_child(root)
	panel = root
	return vb

func _label(t: String, size: int = 18, c: Color = INK, f: Font = null, maxw: float = 0) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if f:
		l.add_theme_font_override("font", f)
	if maxw > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(maxw, 0)
	return l

func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(220, 46)
	b.pressed.connect(cb)
	return b

func _atlas_icon(n: String, h: float) -> TextureRect:
	var r = Spr.AR.get(n)
	var tr := TextureRect.new()
	if r == null:
		return tr
	var at := AtlasTexture.new()
	at.atlas = Spr.atlas_tex(r)
	at.region = Rect2(r[0], r[1], r[2], r[3])
	tr.texture = at
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(h * r[2] / r[3], h)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return tr

# ---------- início ----------
func show_title() -> void:
	state = S.TITLE
	game.running = false
	_show_hud(false)
	Audio.set_song("manha")
	var vb := _overlay(.35)
	var img := TextureRect.new()
	img.texture = load("res://assets/ui/cena1.jpg")
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.modulate = Color(.55, .5, .45)
	panel.add_child(img)
	panel.move_child(img, 0)
	vb.add_child(_label("FIND HER", 68, Color("#f2d28a"), Spr.font_title))
	vb.add_child(_label("Levaram a Lia. Siga a trilha dos lápis de cor.", 18, Color("#e8dcc0"), Spr.font_i))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	vb.add_child(sp)
	var run := Save.load_run()
	if not run.is_empty():
		vb.add_child(_button("CONTINUAR", func(): start_level(true)))
	vb.add_child(_button("NOVO JOGO" if not run.is_empty() else "COMEÇAR", func(): start_level(false)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vb.add_child(_label("Velocidade", 14, Color("#cdbfa6")))
	var cur := int(Save.getv("opt", "tps", 60))
	for o in [["CALMA", 44], ["MÉDIA", 52], ["RÁPIDA", 60]]:
		var b := Button.new()
		b.text = o[0]
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = cur == o[1]
		var v: int = o[1]
		b.pressed.connect(func():
			Save.setv("opt", "tps", v)
			Engine.physics_ticks_per_second = v
			show_title())
		row.add_child(b)
	vb.add_child(row)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 8)
	var sb := Button.new()
	sb.text = "Som: " + ("ligado" if Audio.on else "desligado")
	sb.focus_mode = Control.FOCUS_NONE
	sb.pressed.connect(func():
		Audio.set_on(not Audio.on)
		sb.text = "Som: " + ("ligado" if Audio.on else "desligado"))
	row2.add_child(sb)
	var vbt := Button.new()
	vbt.text = "Vibração: " + ("sim" if Save.getv("opt", "vibrate", true) else "não")
	vbt.focus_mode = Control.FOCUS_NONE
	vbt.pressed.connect(func():
		Save.setv("opt", "vibrate", not Save.getv("opt", "vibrate", true))
		vbt.text = "Vibração: " + ("sim" if Save.getv("opt", "vibrate", true) else "não"))
	row2.add_child(vbt)
	vb.add_child(row2)
	var stb := Button.new()
	stb.text = _stick_label()
	stb.focus_mode = Control.FOCUS_NONE
	stb.pressed.connect(func():
		_toggle_stick()
		stb.text = _stick_label())
	vb.add_child(stb)
	vb.add_child(_label("Teclado: ← → andar · ↑ ↓ subir/abaixar · Espaço pular · F usar · M mochila", 12, Color(.8, .75, .65, .8)))
	panel.set_meta("ok", func(): start_level(not run.is_empty()))

func start_level(cont: bool) -> void:
	game.CLUEGOT.clear()
	game.SPECGOT.clear()
	game.DRAWN.clear()
	game.lives = 3
	game.coin_life = 0
	var run := Save.load_run()
	if cont and not run.is_empty():
		game.restore_run(run)
	else:
		Save.clear_run()
		game.load_level(0)
	_build_world()
	game.running = false
	show_intro(cont)

func show_intro(cont: bool) -> void:
	state = S.INTRO
	_show_hud(false)
	var vb := _overlay(.88)
	vb.add_child(_label("LUGAR 1 DE 7", 14, Color("#cdbfa6")))
	var img := TextureRect.new()
	img.texture = load("res://assets/ui/cena1.jpg")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(520, 190)
	img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(img)
	vb.add_child(_label(game.L.name.to_upper(), 30, GOLD, Spr.font_title))
	vb.add_child(_label(game.L.intro, 16, Color("#e8dcc0"), Spr.font_i, 640))
	var go := func():
		close_panel()
		state = S.PLAY
		game.running = true
		_show_hud(true)
		if cont:
			game.flash("Você continua da última fogueira.")
	vb.add_child(_button("ENTRAR", go))
	panel.set_meta("ok", go)

func _toggle_pause() -> void:
	if state == S.PLAY:
		state = S.PAUSE
		_clear_keys()
		_show_hud(false)
		var vb := _overlay(.7)
		vb.add_child(_label("PAUSA", 34, GOLD, Spr.font_title))
		vb.add_child(_button("CONTINUAR", close_panel))
		var stb2 := _button(_stick_label(), func(): pass)
		stb2.custom_minimum_size = Vector2(320, 46)
		stb2.pressed.connect(func():
			_toggle_stick()
			stb2.text = _stick_label())
		vb.add_child(stb2)
		vb.add_child(_button("MENU INICIAL", func():
			panel.queue_free()
			panel = null
			show_title()))
		panel.set_meta("ok", close_panel)
	elif state == S.PAUSE:
		close_panel()

# ---------- mochila ----------
func open_bag() -> void:
	if state != S.PLAY:
		return
	state = S.BAG
	_clear_keys()
	_show_hud(false)
	bag_sel = ""
	_render_bag("")

func _render_bag(msg: String) -> void:
	var vb := _overlay(.82)
	vb.add_child(_label("MOCHILA", 32, GOLD, Spr.font_title))
	var items := HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 10)
	vb.add_child(items)
	if game.INV.is_empty():
		items.add_child(_label("A mochila está vazia. Procure objetos pelo caminho.", 16, Color("#d8ccb0"), Spr.font_i))
	for id in game.INV:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = bag_sel == id
		b.custom_minimum_size = Vector2(118, 104)
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := _atlas_icon("it_" + id, 54)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(ic)
		var nl := _label(GameData.ITEM_INFO[id][0], 13, INK)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(nl)
		b.add_child(inner)
		var iid: String = id
		b.pressed.connect(func(): _bag_tap(iid))
		items.add_child(b)
	var m := msg
	if m == "":
		if game.INV.size() > 1:
			m = "Toque num objeto e depois em outro para combinar."
		elif game.INV.size() == 1:
			m = game.item_msg(game.INV[0])
	vb.add_child(_label(m, 16, Color("#e8d8b0"), Spr.font_i, 680))
	vb.add_child(_label("LÁPIS ESPECIAIS", 13, Color("#b8a888")))
	var pens := HBoxContainer.new()
	pens.alignment = BoxContainer.ALIGNMENT_CENTER
	for c in GameData.PEN_LIST:
		var ic2 := _atlas_icon("pen_" + c, 40)
		ic2.modulate = Color(1, 1, 1, 1 if game.SPECGOT.has(c) else .2)
		pens.add_child(ic2)
	vb.add_child(pens)
	vb.add_child(_label("CADERNO DE PISTAS", 13, Color("#b8a888")))
	var clues := HBoxContainer.new()
	clues.alignment = BoxContainer.ALIGNMENT_CENTER
	clues.add_theme_constant_override("separation", 6)
	for i in range(1, 7):
		var b2 := Button.new()
		b2.focus_mode = Control.FOCUS_NONE
		b2.custom_minimum_size = Vector2(98, 76)
		var inner2 := VBoxContainer.new()
		inner2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner2.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner2.alignment = BoxContainer.ALIGNMENT_CENTER
		if game.CLUEGOT.has(i):
			var ic3 := _atlas_icon("cl_%d" % i, 36)
			ic3.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner2.add_child(ic3)
			var cl := _label(GameData.CLUE_INFO[i][0], 11, INK, null, 92)
			cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner2.add_child(cl)
			var ii := i
			b2.pressed.connect(func():
				state = S.PLAY
				_on_clue(ii, true))
		else:
			var q := _label("?", 28, Color(.6, .55, .45))
			q.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner2.add_child(q)
			var ql := _label("Pista %d" % i, 11, Color(.6, .55, .45))
			ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner2.add_child(ql)
			b2.disabled = true
		b2.add_child(inner2)
		clues.add_child(b2)
	vb.add_child(clues)
	vb.add_child(_button("FECHAR", close_panel))
	panel.set_meta("ok", close_panel)

func _bag_tap(id: String) -> void:
	if bag_sel != "" and bag_sel != id:
		var r := game.try_combine(bag_sel, id)
		bag_sel = ""
		_render_bag(r if r != "" else "Esses dois não combinam.")
	else:
		bag_sel = "" if bag_sel == id else id
		_render_bag(game.item_msg(bag_sel) if bag_sel != "" else "")

# ---------- pista ----------
func _on_clue(id: int, from_bag: bool = false) -> void:
	state = S.CLUE
	_clear_keys()
	_show_hud(false)
	var vb := _overlay(.84)
	vb.add_child(_label("PISTA %d DE 6" % game.CLUEGOT.size() if not from_bag else "CADERNO DE PISTAS", 14, Color("#cdbfa6")))
	if id == 6:
		vb.add_child(_Badge.new())
	else:
		vb.add_child(_atlas_icon("clb_%d" % id, 170))
	vb.add_child(_label(GameData.CLUE_INFO[id][0], 30, GOLD, Spr.font_title))
	vb.add_child(_label(GameData.CLUE_INFO[id][1], 17, Color("#e8dcc0"), Spr.font_i, 640))
	var ok := func():
		close_panel()
		if from_bag:
			open_bag()
	vb.add_child(_button("CONTINUAR", ok))
	panel.set_meta("ok", ok)

class _Badge extends Control:
	## O crachá do gerente, com o rosto e o nome
	func _init() -> void:
		custom_minimum_size = Vector2(130, 200)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		Spr.begin(self)
		var r = Spr.AR.clb_6
		var h := 200.0
		var w: float = h * r[2] / r[3]
		var x := (size.x - w) / 2
		Spr.AB("clb_6", x, 0, w, h)
		var f = Spr.AR.vg_face
		var fw := w * .6
		var fh: float = fw * f[3] / f[2]
		Spr.ci.draw_texture_rect_region(Spr.atlas_tex(f), Rect2(x + w / 2 - fw / 2, h * .31, fw, min(fh, h * .42)), Rect2(f[0], f[1], f[2], min(f[3], f[3] * (h * .42) / fh)))
		Spr.rect(x + w * .17, h * .73, w * .66, h * .12, Color("#1f2a3a"))
		Spr.text("ADEMAR VARGAS", x + w / 2, h * .785, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, Spr.font_b)
		Spr.text("GERENTE · MINA", x + w / 2, h * .83, 7, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

# ---------- placar ----------
func _on_results() -> void:
	state = S.RESULTS
	_show_hud(false)
	Audio.play("door")
	var nc := game.CLUEGOT.size()
	var ns := game.SPECGOT.size()
	var pen: int = game.STATS.pen
	var pt: int = game.STATS.penTotal
	var secs := int(round((int(game.L.time) * 60 - game.time_left) / 60.0))
	var dr := 0
	for d in game.DRWS:
		if d.got:
			dr += 1
	var stars := 1
	if pen >= pt * .7 and nc >= 4:
		stars = 2
	if pen >= pt * .9 and nc == 6 and ns == 6:
		stars = 3
	Save.set_best(0, {"stars": stars, "pen": pen, "clues": nc, "specs": ns})
	Save.clear_run()
	var vb := _overlay(.86)
	vb.add_child(_label("FIM DO BOSQUE", 14, Color("#cdbfa6")))
	vb.add_child(_label("★".repeat(stars) + "☆".repeat(3 - stars), 40, Color("#ffd76a")))
	var fd := _FinalDrawing.new()
	fd.specs = game.SPECGOT.duplicate()
	vb.add_child(fd)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for t in ["⏱ Tempo  %d:%02d" % [secs / 60, secs % 60], "✏ Lápis  %d/%d" % [pen, pt], "Lápis especiais  %d/6" % ns, "Desenhos  %d/%d" % [dr, game.DRWS.size()], "Pistas  %d/6" % nc]:
		grid.add_child(_label(t, 15, INK))
	vb.add_child(grid)
	var story := "Agora eu sei: foi Ademar Vargas, o gerente que roubava a mina. Ele levou a Lia para se vingar. Vou atrás dele — mina adentro." if nc == 6 else "Ele fugiu para a mina. Ainda faltam pistas para ter certeza de quem é... (%d/6)" % nc
	vb.add_child(_label(story, 16, Color("#e8dcc0"), Spr.font_i, 640))
	vb.add_child(_label("As próximas fases chegam em breve.", 13, Color(.75, .7, .6)))
	vb.add_child(_button("CONTINUAR", func():
		panel.queue_free()
		panel = null
		show_title()))

class _FinalDrawing extends Control:
	## O desenho da Lia, colorido com os lápis especiais encontrados
	var specs := {}
	func _init() -> void:
		custom_minimum_size = Vector2(300, 170)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	func colr(c: String) -> Color:
		return GameData.PEN_COL[c] if specs.has(c) else Color("#f6efdc")
	func _draw() -> void:
		var w := 300.0
		var h := 170.0
		var ink := Color("#3a2a1a")
		draw_rect(Rect2(-3, -3, w + 6, h + 6), Color("#6b4a2a"))
		draw_rect(Rect2(0, 0, w, h * .6), colr("azul"))
		draw_rect(Rect2(0, h * .6, w, h * .4), colr("verde"))
		draw_line(Vector2(0, h * .6), Vector2(w, h * .6), ink, 3)
		draw_circle(Vector2(w * .82, h * .2), 22, colr("amarelo"))
		draw_arc(Vector2(w * .82, h * .2), 22, 0, TAU, 32, ink, 3)
		draw_rect(Rect2(w * .1, h * .38, 70, 52), colr("laranja"))
		draw_rect(Rect2(w * .1, h * .38, 70, 52), ink, false, 3)
		var roof := PackedVector2Array([Vector2(w * .1 - 8, h * .38), Vector2(w * .1 + 35, h * .24), Vector2(w * .1 + 78, h * .38)])
		draw_colored_polygon(roof, colr("vermelho"))
		draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[0]]), ink, 3)
		for f in [[w * .55, 1.3, "roxo"], [w * .66, .95, "vermelho"]]:
			var x: float = f[0]
			var s: float = f[1]
			draw_circle(Vector2(x, h * .55 - 30 * s), 10 * s, colr(f[2]))
			draw_arc(Vector2(x, h * .55 - 30 * s), 10 * s, 0, TAU, 24, ink, 3)
			var b := PackedVector2Array([Vector2(x, h * .55 - 20 * s), Vector2(x - 14 * s, h * .55 + 18 * s), Vector2(x + 14 * s, h * .55 + 18 * s)])
			draw_colored_polygon(b, colr(f[2]))
			draw_polyline(PackedVector2Array([b[0], b[1], b[2], b[0]]), ink, 3)
		draw_line(Vector2(w * .55 + 8, h * .55 - 10), Vector2(w * .66 - 8, h * .55 - 6), ink, 3)
		var txt := "\"Papai e eu\" — Lia" if specs.size() == 6 else "Faltam cores: %d" % (6 - specs.size())
		draw_string(Spr.font_i, Vector2(10, h - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)

# ---------- fim de jogo ----------
func _on_over() -> void:
	state = S.OVER
	_show_hud(false)
	Audio.stop_music()
	var vb := _overlay(.88)
	vb.add_child(_label("A LANTERNA SE APAGOU", 34, GOLD, Spr.font_title))
	vb.add_child(_label("As vidas acabaram. Mas um pai não desiste.", 17, Color("#e8dcc0"), Spr.font_i))
	var run := Save.load_run()
	if not run.is_empty():
		vb.add_child(_button("VOLTAR À FOGUEIRA", func():
			start_level(true)))
	vb.add_child(_button("RECOMEÇAR A FASE", func(): start_level(false)))
	vb.add_child(_button("MENU INICIAL", func():
		panel.queue_free()
		panel = null
		show_title()))
