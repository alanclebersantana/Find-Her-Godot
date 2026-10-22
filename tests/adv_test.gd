extends "res://tests/route.gd"
## Testa os trechos novos sozinhos (teleporta o Tomé para o começo de cada um):
##   godot --headless --path . -s tests/adv_test.gd -- [raft] [ceu] [voo] [cogumelos] [pedra] [armadilhas]

func put(x: float, y: float) -> void:
	g.CINE = {}
	g.VH.mode = ""
	g.player.x = x - 12
	g.player.y = y - 34
	g.player.vx = 0
	g.player.vy = 0
	g.player.vine = null
	g.player.ladder = null
	g.player.spawnX = g.player.x
	g.player.spawnY = g.player.y
	g.player.hp = 5
	g.snap_camera()
	for i in 10:
		frame()
	P = g.player

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(0)
	g.no_coal = true
	for e in g.EN:
		e.dead = 99
	g.lives = 9
	P = g.player
	g.rest_reached.connect(func(n):
		rests.append(n)
		g.running = true)
	var args := OS.get_cmdline_user_args()
	var all := args.is_empty()
	if all or args.has("armadilhas"):
		put(2525, 500)
		S("espinhos da manhã", cross_spikes(trap_at("spikes", 2560), 2700))
		S("sem dano (espinhos)", P.hp == 5)
		put(6950, -20)
		S("cortou a teia", cut_web(trap_at("web", 7340)))
		S("passou da teia", walk_to(7500))
		put(9800, 500)
		S("tronco-pêndulo", cross_swing(trap_at("swing", 10010), 10160))
		S("sem dano (tronco)", P.hp == 5)
		put(11560, 500)
		S("sob a colmeia", walk_to(11800))
		S("colmeia quieta", trap_at("hive", 11640).st == "idle")
		put(19665, 500)
		S("areia movediça", walk_to(19990))
		S("vivo na areia", g.lives >= 9)
		put(19760, 500)
		hold({}, 200)
		S("parado afunda", g.lives == 8)
		g.lives = 9
	if all or args.has("tronco"):
		put(4560, 500)
		use()
		S("quebrou o chão", g.X.broken.has("chao1"))
		walk_to(4610)
		S("desceu", climb_to("S", func(): return P.onGround and P.y > 800, 500))
		# solto lá embaixo (e com ↓ ainda apertado) ele não sobe sozinho
		hold({"S": true}, 40)
		hold({}, 120)
		S("continua no esconderijo", g.player.y > 800)
		S("sobe com ↑", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
	if all or args.has("raft"):
		put(25010, 500)
		walk_to(25050)
		jump_to(25165)
		S("pulou na jangada e embarcou", g.VH.mode == "raft")
		g.VH.mode = ""
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		put(25010, 500)
		walk_to(25040)
		use()
		S("subiu na jangada", g.VH.mode == "raft")
		S("corredeira", ride_raft())
		S("jangada inteira", g.VH.tries == 0 and P.hp == 5)
	if all or args.has("ceu"):
		put(52700, 500)
		S("subida", climb_gusts(55190))
		S("ponte", bridge_run(trap_at("bridge", 55220)))
		S("vivo na ponte", g.lives >= 9)
	if all or args.has("voo"):
		put(56960, 190)
		use()
		S("decolou", g.VH.mode == "plane")
		S("voo", fly_plane())
		S("voo sem batidas", P.hp == 5)
	if all or args.has("cogumelos"):
		put(64400, 500)
		walk_to(64805)
		S("saltador 1", bounce_to(64855))
		S("chapéu alto", P.y + P.h <= 232)
		S("cogumelo baixo", jump_to(65300))
		S("saltador 2", bounce_to(65345))
		S("chapéu mais alto", P.y + P.h <= 152)
		S("desce", jump_to(65825))
		S("fim", jump_to(66010))
		S("vivo", g.lives >= 9)
	if all or args.has("pedra"):
		put(72700, 500)
		S("túnel da pedra", walk_to(72850))
		var bol: Dictionary = trap_at("boulder", 72700)
		S("a pedra caiu", until({"R": true}, func(): return bol.st != "idle", 200))
		S("fuga da pedra", boulder_run(bol))
		S("sem ser atropelado", P.hp == 5)
		S("sai do buraco", jump_to(74540))
		S("barricada quebrada", walk_to(74900))
	if all or args.has("enchente"):
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		g.INV.append("engrenagem")
		put(13110, 900)
		S("chegou na escada", climb_to("U", func(): return g.EV.FL.st != "idle", 120))
		S("enchente começou", g.EV.FL.st in ["warn", "rise"])
		S("subiu antes da água", climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
		S("vivo na enchente", g.lives >= 9)
	if all or args.has("alavancas"):
		put(70910, 500)
		S("portão fechado", g.EV.GATE.lift < 1)
		walk_to(70925)
		use()
		walk_to(70985)
		use()
		S("portão abriu", until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 200))
		S("passa o portão", walk_to(71070))
	if all or args.has("treno"):
		put(51420, 500)
		walk_to(51440)
		use()
		S("subiu no trenó", g.VH.mode == "sled")
		var ok_sled = "timeout"
		for i in 600:
			if g.VH.mode == "":
				ok_sled = true
				break
			var nx := 99999.0
			for o in g.VH.OBS:
				if not o.hit and o.x > g.VH.hx and o.x - g.VH.hx < nx:
					nx = o.x - g.VH.hx
			if nx < 105 and g.VH.hy >= 499 and g.VH.vy == 0:
				press("J")
			frame({"J": true} if g.VH.vy < 0 else {})
		S("desceu de trenó", ok_sled)
		S("trenó sem batidas", P.hp == 5)
	for l in log_lines:
		print(l)
	print("FALHAS: ", fails)
	quit()
