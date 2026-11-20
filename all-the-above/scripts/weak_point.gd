extends Node3D
class_name WeakPoint
## Ponto fraco: uma peça da nave cravada no colosso, brilhando. Três picaretadas arrancam.

var hp := 3
var label := ""
var colossus
var glow: MeshInstance3D
var shard: MeshInstance3D
var light: OmniLight3D
var flash := 0.0
var done := false

func build(normal_local: Vector3) -> void:
	# a peça metálica sai da superfície na direção da face
	var holder := Node3D.new()
	add_child(holder)
	holder.basis = World.axis_basis(normal_local)
	shard = Mk.mi(Mk.cyl(.25, .7, 1.4, 6), _own(Color("#d8d2c4"), .3, .0), holder, Vector3(0, .3, 0))
	Mk.mi(Mk.box(Vector3(1.1, .25, 1.1)), _own(Color("#9aa0aa"), .35, 0.0), holder, Vector3(0, -.05, 0))
	glow = Mk.mi(Mk.sphere(.55, 14), _own(Color(1.0, .7, .25, .35), .5, 2.5), holder, Vector3(0, .2, 0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light = OmniLight3D.new()
	light.light_color = Color("#ffb347")
	light.light_energy = 2.5
	light.omni_range = 9.0
	light.position = Vector3(0, .8, 0)
	holder.add_child(light)

func _own(c: Color, rough: float, emit: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = emit
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func hit() -> bool:
	if done:
		return false
	hp -= 1
	flash = .25
	if hp <= 0:
		done = true
		glow.visible = false
		light.visible = false
		shard.visible = false
		return true
	return false

func _process(dt: float) -> void:
	if done:
		return
	flash = max(0.0, flash - dt)
	var s := 1.0 + sin(Time.get_ticks_msec() * .006) * .12 + flash * 1.5
	glow.scale = Vector3.ONE * s
	light.light_energy = 2.5 + flash * 8.0
