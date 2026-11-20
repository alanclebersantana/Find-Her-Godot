extends Node3D
class_name TomeModel
## O Tomé feito de formas (protótipo): barba branca, capuz verde pontudo, jaqueta de couro,
## lanterna na cintura e a picareta. Animação por código: andar, pular, balançar, escalar, golpear.

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var pick: Node3D
var t := 0.0
var pose := "idle"   # idle, walk, air, swing, climb, pick, hurt
var speed := 0.0
var pick_t := 0.0

func _ready() -> void:
	var skin := Mk.mat(Color("#f2c7a5"), .7)
	var jacket := Mk.mat(Color("#7a4a2a"), .8)
	var pants := Mk.mat(Color("#4a4038"), .9)
	var boots := Mk.mat(Color("#3a2618"), .7)
	var green := Mk.mat(Color("#3f8a3a"), .85)
	var white := Mk.mat(Color("#f4f1ea"), .9)
	var belt := Mk.mat(Color("#2a1a10"), .6)
	hips = Node3D.new()
	hips.position = Vector3(0, .82, 0)
	add_child(hips)
	# pernas (pivô no quadril)
	leg_l = _limb(hips, Vector3(-.13, 0, 0), pants, boots, .11, .74)
	leg_r = _limb(hips, Vector3(.13, 0, 0), pants, boots, .11, .74)
	torso = Node3D.new()
	hips.add_child(torso)
	Mk.mi(Mk.capsule(.27, .78), jacket, torso, Vector3(0, .32, 0), Vector3.ZERO, Vector3(1, 1, .82))
	Mk.mi(Mk.cyl(.285, .285, .09, 14), belt, torso, Vector3(0, .1, 0), Vector3.ZERO, Vector3(1, 1, .84))
	# lanterna na cintura
	var lan := Node3D.new()
	lan.position = Vector3(-.27, .04, .1)
	torso.add_child(lan)
	Mk.mi(Mk.cyl(.06, .07, .16, 8), Mk.mat(Color("#b8862f"), .3), lan, Vector3(0, -.08, 0))
	Mk.mi(Mk.sphere(.055, 8), Mk.mat(Color("#ffd27a"), .2, 3.0), lan, Vector3(0, -.08, 0))
	head = Node3D.new()
	head.position = Vector3(0, .78, 0)
	torso.add_child(head)
	Mk.mi(Mk.sphere(.2, 14), skin, head, Vector3(0, .12, 0))
	Mk.mi(Mk.sphere(.055, 8), Mk.mat(Color("#e8907a"), .6), head, Vector3(0, .1, .2))
	# barba comprida e sobrancelhas
	Mk.mi(Mk.cone(.2, .42, 12), white, head, Vector3(0, -.1, .1), Vector3(PI + .25, 0, 0))
	Mk.mi(Mk.sphere(.14, 10), white, head, Vector3(0, .02, .12), Vector3.ZERO, Vector3(1.2, .8, .9))
	for sx in [-.07, .07]:
		Mk.mi(Mk.box(Vector3(.09, .03, .03)), white, head, Vector3(sx, .19, .18))
		Mk.mi(Mk.sphere(.022, 6), Mk.mat(Color("#1d140e"), .3), head, Vector3(sx, .15, .19))
	# capuz verde pontudo, caído para trás
	Mk.mi(Mk.sphere(.225, 14), green, head, Vector3(0, .17, -.02), Vector3.ZERO, Vector3(1, .85, 1.05))
	Mk.mi(Mk.cone(.2, .55, 12), green, head, Vector3(0, .38, -.18), Vector3(-.75, 0, 0))
	# braços (pivô no ombro)
	arm_l = _limb(torso, Vector3(-.33, .62, 0), jacket, skin, .085, .62)
	arm_r = _limb(torso, Vector3(.33, .62, 0), jacket, skin, .085, .62)
	# picareta na mão direita
	pick = Node3D.new()
	pick.position = Vector3(0, -.62, 0)
	arm_r.add_child(pick)
	Mk.mi(Mk.cyl(.025, .03, .75, 6), Mk.mat(Color("#8a5a2a"), .7), pick, Vector3(0, 0, .3), Vector3(PI / 2.0, 0, 0))
	Mk.mi(Mk.box(Vector3(.5, .07, .09)), Mk.mat(Color("#b7bcc4"), .3), pick, Vector3(0, 0, .66))
	Mk.mi(Mk.cone(.05, .16, 6), Mk.mat(Color("#b7bcc4"), .3), pick, Vector3(.3, 0, .66), Vector3(0, 0, -PI / 2.0))

func _limb(parent: Node3D, at: Vector3, m1: Material, m2: Material, r: float, l: float) -> Node3D:
	var p := Node3D.new()
	p.position = at
	parent.add_child(p)
	Mk.mi(Mk.capsule(r, l), m1, p, Vector3(0, -l / 2.0, 0))
	Mk.mi(Mk.sphere(r * 1.25, 8), m2, p, Vector3(0, -l, .03), Vector3.ZERO, Vector3(1, .8, 1.4))
	return p

func swing_pick() -> void:
	pick_t = .32

func _process(dt: float) -> void:
	t += dt
	pick_t = max(0.0, pick_t - dt)
	var la := 0.0
	var ra := 0.0
	var ll := 0.0
	var rl := 0.0
	var lean := 0.0
	var arm_side_l := .1
	var arm_side_r := -.1
	match pose:
		"walk":
			var f := t * (6.0 + speed * 1.4)
			var amp := clampf(speed / 6.0, .2, 1.0) * .8
			ll = sin(f) * amp
			rl = -sin(f) * amp
			la = -sin(f) * amp * .8
			ra = sin(f) * amp * .8
			lean = .1 * amp
			hips.position.y = .82 + abs(sin(f)) * .05
		"air":
			ll = -.6
			rl = .3
			la = -2.2
			ra = -2.0
			arm_side_l = .4
			arm_side_r = -.4
		"swing":
			# mão direita na corda, lá no alto; pernas soltas
			ra = -3.0
			la = -.6 + sin(t * 3.0) * .2
			ll = .3 + sin(t * 2.0) * .3
			rl = -.2 + sin(t * 2.0 + 1.0) * .3
			lean = -.15
		"climb":
			var c := sin(t * 7.0) * clampf(speed, 0.0, 1.0)
			la = -2.8 + c * .4
			ra = -2.8 - c * .4
			ll = -.6 - c * .4
			rl = -.6 + c * .4
			arm_side_l = .35
			arm_side_r = -.35
			lean = .25
		"hurt":
			la = -1.0
			ra = -1.0
			lean = -.4
		_:
			la = sin(t * 1.6) * .05
			ra = -sin(t * 1.6) * .05
			hips.position.y = .82 + sin(t * 2.0) * .01
	if pick_t > 0.0:
		var u := 1.0 - pick_t / .32
		ra = lerpf(-3.0, .6, smoothstep(0.0, 1.0, u * 1.4))
		lean = lerpf(-.2, .35, u)
	leg_l.rotation.x = lerp_angle(leg_l.rotation.x, ll, .35)
	leg_r.rotation.x = lerp_angle(leg_r.rotation.x, rl, .35)
	arm_l.rotation.x = lerp_angle(arm_l.rotation.x, la, .35)
	arm_r.rotation.x = lerp_angle(arm_r.rotation.x, ra, .5 if pick_t > 0.0 else .35)
	arm_l.rotation.z = lerp_angle(arm_l.rotation.z, -arm_side_l, .3)
	arm_r.rotation.z = lerp_angle(arm_r.rotation.z, -arm_side_r, .3)
	torso.rotation.x = lerp_angle(torso.rotation.x, lean, .2)
