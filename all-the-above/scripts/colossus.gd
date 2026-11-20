extends Node3D
class_name Colossus
## O Chifrudo de Musgo: fera gigante (≈25 m), metade bode da montanha, metade touro, feita de placas de
## pedra, musgo e pelo comprido. Anda em volta do vale, sacode quem está pendurado, pisoteia quem está
## embaixo. Três peças da nave cravadas (joelho, nuca, testa); arrancadas as três, ele volta a dormir.

signal piece_taken(left: int)
signal fell_asleep

const RING := 150.0
const WALK := 4.2
const S := 2.3                 # escala: o corpo é montado em ~25 m e aumentado para ~58 m
const MODEL := "res://assets/models/chifrudo.glb"

var main
var parts: Array = []          # CPart (todas dá para escalar)
var weak: Array = []           # WeakPoint
var mats: Array = []           # materiais próprios (para virar pedra ao dormir)
var body: Node3D               # pivô do corpo inteiro (balança, sacode, ajoelha)
var legs: Array = []           # {"hip": Node3D, "knee": Node3D, "hoof": CPart, "off": float, "last": float}
var neck: Node3D
var head: Node3D
var eyes: Array = []
var tail: Node3D
var warn_light: OmniLight3D
var ang := 0.0                 # posição no anel
var phase := 0.0
var state := "walk"            # walk, stagger, sleep
var shake_t := 0.0
var warn_t := 0.0
var shake_cd := 6.0
var stagger_t := 0.0
var sleep_t := 0.0
var rider_t := 0.0             # quanto tempo o Tomé está agarrado nele
var roar_cd := 0.0

var FUR := Color("#8f6646")
var FUR2 := Color("#ad7d52")
var STONE := Color("#a59f92")
var MOSS := Color("#4f8f5a")
var HORN := Color("#cfc6b0")

func _ready() -> void:
	ang = 0.35
	if not ColossusSkin.build(self, MODEL):
		_build()
	_place()

func _m(c: Color, rough: float = .95, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	m.set_meta("c0", c)
	mats.append(m)
	return m

## só a caixa de escalada (invisível), para o colosso feito a partir do modelo 3D
func cpart(parent: Node3D, half: Vector3, pos: Vector3) -> CPart:
	var p := CPart.new()
	p.colossus = self
	p.position = pos
	parent.add_child(p)
	p.setup(half)
	parts.append(p)
	return p

func weak_at(p: CPart, local: Vector3, n: Vector3, lbl: String) -> void:
	_weak(p, local, n, lbl)

func own_mat(m: Material) -> Material:
	if m is StandardMaterial3D:
		var d: StandardMaterial3D = m.duplicate()
		# pelo não é metal: sem o mapa de metal ele fica claro como na imagem
		d.metallic = 0.0
		d.metallic_texture = null
		d.roughness = 1.0
		d.albedo_color = Color(1.18, 1.14, 1.1)
		d.set_meta("c0", d.albedo_color)
		mats.append(d)
		return d
	return m

func _part(parent: Node3D, half: Vector3, pos: Vector3, fur := true) -> CPart:
	var p := CPart.new()
	p.colossus = self
	p.position = pos
	parent.add_child(p)
	p.setup(half)
	parts.append(p)
	var base := Mk.mi(Mk.box(half * 2.0), _fur_m if fur else _stone_m, p)
	base.name = "base"
	_dress(p, half, fur)
	return p

var _fur_m: StandardMaterial3D
var _fur2_m: StandardMaterial3D
var _stone_m: StandardMaterial3D
var _moss_m: StandardMaterial3D
var _horn_m: StandardMaterial3D

## pelos, placas de pedra e musgo por cima da caixa (só enfeite; a escalada é na caixa)
func _dress(p: CPart, he: Vector3, fur: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = parts.size() * 97
	var area := he.x * he.y + he.y * he.z + he.x * he.z
	var n := int(clampf(area * .35, 6, 26))
	for i in n:
		var axis := rng.randi() % 3
		var sgn := 1 if rng.randf() < .5 else -1
		if axis == 1 and sgn < 0:
			sgn = 1  # pouco enfeite embaixo
		var q := Vector3(rng.randf_range(-he.x, he.x), rng.randf_range(-he.y, he.y), rng.randf_range(-he.z, he.z))
		q[axis] = he[axis] * sgn
		var nrm := Vector3.ZERO
		nrm[axis] = float(sgn)
		var kind := rng.randf()
		if fur and kind < .6:
			# tufo de pelo comprido caindo
			var tl := rng.randf_range(.9, 2.0)
			var tuft := Mk.mi(Mk.cone(.35, tl, 5), _fur2_m if i % 2 == 0 else _fur_m, p, q + nrm * .1 - Vector3(0, tl * .35, 0))
			tuft.rotation = Vector3(PI + rng.randf_range(-.2, .2), rng.randf() * TAU, rng.randf_range(-.2, .2))
		elif kind < .82:
			# placa de pedra
			var s := Vector3(rng.randf_range(1.0, 2.4), rng.randf_range(1.0, 2.4), rng.randf_range(1.0, 2.4))
			s[axis] = .35
			Mk.mi(Mk.box(s), _stone_m, p, q + nrm * .12, Vector3(0, 0, rng.randf_range(-.2, .2)))
		else:
			# musgo
			var s2 := Vector3(rng.randf_range(1.2, 2.8), rng.randf_range(1.2, 2.8), rng.randf_range(1.2, 2.8))
			s2[axis] = .25
			Mk.mi(Mk.box(s2), _moss_m, p, q + nrm * .1)

func _build() -> void:
	_fur_m = _m(FUR)
	_fur2_m = _m(FUR2)
	_stone_m = _m(STONE)
	_moss_m = _m(MOSS)
	_horn_m = _m(HORN, .7)
	body = Node3D.new()
	body.scale = Vector3.ONE * S
	add_child(body)
	# tronco, ombros (corcova) e anca
	var torso := _part(body, Vector3(4.0, 3.5, 9.0), Vector3(0, 14.5, 0))
	# (as partes de cima são mais estreitas que as de baixo: subindo, não há teto para atrapalhar)
	_part(body, Vector3(3.6, 2.2, 3.2), Vector3(0, 18.6, 4.5))
	_part(body, Vector3(3.8, 1.6, 3.0), Vector3(0, 18.2, -5.0), false)
	# plantinhas e arvorezinhas nas costas
	for i in 7:
		var x := -2.6 + (i % 3) * 2.6
		var z := -6.0 + i * 2.0
		var tr := Node3D.new()
		tr.position = Vector3(x, 3.5, z)
		torso.add_child(tr)
		Mk.mi(Mk.cyl(.05, .1, 1.0, 5), _m(Color("#6b5040")), tr, Vector3(0, .5, 0))
		Mk.mi(Mk.sphere(.4 + (i % 2) * .15, 8), _m(Color("#3fc1b0") if i % 2 == 0 else Color("#5fbf6a"), .8, .1), tr, Vector3(0, 1.15, 0))
	# pernas
	var hips := [Vector3(-2.7, 11.1, 6.2), Vector3(2.7, 11.1, 6.2), Vector3(-2.7, 11.1, -6.2), Vector3(2.7, 11.1, -6.2)]
	var offs := [0.0, PI, PI, 0.0]
	for i in 4:
		var hip := Node3D.new()
		hip.position = hips[i]
		body.add_child(hip)
		var up := _part(hip, Vector3(1.35, 2.6, 1.55), Vector3(0, -2.6, 0))
		var knee := Node3D.new()
		knee.position = Vector3(0, -5.2, 0)
		hip.add_child(knee)
		var low := _part(knee, Vector3(1.1, 2.6, 1.3), Vector3(0, -2.6, 0))
		var hoof := _part(knee, Vector3(1.45, .5, 1.75), Vector3(0, -5.4, .25), false)
		hoof.get_node("base").material_override = _m(Color("#3a3a3e"), .6)
		legs.append({"hip": hip, "knee": knee, "hoof": hoof, "off": offs[i], "last": 0.0, "up": up, "low": low})
	# pescoço e cabeça
	neck = Node3D.new()
	neck.position = Vector3(0, 16.0, 8.0)
	neck.rotation.x = -.62
	body.add_child(neck)
	var nk := _part(neck, Vector3(1.8, 1.8, 3.6), Vector3(0, 0, 3.2))
	head = Node3D.new()
	head.position = Vector3(0, .4, 6.6)
	head.rotation.x = .75
	neck.add_child(head)
	var hd := _part(head, Vector3(2.2, 2.0, 2.8), Vector3(0, .4, 2.0))
	var muzzle := _part(head, Vector3(1.5, 1.2, 1.3), Vector3(0, -.4, 5.0), false)
	muzzle.get_node("base").material_override = _m(Color("#5a4636"), .9)
	# olhos (brilham vermelho antes de sacudir)
	for sx in [-1.6, 1.6]:
		var e := Mk.mi(Mk.sphere(.42, 10), _m(Color("#ffcf6a"), .3, 2.5), head, Vector3(sx * 1.05, 1.2, 3.9))
		eyes.append(e)
	# chifres curvos de pedra (pontas com gancho)
	for sx in [-1.0, 1.0]:
		var prev := Vector3(sx * 1.8, 2.3, 1.8)
		var dir := Vector3(sx * .9, .7, -.3).normalized()
		var r := .8
		for k in 6:
			var nxt: Vector3 = prev + dir * 1.8
			var seg := Mk.mi(Mk.cyl(r * .78, r, 2.0, 8), _horn_m, head, (prev + nxt) / 2.0)
			seg.basis = World.axis_basis(dir)
			prev = nxt
			r *= .8
			dir = (dir + Vector3(0, -.32, -.18) + Vector3(sx * .05, 0, 0)).normalized()
		Mk.hook_point(head, prev, "colossus")
	# cauda
	var tail := Node3D.new()
	tail.position = Vector3(0, 16.5, -9.0)
	body.add_child(tail)
	Mk.mi(Mk.cyl(.3, .8, 5.0, 6), _fur_m, tail, Vector3(0, -2.2, -1.2), Vector3(-.5, 0, 0))
	Mk.mi(Mk.sphere(1.0, 8), _fur2_m, tail, Vector3(0, -4.4, -2.4))
	# pontos de gancho no pelo (fora da superfície)
	for lg in legs:
		var lowp: CPart = lg.low
		var upp: CPart = lg.up
		var sx2: float = 1.0 if lowp.get_parent().get_parent().position.x > 0 else -1.0
		Mk.hook_point(lowp, Vector3(sx2 * (lowp.he.x + .4), .6, 0), "colossus")
		Mk.hook_point(upp, Vector3(sx2 * (upp.he.x + .4), 0, 0), "colossus")
	for z in [-5.5, 0.0, 5.5]:
		Mk.hook_point(torso, Vector3(torso.he.x + .4, -.5, z), "colossus")
		Mk.hook_point(torso, Vector3(-torso.he.x - .4, -.5, z), "colossus")
	Mk.hook_point(nk, Vector3(0, nk.he.y + .4, 0), "colossus")
	# os três pontos fracos (peças da nave)
	_weak(legs[0].low, Vector3(0, 1.6, legs[0].low.he.z), Vector3(0, 0, 1), "joelho")
	_weak(nk, Vector3(0, nk.he.y, -1.4), Vector3(0, 1, 0), "nuca")
	_weak(hd, Vector3(0, 1.0, hd.he.z), Vector3(0, 0, 1), "testa")
	# cada parte do corpo vira poucas malhas (pelo, pedra, musgo), menos as peças da nave
	_bake_parts.call_deferred()

func _bake_parts() -> void:
	for p in parts:
		Mk.bake(p, weak)
	Mk.bake(head, parts + weak)

func _weak(p: CPart, local: Vector3, n: Vector3, lbl: String) -> void:
	var w := WeakPoint.new()
	w.position = local
	w.label = lbl
	w.colossus = self
	p.add_child(w)
	w.build(n)
	weak.append(w)

func _place() -> void:
	position = Vector3(cos(ang) * RING, 0, sin(ang) * RING)
	# anda no sentido anti-horário: a frente (+Z local) aponta na tangente
	var tangent := Vector3(-sin(ang), 0, cos(ang))
	rotation.y = atan2(tangent.x, tangent.z)

func awake() -> bool:
	return state != "sleep"

func in_battle(p: Vector3) -> bool:
	if not awake():
		return false
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	return d < 95.0

func shaking() -> bool:
	return shake_t > 0.0

func pieces_left() -> int:
	var n := 0
	for w in weak:
		if not w.done:
			n += 1
	return n

func _physics_process(dt: float) -> void:
	var climbing: bool = main != null and main.player != null and main.player.state == "climb"
	roar_cd = max(0.0, roar_cd - dt)
	match state:
		"walk":
			var v := WALK * (.45 if climbing else 1.0)
			ang += v / RING * dt
			_place()
			phase += dt * v * .55 / S
			_gait(1.0)
			_shake_logic(dt, climbing)
		"stagger":
			stagger_t -= dt
			body.rotation.x = lerpf(body.rotation.x, .1, .05)
			_gait(0.0)
			if stagger_t <= 0.0:
				state = "walk"
		"sleep":
			sleep_t += dt
			var u := clampf(sleep_t / 6.0, 0.0, 1.0)
			body.position.y = lerpf(body.position.y, -4.2 * S, .02)
			body.rotation.z = lerpf(body.rotation.z, 0.0, .05)
			body.rotation.x = lerpf(body.rotation.x, .06, .02)
			for lg in legs:
				lg.hip.rotation.x = lerpf(lg.hip.rotation.x, -1.0 if lg.hip.position.z > 0 else 1.0, .02)
				lg.knee.rotation.x = lerpf(lg.knee.rotation.x, 1.6 if lg.hip.position.z > 0 else -1.6, .02)
			neck.rotation.x = lerpf(neck.rotation.x, -.05, .02)
			for m in mats:
				var c0: Color = m.get_meta("c0")
				var stone := Color(.55, .56, .54).lerp(c0, .25)
				m.albedo_color = c0.lerp(stone, u)
				if m.emission_enabled:
					m.emission_energy_multiplier = lerpf(m.emission_energy_multiplier, 0.0, .03)
	if state != "sleep":
		# sacudida: o corpo inteiro balança de um lado para o outro
		if shake_t > 0.0:
			shake_t -= dt
			var env := clampf(shake_t, 0.0, 1.0)
			body.rotation.z = sin(Time.get_ticks_msec() * .011) * .13 * env
			body.rotation.x = sin(Time.get_ticks_msec() * .007) * .05 * env
		else:
			body.rotation.z = lerpf(body.rotation.z, 0.0, .1)
			if state == "walk":
				body.rotation.x = lerpf(body.rotation.x, 0.0, .1)
		var red := warn_t > 0.0 or shake_t > 0.0
		if warn_light:
			warn_light.light_energy = lerpf(warn_light.light_energy, 9.0 if red else 0.0, .15)
		if tail:
			tail.rotation.y = sin(Time.get_ticks_msec() * .0021) * .25
			tail.rotation.x = sin(Time.get_ticks_msec() * .0013) * .08
		for e in eyes:
			var m2: StandardMaterial3D = e.material_override
			m2.emission = Color(1, .2, .1) if red else Color("#ffcf6a")
			m2.albedo_color = m2.emission
		# a cabeça acompanha o Tomé quando ele está perto
		if main and main.player:
			var lp: Vector3 = head.global_transform.affine_inverse() * main.player.global_position
			var want := clampf(atan2(lp.x, lp.z) * .3, -.35, .35)
			head.rotation.y = lerpf(head.rotation.y, want, .02)
	for p in parts:
		p.tick()

func _gait(k: float) -> void:
	for lg in legs:
		var s := sin(phase + float(lg.off))
		lg.hip.rotation.x = lerpf(lg.hip.rotation.x, s * .3 * k, .2)
		var front: bool = lg.hip.position.z > 0
		var bend: float = -max(0.0, sin(phase + float(lg.off) + .7)) * .55 * k
		lg.knee.rotation.x = lerpf(lg.knee.rotation.x, bend if front else -bend, .2)
		# pisada: o seno passa de positivo para negativo
		if k > 0.0 and float(lg.last) > 0.0 and s <= 0.0:
			_footfall(lg)
		lg.last = s
	body.position.y = abs(sin(phase)) * .3 * S * k

func _footfall(lg: Dictionary) -> void:
	var hoof: CPart = lg.hoof
	var fp := hoof.global_position
	if main == null:
		return
	var pl = main.player
	var d := Vector2(pl.global_position.x - fp.x, pl.global_position.z - fp.z).length()
	main.cam.add_shake(clampf(1.0 - d / 140.0, 0.0, 1.0) * .7)
	if d < 140:
		main.sfx.play("thud", -2.0 - d * .12, randf_range(.8, .95))
	# pisão: quem está no chão bem embaixo leva o golpe
	if d < 3.0 * S and pl.global_position.y < 4.0 and pl.state in ["ground", "air"]:
		var push := Vector3(pl.global_position.x - fp.x, 0, pl.global_position.z - fp.z).normalized()
		pl.hurt(1, push * 9.0 + Vector3(0, 6, 0))

func _shake_logic(dt: float, climbing: bool) -> void:
	if climbing:
		rider_t += dt
	else:
		rider_t = max(0.0, rider_t - dt * 2.0)
	if warn_t > 0.0:
		warn_t -= dt
		if warn_t <= 0.0:
			shake_t = 2.6
		return
	if shake_t > 0.0:
		return
	shake_cd -= dt
	if climbing and rider_t > 3.0 and shake_cd <= 0.0:
		start_shake()

func start_shake(now: bool = false) -> void:
	shake_cd = randf_range(5.5, 8.0)
	if now:
		shake_t = 1.6
	else:
		warn_t = .9
	if roar_cd <= 0.0 and main:
		main.sfx.play("roar", -4.0, randf_range(.9, 1.05))
		roar_cd = 2.5
	if main:
		main.cam.add_shake(.4)

## o Tomé cravou a picareta num ponto fraco
func stab(w: WeakPoint) -> void:
	var broke := w.hit()
	if main:
		main.sfx.play("stab", 0.0, randf_range(.9, 1.1))
	if broke:
		if main:
			main.sfx.play("piece", 0.0)
			main.sfx.play("roar", 0.0, .8)
			main.cam.add_shake(.8)
		var left := pieces_left()
		piece_taken.emit(left)
		if left == 0:
			state = "sleep"
			sleep_t = 0.0
			shake_t = 0.0
			warn_t = 0.0
			fell_asleep.emit()
		else:
			state = "stagger"
			stagger_t = 3.5
	else:
		start_shake(true)
