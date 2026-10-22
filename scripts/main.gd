extends Node
## Cena principal: monta o mundo, as camadas, o HUD, os controles de toque e as telas
## (início, abertura da fase, mochila, pista, placar, fim de jogo, pausa).

enum S { TITLE, INTRO, PLAY, BAG, CLUE, RESULTS, OVER, PAUSE, CUT, REST, COMIC }
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
var dog_btn: TextureButton
var tex_dog: Texture2D = preload("res://assets/ui/btn_dog.png")
var tex_tome: Texture2D = preload("res://assets/ui/btn_tome.png")
var panel: Control = null
var bag_sel := ""
var theme_ui: Theme
var light_tex: Texture2D
var last_joy_ms := -9999
var last_touch_ms := -9999   # último toque na tela (o gesto de "voltar" da borda vem junto com toques)
const KEYMAP := {
	KEY_LEFT: "L", KEY_A: "L", KEY_RIGHT: "R", KEY_D: "R", KEY_UP: "U", KEY_W: "U", KEY_DOWN: "S", KEY_S: "S",
	KEY_SPACE: "J", KEY_Z: "J", KEY_K: "J", KEY_C: "P", KEY_F: "A", KEY_E: "A", KEY_X: "A", KEY_V: "A", KEY_R: "B",
	KEY_G: "G", KEY_J: "G", KEY_Q: "D",
}
const GOLD := Color("#e8d39a")
const INK := Color("#f0e4c8")

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0b0906"))
	# fluidez: o jogo anda a 60 passos por segundo, o mesmo ritmo da tela (a 44 a imagem tremia);
	# quem nunca mexeu na velocidade passa para 60 uma vez só
	if not Save.getv("opt", "tps60", false):
		Save.setv("opt", "tps60", true)
		Save.setv("opt", "tps", 60)
	Engine.physics_ticks_per_second = int(Save.getv("opt", "tps", 60))
	Engine.max_fps = 0
	_make_theme()
	_make_light_tex()
	game = Game.new()
	game.name = "Game"
	add_child(game)
	game.clue_opened.connect(_on_clue)
	game.results_ready.connect(_on_level_end)
	game.game_over.connect(_on_over)
	game.level_won.connect(_on_results)
	game.rest_reached.connect(_on_rest)
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
	var sky := preload("res://scripts/sky_fx.gd").new()
	sky.game = game
	screen_layer.add_child(sky)
	var front := preload("res://scripts/front.gd").new()
	front.game = game
	screen_layer.add_child(front)
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
	apply_controls()
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
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://scripts/blur.gdshader")
	bg.material = bm
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
	# sons posicionados: fogueiras estalando e água correndo
	for c in game.CHK:
		Audio.emitter(game, "loop_fogo", Vector2(c.x, c.y - 20), -4.0 if c.has("rest") else -9.0, 700.0)
	var waters: Array = []
	for w in game.X.WATER:
		waters.append([float(w.x), float(w.x + w.w), float(w.y)])
	for sw in game.SWAMP:
		waters.append([float(sw.x), float(sw.x + sw.w), float(sw.y)])
	if game.VH and not game.VH.RA.is_empty():
		waters.append([float(game.VH.RA.x0), float(game.VH.RA.x1), 480.0])
	for wv in waters:
		var wx: float = wv[0] + 200
		while wx < wv[1]:
			Audio.emitter(game, "loop_agua", Vector2(wx, wv[2]), -8.0, 800.0)
			wx += 900
	player_light = _light(Color(1, .86, .62), 210)
	for c in game.CHK:
		lights.append({"n": _light(Color(1, .7, .35), 140), "chk": c})
	for s in game.SPR:
		lights.append({"n": _light(Color(.45, .75, 1), 110), "pos": Vector2(s.x, s.y - 30)})
	lights.append({"n": _light(Color(1, .8, .5), 150), "pos": Vector2(game.DOOR.x + 30, game.DOOR.y + 20), "door": true})
	lights.append({"n": _light(Color(1, .85, .55), 100), "vil": true})
	# cone de luz quente da lanterna, para o lado em que o Tomé olha
	cone_light = PointLight2D.new()
	cone_light.texture = _cone_tex()
	cone_light.color = Color(1, .82, .5)
	cone_light.energy = 0
	cone_light.texture_scale = 1.0
	cone_light.offset = Vector2(150, 0)
	game.add_child(cone_light)
	# cogumelos gigantes iluminam em volta com a cor deles
	if game.TR:
		for o in game.TR.T:
			if o.k == "giant":
				var gc := Color(o.get("c", "#6a5acd")).lightened(.25)
				lights.append({"n": _light(gc, 170), "pos": Vector2(o.x, o.cap + 10)})
	# facho concentrado da lanterna, cristais e lápis dourado
	lights.append({"n": _light(Color(1, .9, .65), 200), "beam": true})
	for c in game.X.CRYSTALS:
		lights.append({"n": _light(Color(.6, .85, 1), 120), "crystal": c})
	if not game.X.GOLD.is_empty():
		lights.append({"n": _light(Color(1, .85, .4), 90), "gold": true})

var cone_light: PointLight2D
## textura do cone: claro perto da lanterna, abrindo e sumindo para a frente
var _cone: Texture2D
func _cone_tex() -> Texture2D:
	if _cone:
		return _cone
	var im := Image.create(300, 200, false, Image.FORMAT_RGBA8)
	for y in 200:
		for x in 300:
			var u: float = x / 300.0
			var half: float = 18.0 + u * 80.0
			var d: float = abs(y - 100.0) / half
			var a: float = clamp(1.0 - d, 0, 1) * (1.0 - u) * clamp(u * 6.0, 0, 1)
			im.set_pixel(x, y, Color(1, 1, 1, a * a))
	_cone = ImageTexture.create_from_image(im)
	return _cone

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
	var pc := Vector2(p.x + p.w / 2, p.y + p.h / 2 + p.get("wdy", 0.0))
	var out: bool = game.L.has("lanternOutX") and not game.lantern_lit and pc.x > game.L.lanternOutX
	# a lanterna balança na mão conforme ele anda (a luz acompanha)
	var sw: float = sin(game.T * .17) * clamp(abs(p.vx) / 4.0, 0, 1)
	player_light.position = pc + Vector2(p.face * 6 + sw * 7, -4 + abs(sw) * 3)
	player_light.texture_scale = (110.0 if out else 230.0) * 2 / 256.0
	player_light.energy = dark * (1.15 + sin(game.T * .21) * .04) * (.25 + .75 * p.get("wal", 1.0))
	if cone_light:
		cone_light.position = player_light.position + Vector2(p.face * 10, 0)
		cone_light.rotation = 0.0 if p.face > 0 else PI
		cone_light.energy = 0.0 if out else dark * .9 * (.25 + .75 * p.get("wal", 1.0))
	for l in lights:
		var n: PointLight2D = l.n
		if l.has("chk"):
			n.position = Vector2(l.chk.x, l.chk.y - 20)
			n.energy = dark * (1.1 + sin(game.T * .3 + l.chk.x) * .12) if l.chk.on else 0.0
		elif l.has("beam"):
			var on: bool = game.X.focus
			var o: Vector2 = game.X.lamp()
			n.position = o + Vector2(p.face * 190, 0)
			n.energy = dark * 1.25 if on else 0.0
		elif l.has("crystal"):
			n.position = Vector2(l.crystal.x, l.crystal.y)
			n.energy = dark * (1.3 if l.crystal.on else l.crystal.charge / 60.0)
		elif l.has("gold"):
			n.position = Vector2(game.X.GOLD.x, game.X.GOLD.y)
			n.energy = 0.0 if game.X.GOLD.got else dark * .9
		elif l.has("vil"):
			var v = game.VIL
			n.energy = dark * 1.2 if (v and v.go and not v.gone) else 0.0
			if v:
				n.position = Vector2(v.x - 41, v.y - 97)
		else:
			n.position = l.pos
			n.energy = dark * 1.1

func _process(_d: float) -> void:
	if dog_btn and game.X:
		dog_btn.visible = top_buttons.visible and game.X.dog_free()
		dog_btn.texture_normal = tex_tome if game.M.ctrl else tex_dog
	if game.L and game.running:
		var vs := get_viewport().get_visible_rect().size
		game.W = vs.x
		game.H = vs.y
		var amp: float = game.shake * (.55 if Save.getv("opt", "shake", true) else 0.0)
		var tt := Time.get_ticks_msec() / 1000.0
		var sh := Vector2(sin(tt * 53.0) + sin(tt * 31.0) * .5, cos(tt * 47.0) + sin(tt * 29.0) * .5) * amp * .5
		# câmera chega mais perto nas cenas calmas e abre nas de ação
		var zt: float = _zoom_target()
		cam_zoom = lerpf(cam_zoom, zt, .02)
		game.camera.zoom = Vector2(cam_zoom, cam_zoom)
		game.W = vs.x / cam_zoom
		game.H = vs.y / cam_zoom
		game.update_render_cam()
		if stick.mode == "analog" and stick.finger != -1:
			game.axis_x = stick.axis
		game.camera.position = Vector2(game.rcam, game.rcam_y) + sh
		_update_lights()
		var under: bool = game.L.has("under") and game.player.y > game.L.under
		Audio.set_rain(game.AMB.rain * (.35 if under else 1.0) if state == S.PLAY else 0.0)
		var song: String = game.AMB.song
		var px: float = game.player.x
		var tun: Array = game.L.get("tunnel", [0, 0])
		if px > tun[0] and px < tun[1] and game.player.y < 760:
			song = "tunel"
		if game.X and game.X.boss_active():
			song = "perseguicao"
		if game.K and not game.K.HAWK.is_empty() and game.K.HAWK.active and not game.K.HAWK.done:
			song = "gaviao"
		if game.K and not game.K.FISH.is_empty() and game.K.FISH.active and not game.K.FISH.done:
			song = "bagre"
		if game.K and game.K.bear_on():
			song = "urso"
		if game.VH and game.VH.mode == "raft":
			song = "jangada"
		elif game.VH and game.VH.mode == "plane":
			song = "voo"
		if game.TR:
			for o in game.TR.T:
				if o.k == "boulder" and o.st in ["drop", "roll"]:
					song = "pedra"
		if state == S.PLAY:
			Audio.set_song(song)
			Audio.set_danger(_danger_level())
		var in_cine: bool = not game.CINE.is_empty()
		if state == S.PLAY and top_buttons.visible == in_cine:
			top_buttons.visible = not in_cine
			stick.visible = not in_cine
			for b in touch:
				b.visible = not in_cine
			if in_cine:
				stick._release()

## quanto perigo há por perto (para a camada de tambores da música)
func _danger_level() -> float:
	var g := game
	if g.X and g.X.boss_active():
		return 1.0
	if g.K and (g.K.bear_on() or (not g.K.HAWK.is_empty() and g.K.HAWK.active and not g.K.HAWK.done) or (not g.K.FISH.is_empty() and g.K.FISH.active and not g.K.FISH.done)):
		return 1.0
	if g.TR:
		for o in g.TR.T:
			if o.k == "boulder" and o.st in ["drop", "roll"]:
				return 1.0
	var p: Dictionary = g.player
	var px: float = p.x + p.w / 2
	for e in g.EN:
		if not e.dead and abs(e.x - px) < 380 and abs(e.y - p.y) < 220:
			return .65
	return 0.0

var cam_zoom := 1.0
func _zoom_target() -> float:
	var g := game
	if not g.CINE.is_empty():
		return 1.0
	# ação: veículos, cavalgada, chefes, pedra rolando, perseguição
	if (g.VH and g.VH.active()) or (g.RD and g.RD.riding) or (g.X and g.X.boss_active()):
		return .88
	if g.K and (g.K.bear_on() or (not g.K.HAWK.is_empty() and g.K.HAWK.active and not g.K.HAWK.done) or (not g.K.FISH.is_empty() and g.K.FISH.active and not g.K.FISH.done)):
		return .88
	if g.VIL and g.VIL.go and not g.VIL.gone:
		return .9
	if g.TR:
		for o in g.TR.T:
			if o.k == "boulder" and o.st in ["drop", "roll"]:
				return .88
	# calma: perto de uma fogueira, parado
	var p: Dictionary = g.player
	if abs(p.vx) < .5 and p.onGround:
		for c in g.CHK:
			if abs(c.x - (p.x + p.w / 2)) < 220 and abs(c.y - (p.y + p.h)) < 80:
				return 1.1
	return 1.0

func _physics_process(_d: float) -> void:
	if state == S.PLAY and game.comic_req != "":
		_show_comic(game.comic_req)
		game.comic_req = ""
		return
	if state == S.PLAY:
		var __t := Time.get_ticks_usec()
		game.step()
		Spr.pt("step", __t)

## quadrinho (chefe ou primeira vez em algo novo): o jogo espera até ele acabar
func _show_comic(id: String) -> void:
	state = S.COMIC
	_clear_keys()
	if stick:
		stick._release()
	_show_hud(false)
	var c := preload("res://scripts/ui/comic.gd").new(id)
	c.theme = theme_ui
	ui_layer.add_child(c)
	c.finished.connect(func():
		_clear_keys()
		if state == S.COMIC:
			state = S.PLAY
			_show_hud(true))

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
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		last_touch_ms = Time.get_ticks_msec()
	if state == S.PLAY and not game.CINE.is_empty() and ((e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed)):
		# toque avança a fala; no canto de baixo à direita ("PULAR ▸") pula a cena inteira
		var vs := get_viewport().get_visible_rect().size
		var pos: Vector2 = e.position
		if pos.x > vs.x - 170 and pos.y > vs.y - 70:
			game.keys["Kp"] = true
		else:
			game.keys["Jp"] = true
		return
	if e is InputEventKey and not e.echo:
		if e.pressed and (e.keycode == KEY_ESCAPE or e.keycode == KEY_P):
			_toggle_pause("tecla Esc/P")
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
		last_joy_ms = Time.get_ticks_msec()
		var m := {JOY_BUTTON_A: "J", JOY_BUTTON_X: "A", JOY_BUTTON_B: "P", JOY_BUTTON_DPAD_LEFT: "L", JOY_BUTTON_DPAD_RIGHT: "R", JOY_BUTTON_DPAD_UP: "U", JOY_BUTTON_DPAD_DOWN: "S", JOY_BUTTON_BACK: "B", JOY_BUTTON_RIGHT_SHOULDER: "G", JOY_BUTTON_LEFT_SHOULDER: "D"}
		if e.button_index == JOY_BUTTON_Y and e.pressed:
			if state == S.PLAY:
				open_bag()
			elif state == S.BAG:
				close_panel()
		elif e.button_index == JOY_BUTTON_START and e.pressed:
			_toggle_pause("botão Start do controle")
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
		# alguns controles Bluetooth mandam "voltar" junto com o botão B: ignora nesse caso
		if Time.get_ticks_msec() - last_joy_ms < 500:
			return
		# gesto de "voltar" pela borda da tela enquanto o polegar está no direcional: não pausa
		if state == S.PLAY and (Time.get_ticks_msec() - last_touch_ms < 900 or (stick and stick.finger != -1)):
			return
		if state == S.PLAY:
			_toggle_pause("gesto/botão Voltar do celular")
		elif state in [S.BAG, S.CLUE, S.PAUSE]:
			close_panel()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# perder o foco por um instante (gesto de 3 dedos, barra do sistema): só solta os botões
		_clear_keys()
		if stick:
			stick._release()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_clear_keys()
		if stick:
			stick._release()
		if state == S.PLAY:
			_toggle_pause("o jogo saiu da tela (gesto de início/apps do celular)")
			auto_paused_ms = Time.get_ticks_msec()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		# saiu e voltou rapidinho (gesto sem querer na borda): continua sem abrir a pausa
		if state == S.PAUSE and auto_paused_ms >= 0 and Time.get_ticks_msec() - auto_paused_ms < 3000:
			close_panel()
		auto_paused_ms = -1

# ---------- botões de toque ----------
func _make_touch() -> void:
	stick = preload("res://scripts/ui/touch_stick.gd").new()
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick.mode = Save.getv("opt", "stick", "dpad")
	stick.changed.connect(_on_stick)
	hud_layer.add_child(stick)
	var defs = [["J", "btn_jump", 112], ["A", "btn_use", 90], ["G", "btn_golpe", 86]]
	for d in defs:
		var b := TouchScreenButton.new()
		var t: Texture2D = load("res://assets/ui/%s.png" % d[1])
		b.texture_normal = t
		var sc: float = d[2] / float(t.get_width())
		b.scale = Vector2(sc, sc)
		var sh := CircleShape2D.new()
		sh.radius = t.get_width() * .70   # área de toque um pouco maior que o desenho
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

func apply_controls() -> void:
	var sz: float = {"P": .85, "M": 1.0, "G": 1.2}[Save.getv("opt", "btn_size", "M")]
	var op: float = {"clara": .45, "media": .75, "forte": .95}[Save.getv("opt", "btn_alpha", "media")]
	stick.ui_scale = sz
	stick.opacity = op
	stick.left_handed = Save.getv("opt", "left", false)
	stick.mode = Save.getv("opt", "stick", "dpad")
	stick._release()
	for b in touch:
		var base: float = b.get_meta("size") * sz
		var t: Texture2D = b.texture_normal
		b.scale = Vector2.ONE * base / float(t.get_width())
		b.modulate = Color(1, 1, 1, op)
	_layout()

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var left: bool = Save.getv("opt", "left", false)
	var js := 112.0
	for b in touch:
		if b.get_meta("k") == "J":
			js = b.scale.x * b.texture_normal.get_width()
	for b in touch:
		var k: String = b.get_meta("k")
		var sz: float = b.scale.x * b.texture_normal.get_width()
		var pos := Vector2.ZERO
		match k:
			"J": pos = Vector2(vs.x - 18 - sz, vs.y - 34 - sz)
			"A": pos = Vector2(vs.x - 18 - js - 30 - sz, vs.y - 52 - sz)
			"G": pos = Vector2(vs.x - 18 - (js + sz) / 2, vs.y - 34 - js - 18 - sz)
		if left:
			pos.x = vs.x - pos.x - sz
		var off: Array = Save.getv("opt", "pos_" + k, [0, 0])
		b.position = pos + Vector2(off[0], off[1])
	var so: Array = Save.getv("opt", "pos_stick", [0, 0])
	stick.offset = Vector2(so[0], so[1])

func _make_top_buttons() -> void:
	# faixa do topo: só mochila e pausa (menores), logo à esquerda do painel com o nome do trecho;
	# som e "voltar à fogueira" ficam no menu de pausa
	top_buttons = HBoxContainer.new()
	top_buttons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_buttons.offset_left = -262
	top_buttons.offset_right = -262
	top_buttons.offset_top = 6
	top_buttons.offset_bottom = 6
	top_buttons.add_theme_constant_override("separation", 6)
	hud_layer.add_child(top_buttons)
	var bag := TextureButton.new()
	bag.texture_normal = load("res://assets/ui/btn_bag.png")
	bag.ignore_texture_size = true
	bag.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bag.custom_minimum_size = Vector2(44, 44)
	bag.pressed.connect(open_bag)
	top_buttons.add_child(bag)
	var pb := _small_btn("II", _toggle_pause)
	pb.custom_minimum_size = Vector2(44, 44)
	top_buttons.add_child(pb)
	dog_btn = TextureButton.new()
	dog_btn.texture_normal = load("res://assets/ui/btn_dog.png")
	dog_btn.ignore_texture_size = true
	dog_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	dog_btn.custom_minimum_size = Vector2(46, 46)
	dog_btn.tooltip_text = "Trocar entre o Tomé e o Pipoca (Q)"
	dog_btn.pressed.connect(func(): game.keys["Dp"] = true)
	dog_btn.visible = false
	top_buttons.add_child(dog_btn)
	top_buttons.move_child(dog_btn, 0)

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
		# some suavemente (o painel sai da lista na hora; só o desenho termina de sumir)
		var old: Control = panel
		panel = null
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ch in old.get_children():
			if ch is Control:
				ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := old.create_tween()
		tw.tween_property(old, "modulate:a", 0.0, .14)
		tw.tween_callback(old.queue_free)
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
	# aparece com um esmaecer rápido e o conteúdo subindo um pouquinho
	root.modulate.a = 0.0
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, .2)
	vb.position.y += 14
	tw.tween_property(vb, "position:y", vb.position.y - 14, .25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	Audio.set_song("tema")
	var vb := _overlay(.35)
	var img := TextureRect.new()
	img.texture = load("res://assets/ui/cena1.jpg")
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.modulate = Color(.55, .5, .45)
	panel.add_child(img)
	panel.move_child(img, 0)
	vb.add_child(_label("ENCONTRE-A", 68, Color("#f2d28a"), Spr.font_title))
	vb.add_child(_label("EPISÓDIO 1 · O BOSQUE", 22, Color("#e8c98a"), Spr.font_title))
	vb.add_child(_label("Levaram a Isis. Siga a trilha dos lápis de cor.", 18, Color("#e8dcc0"), Spr.font_i))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	vb.add_child(sp)
	var run := Save.load_run()
	if not run.is_empty():
		vb.add_child(_button("CONTINUAR", func(): start_level(true)))
	vb.add_child(_button("NOVO JOGO" if not run.is_empty() else "COMEÇAR", func(): start_level(false)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var gb := _button("GALERIA", show_gallery)
	gb.custom_minimum_size = Vector2(150, 46)
	row.add_child(gb)
	var ob := _button("OPÇÕES", func(): show_options(false))
	ob.custom_minimum_size = Vector2(150, 46)
	row.add_child(ob)
	vb.add_child(row)
	vb.add_child(_label("Teclado: ← → andar · ↑ ↓ subir/abaixar · Espaço pular · F usar · M mochila · N mapa", 12, Color(.8, .75, .65, .8)))
	panel.set_meta("ok", func(): start_level(not run.is_empty()))

## Tela de opções (do início ou da pausa)
func show_options(from_pause: bool) -> void:
	var vb := _overlay(.86)
	vb.add_child(_label("OPÇÕES", 32, GOLD, Spr.font_title))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(grid)
	var opt_row = func(title: String, key: String, opts: Array, def):
		var l := _label(title, 16, Color("#e8dcc0"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.custom_minimum_size = Vector2(190, 0)
		grid.add_child(l)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var cur = Save.getv("opt", key, def)
		for o in opts:
			var b := Button.new()
			b.text = o[0]
			b.focus_mode = Control.FOCUS_NONE
			b.toggle_mode = true
			b.button_pressed = cur == o[1]
			b.add_theme_font_size_override("font_size", 15)
			var val = o[1]
			b.pressed.connect(func():
				Save.setv("opt", key, val)
				if key == "tps":
					Engine.physics_ticks_per_second = val
				if key == "sound":
					Audio.set_on(val)
				apply_controls()
				show_options(from_pause))
			hb.add_child(b)
		grid.add_child(hb)
	opt_row.call("Controle", "stick", [["Direcional", "dpad"], ["Analógico", "analog"]], "dpad")
	opt_row.call("Tamanho dos botões", "btn_size", [["Pequeno", "P"], ["Médio", "M"], ["Grande", "G"]], "M")
	opt_row.call("Transparência", "btn_alpha", [["Clara", "clara"], ["Média", "media"], ["Forte", "forte"]], "media")
	opt_row.call("Mão", "left", [["Destro", false], ["Canhoto", true]], false)
	opt_row.call("Velocidade", "tps", [["Calma", 44], ["Média", 52], ["Normal (mais fluido)", 60]], 60)
	opt_row.call("Tutorial (dicas)", "tutorial", [["Ligado", true], ["Desligado", false]], true)
	opt_row.call("Som", "sound", [["Ligado", true], ["Desligado", false]], true)
	opt_row.call("Vibração", "vibrate", [["Sim", true], ["Não", false]], true)
	opt_row.call("Tremor da tela", "shake", [["Sim", true], ["Não", false]], true)
	vb.add_child(_label("Destro: movimento à esquerda e PULAR à direita. Canhoto: ao contrário.", 13, Color(.8, .75, .65), Spr.font_i))
	vb.add_child(_button("POSICIONAR BOTÕES NA TELA", func(): _edit_controls(from_pause)))
	var back := func():
		if from_pause:
			_pause_menu()
		else:
			panel.queue_free()
			panel = null
			show_title()
	vb.add_child(_button("VOLTAR", back))
	panel.set_meta("ok", back)

## editor: arraste o direcional e os botões para onde preferir
func _edit_controls(from_pause: bool) -> void:
	if panel:
		panel.queue_free()
		panel = null
	var ed := _CtrlEditor.new()
	ed.main = self
	ed.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ed)
	panel = ed
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hb.offset_top = 16
	hb.add_theme_constant_override("separation", 12)
	ed.add_child(hb)
	var ok := _button("PRONTO", func():
		ed.queue_free()
		panel = null
		show_options(from_pause))
	var rst := _button("RESTAURAR", func():
		for k in ["J", "A", "G", "stick"]:
			Save.setv("opt", "pos_" + k, [0, 0])
		_layout())
	hb.add_child(rst)
	hb.add_child(ok)
	panel.set_meta("ok", func(): ok.pressed.emit())

class _CtrlEditor extends Control:
	var main
	var drag := ""
	var last := Vector2.ZERO
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _process(_d: float) -> void:
		queue_redraw()
	func _targets() -> Dictionary:
		var t := {}
		for b in main.touch:
			var sz: float = b.scale.x * b.texture_normal.get_width()
			t[b.get_meta("k")] = [b.position + Vector2(sz, sz) / 2, sz / 2, b]
		t["stick"] = [main.stick._home(), main.stick.radius * main.stick.ui_scale, null]
		return t
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, .55))
		draw_string(Spr.font_i, Vector2(size.x / 2 - 200, size.y / 2), "Arraste o direcional e os botões para onde preferir.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, .95, .8))
		var t := _targets()
		for k in t:
			var c: Vector2 = t[k][0]
			var r: float = t[k][1]
			draw_circle(c, r + 6, Color(1, .85, .4, .25 if drag != k else .5))
			draw_arc(c, r + 6, 0, TAU, 48, Color(1, .9, .6, .9), 3, true)
			if t[k][2]:
				var b: TouchScreenButton = t[k][2]
				var sz: float = r * 2
				draw_texture_rect(b.texture_normal, Rect2(c - Vector2(r, r), Vector2(sz, sz)), false)
	func _gui_input(e: InputEvent) -> void:
		var pos := Vector2.ZERO
		var down := false
		var moving := false
		if e is InputEventScreenTouch:
			pos = e.position
			down = e.pressed
			if not down:
				if drag != "":
					Save.cfg.save(Save.PATH)
				drag = ""
				return
		elif e is InputEventMouseButton:
			pos = e.position
			down = e.pressed
			if not down:
				if drag != "":
					Save.cfg.save(Save.PATH)
				drag = ""
				return
		elif e is InputEventScreenDrag or e is InputEventMouseMotion:
			pos = e.position
			moving = true
		else:
			return
		if down:
			var t := _targets()
			for k in t:
				if pos.distance_to(t[k][0]) < t[k][1] + 14:
					drag = k
					last = pos
					return
		elif moving and drag != "":
			var d := pos - last
			last = pos
			var cur: Array = Save.getv("opt", "pos_" + drag, [0, 0])
			# só na memória enquanto arrasta; grava no disco ao soltar
			Save.cfg.set_value("opt", "pos_" + drag, [cur[0] + d.x, cur[1] + d.y])
			main._layout()

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
	if cont:
		show_intro(true)
	else:
		_ask_tutorial(func(): play_cut("abertura", func(): show_intro(false)))

## grande fogueira: fim de um período. Pausa, lembrança da Isis e escolha de seguir ou parar.
const REST_INFO := {
	1: ["FIM DA MANHÃ", "Toda tarde ela desenhava na varanda, esperando eu voltar do trabalho.", "Aguenta firme, filha. Estou chegando."],
	2: ["FIM DA TARDE", "Pega-pega no quintal... e ela sempre ganhava de mim.", "Aguenta firme, filha. Estou chegando."],
	3: ["FIM DO PÂNTANO", "Pular nas poças com a lanterna acesa. Ela nunca teve medo da chuva.", "Estou chegando, Isis. Não tenha medo do escuro."],
	4: ["FIM DA NEVE", "O boneco de neve ficou com o meu gorro. Ela riu a tarde inteira.", "Falta pouco, filha. Aguenta firme."],
	5: ["FIM DO CÉU", "Soltar pipa no morro... ela dizia que um dia ia voar de avião.", "Voei por você, filha. Agora falta só a mina."],
}

func _on_rest(n: int) -> void:
	state = S.REST
	_clear_keys()
	_show_hud(false)
	if panel:
		panel.queue_free()
	var root := Control.new()
	root.theme = theme_ui
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sc := RestScene.new()
	var found := 0
	for d in game.DRWS:
		if d.got:
			found += 1
	sc.setup(n, found)
	root.add_child(sc)
	var info: Array = REST_INFO.get(n, REST_INFO[1])
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_END
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vb)
	var title := _label(info[0] + " · progresso salvo", 15, Color("#cdbfa6"))
	var mem := _label(info[1], 17, Color("#e8dcc0"), Spr.font_i, 620)
	var line := _label("“" + info[2] + "”", 22, GOLD, Spr.font_title, 640)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var go := func():
		if panel:
			panel.queue_free()
			panel = null
		state = S.PLAY
		_show_hud(true)
		_clear_keys()
		game.running = true
		game.flash("Novo trecho: o relógio recomeçou.", 150)
	row.add_child(_button("CONTINUAR A JORNADA", go))
	row.add_child(_button("JOGAR MAIS TARDE", func():
		if panel:
			panel.queue_free()
			panel = null
		show_title()))
	for c in [title, mem, line, row]:
		c.modulate.a = 0.0
		vb.add_child(c)
	ui_layer.add_child(root)
	panel = root
	panel.set_meta("ok", go)
	Audio.set_song("tema")
	var tw := root.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(title, "modulate:a", 1.0, .5)
	tw.tween_property(mem, "modulate:a", 1.0, .8)
	tw.tween_interval(1.2)
	tw.tween_property(line, "modulate:a", 1.0, .8)
	tw.tween_interval(.6)
	tw.tween_property(row, "modulate:a", 1.0, .5)

## no começo de um jogo novo: quer as dicas do tutorial?
func _ask_tutorial(next: Callable) -> void:
	state = S.INTRO
	_show_hud(false)
	var vb := _overlay(.9)
	vb.add_child(_label("ANTES DE COMEÇAR", 30, GOLD, Spr.font_title))
	vb.add_child(_label("Quer ajuda do tutorial? As dicas explicam os controles e os desafios pelo caminho. Dá para mudar depois em OPÇÕES.", 17, Color("#e8dcc0"), Spr.font_i, 620))
	var pick := func(on: bool):
		Save.setv("opt", "tutorial", on)
		panel.queue_free()
		panel = null
		next.call()
	vb.add_child(_button("SIM, QUERO DICAS", func(): pick.call(true)))
	vb.add_child(_button("NÃO, QUERO DESCOBRIR SOZINHO", func(): pick.call(false)))
	panel.set_meta("ok", func(): pick.call(true))

func show_intro(cont: bool) -> void:
	state = S.INTRO
	_show_hud(false)
	var vb := _overlay(.88)
	vb.add_child(_label("EPISÓDIO 1", 16, Color("#cdbfa6"), Spr.font_title))
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

var pause_reason := ""
var auto_paused_ms := -1

func _toggle_pause(reason: String = "botão II") -> void:
	if state == S.PLAY:
		pause_reason = reason
		state = S.PAUSE
		_clear_keys()
		_show_hud(false)
		_pause_menu()
	elif state == S.PAUSE:
		close_panel()

func _pause_menu() -> void:
	var vb := _overlay(.7)
	vb.add_child(_label("PAUSA", 34, GOLD, Spr.font_title))
	if pause_reason != "":
		vb.add_child(_label("(pausado por: %s)" % pause_reason, 12, Color("#a89a80"), Spr.font_i))
	vb.add_child(_button("CONTINUAR", close_panel))
	var sb := _button("SOM: " + ("LIGADO" if Audio.on else "DESLIGADO"), func(): pass)
	sb.pressed.connect(func():
		Audio.set_on(not Audio.on)
		sb.text = "SOM: " + ("LIGADO" if Audio.on else "DESLIGADO"))
	vb.add_child(sb)
	vb.add_child(_button("VOLTAR À ÚLTIMA FOGUEIRA", func():
		close_panel()
		game.keys["Bp"] = true))
	vb.add_child(_button("MAPA DA FASE", func(): show_map(true)))
	vb.add_child(_button("OPÇÕES", func(): show_options(true)))
	vb.add_child(_button("MENU INICIAL", func():
		panel.queue_free()
		panel = null
		show_title()))
	panel.set_meta("ok", close_panel)

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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var mb := _button("MAPA", func(): show_map(false, true))
	mb.custom_minimum_size = Vector2(150, 46)
	row.add_child(mb)
	var fb := _button("FECHAR", close_panel)
	fb.custom_minimum_size = Vector2(150, 46)
	row.add_child(fb)
	vb.add_child(row)
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
	if id == 6 and not from_bag:
		state = S.CUT
		_clear_keys()
		play_cut("cracha", func(): _show_clue(6, false))
		return
	_show_clue(id, from_bag)

func _show_clue(id: int, from_bag: bool) -> void:
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

class _Speaker extends Control:
	## alto-falante com ondas (som ligado) ou com um X (som desligado)
	func _draw() -> void:
		var c := Vector2(size.x / 2 - 4, size.y / 2)
		var col := Color("#e8d39a")
		draw_rect(Rect2(c.x - 13, c.y - 6, 8, 12), col)
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 6, c.y - 6), Vector2(c.x + 4, c.y - 14), Vector2(c.x + 4, c.y + 14), Vector2(c.x - 6, c.y + 6)]), col)
		if Audio.on:
			draw_arc(Vector2(c.x + 4, c.y), 8, -.9, .9, 10, col, 2.5, true)
			draw_arc(Vector2(c.x + 4, c.y), 14, -.9, .9, 12, col, 2.5, true)
		else:
			draw_line(Vector2(c.x + 9, c.y - 7), Vector2(c.x + 19, c.y + 7), Color("#ff8a6a"), 3, true)
			draw_line(Vector2(c.x + 19, c.y - 7), Vector2(c.x + 9, c.y + 7), Color("#ff8a6a"), 3, true)

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

# ---------- cenas da história ----------
func play_cut(id: String, after: Callable) -> void:
	if panel:
		panel.queue_free()
		panel = null
	state = S.CUT
	_show_hud(false)
	_clear_keys()
	if id == "abertura":
		Audio.set_song("tema")
	elif id == "mina":
		Audio.set_song("vitoria")
	elif id == "posfinal":
		Audio.set_song("tunel")
	var c := preload("res://scripts/ui/cutscene.gd").new(id)
	c.theme = theme_ui
	ui_layer.add_child(c)
	c.finished.connect(after)

func _on_level_end() -> void:
	play_cut("mina", _on_results)

# ---------- mapa da fase ----------
## from_pause: volta ao menu de pausa; from_bag: volta à mochila; senão volta ao jogo
func show_map(from_pause: bool, from_bag: bool = false) -> void:
	var vb := _overlay(.9)
	vb.add_child(_label("MAPA DA FASE", 30, GOLD, Spr.font_title))
	var m := preload("res://scripts/ui/level_map.gd").new()
	m.game = game
	var vs := get_viewport().get_visible_rect().size
	m.custom_minimum_size = Vector2(min(vs.x - 60, 1100), 250)
	vb.add_child(m)
	vb.add_child(_label("As fogueiras acesas são onde você volta. \"?\" = algo que ficou para trás num trecho já visitado.", 13, Color(.8, .75, .65), Spr.font_i, 700))
	var back := func():
		if from_pause:
			_pause_menu()
		elif from_bag:
			state = S.BAG
			_render_bag("")
		else:
			close_panel()
	vb.add_child(_button("VOLTAR", back))
	panel.set_meta("ok", back)

# ---------- galeria ----------
func show_gallery() -> void:
	var vb := _overlay(.92)
	vb.add_child(_label("GALERIA DA ISIS", 30, GOLD, Spr.font_title))
	vb.add_child(_label("Os desenhos que você encontrou pelo caminho.", 14, Color(.85, .8, .7), Spr.font_i))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var KD := preload("res://scripts/ui/kid_drawing.gd")
	for i in 3:
		var d = KD.new()
		d.kind = [0, 1, 3][i]
		d.locked = not Save.getv("gallery", "d%d" % i, false)
		d.custom_minimum_size = Vector2(196, 128)
		row.add_child(d)
	var fin = Save.getv("gallery", "final", null)
	if fin == null:
		var d3 = KD.new()
		d3.locked = true
		row.add_child(d3)
	else:
		var fd := _FinalDrawing.new()
		for c in fin:
			fd.specs[c] = 1
		fd.scale = Vector2(.66, .66)
		fd.custom_minimum_size = Vector2(198, 128)
		row.add_child(fd)
	if Save.getv("gallery", "gold", false):
		var gl := HBoxContainer.new()
		gl.alignment = BoxContainer.ALIGNMENT_CENTER
		gl.add_child(_atlas_icon("pen_gold", 34))
		gl.add_child(_label("  O lápis dourado da Isis — encontrado!", 14, Color("#ffd76a"), Spr.font_i))
		vb.add_child(gl)
	vb.add_child(_label("PISTAS ENCONTRADAS", 13, Color("#b8a888")))
	var cl := HBoxContainer.new()
	cl.alignment = BoxContainer.ALIGNMENT_CENTER
	cl.add_theme_constant_override("separation", 10)
	for i in range(1, 7):
		if Save.getv("gallery", "c%d" % i, false):
			var ic := _atlas_icon("clb_%d" % i, 64)
			ic.tooltip_text = GameData.CLUE_INFO[i][0]
			cl.add_child(ic)
		else:
			var q := _label("?", 34, Color(.5, .45, .38))
			q.custom_minimum_size = Vector2(64, 64)
			cl.add_child(q)
	vb.add_child(cl)
	var best := Save.best(0)
	if not best.is_empty():
		vb.add_child(_label("Melhor resultado no Bosque: %s   ·   lápis %d   ·   pistas %d/6" % ["★".repeat(int(best.get("stars", 0))), int(best.get("pen", 0)), int(best.get("clues", 0))], 14, Color("#ffd76a")))
	var b := HBoxContainer.new()
	b.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_theme_constant_override("separation", 10)
	var rb := _button("REVER ABERTURA", func(): play_cut("abertura", show_title))
	rb.custom_minimum_size = Vector2(200, 46)
	b.add_child(rb)
	var back := func():
		panel.queue_free()
		panel = null
		show_title()
	var vb2 := _button("VOLTAR", back)
	vb2.custom_minimum_size = Vector2(150, 46)
	b.add_child(vb2)
	vb.add_child(b)
	panel.set_meta("ok", back)

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
	var prev: Array = Save.getv("gallery", "final", [])
	if game.SPECGOT.size() >= prev.size():
		Save.setv("gallery", "final", game.SPECGOT.keys())
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
	var gold_txt := "Lápis dourado  " + ("✓" if game.X.GOLD.get("got", false) else "—")
	var sec_txt := "Lugares secretos  %d/%d" % [game.X.found.size(), game.X.SECRETS.size()]
	for t in ["⏱ Tempo  %d:%02d" % [secs / 60, secs % 60], "✏ Lápis  %d/%d" % [pen, pt], "Lápis especiais  %d/6" % ns, "Desenhos  %d/%d" % [dr, game.DRWS.size()], "Pistas  %d/6" % nc, gold_txt, sec_txt]:
		grid.add_child(_label(t, 15, INK))
	vb.add_child(grid)
	var story := "Agora eu sei: foi Ademar Vargas, o gerente que roubava a mina. Ele levou a Isis para se vingar. Vou atrás dele — mina adentro." if nc == 6 else "Ele fugiu para a mina. Ainda faltam pistas para ter certeza de quem é... (%d/6)" % nc
	vb.add_child(_label(story, 16, Color("#e8dcc0"), Spr.font_i, 640))
	vb.add_child(_label("As próximas fases chegam em breve.", 13, Color(.75, .7, .6)))
	vb.add_child(_button("CONTINUAR", func(): play_cut("posfinal", show_title)))

class _FinalDrawing extends Control:
	## O desenho da Isis, colorido com os lápis especiais encontrados
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
		var txt := "\"Papai e eu\" — Isis" if specs.size() == 6 else "Faltam cores: %d" % (6 - specs.size())
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
			start_level(true)
			game.lives = max(game.lives, 3)))
	vb.add_child(_button("RECOMEÇAR A FASE", func(): start_level(false)))
	vb.add_child(_button("MENU INICIAL", func():
		panel.queue_free()
		panel = null
		show_title()))
