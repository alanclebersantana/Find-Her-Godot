extends SceneTree
## Teste do protótipo: andar, gancho (balançar e voar até o colosso), escalada, barra de agarre,
## pontos fracos, colosso dormindo, alienígenas.
##   godot --headless --path . --fixed-fps 60 -s tests/proto_test.gd

var main
var fails := 0

func ok(name: String, cond: bool, extra: String = "") -> void:
	if not cond:
		fails += 1
	print("%s %s %s" % ["·" if cond else "✗", name, extra])

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func hold(b: String, on: bool) -> void:
	main.inp.force(b, on)

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(3)
	main.start()
	await frames(5)
	var P: Player = main.player
	var C: Colossus = main.colossus
	# ---------------- andar
	var p0 := P.global_position
	main.inp.test_move = Vector2(0, 1)
	await frames(60)
	main.inp.test_move = Vector2.ZERO
	ok("anda", P.global_position.distance_to(p0) > 4.0, "d=%.1f" % P.global_position.distance_to(p0))
	# ---------------- gancho na árvore: balança e solta voando
	var tp: Node3D = null
	for n in get_nodes_in_group("hook"):
		if n.get_meta("kind") == "tree" and n.global_position.y > 15:
			tp = n
			break
	P.global_position = tp.global_position + Vector3(9, -14, 0)
	P.global_position.y = max(P.global_position.y, 0.1)
	P.velocity = Vector3.ZERO
	await frames(2)
	hold("hook", true)
	P.fire_hook(tp)
	await frames(30)
	ok("balançando na corda", P.state == "swing", P.state)
	var sw0 := P.global_position
	await frames(40)
	ok("o balanço move o Tomé", P.global_position.distance_to(sw0) > 2.0, "d=%.1f" % P.global_position.distance_to(sw0))
	ok("corda segura (não passa do comprimento)", (P.global_position + P.HAND).distance_to(tp.global_position) <= P.rope_len + .3)
	hold("hook", false)
	await frames(2)
	ok("soltou e voa", P.state == "air" and P.velocity.length() > 3.0, "%s v=%.1f" % [P.state, P.velocity.length()])
	await frames(180)
	# ---------------- voar até o pelo do colosso e escalar
	var cp: Node3D = null
	for n in get_nodes_in_group("hook"):
		if n.get_meta("kind") == "colossus" and n.global_position.y < 16:
			cp = n
			break
	P.global_position = C.global_position + (C.global_transform.basis.x * 20.0)
	P.global_position.y = 0.1
	P.velocity = Vector3.ZERO
	await frames(2)
	hold("grab", true)
	hold("hook", true)
	P.fire_hook(cp)
	var climbed := false
	for i in 240:
		await physics_frame
		if P.state == "climb":
			climbed = true
			break
	hold("hook", false)
	ok("voou até o pelo e agarrou", climbed, P.state)
	# sobe escalando
	var y0 := P.global_position.y
	main.inp.test_move = Vector2(0, 1)
	for i in 200:
		# câmera de frente para a parede: empurrar para frente = subir
		main.cam.yaw = atan2(P.climb_n.x, P.climb_n.z)
		await physics_frame
	main.inp.test_move = Vector2.ZERO
	ok("escalou para cima", P.global_position.y > y0 + 3.0, "y %.1f -> %.1f parte=%s" % [y0, P.global_position.y, str(C.parts.find(P.climb_part))])
	ok("barra de agarre gasta", P.stamina < .9, "st=%.2f" % P.stamina)
	# solta
	hold("grab", false)
	await frames(2)
	ok("soltou o pelo e caiu", P.state == "air", P.state)
	await frames(240)
	# ---------------- barra de agarre zerada derruba
	hold("grab", true)
	var near := _surface_near(C.parts[0], P)
	P.start_climb(near)
	P.stamina = .02
	await frames(40)
	ok("mão cansada solta", P.state != "climb", P.state)
	hold("grab", false)
	await frames(200)
	# ---------------- pontos fracos: três picaretadas cada
	hold("grab", true)
	for w in C.weak:
		var wp: WeakPoint = w
		var c := _surface_at(wp, P)
		P.start_climb(c)
		P.stamina = 1.0
		await frames(3)
		for k in 3:
			main.inp.force("pick", true)
			await frames(2)
			main.inp.force("pick", false)
			await frames(30)
			P.stamina = 1.0
		ok("ponto fraco (%s) arrancado" % wp.label, wp.done, "hp=%d dist=%.2f estado=%s" % [wp.hp, wp.global_position.distance_to(P.center()), P.state])
		if C.state == "stagger":
			C.stagger_t = 0.0
		await frames(5)
	ok("colosso dormiu", C.state == "sleep" and main.asleep == 1, C.state)
	hold("grab", false)
	await frames(400)
	ok("dormindo ele deita", C.body.position.y < -1.0, "y=%.2f" % C.body.position.y)
	# ---------------- alienígenas (o colosso dormindo não segura batalha)
	var A: Aliens = main.aliens
	var crab = null
	for a in A.list:
		if a.kind == "crab" and a.alive():
			crab = a
			break
	P.respawn()
	await frames(5)
	crab.global_position = P.global_position + Vector3(sin(P.face_yaw), 0, cos(P.face_yaw)) * 1.5
	crab.st = "stun"
	crab.t = 5.0
	for k in 2:
		main.inp.force("pick", true)
		await frames(2)
		main.inp.force("pick", false)
		await frames(30)
		crab.global_position = P.global_position + Vector3(sin(P.face_yaw), 0, cos(P.face_yaw)) * 1.5
	ok("caranguejo derrotado", not crab.alive(), "hp=%d st=%s" % [crab.hp, crab.st])
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)

func _surface_near(part: CPart, P: Player) -> Dictionary:
	var side: Vector3 = part.global_transform * Vector3(part.he.x + .8, 0, 0)
	var r := part.closest(side)
	r.part = part
	return r

func _surface_at(w: WeakPoint, P: Player) -> Dictionary:
	var part: CPart = w.get_parent()
	var r := part.closest(w.global_position + (w.global_position - part.global_position).normalized() * .5)
	r.part = part
	return r
