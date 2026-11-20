extends Node3D
class_name TomeModel
## O Tomé de verdade: modelo 3D (Meshy) com esqueleto e animações (parado, andando, correndo,
## golpe, levar pancada, desmaiar). As poses que não vêm prontas (no ar, balançando na corda,
## escalando) são feitas por cima, mexendo nos ossos dos braços e pernas (TomePoseMod).
## Se o arquivo do modelo faltar, usa o Tomé de formas antigo.

const MODEL := "res://assets/models/tome.glb"
const LOOPS := ["Idle", "Walking", "Running"]

var pose := "idle"          # idle, walk, air, swing, climb, hurt
var speed := 0.0
var t := 0.0

var anim: AnimationPlayer
var skel: Skeleton3D
var mod: TomePoseMod
var fallback: TomeModelProc
var _cur := ""
var _pick_t := 0.0
var _hurt_played := false

func _ready() -> void:
	var ps: PackedScene = load(MODEL) if ResourceLoader.exists(MODEL) else null
	if ps == null:
		fallback = TomeModelProc.new()
		add_child(fallback)
		return
	var inst := ps.instantiate()
	add_child(inst)
	anim = inst.find_child("AnimationPlayer", true, false)
	skel = inst.find_child("Skeleton3D", true, false)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if anim:
		for a in anim.get_animation_list():
			var an := anim.get_animation(a)
			an.loop_mode = Animation.LOOP_LINEAR if a in LOOPS else Animation.LOOP_NONE
		anim.animation_finished.connect(_on_finished)
		_play("Idle", 0.0)
	if skel:
		mod = TomePoseMod.new()
		mod.model = self
		skel.add_child(mod)

func swing_pick() -> void:
	if fallback:
		fallback.swing_pick()
		return
	_pick_t = .55
	# golpe rápido: só o começo da animação de ataque, acelerado
	if anim and anim.has_animation("Attack") and pose in ["idle", "walk"]:
		_play("Attack", .08, 2.2, true)

func _play(name: String, blend: float, spd := 1.0, force := false) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if _cur == name and not force:
		anim.speed_scale = spd
		return
	_cur = name
	anim.play(name, blend)
	anim.speed_scale = spd
	if force:
		anim.seek(0.0, true)

func _on_finished(n: StringName) -> void:
	if n == &"Attack":
		_cur = ""

func _process(dt: float) -> void:
	if fallback:
		fallback.pose = pose
		fallback.speed = speed
		return
	t += dt
	_pick_t = maxf(0.0, _pick_t - dt)
	if pose != "hurt":
		_hurt_played = false
	if _cur == "Attack" and _pick_t > 0.0 and pose in ["idle", "walk"]:
		return
	match pose:
		"walk":
			if speed > 4.8:
				_play("Running", .2, clampf(speed / 7.0, .7, 1.3))
			else:
				_play("Walking", .2, clampf(speed / 2.6, .6, 1.6))
		"hurt":
			if not _hurt_played:
				_hurt_played = true
				_play("Dead", .15, 1.3, true)
		"air", "swing":
			_play("Running", .25, .15)
		"climb":
			_play("Idle", .2, 1.0)
		_:
			_play("Idle", .25, 1.0)
