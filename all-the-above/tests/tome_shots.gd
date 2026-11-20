extends SceneTree
## Capturas de perto do Tomé (modelo 3D) em várias poses: /tmp/ata_shots/tome_*.png
var main
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func snap(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/ata_shots/tome_%s.png" % name)
	print("SHOT ", name)
func pose_shot(name: String, pose: String, spd: float, yaw: float) -> void:
	var P: Player = main.player
	P.set_physics_process(false)
	P.model.pose = pose
	P.model.speed = spd
	main.cam.set_process(false)
	var cam: Camera3D = main.cam.cam
	var c := P.global_position + Vector3(0, 1.0, 0)
	cam.global_position = c + Vector3(sin(yaw), .15, cos(yaw)) * 3.2
	cam.look_at(c, Vector3.UP)
	cam.fov = 50
	await frames(40)
	await snap(name)
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/ata_shots")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(30)
	main.start()
	main.hud.visible = false
	await frames(20)
	var P: Player = main.player
	P.global_position = Vector3(60, 0.0, 120)
	P.velocity = Vector3.ZERO
	P.face_yaw = 0.0
	P.model.rotation.y = 0.0
	await pose_shot("parado", "idle", 0, .3)
	await pose_shot("andando", "walk", 3, 1.2)
	await pose_shot("correndo", "walk", 7, 1.6)
	await pose_shot("ar", "air", 0, .5)
	await pose_shot("corda", "swing", 0, .8)
	await pose_shot("escalando", "climb", 1, PI + .4)
	quit()
