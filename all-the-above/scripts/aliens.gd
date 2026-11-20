extends Node3D
class_name Aliens
## Alienígenas pequenos da travessia: caranguejo (casco turquesa), morcego-água-viva (voa e dá rasante)
## e saltador (peludo, um olho só). Só aparecem quando não há colosso em batalha.

var main
var list: Array = []
var spots: Array = []
var hidden := false

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# grupos espalhados pelo vale, longe do caminho do colosso
	for d in [[40.0, .3], [62.0, 2.2], [55.0, 4.1], [235.0, 1.0], [250.0, 3.0], [260.0, 5.2], [60.0, 5.6]]:
		var a: float = d[1]
		spots.append(Vector3(cos(a) * d[0], 0, sin(a) * d[0]))
	for i in spots.size():
		var kinds: Array = [["crab", "crab", "jelly"], ["hopper", "crab"], ["jelly", "jelly", "hopper"], ["crab", "hopper", "jelly"], ["hopper", "hopper"], ["crab", "crab", "crab"], ["jelly", "crab"]][i]
		for k in kinds:
			var a := Alien.new()
			a.kind = k
			a.home = spots[i] + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
			a.main = main
			add_child(a)
			list.append(a)

func _physics_process(_dt: float) -> void:
	if main == null or main.state != "play":
		return
	var battle: bool = main.colossus.in_battle(main.player.global_position)
	if battle and not hidden:
		hidden = true
		for a in list:
			a.vanish()
	elif not battle and hidden:
		hidden = false
		for a in list:
			a.respawn_later()

## golpe da picareta numa área
func hit_area(p: Vector3, r: float, dmg: int, dir: Vector3) -> void:
	for a in list:
		var al: Alien = a
		if al.alive() and al.global_position.distance_to(p) < r + al.radius:
			al.hit(dmg, dir)

func alive_count() -> int:
	var n := 0
	for a in list:
		if a.alive():
			n += 1
	return n


class Alien extends Node3D:
	var main
	var kind := "crab"
	var home := Vector3.ZERO
	var hp := 2
	var vel := Vector3.ZERO
	var st := "idle"         # idle, chase, wind, swoop, stun, dead, gone
	var t := 0.0
	var cd := 0.0
	var flash := 0.0
	var radius := .9
	var model: Node3D
	var glow_mats: Array = []
	var respawn_t := 0.0
	var wander := Vector3.ZERO
	var hook: Node3D

	func _ready() -> void:
		hp = {"crab": 2, "jelly": 1, "hopper": 3}[kind]
		radius = {"crab": 1.0, "jelly": .9, "hopper": .8}[kind]
		position = home + Vector3(0, 5.0 if kind == "jelly" else 0.0, 0)
		model = Node3D.new()
		add_child(model)
		match kind:
			"crab":
				_crab()
			"jelly":
				_jelly()
			"hopper":
				_hopper()
		hook = Mk.hook_point(self, Vector3(0, .8, 0), "alien")
		wander = home

	func _gm(c: Color, emit: float = 0.0, rough: float = .6) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		if emit > 0.0:
			m.emission_enabled = true
			m.emission = Color(c.r, c.g, c.b)
			m.emission_energy_multiplier = emit
			glow_mats.append(m)
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return m

	func _crab() -> void:
		var shell := _gm(Color("#2fb8b0"), .6, .3)
		var dark := _gm(Color("#1d3a44"))
		Mk.mi(Mk.sphere(.75, 14), shell, model, Vector3(0, .6, 0), Vector3.ZERO, Vector3(1.3, .55, 1.0))
		Mk.mi(Mk.sphere(.6, 10), dark, model, Vector3(0, .45, 0), Vector3.ZERO, Vector3(1.25, .4, .95))
		for i in 6:
			var sx := -1.0 if i < 3 else 1.0
			var z := -.4 + (i % 3) * .4
			Mk.mi(Mk.cyl(.04, .07, .9, 5), dark, model, Vector3(sx * .85, .3, z), Vector3(0, 0, sx * .9))
		for sx in [-1.0, 1.0]:
			Mk.mi(Mk.sphere(.25, 8), shell, model, Vector3(sx * .55, .55, .85), Vector3.ZERO, Vector3(1, .7, 1.4))
		for sx in [-.18, .18]:
			Mk.mi(Mk.sphere(.08, 6), _gm(Color("#d6fff7"), 2.0), model, Vector3(sx, .9, .55))

	func _jelly() -> void:
		var dome := _gm(Color(.7, .5, 1.0, .75), .8, .2)
		Mk.mi(Mk.sphere(.65, 14), dome, model, Vector3.ZERO, Vector3.ZERO, Vector3(1, .75, 1))
		for sx in [-1.0, 1.0]:
			var w := Mk.mi(Mk.box(Vector3(1.3, .05, .7)), _gm(Color(.6, .4, .95, .7), .4), model, Vector3(sx * .95, .1, 0))
			w.name = "wing_l" if sx < 0 else "wing_r"
		for i in 6:
			var a := TAU * i / 6.0
			Mk.mi(Mk.cyl(.03, .06, 1.1, 4), _gm(Color("#c7a6ff"), 1.5), model, Vector3(cos(a) * .35, -.75, sin(a) * .35))
		Mk.mi(Mk.sphere(.1, 6), _gm(Color("#ffffff"), 2.0), model, Vector3(0, .1, .6))

	func _hopper() -> void:
		var fur := _gm(Color("#e0843a"), 0.0, .95)
		var teal := _gm(Color("#2f9f9a"), .4)
		Mk.mi(Mk.sphere(.7, 14), fur, model, Vector3(0, .75, 0))
		Mk.mi(Mk.sphere(.32, 10), _gm(Color("#ffffff"), .2, .2), model, Vector3(0, .9, .52))
		Mk.mi(Mk.sphere(.15, 8), _gm(Color("#1a1a2a")), model, Vector3(0, .9, .78))
		for sx in [-1.0, 1.0]:
			Mk.mi(Mk.cone(.16, .9, 6), teal, model, Vector3(sx * .35, 1.6, -.1), Vector3(-.3, 0, -sx * .35))
			Mk.mi(Mk.sphere(.2, 6), fur, model, Vector3(sx * .4, .15, .2), Vector3.ZERO, Vector3(1, .6, 1.5))
		for i in 4:
			Mk.mi(Mk.cone(.1, .5, 4), teal, model, Vector3(0, .9 - i * .12, -.75 - i * .12), Vector3(-1.2, 0, 0))

	func alive() -> bool:
		return st != "dead" and st != "gone"

	func vanish() -> void:
		if not alive():
			return
		st = "gone"
		_poof()
		visible = false
		hook.remove_from_group("hook")

	func respawn_later() -> void:
		if st == "gone":
			respawn_t = 3.0

	func hit(dmg: int, dir: Vector3) -> void:
		if not alive():
			return
		hp -= dmg
		flash = .2
		vel = dir.normalized() * 9.0 + Vector3(0, 4, 0)
		st = "stun"
		t = .6
		main.sfx.play("hit", -2.0, randf_range(1.0, 1.25))
		main.cam.add_shake(.12)
		if hp <= 0:
			st = "dead"
			_poof()
			visible = false
			hook.remove_from_group("hook")
			respawn_t = 25.0

	## o gancho puxou o bicho até o Tomé
	func yank(pl) -> void:
		if not alive():
			return
		var to: Vector3 = pl.center() - global_position
		vel = to.normalized() * min(16.0, to.length() * 2.2) + Vector3(0, 3, 0)
		st = "stun"
		t = 1.0
		main.sfx.play("hook", -4.0, .8)

	func _poof() -> void:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = true
		p.amount = 16
		p.lifetime = .7
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.0
		p.mesh = Mk.sphere(.15, 5)
		p.material_override = Mk.mat(Color("#bff7ef"), .5, 2.0)
		get_parent().add_child(p)
		p.global_position = global_position + Vector3(0, .7, 0)
		get_tree().create_timer(1.5).timeout.connect(p.queue_free)

	func _physics_process(dt: float) -> void:
		if main == null or main.state != "play":
			return
		t -= dt
		cd = max(0.0, cd - dt)
		flash = max(0.0, flash - dt)
		for m in glow_mats:
			m.emission_energy_multiplier = (4.0 if st == "wind" or flash > 0.0 else 1.0)
		if st == "dead" or st == "gone":
			respawn_t -= dt
			if respawn_t <= 0.0 and respawn_t > -999.0 and not main.aliens.hidden:
				var pl0 = main.player
				if pl0.global_position.distance_to(home) > 40.0 or st == "gone":
					_revive()
			return
		var pl = main.player
		var to: Vector3 = pl.global_position - global_position
		var flat := Vector3(to.x, 0, to.z)
		var d := flat.length()
		match kind:
			"crab":
				_crab_ai(dt, pl, flat, d)
			"jelly":
				_jelly_ai(dt, pl, to, d)
			"hopper":
				_hopper_ai(dt, pl, flat, d)
		# encostou no Tomé sem estar atordoado: machuca
		if st in ["chase", "swoop", "hop"] and global_position.distance_to(pl.center()) < radius + .6 and pl.state != "climb":
			pl.hurt(1, flat.normalized() * 6.0 + Vector3(0, 4, 0))
			cd = 1.4
			if kind == "jelly":
				st = "rise"
		if flat.length() > .1 and st != "stun":
			rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), .15)

	func _revive() -> void:
		hp = {"crab": 2, "jelly": 1, "hopper": 3}[kind]
		st = "idle"
		visible = true
		position = home + Vector3(0, 5.0 if kind == "jelly" else 0.0, 0)
		vel = Vector3.ZERO
		if not hook.is_in_group("hook"):
			hook.add_to_group("hook")
		respawn_t = -9999.0

	func _ground_move(dt: float) -> void:
		vel.y -= 24.0 * dt
		position += vel * dt
		if position.y < 0.0:
			position.y = 0.0
			vel.y = 0.0
			vel.x *= .8
			vel.z *= .8

	func _crab_ai(dt: float, pl, flat: Vector3, d: float) -> void:
		match st:
			"stun":
				_ground_move(dt)
				if t <= 0.0:
					st = "chase"
			"idle":
				if position.distance_to(wander) < 1.0 or t <= 0.0:
					wander = home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
					t = 3.0
				var w := (wander - position)
				w.y = 0
				vel = w.normalized() * 1.5
				_ground_move(dt)
				if d < 22.0:
					st = "chase"
			"chase":
				vel.x = flat.normalized().x * 4.2
				vel.z = flat.normalized().z * 4.2
				_ground_move(dt)
				model.position.y = abs(sin(Time.get_ticks_msec() * .02)) * .08
				if d < 2.0 and cd <= 0.0:
					st = "wind"
					t = .5
				elif d > 32.0:
					st = "idle"
			"wind":
				vel = Vector3.ZERO
				if t <= 0.0:
					if d < 2.4:
						pl.hurt(1, flat.normalized() * 6.0 + Vector3(0, 4, 0))
					cd = 1.2
					st = "chase"

	func _jelly_ai(dt: float, pl, to: Vector3, d: float) -> void:
		var flap := sin(Time.get_ticks_msec() * .015)
		var wl := model.get_node_or_null("wing_l")
		var wr := model.get_node_or_null("wing_r")
		if wl:
			wl.rotation.z = flap * .6
			wr.rotation.z = -flap * .6
		match st:
			"stun":
				position += vel * dt
				vel *= .92
				if t <= 0.0:
					st = "rise"
			"idle":
				var a := Time.get_ticks_msec() * .0006 + home.x
				var tgt := home + Vector3(cos(a) * 6.0, 5.0 + sin(a * 2.0), sin(a) * 6.0)
				position = position.lerp(tgt, .02)
				if d < 25.0:
					st = "chase"
			"chase", "rise":
				var tgt2: Vector3 = pl.global_position + Vector3(-to.x, 0, -to.z).normalized() * 6.0 + Vector3(0, 4.5, 0)
				position = position.lerp(tgt2, .03)
				if st == "chase" and cd <= 0.0 and d < 12.0:
					st = "wind"
					t = .6
				if st == "rise" and t <= -1.2:
					st = "chase"
					cd = 2.0
				if d > 34.0:
					st = "idle"
			"wind":
				if t <= 0.0:
					st = "swoop"
					vel = (pl.center() - global_position).normalized() * 13.0
					t = 1.0
			"swoop":
				position += vel * dt
				if t <= 0.0 or position.y < .6:
					st = "rise"
					t = 0.0

	func _hopper_ai(dt: float, pl, flat: Vector3, d: float) -> void:
		match st:
			"stun":
				_ground_move(dt)
				if t <= 0.0 and position.y <= 0.01:
					st = "chase"
			"idle":
				_ground_move(dt)
				if d < 20.0:
					st = "chase"
			"chase", "hop":
				_ground_move(dt)
				if position.y <= 0.01:
					st = "chase"
					if t <= 0.0:
						vel = flat.normalized() * 6.5 + Vector3(0, 7.0, 0)
						st = "hop"
						t = 1.1
				if d > 30.0 and position.y <= .01:
					st = "idle"
		model.scale = Vector3(1, 1.0 + clampf(vel.y * .03, -.2, .25), 1)
