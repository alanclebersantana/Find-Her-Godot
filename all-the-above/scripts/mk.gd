extends RefCounted
class_name Mk
## Atalhos para montar formas 3D simples (o protótipo é todo feito de formas; a arte final vem depois).

static var _mats := {}

static func mat(c: Color, rough: float = .85, emit: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [c.to_html(), rough, emit, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func mi(mesh: Mesh, m: Material, parent: Node3D, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation = rot
	n.scale = sc
	parent.add_child(n)
	return n

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func sphere(r: float, segs: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = max(6, segs / 2)
	return s

static func cyl(r_top: float, r_bot: float, h: float, segs: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c

static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c

static func cone(r: float, h: float, segs: int = 10) -> CylinderMesh:
	return cyl(0.0, r, h, segs)

## corpo estático com uma forma de colisão
static func static_shape(parent: Node3D, shape: Shape3D, pos: Vector3, rot: Vector3 = Vector3.ZERO, layer: int = 1) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = layer
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	b.position = pos
	b.rotation = rot
	parent.add_child(b)
	return b

static func box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s

static func cyl_shape(r: float, h: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	return s

static func capsule_shape(r: float, h: float) -> CapsuleShape3D:
	var s := CapsuleShape3D.new()
	s.radius = r
	s.height = h
	return s

## ponto de gancho (brilha de leve); kind: "tree", "colossus", "alien"
static func hook_point(parent: Node3D, pos: Vector3, kind: String) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.set_meta("kind", kind)
	n.add_to_group("hook")
	parent.add_child(n)
	if kind != "alien":
		var g := mi(sphere(.35 if kind == "tree" else .22, 8), mat(Color(1.0, .85, .45) if kind == "tree" else Color(1.0, .55, .3), .5, 2.5 if kind == "tree" else 1.2), n)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.name = "glow"
	return n

## junta as formas paradas debaixo de root numa malha por material (bem menos desenhos por quadro:
## o celular agradece). skip: nós cujos filhos não entram (partes que se mexem, peças da nave...)
static func bake(root: Node3D, skip: Array = []) -> int:
	var groups := {}
	var inv := root.global_transform.affine_inverse()
	var stack: Array = root.get_children()
	var victims: Array = []
	while not stack.is_empty():
		var n = stack.pop_back()
		if n in skip or n is CPUParticles3D:
			continue
		if n is MeshInstance3D and n.mesh is PrimitiveMesh and n.material_override and n.visible:
			var key := "%d|%d" % [n.material_override.get_instance_id(), n.cast_shadow]
			if not groups.has(key):
				groups[key] = {"m": n.material_override, "cs": n.cast_shadow, "list": []}
			groups[key].list.append(n)
			victims.append(n)
		for c in n.get_children():
			if c is Node3D and not (c is CollisionObject3D and c is CPart):
				stack.append(c)
	for k in groups:
		var g: Dictionary = groups[k]
		if g.list.size() < 2:
			victims.erase(g.list[0])
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi_ in g.list:
			var x: Transform3D = inv * mi_.global_transform
			st.append_from(mi_.mesh, 0, x)
		var out := MeshInstance3D.new()
		out.mesh = st.commit()
		out.material_override = g.m
		out.cast_shadow = g.cs
		root.add_child(out)
	for v in victims:
		var keep := false
		for k2 in groups:
			if groups[k2].list.size() < 2 and v in groups[k2].list:
				keep = true
		if not keep:
			v.get_parent().remove_child(v)
			v.free()
	return victims.size()
