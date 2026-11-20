extends Node3D
class_name CameraRig
## Câmera em terceira pessoa que gira em volta do Tomé. Perto do colosso ela desce e olha para cima
## (de baixo para cima); nas costas dele, sobe e olha para baixo (de cima para baixo).

var main
var cam: Camera3D
var yaw := 0.0
var pitch := -0.22
var dist := 7.0
var shake := 0.0
var idle_cam := 0.0
var look_pt := Vector3.ZERO
var title_t := 0.0
var _ray := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = .1
	cam.far = 2600.0
	add_child(cam)
	cam.current = true
	_ray.collision_mask = 1 | 2

func add_shake(a: float) -> void:
	shake = max(shake, a)

func snap() -> void:
	if main and main.player:
		yaw = main.player.face_yaw + PI
		look_pt = main.player.center()

func _process(dt: float) -> void:
	if main == null:
		return
	shake = max(0.0, shake - dt * 1.6)
	if main.state == "title":
		_title(dt)
		return
	var p: Player = main.player
	var c: Vector2 = main.inp.take_cam()
	if c != Vector2.ZERO:
		idle_cam = 0.0
		yaw -= c.x * .006
		pitch = clampf(pitch - c.y * .005, -1.25, .75)
	else:
		idle_cam += dt
	# volta sozinha para trás do Tomé quando ele anda e você não mexe na câmera
	if idle_cam > 1.2 and main.inp.move.length() > .3 and p.state in ["ground", "air"]:
		yaw = lerp_angle(yaw, p.face_yaw + PI, 1.0 - exp(-1.2 * dt))
	# balançando ou voando rápido, a câmera vai virando para onde o Tomé está indo
	var hvel := Vector3(p.velocity.x, 0, p.velocity.z)
	if idle_cam > .6 and p.state in ["swing", "zip", "air"] and hvel.length() > 9.0:
		yaw = lerp_angle(yaw, atan2(hvel.x, hvel.z) + PI, 1.0 - exp(-1.6 * dt))
	var col: Colossus = main.colossus
	var center := p.center() + Vector3(0, .6, 0)
	var want_dist := 7.0
	var bias := 0.0
	var fov := 70.0
	var look := center
	var near_k := 0.0
	if col and col.awake():
		var d := Vector2(p.global_position.x - col.global_position.x, p.global_position.z - col.global_position.z).length()
		near_k = clampf(1.0 - (d - 45.0) / 110.0, 0.0, 1.0)
	match p.state:
		"climb":
			want_dist = 9.0
			if p.climb_n.y > .75:
				# nas costas do gigante: de cima para baixo
				bias = -.3
				want_dist = 13.0
			else:
				bias = -.05
			fov = 72.0
		"swing", "zip", "hookfly":
			want_dist = 8.5 + clampf(p.velocity.length() / 34.0, 0.0, 1.0) * 3.0
			fov = 78.0 + clampf(p.velocity.length() / 34.0, 0.0, 1.0) * 10.0
			# olha um pouco à frente do movimento
			look = center + p.velocity * .12
		_:
			if near_k > 0.0 and p.global_position.y < 10.0:
				# perto do colosso, no chão: câmera baixa olhando para cima
				bias = .55 * near_k
				want_dist = lerpf(7.0, 9.5, near_k)
				fov = lerpf(70.0, 80.0, near_k)
				var head_pos: Vector3 = col.head.global_position
				look = center.lerp(head_pos, .22 * near_k)
	if p.state == "air" and p.velocity.length() > 12.0:
		fov = maxf(fov, 76.0 + clampf(p.velocity.length() / 34.0, 0.0, 1.0) * 10.0)
		want_dist = maxf(want_dist, 9.0)
	var k_slow := 1.0 - exp(-3.0 * dt)
	dist = lerpf(dist, want_dist, k_slow)
	cam.fov = lerpf(cam.fov, fov, k_slow)
	var ep := clampf(pitch + bias, -1.3, .95)
	var off := Vector3(sin(yaw) * cos(ep), -sin(ep), cos(yaw) * cos(ep)) * dist
	look_pt = look_pt.lerp(look, 1.0 - exp(-12.0 * dt)) if look_pt != Vector3.ZERO else look
	var want := center + off
	if want.y < .4:
		want.y = .4
	# não atravessa árvores, pedras e paredes
	var space := get_world_3d().direct_space_state
	_ray.from = center
	_ray.to = want
	_ray.exclude = [p.get_rid()]
	# escalando, a câmera pode atravessar o corpo do colosso (por dentro ele não aparece)
	_ray.collision_mask = 1 if p.state == "climb" else (1 | 2)
	var hit := space.intersect_ray(_ray)
	if not hit.is_empty():
		want = hit.position + (center - want).normalized() * .4
	# quando bate em algo a câmera chega rápido (não atravessa); livre, ela segue macia
	var kp := 1.0 - exp((-30.0 if not hit.is_empty() else -14.0) * dt)
	var pos := cam.global_position.lerp(want, kp) if cam.global_position.distance_to(want) < 40 else want
	if shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * .35
	cam.global_position = pos
	if pos.distance_to(look_pt) > .1:
		cam.look_at(look_pt, Vector3.UP)

func _title(dt: float) -> void:
	title_t += dt
	var col: Colossus = main.colossus
	var cpos := col.global_position
	var a := title_t * .04 + 2.2
	# de baixo para cima, girando devagar em volta do gigante
	var pos := cpos + Vector3(sin(a) * 48.0, 1.5, cos(a) * 48.0)
	cam.global_position = pos
	cam.fov = 80.0
	cam.look_at(col.head.global_position + Vector3(0, -12, 0), Vector3.UP)
