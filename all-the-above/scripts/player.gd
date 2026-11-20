extends CharacterBody3D
class_name Player
## O Tomé: anda, pula, joga o gancho (a picareta presa na corda), balança, voa até o pelo do colosso,
## escala com a barra de agarre e crava a picareta nos pontos fracos.

var main
var model: TomeModel
var state := "ground"          # ground, air, hookfly, swing, zip, climb, dead

const SPEED := 7.0
const ACC := 45.0
const AIR_ACC := 10.0
const JUMP := 8.5
const GRAV := 24.0
const HOOK_RANGE := 55.0
const CLIMB_SPEED := 3.4
const HAND := Vector3(0, 1.5, 0)

var hp := 5
var max_hp := 5
var stamina := 1.0
var invul := 0.0
var hook_target: Node3D = null
var hook_kind := ""
var rope_len := 0.0
var hook_t := 0.0
var rope: MeshInstance3D
var climb_part: CPart = null
var climb_local := Vector3.ZERO
var climb_axis := 0
var climb_sgn := 1
var climb_n := Vector3.UP
var face_yaw := 0.0
var pick_cd := 0.0
var dead_t := 0.0
var aim: Node3D = null
var tired_msg := 0.0
var regrip := false           # a mão cansou: só agarra de novo depois de soltar o botão

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = .3
	var cs := CollisionShape3D.new()
	cs.shape = Mk.capsule_shape(.35, 1.7)
	cs.position = Vector3(0, .85, 0)
	add_child(cs)
	model = TomeModel.new()
	add_child(model)
	rope = MeshInstance3D.new()
	rope.mesh = Mk.cyl(.035, .035, 1.0, 5)
	rope.material_override = Mk.mat(Color("#d9b77a"), .8)
	rope.top_level = true
	rope.visible = false
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope)

func center() -> Vector3:
	return global_position + Vector3(0, .9, 0)

func cam_basis() -> Array:
	var yaw: float = main.cam.yaw
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	var r := Vector3(cos(yaw), 0, -sin(yaw))
	return [f, r]

func move_dir() -> Vector3:
	var b := cam_basis()
	var m: Vector2 = main.inp.move
	return (b[1] * m.x + b[0] * m.y)

func _physics_process(dt: float) -> void:
	if main == null or main.state != "play":
		return
	var inp: InputState = main.inp
	invul = max(0.0, invul - dt)
	pick_cd = max(0.0, pick_cd - dt)
	tired_msg = max(0.0, tired_msg - dt)
	if state != "climb" and state != "dead":
		stamina = min(1.0, stamina + .45 * dt)
	if state in ["ground", "air", "swing", "climb"]:
		aim = _find_aim()
	else:
		aim = null
	match state:
		"ground", "air":
			_walk(dt, inp)
		"hookfly":
			_hookfly(dt, inp)
		"swing":
			_swing(dt, inp)
		"zip":
			_zip(dt, inp)
		"climb":
			_climb(dt, inp)
		"dead":
			dead_t -= dt
			velocity.y -= GRAV * dt
			move_and_slide()
			if dead_t <= 0.0:
				respawn()
	_rope_draw()
	if global_position.y < -40.0:
		respawn()
	model.rotation.y = lerp_angle(model.rotation.y, face_yaw, .25)

# ------------------------------------------------------------------ andar e pular
func _walk(dt: float, inp: InputState) -> void:
	var dir := move_dir()
	var target := dir * SPEED
	var acc := ACC if is_on_floor() else AIR_ACC
	velocity.x = move_toward(velocity.x, target.x, acc * dt)
	velocity.z = move_toward(velocity.z, target.z, acc * dt)
	if not is_on_floor():
		velocity.y -= GRAV * dt
	if inp.pressed.jump and is_on_floor():
		velocity.y = JUMP
		main.sfx.play("jump", -6.0)
	var vy_before := velocity.y
	move_and_slide()
	if is_on_floor():
		if state == "air" and vy_before < -26.0:
			hurt(1, Vector3.ZERO)
			main.sfx.play("land", 0.0, .7)
		elif state == "air" and vy_before < -8.0:
			main.sfx.play("land", -8.0)
		state = "ground"
	else:
		state = "air"
	if dir.length() > .1:
		face_yaw = atan2(dir.x, dir.z)
	var hs := Vector2(velocity.x, velocity.z).length()
	model.speed = hs
	model.pose = ("walk" if hs > .5 else "idle") if state == "ground" else "air"
	# agarrar no colosso (no chão ou caindo perto dele)
	if not inp.held.grab:
		regrip = false
	if inp.held.grab and stamina > .2 and not regrip:
		var c := nearest_surface(1.3)
		if not c.is_empty():
			start_climb(c)
			return
	if inp.pressed.hook and aim:
		fire_hook(aim)
		return
	if inp.pressed.pick:
		attack()

# ------------------------------------------------------------------ gancho
func _find_aim() -> Node3D:
	var cam: Camera3D = main.cam.cam
	var cpos := cam.global_position
	var fwd := -cam.global_basis.z
	var me := center()
	var best: Node3D = null
	var best_s := -1e9
	for n in get_tree().get_nodes_in_group("hook"):
		var node: Node3D = n
		if not node.is_visible_in_tree():
			continue
		var kind: String = node.get_meta("kind")
		var p := node.global_position
		var d := p.distance_to(me)
		var rng := 18.0 if kind == "alien" else HOOK_RANGE
		if d > rng or d < 2.5:
			continue
		if kind == "tree" and p.y < me.y + 2.5:
			continue
		if kind == "colossus" and state == "climb" and climb_part and node.get_parent() == climb_part:
			continue
		var dc := (p - cpos).normalized()
		var dot := dc.dot(fwd)
		if dot < .8:
			continue
		var s := dot * 3.0 - d / rng
		if kind == "colossus":
			s += .4
		if s > best_s:
			best_s = s
			best = node
	return best

func fire_hook(t: Node3D) -> void:
	hook_target = t
	hook_kind = t.get_meta("kind")
	hook_t = 0.0
	if state == "climb":
		_leave_climb(Vector3.ZERO)
	state = "hookfly"
	main.sfx.play("hook", -3.0)
	model.pose = "swing"
	var to := t.global_position - center()
	face_yaw = atan2(to.x, to.z)

func _hookfly(dt: float, inp: InputState) -> void:
	hook_t += dt
	velocity.y -= GRAV * dt * .5
	move_and_slide()
	if not is_instance_valid(hook_target) or not inp.held.hook:
		_cancel_hook()
		return
	var d := hook_target.global_position.distance_to(global_position + HAND)
	if hook_t >= max(.08, d / 110.0):
		match hook_kind:
			"tree":
				state = "swing"
				rope_len = max(4.0, d * .92)
			"colossus":
				state = "zip"
				main.sfx.play("swish", -4.0)
			"alien":
				var al = hook_target.get_parent()
				if al and al.has_method("yank"):
					al.yank(self)
				_cancel_hook()

func _cancel_hook() -> void:
	hook_target = null
	state = "air"

func _swing(dt: float, inp: InputState) -> void:
	if not is_instance_valid(hook_target):
		_cancel_hook()
		return
	var hp_ := hook_target.global_position
	velocity.y -= GRAV * dt
	var dir := move_dir()
	velocity += dir * 9.0 * dt
	# recolhe a corda devagar: ganha velocidade no balanço
	rope_len = max(5.0, rope_len - 1.5 * dt)
	var hand := global_position + HAND
	var rel := hand - hp_
	if rel.length() >= rope_len:
		var rn := rel.normalized()
		var vr := velocity.dot(rn)
		if vr > 0.0:
			velocity -= rn * vr
	move_and_slide()
	hand = global_position + HAND
	rel = hand - hp_
	if rel.length() > rope_len:
		global_position = hp_ + rel.normalized() * rope_len - HAND
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() > 1.0:
		face_yaw = atan2(hv.x, hv.z)
	model.pose = "swing"
	if inp.pressed.jump or not inp.held.hook:
		# solta e voa: um empurrão a mais na direção do balanço
		var boost := velocity.normalized() * 3.0 + Vector3(0, 4.0 if inp.pressed.jump else 2.5, 0)
		velocity += boost
		hook_target = null
		state = "air"
		main.sfx.play("swish", -6.0)
		return
	if inp.held.grab and not regrip and stamina > .2:
		var c := nearest_surface(1.5)
		if not c.is_empty():
			hook_target = null
			start_climb(c)

func _zip(dt: float, inp: InputState) -> void:
	if not is_instance_valid(hook_target) or not inp.held.hook:
		velocity *= .5
		_cancel_hook()
		return
	var to := hook_target.global_position - center()
	var d := to.length()
	velocity = to.normalized() * 30.0
	global_position += velocity * dt
	face_yaw = atan2(to.x, to.z)
	model.pose = "swing"
	if d < 1.8:
		var c := nearest_surface(4.0)
		hook_target = null
		if not c.is_empty():
			start_climb(c)
		else:
			state = "air"

func _rope_draw() -> void:
	if state in ["hookfly", "swing", "zip"] and is_instance_valid(hook_target):
		var a := global_position + HAND + Vector3(0, .3, 0)
		var b := hook_target.global_position
		if state == "hookfly":
			var d := a.distance_to(b)
			b = a + (b - a).normalized() * min(d, hook_t * 110.0)
		var l := a.distance_to(b)
		if l < .05:
			rope.visible = false
			return
		rope.visible = true
		var bs := World.axis_basis(b - a)
		rope.global_transform = Transform3D(Basis(bs.x, bs.y * l, bs.z), (a + b) / 2.0)
	else:
		rope.visible = false

# ------------------------------------------------------------------ escalada
## superfície do colosso mais perto do corpo do Tomé (vazio se longe demais)
func nearest_surface(maxd: float) -> Dictionary:
	if main.colossus == null:
		return {}
	var best := {}
	var bd := maxd
	var c := center()
	for p in main.colossus.parts:
		var part: CPart = p
		var r := part.closest(c)
		if r.dist < bd:
			bd = r.dist
			best = r
			best.part = part
	return best

func start_climb(c: Dictionary) -> void:
	climb_part = c.part
	climb_local = c.local
	climb_axis = c.axis
	climb_sgn = c.sgn
	state = "climb"
	velocity = Vector3.ZERO
	main.sfx.play("land", -6.0, 1.3)
	_place_on_surface()

func _surface_point() -> Vector3:
	return climb_part.to_world(climb_local)

func _place_on_surface() -> void:
	climb_n = climb_part.normal_world(climb_axis, climb_sgn)
	var s := _surface_point()
	var up_k := clampf(climb_n.y, 0.0, 1.0)
	global_position = s + climb_n * .42 * (1.0 - up_k) - Vector3(0, .85, 0) * (1.0 - up_k)

func _climb(dt: float, inp: InputState) -> void:
	if not is_instance_valid(climb_part):
		state = "air"
		return
	var col: Colossus = main.colossus
	climb_n = climb_part.normal_world(climb_axis, climb_sgn)
	var rest := climb_n.y > .75
	# barra de agarre
	var mv: Vector2 = inp.move
	var moving := mv.length() > .1
	if rest:
		stamina = min(1.0, stamina + .28 * dt)
	else:
		stamina -= (.045 + (.2 if col.shaking() else 0.0) + (.025 if moving else 0.0)) * dt
	if stamina <= 0.0:
		stamina = 0.0
		if not rest:
			if tired_msg <= 0.0:
				main.hud.msg("A mão cansou e soltou!", 2.0)
				tired_msg = 3.0
			regrip = true
			_leave_climb(climb_n * 1.5)
			return
	if not inp.held.grab:
		_leave_climb(climb_n * 1.5)
		return
	if inp.pressed.jump:
		_leave_climb(climb_n * 7.0 + Vector3(0, 6.5, 0))
		main.sfx.play("jump", -6.0)
		return
	if inp.pressed.hook and aim and aim.get_parent() != climb_part:
		fire_hook(aim)
		return
	if inp.pressed.pick:
		_stab()
	# andar pela superfície (relativo à câmera)
	if moving:
		var b := cam_basis()
		var flat: Vector3 = b[1] * mv.x + b[0] * mv.y
		var want: Vector3
		if abs(climb_n.y) < .8:
			# parede: o que vai de lado anda de lado; empurrar para a parede sobe, para fora desce
			var up_dir := (Vector3.UP - climb_n * climb_n.dot(Vector3.UP)).normalized()
			var side := flat - climb_n * flat.dot(climb_n)
			side -= up_dir * side.dot(up_dir)
			var into := -flat.dot(climb_n)
			want = side + up_dir * into
		else:
			want = flat - climb_n * flat.dot(climb_n)
		var dl: Vector3 = climb_part.global_transform.basis.inverse() * want
		dl[climb_axis] = 0.0
		climb_local += dl * CLIMB_SPEED * dt
		_edge(col)
	# encostou dentro de outra parte do corpo (perna entrando no tronco, etc.): passa para ela
	var sp := _surface_point()
	for p in col.parts:
		var part: CPart = p
		if part == climb_part:
			continue
		var l: Vector3 = part.global_transform.affine_inverse() * sp
		if abs(l.x) < part.he.x - .05 and abs(l.y) < part.he.y - .05 and abs(l.z) < part.he.z - .05:
			var r := part.closest(sp)
			if r.n.y < -.6 and climb_n.y > -.6:
				continue
			climb_part = part
			climb_local = r.local
			climb_axis = r.axis
			climb_sgn = r.sgn
			break
	_place_on_surface()
	var n := climb_n
	if rest:
		var hv := Vector3(want_dir(inp).x, 0, want_dir(inp).z)
		if hv.length() > .1:
			face_yaw = atan2(hv.x, hv.z)
		model.pose = "walk" if moving else "idle"
		model.speed = 2.0
	else:
		if Vector2(n.x, n.z).length() > .2:
			face_yaw = atan2(-n.x, -n.z)
		model.pose = "climb"
		model.speed = 1.0 if moving else 0.0

## passou da borda da face: primeiro tenta passar para outra parte do corpo ali perto
## (perna -> tronco -> corcova -> pescoço -> cabeça); se não tem, dobra para a face vizinha
func _edge(col: Colossus) -> void:
	var he: Vector3 = climb_part.he
	var worst := -1
	var wr := 0.0
	for a in 3:
		if a == climb_axis:
			continue
		var r: float = abs(climb_local[a]) - he[a]
		if r > 0.0 and r > wr:
			wr = r
			worst = a
	if worst < 0:
		return
	var wp: Vector3 = climb_part.to_world(climb_local)
	var best := {}
	var bd := .75
	for p in col.parts:
		var part: CPart = p
		if part == climb_part:
			continue
		var r2 := part.closest(wp)
		if r2.dist < bd:
			bd = r2.dist
			best = r2
			best.part = part
	if not best.is_empty():
		climb_part = best.part
		climb_local = best.local
		climb_axis = best.axis
		climb_sgn = best.sgn
		return
	var s := 1 if climb_local[worst] > 0 else -1
	climb_axis = worst
	climb_sgn = s
	for a in 3:
		climb_local[a] = clampf(climb_local[a], -he[a], he[a])
	climb_local[worst] = he[worst] * s

func want_dir(inp: InputState) -> Vector3:
	var b := cam_basis()
	return b[1] * inp.move.x + b[0] * inp.move.y

func _leave_climb(extra: Vector3) -> void:
	var v := Vector3.ZERO
	if is_instance_valid(climb_part):
		v = climb_part.point_velocity(climb_local, get_physics_process_delta_time())
	climb_part = null
	velocity = v + extra
	state = "air"

func _stab() -> void:
	if pick_cd > 0.0:
		return
	pick_cd = .38
	model.swing_pick()
	var best: WeakPoint = null
	var bd := 2.8
	for w in main.colossus.weak:
		var wp: WeakPoint = w
		if wp.done:
			continue
		var d := wp.global_position.distance_to(center())
		if d < bd:
			bd = d
			best = wp
	if best:
		stamina = max(0.0, stamina - .05)
		main.colossus.stab(best)
		main.cam.add_shake(.25)
	else:
		main.sfx.play("swish", -10.0)

# ------------------------------------------------------------------ combate e vida
func attack() -> void:
	if pick_cd > 0.0:
		return
	pick_cd = .35
	model.swing_pick()
	main.sfx.play("swish", -6.0)
	var f := Vector3(sin(face_yaw), 0, cos(face_yaw))
	if main.aliens:
		main.aliens.hit_area(center() + f * 1.2, 1.7, 1, f)

func hurt(d: int, kb: Vector3) -> void:
	if invul > 0.0 or state == "dead":
		return
	hp -= d
	invul = 1.2
	main.sfx.play("hurt", -2.0)
	main.hud.hurt_flash()
	main.cam.add_shake(.35)
	if kb != Vector3.ZERO:
		if state == "climb":
			_leave_climb(Vector3.ZERO)
		velocity = kb
		state = "air"
	if hp <= 0:
		hp = 0
		state = "dead"
		dead_t = 2.5
		hook_target = null
		climb_part = null
		model.pose = "hurt"
		main.hud.msg("O Tomé desmaiou… de volta à fogueira.", 2.5)

func respawn() -> void:
	global_position = main.world.spawn
	velocity = Vector3.ZERO
	hp = max_hp
	stamina = 1.0
	state = "ground"
	hook_target = null
	climb_part = null
	invul = 1.5
	main.cam.snap()
