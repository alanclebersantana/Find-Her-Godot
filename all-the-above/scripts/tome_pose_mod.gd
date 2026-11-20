extends SkeletonModifier3D
class_name TomePoseMod
## Por cima da animação: aponta braços e pernas do Tomé para direções escolhidas,
## para as poses que não vêm prontas no modelo (no ar, pendurado na corda, escalando).
## As direções são no espaço do Tomé: +Z frente, +Y cima, +X lado esquerdo dele.

var model                      # TomeModel
var w := 0.0                   # quanto a pose feita à mão vale (0 = só a animação)
var bones := {}
var _ok := false

const CHAINS := {
	"arm_l": ["mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand"],
	"arm_r": ["mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand"],
	"leg_l": ["mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot"],
	"leg_r": ["mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot"],
}

func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_ok = true
	for k in CHAINS:
		var ids := []
		for n in CHAINS[k]:
			var i := sk.find_bone(n)
			if i < 0:
				_ok = false
			ids.append(i)
		bones[k] = ids

func _targets() -> Dictionary:
	var t: float = model.t
	var sp: float = clampf(model.speed, 0.0, 1.0)
	match model.pose:
		"swing":
			var s := sin(t * 2.2)
			return {
				"arm_l": [Vector3(.18, 1, .12), Vector3(.04, 1, .08)],
				"arm_r": [Vector3(-.18, 1, .12), Vector3(-.04, 1, .08)],
				"leg_l": [Vector3(.06, -1, .35 + .2 * s), Vector3(0, -1, -.15)],
				"leg_r": [Vector3(-.06, -1, .25 - .2 * s), Vector3(0, -1, -.2)],
			}
		"climb":
			var c := sin(t * 7.0) * sp
			var d := {
				"arm_l": [Vector3(.45, .85 + .25 * c, .45), Vector3(.08, 1, .3)],
				"arm_r": [Vector3(-.45, .85 - .25 * c, .45), Vector3(-.08, 1, .3)],
				"leg_l": [Vector3(.18, -.8, .45 + .3 * c), Vector3(0, -1, -.35)],
				"leg_r": [Vector3(-.18, -.8, .45 - .3 * c), Vector3(0, -1, -.35)],
			}
			if model._pick_t > 0.0:
				# crava a picareta: levanta e desce o braço direito
				var u: float = 1.0 - model._pick_t / .55
				var up := 1.0 - smoothstep(.15, .6, u)
				d["arm_r"] = [Vector3(-.25, lerpf(.1, 1.0, up), lerpf(1.0, .25, up)), Vector3(-.1, lerpf(-.2, 1.0, up), 1.0)]
			return d
		"air":
			return {
				"arm_l": [Vector3(.8, .45, .1), Vector3(.6, .7, .25)],
				"arm_r": [Vector3(-.8, .45, .1), Vector3(-.6, .7, .25)],
				"leg_l": [Vector3(.05, -1, .5), Vector3(0, -1, -.45)],
				"leg_r": [Vector3(-.05, -1, -.1), Vector3(0, -1, -.35)],
			}
	return {}

func _process_modification() -> void:
	if not _ok or model == null:
		return
	var dt := get_process_delta_time() if is_inside_tree() else .016
	var tg := _targets()
	w = move_toward(w, 1.0 if not tg.is_empty() else 0.0, dt * 6.0)
	if w <= 0.001 or tg.is_empty():
		return
	var sk := get_skeleton()
	# do espaço do Tomé para o espaço do esqueleto
	var to_sk: Basis = sk.global_basis.inverse() * (model as Node3D).global_basis
	for k in tg:
		var ids: Array = bones[k]
		var dirs: Array = tg[k]
		for j in 2:
			var a: int = ids[j]
			var b: int = ids[j + 1]
			var ga := sk.get_bone_global_pose(a)
			var gb := sk.get_bone_global_pose(b)
			var cur := gb.origin - ga.origin
			if cur.length() < .0001:
				continue
			cur = cur.normalized()
			var want: Vector3 = (to_sk * (dirs[j] as Vector3)).normalized()
			var goal := cur.slerp(want, w)
			if cur.dot(goal) > .99999:
				continue
			var q := Quaternion(cur, goal)
			sk.set_bone_global_pose(a, Transform3D(Basis(q) * ga.basis, ga.origin))
