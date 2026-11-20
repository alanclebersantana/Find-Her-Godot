extends AnimatableBody3D
class_name CPart
## Um pedaço do corpo do colosso (caixa): dá para escalar em qualquer face.
## A conta da escalada é feita direto na caixa (ponto mais perto da superfície e a face).

var he := Vector3.ONE          # metade do tamanho
var climb := true
var colossus                   # Colossus
var prev_xf := Transform3D.IDENTITY
var cur_xf := Transform3D.IDENTITY

func setup(half: Vector3) -> void:
	he = half
	collision_layer = 2
	collision_mask = 0
	sync_to_physics = false
	var cs := CollisionShape3D.new()
	cs.shape = Mk.box_shape(half * 2.0)
	add_child(cs)

func tick() -> void:
	prev_xf = cur_xf
	cur_xf = global_transform

## ponto da superfície mais perto de p (mundo); devolve local, eixo e sinal da face, distância
func closest(p: Vector3) -> Dictionary:
	var l: Vector3 = global_transform.affine_inverse() * p
	var q := Vector3(clampf(l.x, -he.x, he.x), clampf(l.y, -he.y, he.y), clampf(l.z, -he.z, he.z))
	var axis := 0
	var sgn := 1
	if q.is_equal_approx(l):
		# dentro: empurra para a face mais perto
		var best := -1e9
		for a in 3:
			var r: float = abs(l[a]) - he[a]
			if r > best:
				best = r
				axis = a
		sgn = 1 if l[axis] >= 0 else -1
		q[axis] = he[axis] * sgn
	else:
		var best2 := -1e9
		for a in 3:
			var r2: float = abs(l[a]) - he[a]
			if r2 > best2:
				best2 = r2
				axis = a
		sgn = 1 if l[axis] >= 0 else -1
		q[axis] = he[axis] * sgn
	var world: Vector3 = global_transform * q
	return {"local": q, "axis": axis, "sgn": sgn, "dist": world.distance_to(p), "pt": world, "n": normal_world(axis, sgn)}

func normal_world(axis: int, sgn: int) -> Vector3:
	var n := Vector3.ZERO
	n[axis] = float(sgn)
	return (global_transform.basis * n).normalized()

func to_world(local: Vector3) -> Vector3:
	return global_transform * local

## velocidade de um ponto local (para o Tomé sair voando junto quando solta)
func point_velocity(local: Vector3, dt: float) -> Vector3:
	if dt <= 0.0:
		return Vector3.ZERO
	return (cur_xf * local - prev_xf * local) / dt
