extends SceneTree
## Vitrine do Tomé em peças: desenha bem grande, em vários estados, e salva quadros em /tmp/fh_rig
## godot --path . -s tests/rig_view.gd -- estado quadros [escala]
class V extends Node2D:
	var p := {}
	var T := 0
	var sc := 3.0
	func _draw() -> void:
		var S = get_node("/root/Spr")
		S.begin(self)
		draw_rect(Rect2(0, 0, 1280, 720), Color(.78, .86, .8))
		draw_rect(Rect2(0, 470, 1280, 80), Color(.45, .6, .35))
		S.save()
		S.translate(480, 470)
		S.scale(sc, sc)
		load("res://scripts/rig2.gd").draw(p, 0, 0, T, true)
		S.restore()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/fh_rig")
	var args := OS.get_cmdline_user_args()
	var st: String = args[0] if args.size() > 0 else "walk"
	var caps: Array = []
	for c in (args[1] if args.size() > 1 else "0,6,12,18,24,30").split(","):
		caps.append(int(c))
	var v := V.new()
	v.sc = float(args[2]) if args.size() > 2 else 3.0
	root.add_child(v)
	var p := {"x": 0.0, "y": 0.0, "w": 20.0, "h": 34.0, "vx": 0.0, "vy": 0.0, "face": 1, "onGround": true, "swim": false,
		"crouch": false, "run": 0, "anim": 0.0, "ladder": null, "vine": null, "squash": 0.0, "landT": 0, "iframe": 0, "climbA": 0.0}
	v.p = p
	var n := 0
	for f in caps.max() + 1:
		match st:
			"walk": p.vx = min(4.3, f * .5)
			"run": p.vx = min(6.6, f * .6); p.run = 1
			"stop": p.vx = max(0.0, 4.3 - f * .4)
			"jump":
				p.vx = 3.0
				p.onGround = f < 4 or f > 44
				p.vy = -11.8 + max(0, f - 4) * .55 if not p.onGround else 0.0
				if f == 45:
					p.landT = 8
					p.squash = .5
			"crouch": p.crouch = true; p.vx = 1.5 if f > 10 else 0.0
			"swim": p.swim = true; p.onGround = false; p.vx = 2.5
			"idle": p.vx = 0.0
		if p.landT > 0 and f > 45:
			p.landT -= 1
		p.squash *= .78
		v.T = f
		v.queue_redraw()
		await process_frame
		if f in caps:
			await process_frame
			root.get_texture().get_image().save_png("/tmp/fh_rig/r%02d.png" % n)
			n += 1
	quit()
