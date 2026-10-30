extends "res://tests/route3.gd"
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
	frame()

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(2)
	g.no_coal = true
	g.lives = 99
	for e in g.EN:
		e.dead = 99
	P = g.player
	g.lantern_lit = true
	var only: String = OS.get_environment("CHEFE")
	var lives0: int = g.lives
	if only == "" or only == "enguia":
		_at(19380, 500)
		S("pilar 1", jump_to(19605, true))
		S("vence a Enguia de Cristal", eel_fight())
	if only == "" or only == "salamandra":
		_at(21000 + 5950, 500)
		S("vence a Salamandra de Fogo", sal_fight())
	if only == "" or only == "guardiao":
		_at(28700 + 4300, 500)
		S("vence o Guardião de Ferro", gua_fight())
	if only == "" or only == "trem":
		for b in g.K.B3.B:
			b.done = true
		_at(28700 + 5800, 500)
		S("o trem partiu", walk_to(float(g.L.door.x) - 100) and g.VH.dep_t >= 0)
		S("sobe no trole", until({"R": true}, func(): return g.VH.mode == "sled", 500))
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
					press("J")
				if o.k == "crack" and ground and dx < 40 and dx > -5:
					press("J")
				if o.k == "branch" and dx < 110 and dx > -100:
					d["S"] = true
				break
			frame(d)
		var hk := []
		for o in VH.OBS:
			if o.hit:
				hk.append(o.k + "@" + str(o.u))
		S("trole sem batidas " + str(hk), hk.is_empty())
		var sa = until({}, func(): return not g.running, 300)
		S("fim do episódio", sa is String and sa == "state")
	S("sem morrer (vidas %d -> %d)" % [lives0, g.lives], g.lives == lives0)
	for l in log_lines:
		print(l)
	print("FALHAS: ", fails)
	quit()
