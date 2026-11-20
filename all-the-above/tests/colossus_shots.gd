extends SceneTree
## Capturas do colosso de longe: /tmp/ata_shots/col_*.png  (caixas de escalada em vermelho translúcido no "caixas")
var main
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func snap(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/ata_shots/col_%s.png" % name)
	print("SHOT ", name)
func view(name: String, yaw: float, dist: float, h: float, look_h: float) -> void:
	var C: Colossus = main.colossus
	var cam: Camera3D = main.cam.cam
	var c := C.global_position
	var b := C.global_transform.basis
	var dir := (b.x * sin(yaw) + b.z * cos(yaw)).normalized()
	cam.global_position = c + dir * dist + Vector3(0, h, 0)
	cam.look_at(c + Vector3(0, look_h, 0), Vector3.UP)
	cam.fov = 60
	await frames(4)
	await snap(name)
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/ata_shots")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(30)
	main.start()
	main.hud.visible = false
	main.cam.set_process(false)
	main.player.set_physics_process(false)
	main.colossus.set_physics_process(false)
	await frames(10)
	await view("lado", PI / 2.0, 85, 20, 25)
	await view("frente", 0.4, 140, 15, 22)
	await view("tras", PI + .5, 140, 40, 22)
	# caixas
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0, 0, .35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for p in main.colossus.parts:
		var cp: CPart = p
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = cp.he * 2.0
		mi.mesh = bm
		mi.material_override = m
		cp.add_child(mi)
	for w in main.colossus.weak:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		s.mesh = sm
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(0, 1, 1)
		m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s.material_override = m2
		w.add_child(s)
	await view("caixas_lado", PI / 2.0, 85, 30, 25)
	await view("caixas_frente", 0.6, 80, 45, 30)
	quit()
