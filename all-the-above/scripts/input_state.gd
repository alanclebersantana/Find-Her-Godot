extends Node
class_name InputState
## Entrada unificada: toque (joystick à esquerda, arrastar à direita gira a câmera, 4 botões),
## teclado e controle de videogame. Os outros scripts só leem os campos daqui.

var move := Vector2.ZERO          # x direita, y para cima (frente)
var cam := Vector2.ZERO           # giro de câmera acumulado neste quadro (pixels/unidades)
var held := {"hook": false, "grab": false, "jump": false, "pick": false}
var pressed := {}                 # botão apertado neste quadro
var released := {}                # botão solto neste quadro
var tap := false                  # toque em qualquer lugar (tela de abertura)
var test_move = null              # testes: força o joystick

const BUTTONS := ["hook", "jump", "grab", "pick"]
const LABEL := {"hook": "GANCHO", "jump": "PULAR", "grab": "AGARRAR", "pick": "PICARETA"}

# toque
var touches := {}                 # índice -> {"role": "stick"/"cam"/botão, "pos": Vector2, "start": Vector2}
var stick_center := Vector2.ZERO
var stick_radius := 90.0
var stick_vec := Vector2.ZERO
var _touch_held := {}
var _prev := {}

func viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

## posição e raio de cada botão na tela (mesma conta que o HUD usa para desenhar)
func button_rects() -> Dictionary:
	var s := viewport_size()
	var r := clampf(s.y * .085, 44.0, 70.0)
	var bx := s.x - r * 1.5
	var by := s.y - r * 1.5
	return {
		"hook": [Vector2(bx - r * 0.2, by - r * 0.3), r * 1.25],
		"jump": [Vector2(bx - r * 2.6, by + r * 0.15), r],
		"grab": [Vector2(bx - r * 0.5, by - r * 2.75), r],
		"pick": [Vector2(bx - r * 2.9, by - r * 2.1), r],
	}

func stick_home() -> Vector2:
	var s := viewport_size()
	return Vector2(clampf(s.x * .13, 120, 190), s.y - clampf(s.y * .25, 120, 190))

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			tap = true
			var role := "cam"
			var br := button_rects()
			for b in BUTTONS:
				if e.position.distance_to(br[b][0]) <= br[b][1] * 1.08:
					role = b
					break
			if role == "cam" and e.position.x < viewport_size().x * .42 and e.position.y > viewport_size().y * .35:
				role = "stick"
				stick_center = e.position
			touches[e.index] = {"role": role, "pos": e.position, "start": e.position}
		else:
			if touches.has(e.index) and touches[e.index].role == "stick":
				stick_vec = Vector2.ZERO
			touches.erase(e.index)
	elif e is InputEventScreenDrag:
		if not touches.has(e.index):
			return
		var t: Dictionary = touches[e.index]
		if t.role == "stick":
			var v: Vector2 = (e.position - stick_center) / stick_radius
			if v.length() > 1.0:
				# o joystick acompanha o dedo quando ele passa da borda
				stick_center = e.position - v.normalized() * stick_radius
				v = v.normalized()
			stick_vec = v
		elif t.role == "cam":
			cam += e.relative
		t.pos = e.position

func _process(_dt: float) -> void:
	pass

## chamado no começo de cada quadro de física pelo Main
func poll() -> void:
	var now := {}
	for b in BUTTONS:
		now[b] = false
	for k in touches:
		var t: Dictionary = touches[k]
		if t.role in BUTTONS:
			now[t.role] = true
	# teclado
	var kb := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		kb.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		kb.y -= 1
	if Input.is_key_pressed(KEY_SPACE):
		now.jump = true
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SHIFT):
		now.hook = true
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		now.grab = true
	if Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_J):
		now.pick = true
	if Input.is_key_pressed(KEY_I):
		cam.y -= 6
	if Input.is_key_pressed(KEY_K):
		cam.y += 6
	if Input.is_key_pressed(KEY_L):
		cam.x += 8
	if Input.is_key_pressed(KEY_O) or Input.is_key_pressed(KEY_U):
		cam.x -= 8
	# controle de videogame (o primeiro conectado)
	var pad := Vector2.ZERO
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var j: int = pads[0]
		pad = Vector2(Input.get_joy_axis(j, JOY_AXIS_LEFT_X), -Input.get_joy_axis(j, JOY_AXIS_LEFT_Y))
		if pad.length() < .2:
			pad = Vector2.ZERO
		var rs := Vector2(Input.get_joy_axis(j, JOY_AXIS_RIGHT_X), Input.get_joy_axis(j, JOY_AXIS_RIGHT_Y))
		if rs.length() > .15:
			cam += rs * 9.0
		if Input.is_joy_button_pressed(j, JOY_BUTTON_A):
			now.jump = true
		if Input.is_joy_button_pressed(j, JOY_BUTTON_X):
			now.pick = true
		if Input.is_joy_button_pressed(j, JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(j, JOY_AXIS_TRIGGER_RIGHT) > .4:
			now.hook = true
		if Input.is_joy_button_pressed(j, JOY_BUTTON_LEFT_SHOULDER) or Input.get_joy_axis(j, JOY_AXIS_TRIGGER_LEFT) > .4:
			now.grab = true
		if Input.is_joy_button_pressed(j, JOY_BUTTON_START):
			tap = true
	var m: Vector2 = stick_vec
	if kb != Vector2.ZERO:
		m = kb.normalized()
	if pad != Vector2.ZERO:
		m = pad.limit_length(1.0)
	move = Vector2(m.x, -m.y) if m == stick_vec else m
	if test_move != null:
		move = test_move
	pressed = {}
	released = {}
	for b in BUTTONS:
		var was: bool = _prev.get(b, false)
		pressed[b] = now[b] and not was
		released[b] = was and not now[b]
		held[b] = now[b]
		_prev[b] = now[b]
	if pressed.values().has(true):
		tap = true

## a câmera consome o giro acumulado
func take_cam() -> Vector2:
	var c := cam
	cam = Vector2.ZERO
	return c

func take_tap() -> bool:
	var t := tap
	tap = false
	return t

## usado pelos testes para simular botões
func force(b: String, on: bool) -> void:
	if on:
		touches[-100 - BUTTONS.find(b)] = {"role": b, "pos": Vector2.ZERO, "start": Vector2.ZERO}
	else:
		touches.erase(-100 - BUTTONS.find(b))
