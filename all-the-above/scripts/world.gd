extends Node3D
class_name World
## O vale alienígena: chão, paredões em volta, rio, árvores gigantes (galhos com pontos de gancho),
## ruínas, plantas que brilham, a nave caída do Tomé, o santuário com a fogueira e as duas luas.

const COLOSSUS_RING := 150.0   # raio do caminho que o colosso percorre (sem árvores nessa faixa)
var spawn := Vector3(6, 1, 34)
var rng := RandomNumberGenerator.new()
var trees: Array = []          # {"pos", "r", "h"}
var sun: DirectionalLight3D

func _ready() -> void:
	rng.seed = 20261120
	_environment()
	_ground()
	_cliffs()
	_river()
	_trees()
	_ruins()
	_flora()
	_ship()
	_shrine()
	# junta tudo o que é parado (árvores, pedras, ruínas, plantas) em poucas malhas
	Mk.bake.call_deferred(self)

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#1f4f9a")
	sm.sky_horizon_color = Color("#8cc7c0")
	sm.ground_horizon_color = Color("#8cc7c0")
	sm.ground_bottom_color = Color("#36503f")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#9ccfc8")
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.6
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-35), 0)
	sun.light_color = Color("#ffe6c4")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	# duas luas, bem longe no céu
	_moon(Vector3(-620, 420, -900), 120.0, Color("#cfeee6"))
	_moon(Vector3(520, 300, -980), 52.0, Color("#ffc98a"))

func _moon(p: Vector3, r: float, c: Color) -> void:
	var m := Mk.mi(Mk.sphere(r, 32), Mk.mat(c, 1.0, 1.4, true), self, p)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# halo
	var h := Mk.mi(Mk.sphere(r * 1.25, 24), Mk.mat(Color(c.r, c.g, c.b, .12), 1.0, 0.0, true), self, p)
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1100, 1100)
	var g := Mk.mi(pm, Mk.mat(Color("#3d7556"), .95), self)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ws := WorldBoundaryShape3D.new()
	Mk.static_shape(self, ws, Vector3.ZERO)
	# manchas de capim alienígena (azulado e violeta)
	for i in 70:
		var a := rng.randf() * TAU
		var d := rng.randf_range(10, 420)
		var c: Color = [Color("#3f7f78"), Color("#5d9a5c"), Color("#6a6aa0"), Color("#3c6f5a")][i % 4]
		var r := rng.randf_range(8, 30)
		var disc := Mk.mi(Mk.cyl(r, r, .04, 20), Mk.mat(c, 1.0), self, Vector3(cos(a) * d, .02 + i * .0004, sin(a) * d))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _cliffs() -> void:
	# paredões fechando o vale (não dá para sair)
	for i in 40:
		var a := TAU * i / 40.0 + rng.randf_range(-.04, .04)
		var d := rng.randf_range(400, 440)
		var h := rng.randf_range(70, 150)
		var r := rng.randf_range(35, 60)
		var p := Vector3(cos(a) * d, h / 2.0, sin(a) * d)
		var c: Color = [Color("#7a6c86"), Color("#8a7a6e"), Color("#6d7f8c")][i % 3]
		Mk.mi(Mk.cyl(r * .7, r, h, 9), Mk.mat(c, .95), self, p, Vector3(0, rng.randf() * TAU, 0))
		Mk.static_shape(self, Mk.cyl_shape(r, h), p)
		# musgo no topo
		Mk.mi(Mk.cyl(r * .72, r * .75, 3, 9), Mk.mat(Color("#4f8f6a"), 1.0), self, p + Vector3(0, h / 2.0, 0))

func _river() -> void:
	# rio raso atravessando o vale (só visual: dá para andar dentro)
	var pts: Array = []
	for i in 23:
		var z := -440.0 + i * 40.0
		pts.append(Vector3(-180.0 + sin(i * .5) * 60.0, .05, z))
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid := (a + b) / 2.0
		var len := a.distance_to(b)
		var seg := Mk.mi(Mk.box(Vector3(16, .05, len + 4)), Mk.mat(Color("#3fa0c8"), .1, .25), self, mid)
		seg.look_at(b + Vector3(0, .05, 0), Vector3.UP)
		seg.position = mid
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _trees() -> void:
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 2000:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(22, 330)
		if d > COLOSSUS_RING - 45 and d < COLOSSUS_RING + 45:
			continue
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if p.distance_to(spawn) < 14 or p.distance_to(Vector3(34, 0, 62)) < 22:
			continue
		var ok := true
		for t in trees:
			if p.distance_to(t.pos) < 26:
				ok = false
				break
		if not ok:
			continue
		_tree(p, rng.randf_range(24, 38))
		placed += 1

func _tree(p: Vector3, h: float) -> void:
	var root := Node3D.new()
	root.position = p
	add_child(root)
	var rb := rng.randf_range(2.2, 3.0)
	var bark := Mk.mat([Color("#6b4f63"), Color("#5e5470"), Color("#6d5a4a")][rng.randi() % 3], .95)
	Mk.mi(Mk.cyl(rb * .55, rb, h, 10), bark, root, Vector3(0, h / 2.0, 0))
	Mk.static_shape(root, Mk.cyl_shape(rb * .8, h), Vector3(0, h / 2.0, 0))
	# raízes
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf()
		Mk.mi(Mk.cyl(.3, rb * .6, 5, 6), bark, root, Vector3(cos(a) * rb, 1.2, sin(a) * rb), Vector3(cos(a) * .9, 0, -sin(a) * .9))
	# copa (bolas turquesa e violeta)
	var leaf_cols := [Color("#3fc1b0"), Color("#7a6ad8"), Color("#4fd6a0"), Color("#5aa8e0")]
	var lc: Color = leaf_cols[rng.randi() % leaf_cols.size()]
	for i in 4:
		var off := Vector3(rng.randf_range(-6, 6), rng.randf_range(-2, 4), rng.randf_range(-6, 6))
		var r := rng.randf_range(5, 8)
		Mk.mi(Mk.sphere(r, 14), Mk.mat(lc, .8, .15), root, Vector3(0, h, 0) + off)
	# galhos grossos com ponto de gancho na ponta (e dá para ficar em pé neles)
	var yaw0 := rng.randf() * TAU
	for i in 3:
		var bh := h * (.42 + i * .15)
		var yaw := yaw0 + i * 2.2 + rng.randf_range(-.3, .3)
		var bl := rng.randf_range(9, 13)
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var mid := dir * (bl / 2.0 + rb * .5) + Vector3(0, bh, 0)
		var br := Mk.mi(Mk.cyl(.55, .9, bl, 8), bark, root, mid)
		br.basis = axis_basis(dir)
		var cs := Mk.static_shape(root, Mk.capsule_shape(.8, bl), mid)
		cs.basis = axis_basis(dir)
		cs.name = "branch"
		var tip := dir * (bl + rb * .5 - .6) + Vector3(0, bh - .9, 0)
		Mk.hook_point(root, tip, "tree")
		# tufo de folhas na ponta
		Mk.mi(Mk.sphere(2.4, 10), Mk.mat(lc, .8, .15), root, tip + Vector3(0, 1.6, 0))
	trees.append({"pos": p, "r": rb, "h": h})

func _ruins() -> void:
	for i in 9:
		var a := rng.randf() * TAU
		var d := rng.randf_range(40, 260)
		if d > COLOSSUS_RING - 40 and d < COLOSSUS_RING + 40:
			d += 90
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		var root := Node3D.new()
		root.position = p
		root.rotation.y = rng.randf() * TAU
		add_child(root)
		var stone := Mk.mat(Color("#9a9488"), .95)
		var moss := Mk.mat(Color("#4f8f6a"), 1.0)
		var ph := rng.randf_range(9, 16)
		for sx in [-5.0, 5.0]:
			Mk.mi(Mk.box(Vector3(2.4, ph, 2.4)), stone, root, Vector3(sx, ph / 2.0, 0))
			Mk.static_shape(root, Mk.box_shape(Vector3(2.4, ph, 2.4)), Vector3(sx, ph / 2.0, 0))
		if i % 3 != 2:
			Mk.mi(Mk.box(Vector3(13, 2.2, 3)), stone, root, Vector3(0, ph + 1.1, 0))
			Mk.mi(Mk.box(Vector3(13.2, .5, 3.2)), moss, root, Vector3(0, ph + 2.3, 0))
			Mk.static_shape(root, Mk.box_shape(Vector3(13, 2.6, 3)), Vector3(0, ph + 1.2, 0))
			Mk.hook_point(root, Vector3(0, ph - .4, 0), "tree")
		else:
			# arco quebrado: um bloco caído
			Mk.mi(Mk.box(Vector3(6, 2.2, 3)), stone, root, Vector3(2, 1.1, 4), Vector3(0, .5, .1))
			Mk.static_shape(root, Mk.box_shape(Vector3(6, 2.2, 3)), Vector3(2, 1.1, 4), Vector3(0, .5, .1))

func _flora() -> void:
	# bulbos que brilham e talos altos
	for i in 120:
		var a := rng.randf() * TAU
		var d := rng.randf_range(8, 380)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if i % 3 == 0:
			var h := rng.randf_range(2, 4.5)
			Mk.mi(Mk.cyl(.06, .12, h, 5), Mk.mat(Color("#3f7f60"), 1.0), self, p + Vector3(0, h / 2.0, 0))
			var bulb := Mk.mi(Mk.sphere(.35, 8), Mk.mat([Color("#7ff2e0"), Color("#d08aff"), Color("#ffd36a")][i % 3], .4, 2.0), self, p + Vector3(0, h, 0))
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			var r := rng.randf_range(.5, 1.4)
			Mk.mi(Mk.sphere(r, 8), Mk.mat([Color("#2f8f7a"), Color("#6a5ab0"), Color("#3a9f5a")][i % 3], .9, .1), self, p + Vector3(0, r * .5, 0), Vector3.ZERO, Vector3(1, .6, 1))
	# pedras soltas
	for i in 40:
		var a := rng.randf() * TAU
		var d := rng.randf_range(15, 380)
		var r := rng.randf_range(.8, 3.0)
		var p := Vector3(cos(a) * d, r * .4, sin(a) * d)
		Mk.mi(Mk.sphere(r, 7), Mk.mat(Color("#8b8578"), .95), self, p, Vector3(rng.randf(), rng.randf(), 0), Vector3(1.2, .7, 1))
		if r > 1.6:
			Mk.static_shape(self, Mk.box_shape(Vector3(r * 1.8, r * 1.0, r * 1.6)), p)

func _ship() -> void:
	# a nave do Tomé, caída num morrinho, soltando fumaça
	var root := Node3D.new()
	root.position = Vector3(34, 0, 62)
	root.rotation = Vector3(0, .7, 0)
	add_child(root)
	Mk.mi(Mk.sphere(9, 16), Mk.mat(Color("#5d8f5e"), 1.0), root, Vector3(0, -5, 0), Vector3.ZERO, Vector3(1.6, 1, 1.4))
	var hull := Mk.mat(Color("#c9ccd2"), .35)
	var body := Mk.mi(Mk.capsule(2.2, 11), hull, root, Vector3(0, 3.2, 0), Vector3(PI / 2.0 - .25, 0, .35))
	Mk.mi(Mk.sphere(1.7, 12), Mk.mat(Color("#7fd8ff"), .1, .6), root, Vector3(0, 4.6, 4.2))
	Mk.mi(Mk.box(Vector3(9, .35, 3)), hull, root, Vector3(-1, 2.6, -.5), Vector3(0, 0, .5))
	Mk.mi(Mk.box(Vector3(4, .35, 2.6)), Mk.mat(Color("#8a8d94"), .5), root, Vector3(4, 1.4, -1), Vector3(.3, .5, -.9))
	Mk.mi(Mk.cyl(1.0, 1.4, 2.2, 10), Mk.mat(Color("#555a62"), .6), root, Vector3(0, 2.2, -5.4), Vector3(PI / 2.0 - .25, 0, .35))
	Mk.static_shape(root, Mk.box_shape(Vector3(5, 5, 12)), Vector3(0, 2.5, 0), Vector3(-.25, 0, .35))
	var smoke := CPUParticles3D.new()
	smoke.amount = 40
	smoke.lifetime = 6.0
	smoke.direction = Vector3(0.2, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 3.5
	smoke.gravity = Vector3(.6, .4, 0)
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 4.5
	smoke.mesh = Mk.sphere(.6, 6)
	smoke.material_override = Mk.mat(Color(.35, .35, .38, .55), 1.0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, .4))
	curve.add_point(Vector2(1, 1.6))
	smoke.scale_amount_curve = curve
	smoke.position = Vector3(0, 3.5, -5.6)
	root.add_child(smoke)

func _shrine() -> void:
	# santuário: anel de pedras e a fogueira onde o Tomé volta
	var root := Node3D.new()
	root.position = spawn - Vector3(0, 1, 0) + Vector3(-4, 0, -4)
	add_child(root)
	for i in 8:
		var a := TAU * i / 8.0
		var h := 2.0 + (i % 3) * .8
		Mk.mi(Mk.box(Vector3(1.2, h, .9)), Mk.mat(Color("#a19a8c"), .95), root, Vector3(cos(a) * 6, h / 2.0, sin(a) * 6), Vector3(0, -a, 0))
	Mk.mi(Mk.cyl(1.2, 1.4, .4, 10), Mk.mat(Color("#5a5650"), 1.0), root, Vector3(0, .2, 0))
	var fire := CPUParticles3D.new()
	fire.amount = 30
	fire.lifetime = .9
	fire.direction = Vector3.UP
	fire.spread = 15.0
	fire.initial_velocity_min = 1.0
	fire.initial_velocity_max = 2.2
	fire.gravity = Vector3(0, 1.5, 0)
	fire.scale_amount_min = .5
	fire.scale_amount_max = 1.0
	fire.mesh = Mk.sphere(.25, 6)
	fire.material_override = Mk.mat(Color("#ffb347"), .5, 3.0, true)
	fire.position = Vector3(0, .5, 0)
	root.add_child(fire)
	var l := OmniLight3D.new()
	l.light_color = Color("#ffb060")
	l.light_energy = 2.0
	l.omni_range = 12.0
	l.position = Vector3(0, 1.5, 0)
	root.add_child(l)

## base cujo eixo Y aponta para dir (cilindros e cápsulas deitados)
static func axis_basis(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.UP if abs(y.y) < .95 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

## chão mais alto embaixo de um ponto (para os bichos andarem por cima de pedras grandes)
func ground_y(_p: Vector3) -> float:
	return 0.0
