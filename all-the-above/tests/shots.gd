extends SceneTree
## Capturas do protótipo em /tmp/ata_shots
##   xvfb-run -a godot --path . --resolution 1280x720 -s tests/shots.gd
var main

func snap(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/ata_shots/%s.png" % name)
	print("SHOT ", name)

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/ata_shots")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(90)
	await snap("01_abertura")
	main.start()
	var P: Player = main.player
	var C: Colossus = main.colossus
	main.hud.msg_t = 0.0
	await frames(30)
	main.cam.yaw = 2.6
	main.cam.pitch = -.12
	await frames(40)
	await snap("02_vale")
	print("DESENHOS POR QUADRO: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "  objetos: ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "  fps: ", Engine.get_frames_per_second())
	# perto das patas do colosso, no chão: câmera de baixo para cima
	P.global_position = C.global_position + C.global_transform.basis.x * 22.0 + C.global_transform.basis.z * 10.0
	P.global_position.y = .1
	var to := C.global_position - P.global_position
	main.cam.yaw = atan2(-to.x, -to.z) + .35
	main.cam.pitch = .1
	main.cam.look_pt = Vector3.ZERO
	await frames(60)
	await snap("03_debaixo")
	# balançando numa árvore
	var tp: Node3D = null
	for n in get_nodes_in_group("hook"):
		if n.get_meta("kind") == "tree" and n.global_position.y > 18 and n.global_position.distance_to(main.world.spawn) < 120:
			tp = n
			break
	P.global_position = tp.global_position + Vector3(10, -12, 0)
	P.velocity = Vector3(0, 0, 8)
	main.inp.force("hook", true)
	P.fire_hook(tp)
	main.cam.yaw = 1.2
	main.cam.pitch = -.05
	await frames(50)
	await snap("04_balanco")
	main.inp.force("hook", false)
	await frames(60)
	# escalando a perna
	main.inp.force("grab", true)
	var leg: CPart = C.legs[1].low
	var r := leg.closest(leg.global_transform * Vector3(leg.he.x + 1.0, 1.0, 0))
	r.part = leg
	P.start_climb(r)
	var n0: Vector3 = P.climb_n
	main.cam.yaw = atan2(n0.x, n0.z) + .5
	main.cam.pitch = -.1
	await frames(60)
	await snap("05_escalando")
	# nas costas: de cima para baixo
	var tor: CPart = C.parts[0]
	var r2 := tor.closest(tor.global_transform * Vector3(1.0, tor.he.y + 1, -2.0))
	r2.part = tor
	P.start_climb(r2)
	main.cam.pitch = -.35
	await frames(60)
	await snap("06_costas")
	print("COSTAS estado=", P.state, " n=", P.climb_n, " parte=", C.parts.find(P.climb_part), " pos=", P.global_position, " cam=", main.cam.cam.global_position)
	# no ponto fraco da nuca
	var w: WeakPoint = C.weak[1]
	var wpart: CPart = w.get_parent()
	var r3 := wpart.closest(w.global_position + Vector3(0, 1, 0))
	r3.part = wpart
	P.start_climb(r3)
	await frames(30)
	main.inp.force("pick", true)
	await frames(6)
	await snap("07_ponto_fraco")
	main.inp.force("pick", false)
	main.inp.force("grab", false)
	# alienígenas
	P.respawn()
	var A: Aliens = main.aliens
	var spot: Vector3 = A.spots[0]
	P.global_position = spot + Vector3(-9, .1, -9)
	A.hidden = false
	for a in A.list:
		if not a.alive():
			a._revive()
		if a.home.distance_to(spot) < 10:
			a.st = "idle"
	var to2 := spot - P.global_position
	main.cam.yaw = atan2(-to2.x, -to2.z)
	main.cam.pitch = -.2
	await frames(70)
	await snap("08_alienigenas")
	# dormindo
	for wp in C.weak:
		while not wp.done:
			C.stab(wp)
		C.state = "walk"
	C.state = "sleep"
	C.sleep_t = 0.0
	P.global_position = C.global_position + C.global_transform.basis.x * 75.0
	P.global_position.y = .1
	var to3 := C.global_position - P.global_position
	main.cam.yaw = atan2(-to3.x, -to3.z)
	main.cam.pitch = -.05
	await frames(420)
	await snap("09_dormindo")
	quit()
