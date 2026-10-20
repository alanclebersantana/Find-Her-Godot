extends SceneTree
## Capturas de tela: teleporta o Tomé para pontos da fase e salva PNGs em /tmp/fh_shots.
## Uso: godot --path . -s tests/shots.gd -- x1,y1 x2,y2 ...
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/fh_shots")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "title":
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/fh_shots/title.png")
		quit()
		return
	main.start_level(false)
	await process_frame
	for c in main.ui_layer.get_children():
		if c.has_method("_end"):
			c._end()
	await process_frame
	if args.size() > 0 and args[0] == "intro":
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/fh_shots/intro.png")
		quit()
		return
	main.panel.get_meta("ok").call()
	var g = main.game
	g.lives = 99
	g.clue_opened.disconnect(main._on_clue)
	for e in g.EN:
		if e.k != "owl" and e.k != "frog" and e.k != "leech":
			e.dead = 99
	var n := 0
	for a in args:
		var p = a.split(",")
		var x := float(p[0])
		var y := float(p[1])
		g.CINE = {}
		g.X.boss_reset()
		g.player.x = x - 12
		g.player.y = y - 34
		g.player.vx = 0
		g.player.vine = null
		g.player.ladder = null
		g.player.vy = 0
		g.player.spawnX = g.player.x
		g.player.spawnY = g.player.y
		if p.size() > 2:
			for k in p[2].split("+"):
				if k == "lit":
					g.lantern_lit = true
				elif k == "dark":
					g.lantern_lit = false
				elif k == "drain":
					for sw in g.SWAMP:
						if sw.get("id") == "canal":
							sw.y = 640
				elif k == "vil":
					g.VIL.go = true
					g.VIL.x = 9470
				elif k == "chase":
					g.VIL.go = true
					g.VIL.x = x + 380
					g.lantern_lit = true
				elif k == "lad0":
					g.player.ladder = g.CLIMB[0]
				elif k == "netc":
					g.player.ladder = g.CLIMB[2]
				elif k == "rope":
					g.INV.append("gancho_corda")
					g.use_lock(g.LOCKS[0])
					g.player.ladder = g.CLIMB.back()
				elif k == "vine":
					g.player.vine = g.VINES[0]
					g.player.vr = 150.0
					g.VINES[0].om = .03
				elif k.begins_with("w_"):
					g.X.weather = k.substr(2)
				elif k == "dog":
					g.X.DOG.st = "follow"
					g.X.DOG.x = x - 50
					g.X.DOG.y = y
					g.X.TRAIL = [Vector2(x - 50, y)]
				elif k == "fl":
					g.player.face = -1
				elif k == "pick":
					g.INV.append("picareta")
				elif k == "slab":
					for c in g.X.CRACKS:
						if c.id == "slab":
							g.X.break_crack(c, false)
				elif k == "m1":
					g.X.MIRRORS[0].s = 1
					g.X.MIRRORS[1].s = 1
				elif k == "boss":
					g.X.BOSS.st = "wait"
					g.X.BOSS.done = false
				elif k == "bstun":
					g.X.BOSS.active = true
					g.X.BOSS.st = "stun"
					g.X.BOSS.x = 3500
					g.X.BOSS.y = 500.0
					g.X.BOSS.t = 0
					g.X._gate_on(true)
				elif k == "found":
					for sc in g.X.SECRETS:
						g.X.found[sc.id] = true
						sc.a = 0.0
				elif k == "noen":
					for e in g.EN:
						e.dead = 99
				else:
					g.keys[k] = true
		g.snap_camera()
		g.player.iframe = 0
		for i in (int(p[3]) if p.size() > 3 else 70):
			await physics_frame
			g.player.hp = 3
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/fh_shots/s%02d.png" % n)
		g.keys.clear()
		n += 1
	print("SHOTS ", n)
	quit()
