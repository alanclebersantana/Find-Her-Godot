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
	g.lives = 9
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
		put(9800, 500)
		S("tronco-pêndulo", cross_swing(trap_at("swing", 10010), 10290))
		S("sem dano (tronco)", P.hp == 5)
		for hx in [21215.0, 15465.0, 22918.0]:
			# espaço de chão antes (para pousar e abaixar) e depois (para levantar)
			var ga: float = hx
			var gb: float = hx
			for k in 40:
				for so in g.L.solids:
					if so.t == "ground" and so.y == 500 and so.x <= ga - 1 and so.x + so.w >= ga - 1:
						ga = so.x
					if so.t == "ground" and so.y == 500 and so.x <= gb + 1 and so.x + so.w >= gb + 1:
						gb = so.x + so.w
			S("chão antes da colmeia %d >= 140 (%d)" % [int(hx), int(hx - 22 - ga)], hx - 22 - ga >= 140)
			S("chão depois da colmeia %d >= 110 (%d)" % [int(hx), int(gb - hx - 22)], gb - hx - 22 >= 108)
			put(hx - 70, 500)
			hold({}, 10)
			S("em pé toca a colmeia %d" % int(hx), g.hit(P, g.R(hx - 22, 0, 44, 2000)) == false and (P.y < 474))
			S("abaixado passa sob a colmeia %d" % int(hx), crawl(hx + 48))
			S("colmeia %d quieta" % int(hx), trap_at("hive", hx).st == "idle")
			put(hx - 70, 500)
			hold({}, 10)
			walk_to(hx + 48)
			S("andando em pé acorda a colmeia %d" % int(hx), trap_at("hive", hx).st == "angry")
			var hv0: Dictionary = trap_at("hive", hx)
			hv0.st = "idle"
			hv0.cool = 0
			hv0.sx = hv0.x
			hv0.sy = hv0.y - 20
			P.hp = 5
			P.iframe = 0
		put(15370, 500)
		S("sob a colmeia", crawl(15530))
		S("colmeia quieta", trap_at("hive", 15465).st == "idle")
		# cutucou a colmeia: só mergulhando no lago o enxame desiste
		var hv: Dictionary = trap_at("hive", 15465)
		g.TR._hive_wake(hv)
		S("enxame acordou", hv.st == "angry")
		S("pula no lago", walk_to(15700))
		hold({"S": true}, 50)
		S("mergulhou e despistou", until({"S": true}, func(): return hv.st != "angry", 200))
		hold({"J": true}, 60)
		put(19665, 500)
		S("areia movediça", walk_to(19990))
		S("vivo na areia", g.lives >= 9)
		put(19760, 500)
		hold({}, 200)
		S("parado afunda", g.lives == 8)
		g.lives = 9
	if all or args.has("tronco"):
		put(4605, 500)
		use()
		S("picareta não quebra (é do mergulho)", not g.X.broken.has("chao1"))
		slam_here()
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
		# não dá para voltar para a água depois do fim (cerca na margem)
		hold({"L": true}, 120)
		S("cerca segura na margem final", px() > float(g.VH.RA.x1) - 4 and g.VH.mode == "")
		var jj := 0
		for i in 6:
			press("J")
			hold({"L": true, "J": true}, 40)
		S("nem pulando volta para a água", px() > float(g.VH.RA.x1) - 4)
	if all or args.has("rio"):
		# pular no rio de vários pontos do barranco: sempre cai na jangada, sem morrer
		for k in 5:
			g.load_level(0)
			for e in g.EN:
				e.dead = 99
			put(25010, 500)
			walk_to(25040 + k * 6)
			var lv: int = g.lives
			press("J")
			hold({"R": true, "J": true}, 8 + k * 6)
			var ok := false
			for i in 120:
				frame({"R": true} if i < 20 + k * 8 else {})
				if g.VH.mode == "raft":
					ok = true
					break
			S("pulo %d no rio caiu na jangada" % k, ok and g.lives == lv)
		# morreu no meio da corredeira: volta e a jangada está no cais
		g.VH.mode = ""
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		put(25010, 500)
		walk_to(25040)
		use()
		hold({}, 200)
		S("no meio da corredeira", g.VH.mode == "raft")
		g.player.spawnX = 25000
		g.player.spawnY = 466
		g.die("teste")
		hold({}, 200)
		S("voltou da morte a pé", g.VH.mode == "")
		S("jangada de volta ao cais", abs(g.VH.RA.px - float(g.VH.RA.x)) < 1 and g.SOL.has(g.VH.RAFT_SOL))
		walk_to(25040)
		use()
		S("embarca de novo", g.VH.mode == "raft")
	if all or args.has("ceu"):
		put(52700, 500)
		S("subida", climb_gusts(55190))
		S("ponte", bridge_run(trap_at("bridge", 55220)))
		S("vivo na ponte", g.lives >= 9)
	if all or args.has("voo"):
		# espaço entre os obstáculos do voo: ondas com trechos calmos para aproveitar o céu
		var xs: Array = g.L.plane.obs.map(func(o): return float(o.x))
		xs.sort()
		var mind := 1e9
		var calm := 0
		var prev: float = float(g.L.plane.edge)
		for x in xs:
			mind = min(mind, x - prev) if prev > float(g.L.plane.edge) else mind
			if x - prev >= 900:
				calm += 1
			prev = x
		S("obstáculos do voo espaçados (>= 400)", mind >= 400)
		S("trechos calmos no voo (>= 3)", calm >= 3)
		put(56960, 190)
		use()
		S("decolou", g.VH.mode == "plane")
		S("voo", fly_plane())
		S("voo sem batidas", P.hp == 5)
	if all or args.has("cogumelos"):
		put(64400, 500)
		walk_to(64470)
		S("pula a caixa de coração", jump_to(64610, true))
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
		g.lives = 9
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
	if all or args.has("mergulho"):
		# estaca: subir nela e mergulhar baixa a ponte do riacho
		put(2040, 456)
		var stk: Dictionary = g.SL.STAKES[0]
		S("ponte em pé", not g.SOL.has(stk.sol))
		S("em cima da estaca", P.onGround and P.y + P.h < 470)
		slam_here()
		S("estaca cravada", stk.done)
		hold({}, 120)
		S("ponte deitou", g.SOL.has(stk.sol))
		S("atravessa a ponte", walk_to(2380))
		S("seco (não caiu na água)", not P.swim)
		# gangorra: mergulho na ponta de cá lança a pedra e caem lápis e uma fruta
		put(63485, 456)
		var sw: Dictionary = g.SL.SAWS[0]
		var c0: int = g.coin_life
		S("na ponta de cá", P.onGround and P.y + P.h < 470)
		slam_here()
		S("gangorra lançou", sw.done)
		hold({}, 150)
		S("caiu coisa da árvore", g.SL.DROPS.size() >= 5)
		for d in g.SL.DROPS:
			if not d.got:
				walk_to(d.x)
		S("pegou os lápis", g.coin_life > c0)
		# arbusto de frutas: o mergulho perto derruba as frutas; cada uma devolve um coração
		put(66220, 500)
		P.hp = 3
		slam_here()
		hold({}, 60)
		S("frutas caíram", g.SL.FRUIT[1].left == 0)
		walk_to(66330)
		walk_to(66270)
		S("comeu fruta (+coração)", P.hp >= 4)
		# onda de choque: um bicho do chão por perto fica tonto
		put(34120, 500)
		var en: Dictionary = {}
		for e in g.EN:
			if e.k == "squirrel":
				en = e
				break
		en.dead = 0
		en.x = 34210.0
		en.y = 500.0
		en.base = 500.0
		en.r = [34230, 34260]
		slam_here()
		S("bicho ficou tonto", en.stun > 0)
		en.dead = 99
	if all or args.has("treno"):
		put(51420, 500)
		walk_to(51440)
		use()
		S("subiu no trenó", g.VH.mode == "sled")
		var VH = g.VH
		S("descida comprida (>= 4000)", float(VH.SL.len) >= 4000)
		var ok_sled = "timeout"
		var top_spd := 0.0
		for i in 3000:
			if g.VH.mode == "":
				ok_sled = true
				break
			top_spd = max(top_spd, VH.spd)
			var d := {}
			var gy: float = VH.sled_y(VH.su)
			var ground: bool = VH.hy >= gy - 1
			for o in VH.OBS:
				var dx: float = o.x - VH.hx
				if o.hit or o.k == "bump" or dx < -140 or dx > 300:
					continue
				if o.k in ["rock", "log"] and ground and dx < VH.spd * 9.0 + 10 and dx > 20:
					press("J")
				if o.k == "crack" and ground and dx < 40 and dx > -5:
					press("J")
				if o.k == "branch" and dx < 110 and dx > -70:
					d["S"] = true
				break
			frame(d)
		S("desceu de trenó", ok_sled)
		S("velocidade cresce na descida (> 7)", top_spd > 7.0)
		S("trenó sem batidas", P.hp == 5 and VH.tries == 0)
	if all or args.has("urso"):
		put(50150, 500)
		S("Urso-Rei", bear_fight())
		S("urso: Tomé vivo", g.lives >= 9)
		# o galho não é esconderijo: parado nele, o urso sacode a árvore e derruba
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		P = g.player
		put(50150, 500)
		hold({}, 300)
		var bb: Dictionary = g.K.BEAR
		bb.x = 50900.0
		bb.st = "walk"
		put(50345, 310)
		var shook := false
		for i in 600:
			frame()
			if bb.st == "shake":
				shook = true
			if shook and bb.st == "back":
				break
		S("urso sacode o galho", shook)
		S("Tomé caiu do galho", g.player.y + g.player.h > 400)
	if all or args.has("cavalo"):
		put(39380, 500)
		for h in g.NT.HOLES:
			h.filled = true
		S("cavalo preso", g.RD.H.st == "trapped")
		walk_to(39440)
		use()
		S("cavalgada começou", until({}, func(): return g.RD.riding, 500))
		var obsd: Array = g.RD.OBS.map(func(o): return float(o.x))
		var md := 1e9
		for i in range(1, obsd.size()):
			md = min(md, obsd[i] - obsd[i - 1])
		S("obstáculos da cavalgada espaçados (>= 600)", md >= 600)
		S("cavalgada", ride())
		S("cavalgada sem batidas", P.hp == 5 and g.RD.tries == 0)
	if all or args.has("machado"):
		var ax: Dictionary = g.TR.by_kind("axe")[0]
		var bad := 0
		for k in 8:
			put(64010, 500)
			for e in g.EN:
				e.dead = 99
			hold({}, k * 16)
			walk_to(64020)
			until({}, func(): g.TR.axe_blade(ax); return ax.ang > .35, 300)
			var hp0: int = P.hp
			jump_to(64360, true)
			if P.hp < hp0:
				bad += 1
		S("pulos bem feitos sobre a lâmina sem dano (%d batidas)" % bad, bad == 0)
		put(64200, 500)
		var hp1: int = P.hp
		hold({}, 140)
		S("parado no caminho da lâmina leva dano", P.hp < hp1)
		# em cima da haste/forca não machuca
		var pts: PackedVector2Array = g.TR.axe_points(ax, 0.0)
		S("haste não está na área de dano", pts.size() == 18)
	if all or args.has("gelo"):
		put(35200, 500)
		for e in g.EN:
			e.dead = 99
		for o in g.TR.T:
			if o.k == "roll":
				o.st = "done"
		walk_to(35280)
		S("pula o buraco de gelo aberto", jump_to(35565, true))
		S("passou vivo", g.lives >= 9 and px() > 35510)
	if all or args.has("pingentes"):
		var ic: Dictionary = trap_at("icicle", 37450)
		put(37300, 868)
		S("pingente pronto", ic.st == "idle" and ic.grow >= 1.0)
		put(37452, 868)
		S("pingente tremendo", until({}, func(): return ic.st == "shake", 60))
		var t0: int = g.T
		S("treme ~1 s antes de cair", until({}, func(): return ic.st == "fall", 120) and g.T - t0 >= 50)
		S("cai e acerta quem fica parado", until({}, func(): return ic.st == "broken", 120) and P.hp == 4)
		S("volta a crescer", until({}, func(): return ic.st == "shake" or (ic.st == "idle" and ic.grow >= 1.0), 400))
		var ic2: Dictionary = trap_at("icicle", 37080)
		put(36950, 868)
		S("pingente 2 tremendo", until({"R": true}, func(): return ic2.st == "shake", 120))
		S("dá tempo de fugir", walk_to(36960) and until({}, func(): return ic2.st == "broken", 200) and P.hp == 5)
	for l in log_lines:
		print(l)
	print("FALHAS: ", fails)
	quit()
