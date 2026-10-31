extends "res://tests/rec/route3.gd"
## Os três chefes do Episódio 3 (Enguia de Cristal, Salamandra de Fogo, Guardião de Ferro) e a
## perseguição do trem: teleporta para perto de cada arena e joga a luta inteira.
##   CHEFE=enguia|salamandra|guardiao|trem godot --headless --path . -s tests/ep3_bosses_test.gd

func _at(x: float, y: float) -> void:
	g.CINE = {}
	P = g.player
	P.x = x - P.w / 2
	P.y = y - P.h
	P.vx = 0.0
	P.vy = 0.0
	P.spawnX = P.x
	P.spawnY = P.y
	P.hp = 5
	g.snap_camera()
	await frame()

func _initialize() -> void:
	await _rec_setup(2)
	g.no_coal = true
	g.lives = 99
	for e in g.EN:
		e.dead = 99
	P = g.player
	g.lantern_lit = true
	var only: String = OS.get_environment("CHEFE")
	var lives0: int = g.lives
	if only == "" or only == "salamandra":
		await _at(float(g.L.sections[3].x) + 5950, 500)
		await S("vence a Salamandra de Fogo", await sal_fight())
	if only == "" or only == "guardiao":
		await _at(float(g.L.sections[4].x) + 4300, 500)
		await S("vence o Guardião de Ferro", await gua_fight())
	if only == "" or only == "trem":
		for b in g.K.B3.B:
			if b.id != "vargas":
				b.done = true
		await _at(float(g.L.sections[4].x) + 5800, 500)
		await S("o trem partiu", await walk_to(float(g.L.door.x) - 100) and g.VH.dep_t >= 0)
		g.VH.tied = false
		await S("sobe no trole", await until({"R": true}, func(): return g.VH.mode == "sled", 500))
		var VH = g.VH
		for i in 5000:
			if VH.mode == "" or not g.running:
				break
			var d := {}
			var ground: bool = VH.hy >= VH.sled_y(VH.su) - 1
			if i % 60 == 0 and OS.get_environment("DBG") != "":
				print("TR su=%d spd=%.1f hits=%d" % [int(VH.su), VH.spd, VH.hits])
			for o in VH.OBS:
				var dx: float = o.x - VH.hx
				if o.hit or o.k == "bump" or dx < -140 or dx > 300:
					continue
				if o.k in ["rock", "log"] and ground and dx < VH.spd * 9.0 + 24 and dx > 30:
					await press("J")
				if o.k == "crack" and ground and dx < 40 and dx > -5:
					await press("J")
				if o.k == "branch" and dx < 110 and dx > -100:
					d["S"] = true
				break
			await frame(d)
		var hk := []
		for o in VH.OBS:
			if o.hit:
				hk.append(o.k + "@" + str(o.u))
		await S("trole sem batidas " + str(hk), hk.is_empty())
		var started := [false]
		g.isis_start.connect(func(): started[0] = true)
		await until({}, func(): return started[0] or not g.running, 300)
		await S("o trole alcançou o trem: agora é a Isis", started[0])
	if only == "isis" or only == "":
		g.lives = 99
		g.begin_isis()
		P = g.player
		await S("a Isis foge pelo trem e puxa o freio", await isis_train())
	if only == "" or only == "vargas":
		g.begin_vargas()
		P = g.player
		var endv := [false]
		g.results_ready.connect(func(): endv[0] = true)
		await S("vence o Vargas", await vargas_fight())
		await S("fim (resultados)", endv[0])
	await S("no máximo 2 vidas perdidas (vidas %d -> %d)" % [lives0, g.lives], g.lives >= lives0 - 2)
	for l in log_lines:
		print(l)
	print("FALHAS: ", fails)
	quit()
