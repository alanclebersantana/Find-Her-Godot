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
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(52800, 500)
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
		put(56600, 190)
		g.comic_req = ""
		var cams: Array = []
		var boarded = until({"R": true}, func(): return g.VH.mode == "plane", 900)
		S("chegou no avião: embarca sozinho", boarded)
		S("chegou no avião: quadrinho", g.comic_req == "aviao" or g.auto_cine)
		S("embarque: Tomé sobe na cabine", g.VH.phase == "board")
		var pc: float = g.cam
		var pcy: float = g.cam_y
		var jump_cam := 0.0
		for i in 260:
			frame()
			jump_cam = max(jump_cam, abs(g.cam - pc) + abs(g.cam_y - pcy))
			pc = g.cam
			pcy = g.cam_y
			if g.VH.phase == "fly" and i > 200:
				break
		S("decolou sozinho (sem botão)", g.VH.phase == "fly")
		S("câmera sem pulo no embarque/decolagem (< 30)", jump_cam < 30.0)
		S("decolou", g.VH.mode == "plane")
		S("voo", fly_plane())
		S("voo sem batidas", P.hp == 5)
	if all or args.has("transicoes"):
		# a câmera não pula ao subir/descer dos veículos (só com a tela fechada, na troca de lugar do trenó)
		var meas := func(n: int, set: Dictionary) -> float:
			var mx := 0.0
			var c0: float = g.cam
			var c1: float = g.cam_y
			for i in n:
				var covered: bool = g.VH.mode == "sled" and (g.VH.sboard == 1 or g.VH.sfin == 1)
				frame(set)
				var dj: float = abs(g.cam - c0) + abs(g.cam_y - c1)
				if not covered and g.iris_t < 29:
					mx = max(mx, dj)
				c0 = g.cam
				c1 = g.cam_y
			return mx
		# jangada: pula do barranco direto no rio
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(25000, 500)
		hold({}, 30)
		var jr1: float = meas.call(10, {"R": true})
		press("J")
		var jr2: float = meas.call(140, {"R": true})
		S("pulou no rio: caiu na jangada", g.VH.mode == "raft")
		S("jangada: câmera suave (< 30)", max(jr1, jr2) < 30.0)
		# fim da jangada: vai devagar até a margem
		g.VH.hx = float(g.VH.RA.x1) - 600.0
		for o in g.VH.OBS:
			o.hit = true
		hold({}, 20)
		var sl_end := false
		var fin_cam: float = meas.call(200, {})
		for i in 200:
			if g.VH.mode != "raft":
				break
			if g.VH.hx > float(g.VH.RA.x1) - 120 and g.VH.spd < float(g.VH.RA.spd) * .75:
				sl_end = true
			frame()
		S("jangada: desacelera antes da margem", sl_end or g.VH.raft_done)
		S("jangada: desembarque sem pulo de câmera (< 30)", fin_cam < 30.0)
		# trenó: senta, escorrega, a tela fecha e abre lá no morro
		g.load_level(0)
		P = g.player
		put(51420, 500)
		walk_to(51440)
		use()
		S("trenó: embarque com animação", g.VH.mode == "sled" and g.VH.sboard > 0)
		var sc: float = meas.call(80, {})
		S("trenó: chegou na descida", g.VH.sboard == 0 and g.VH.su > 30)
		S("trenó: câmera só troca com a tela fechada (< 40)", sc < 40.0)
		# cavalo: começa e termina sem pulo de câmera
		g.load_level(0)
		P = g.player
		put(39380, 500)
		for h in g.NT.HOLES:
			h.filled = true
		walk_to(39440)
		use()
		var hc: float = meas.call(120, {})
		S("cavalo: câmera suave na partida (< 30)", hc < 30.0)
		g.load_level(0)
		P = g.player
	if all or args.has("cogumelos"):
		put(64400, 500)
		walk_to(64470)
		S("pula a caixa de coração", jump_to(64610, true))
		walk_to(64805)
		S("saltador 1", bounce_to(64855))
		S("chapéu alto", P.y + P.h <= 232)
		S("saltador 2: o gigante laranja lança sozinho", bounce_to(65315))
		S("chapéu mais alto", P.y + P.h <= 152)
		S("desce", jump_to(65825))
		S("fim", jump_to(66010))
		S("vivo", g.lives >= 9)
		# sem cogumelinho em cima dos gigantes; todo saltador é um gigante laranja
		var small_on_top := false
		for o in g.TR.T:
			if o.k == "bounce" and o.x > 64000 and o.x < 67000:
				small_on_top = true
		S("sem cogumelo pequeno em cima dos gigantes", not small_on_top)
		# o buraco embaixo dos cogumelos tem água verde de veneno (e os outros buracos da noite também)
		var all_filled := true
		for pt in g.L.pits:
			if float(pt[0]) < 64900:
				continue
			var f := false
			for sw in g.SWAMP:
				if float(sw.x) <= float(pt[0]) + 1 and float(sw.x) + float(sw.w) >= float(pt[1]) - 1:
					f = true
			if not f:
				all_filled = false
		S("buracos da noite com água venenosa", all_filled)
		# cair no buraco: afunda na água verde
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(65000, 300)
		var drown := false
		for i in 200:
			frame()
			if P.dyingT > 0 and str(P.dieMsg).contains("brejo"):
				drown = true
				break
		S("caiu no buraco: água venenosa mata", drown)
		# o Pipoca vem junto pelos saltadores
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(64700, 500)
		g.X.DOG.st = "follow"
		g.X.DOG.x = 64650.0
		g.X.DOG.y = 500.0
		hold({}, 30)
		walk_to(64805)
		bounce_to(64855)
		bounce_to(65315)
		jump_to(65825)
		jump_to(66010)
		hold({}, 240)
		S("Pipoca acompanha pelos cogumelos", abs(float(g.X.DOG.x) - px()) < 300)
	if all or args.has("pedra"):
		put(72700, 500)
		S("túnel da pedra", walk_to(72850))
		var bol: Dictionary = trap_at("boulder", 72700)
		S("a pedra caiu", until({"R": true}, func(): return bol.st != "idle", 200))
		S("fuga da pedra", boulder_run(bol))
		S("sem ser atropelado", P.hp == 5)
		until({"S": true}, func(): return bol.st in ["break", "done"], 600)
		S("sai do buraco", jump_to(76340))
		S("barricada quebrada", walk_to(76700))
	if all or args.has("vargas"):
		# trecho da pedra gigante ~2x mais comprido
		var bo: Dictionary = trap_at("boulder", 72700)
		S("pedra gigante: trecho comprido (>= 3200)", float(bo.end) - float(bo.trig) >= 3200)
		# perseguição do Vargas: sem óleo, sem pedra rolando, lanterna cheia e sem medidor
		var vt: float = float(g.L.villain.trig)
		var oil_in := 0
		for c in g.OIL:
			if float(c.x) > vt - 100:
				oil_in += 1
		S("perseguição sem potes de óleo", oil_in == 0)
		var roll_in := false
		for o in g.TR.T:
			if o.k == "roll" and float(o.x) > vt - 300:
				roll_in = true
		S("perseguição sem pedra rolando", not roll_in)
		g.FUEL = .2
		put(vt + 150, 500)
		hold({"R": true}, 60)
		S("lanterna cheia na perseguição", g.FUEL >= 1.0)
		S("medidor escondido na perseguição", g.chase_on())
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
		S("velocidade cresce na descida (> 6.5)", top_spd > 6.5)
		S("velocidade máxima menor (<= 8)", top_spd <= 8.01)
		S("trenó sem batidas", P.hp == 5 and VH.tries == 0)
		# obstáculos bem espaçados (dá para pousar de um pulo antes do próximo)
		var us: Array = []
		for o in VH.SL.obs:
			us.append(float(o.u))
		us.sort()
		var gap_ok := true
		for i in us.size() - 1:
			if us[i + 1] - us[i] < 650:
				gap_ok = false
		S("obstáculos do trenó espaçados (>= 650)", gap_ok)
		# batidas de propósito nas duas primeiras: perde 1 coração cada e segue (sem voltar)
		g.load_level(0)
		P = g.player
		put(51420, 500)
		walk_to(51440)
		use()
		VH = g.VH
		var back := false
		var last_u := 0.0
		var hits := 0
		ok_sled = "timeout"
		for i in 3000:
			if g.VH.mode == "":
				ok_sled = true
				break
			if VH.su < last_u - .5:
				back = true
			last_u = VH.su
			var d := {}
			var ground: bool = VH.hy >= VH.sled_y(VH.su) - 1
			var nhit := 0
			for o in VH.OBS:
				if o.hit:
					nhit += 1
			hits = nhit
			for o in VH.OBS:
				var dx: float = o.x - VH.hx
				if o.hit or dx < -140 or dx > 300:
					continue
				if float(o.u) < 1500:
					break   # bate de propósito nas duas primeiras
				if o.k in ["rock", "log"] and ground and dx < VH.spd * 9.0 + 10 and dx > 20:
					press("J")
				if o.k == "crack" and ground and dx < 40 and dx > -5:
					press("J")
				if o.k == "branch" and dx < 110 and dx > -70:
					d["S"] = true
				break
			frame(d)
		S("batidas: segue descendo sem recomeçar", ok_sled == true and not back)
		S("batidas: perdeu 2 corações", P.hp == 3 and hits == 2)
		S("batidas: Tomé vivo no fim", g.lives == 9 and P.dyingT == 0)
		# batendo em tudo: sem corações, morre e volta para a fogueira; o trenó fica no alto de novo
		g.load_level(0)
		P = g.player
		put(51420, 500)
		walk_to(51440)
		use()
		VH = g.VH
		var lv0: int = g.lives
		var died := false
		for i in 3000:
			if P.dyingT > 0:
				died = true
			if died and P.dyingT == 0:
				break
			frame({})
		hold({}, 40)
		S("bateu em tudo: morreu", died and g.lives <= lv0)
		S("bateu em tudo: volta da fogueira", VH.mode == "" and abs(px() - 51320) < 200)
		S("bateu em tudo: trenó de volta no alto", not VH.sled_done and VH.near_sled() or abs(float(VH.SL.x) - px()) < 300)
	if all or args.has("urso"):
		put(50250, 500)
		S("Urso-Rei", bear_fight())
		S("urso: Tomé vivo", g.lives >= 9)
		# o galho não é esconderijo: parado nele, o urso sacode a árvore e derruba
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		P = g.player
		put(50250, 500)
		hold({}, 300)
		var bb: Dictionary = g.K.BEAR
		bb.x = 50950.0
		bb.st = "walk"
		put(50325, 310)
		var shook := false
		for i in 600:
			frame()
			if bb.st == "shake":
				shook = true
			if shook and bb.st == "back":
				break
		S("urso sacode o galho", shook)
		S("Tomé caiu do galho", g.player.y + g.player.h > 400)
		# os muros não dão para pular (do chão, do bloco de gelo, do galho, com pulo duplo)
		g.load_level(0)
		for e in g.EN:
			e.dead = 99
		P = g.player
		put(50250, 500)
		hold({}, 300)
		var esc := false
		for side in ["L", "R"]:
			for start in [50110.0, 50340.0, 50830.0, 51100.0]:
				put(start, 500)
				g.K.BEAR.x = 50600.0
				g.K.BEAR.st = "dizzy"
				g.K.BEAR.t = 0
				djump(side)
				hold({side: true}, 60)
				if px() < 50060 or px() > 51150:
					esc = true
		put(50325, 310)
		djump("L")
		hold({"L": true}, 60)
		if px() < 50060:
			esc = true
		put(50825, 310)
		djump("R")
		hold({"R": true}, 60)
		if px() > 51150:
			esc = true
		S("não pula os muros da arena", not esc)
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
		S("velocidade do cavalo 5.2", abs(float(g.RD.H.spd) - 5.2) < .01)
		S("cavalgada", ride())
		S("cavalgada sem batidas", P.hp == 5 and g.RD.tries == 0)
		# o fim: o cavalo vai parando, o Tomé desce com calma, faz carinho e o cavalo vai embora trotando
		g.load_level(0)
		P = g.player
		for e in g.EN:
			e.dead = 99
		put(39380, 500)
		for h in g.NT.HOLES:
			h.filled = true
		walk_to(39440)
		use()
		until({}, func(): return g.RD.riding, 500)
		for o in g.RD.OBS:
			o.hit = true
		g.RD.hx = float(g.RD.H.ride1) - 900.0
		var max_end := -1
		var slowed := false
		var gone_t := 0
		for i in 900:
			frame()
			max_end = max(max_end, g.RD.endT)
			if g.RD.riding and g.RD.endT < 0 and g.RD.spd < 2.0:
				slowed = true
			if not g.RD.riding and g.RD.H.st in ["gone", "away"]:
				gone_t += 1
			if g.RD.H.st == "away":
				break
		S("fim: cavalo desacelera até parar", slowed)
		S("fim: cena de desmontar (>= 160 quadros)", max_end >= 160)
		S("fim: Tomé no chão depois de descer", P.onGround and not g.RD.riding)
		S("fim: cavalo vai embora devagar", gone_t > 60)
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
