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
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
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
	if args.size() > 0 and args[0] == "rest":
		for k in range(1, args.size()):
			main._on_rest(int(args[k]))
			for i in 420:
				await process_frame
			root.get_texture().get_image().save_png("/tmp/fh_shots/rest%s.png" % args[k])
		quit()
		return
	g.lives = 99
	g.clue_opened.disconnect(main._on_clue)
	for cid in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada"]:
		root.get_node("Save").setv("comic", cid, true)
	for e in g.EN:
		if e.k != "owl" and e.k != "frog" and e.k != "leech":
			e.dead = 99
	var n := 0
	for a in args:
		var p = a.split(",")
		var x := float(p[0])
		var y := float(p[1])
		g.CINE = {}
		g.VH.mode = ""
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
				elif k == "dog":
					g.X.DOG.st = "follow"
					g.X.DOG.x = x - 50
					g.X.DOG.y = y
					g.X.TRAIL = [Vector2(x - 50, y), Vector2(x, y)]
				elif k == "ctrl":
					g.X.DOG.st = "follow"
					g.X.DOG.x = x
					g.X.DOG.y = y
					g.player.onGround = true
					g.M.toggle_dog()
				elif k == "hawkm" or k == "hawks":
					var h: Dictionary = g.K.HAWK
					h.active = true
					h.st = "mark" if k == "hawkm" else "stuck"
					h.t = 30
					h.tx = x + 120
					h.x = x + 120
					h.y = h.gy - 300 if k == "hawkm" else h.gy
				elif k == "fisht" or k == "fishs":
					var f: Dictionary = g.K.FISH
					f.active = true
					f.st = "tired" if k == "fisht" else "suck"
					f.t = 60
					f.x = x + 260
					f.y = y
					f.dir = -1
					g.NT.helmet = true
					g.NT.harpoon = true
				elif k == "mud":
					g.K.FISH.mud = .8
				elif k == "bearw" or k == "bearr" or k == "beard":
					var b: Dictionary = g.K.BEAR
					b.active = true
					b.st = {"bearw": "walk", "bearr": "rear", "beard": "dizzy"}[k]
					b.t = 20
					b.x = x + 220
					b.dir = -1
				elif k == "ride":
					g.RD._start()
					g.RD.hx = x
					g.RD.spd = 5.2
				elif k == "duck":
					g.keys["S"] = true
				elif k == "bar":
					g.player.bar = g.NT.BARS[0]
					g.player.y = g.NT.BARS[0].y + 6
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
				elif k == "raft":
					g.VH._start_raft()
					g.VH.hx = x
				elif k == "plane":
					g.VH._start_plane()
					g.VH.phase = "fly"
					g.VH.hx = x
					g.VH.hy = y
					g.VH.spd = 6.2
				elif k == "taxi":
					g.VH._start_plane()
				elif k == "boul":
					for o in g.TR.T:
						if o.k == "boulder":
							o.st = "roll"
							o.bx = x - 260.0
							o.by = o.y - o.r
							o.vx = 5.0
				elif k == "hive":
					for o in g.TR.T:
						if o.k == "hive":
							g.TR._hive_wake(o)
				elif k == "brg":
					for o in g.TR.T:
						if o.k == "bridge":
							o.st = "go"
							o.t = 30
							o.front = x - 140
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
