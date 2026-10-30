extends "res://tests/route2.gd"
## Teste automático do Episódio 3 (O Covil do Vargas · a fortaleza na serra): joga a fase inteira, da
## trilha da serra até a estação velha, pegando as 6 pistas, os 6 lápis especiais e os desenhos, e
## passando pelos dois caminhos onde há escolha (o de cima e o de baixo).
##   godot --headless --path . -s tests/route3.gd

func S(name: String, r) -> void:
	super.S(name, r)
	if OS.get_environment("DBG") != "":
		print(log_lines[-1])

## espera a tábua que vai e vem (k "path") chegar perto da ponta e pula nela
func board_path(o: Dictionary, at_start: bool):
	var s: Dictionary = o.plats[0]
	var x_end: float = float(o.x0) if at_start else float(o.x1)
	var r = until({}, func(): return absf(float(s.x) - x_end) < 6, 900)
	if not (r is bool and r):
		return "a tábua não veio: " + str(r)
	press("J")
	for i in 160:
		var d := {"J": i < 16}
		var c: float = float(s.x) + float(s.w) / 2
		if px() < c - 8:
			d["R"] = true
		elif px() > c + 8:
			d["L"] = true
		frame(d)
		P = g.player
		if P.onGround and P.get("_g") == s:
			return true
		if not ok():
			return "state"
	return "não subiu na tábua y=%d" % int(P.y)

func ride_path(o: Dictionary, to_end: bool):
	var s: Dictionary = o.plats[0]
	var x_end: float = float(o.x1) if to_end else float(o.x0)
	for i in 900:
		P = g.player
		if P.get("_g") != s:
			return "caiu da tábua"
		if absf(float(s.x) - x_end) < 8:
			return true
		var c: float = float(s.x) + float(s.w) / 2
		var d := {}
		if px() < c - 20:
			d["R"] = true
		elif px() > c + 20:
			d["L"] = true
		frame(d)
	return "timeout"

## sobe no vapor segurando PULAR até a condição
func steam_to(x: float, cond: Callable, mx: int = 400):
	press("J")
	var used := false
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		if cond.call():
			return true
		var d := {"J": true}
		if px() < x - 6:
			d["R"] = true
		elif px() > x + 6:
			d["L"] = true
		if not used and i > 14 and P.vy > -1:
			press("J")
			used = true
		frame(d)
	return "timeout@%d,%d" % [int(px()), int(P.y)]

## Enguia de Cristal: sai do pilar que borbulha; com ela tonta no pilar, pula na cabeça
func eel_fight():
	var B3 = g.K.B3
	var b: Dictionary = B3.boss("enguia")
	for it in 6000:
		if OS.get_environment("DBG") != "" and it % 20 == 0:
			print("EEL it=%d st=%s t=%d hp=%d bx=%d px=%d py=%d php=%d lives=%d" % [it, b.st, b.t, b.hp, int(b.x), int(px()), int(P.y + P.h), P.hp, g.lives])
		P = g.player
		if not ok():
			return "state"
		if b.done or b.st == "down":
			hold({}, 30)
			return true
		var on: int = B3._on_pillar(b)
		if P.onGround and on < 0:
			jump_to(B3._pc(b, B3._pillar_of(px(), b)), true)
			continue
		if b.st == "warn" and on >= 0 and absf(B3._pc(b, on) - float(b.tx)) < 5 and P.onGround:
			var nx: int = on + 1 if on + 1 < b.pillars.size() else on - 1
			jump_to(B3._pc(b, nx), true)
			continue
		if b.st == "stun" and b.t > 8 and P.onGround and on >= 0 and absf(B3._pc(b, on) - b.x) > 5:
			jump_to(b.x, true)
			continue
		frame()
	return "timeout st=%s hp=%d" % [b.st, b.hp]

## Salamandra de Fogo: espera no balcão da 1ª caixa; vira a água quando ela passa embaixo; apagada,
## pula em cima dela e volta para o balcão
func sal_fight():
	var B3 = g.K.B3
	var b: Dictionary = B3.boss("salamandra")
	var t0: Dictionary = B3.TANKS[0]
	walk_to(float(b.trig) + 40)
	jump_to(float(t0.lever), true)
	for it in 8000:
		if OS.get_environment("DBG") != "" and (it % 20 == 0 or (OS.get_environment("DBG") == "2" and b.st in ["cool", "hurt", "flee"])):
			print("SAL it=%d st=%s t=%d hp=%d bx=%d px=%d py=%d php=%d lives=%d" % [it, b.st, b.t, b.hp, int(b.x), int(px()), int(P.y + P.h), P.hp, g.lives])
		P = g.player
		if not ok():
			return "state"
		if b.done or b.st == "down":
			hold({}, 30)
			return true
		var on_balc: bool = P.onGround and absf(P.y + P.h - float(t0.py)) < 6
		if b.st == "cool" and b.t > 10 and b.t < 170:
			# pula do balcão em cima dela; acertou, volta direto para o balcão
			press("J")
			for k in 120:
				P = g.player
				if b.st != "cool" or (P.onGround and k > 6):
					break
				frame({"R" if b.x > px() else "L": true, "J": k < 10})
			continue
		if P.onGround and not on_balc:
			# no chão: pula a bola de fogo que vem rente ao chão, senão volta para o balcão
			var fire_near := false
			for sh in B3.SHOTS:
				if sh.k == "fire" and absf(sh.x - px()) < 110 and signf(px() - sh.x) == signf(sh.vx):
					fire_near = true
			if fire_near:
				press("J")
				hold({"J": true}, 14)
				continue
			jump_to(float(t0.lever), true)
			continue
		if on_balc and absf(px() - float(t0.lever)) > 8:
			frame({"R" if float(t0.lever) > px() else "L": true})
			continue
		if t0.st == "full" and b.st == "walk" and absf(b.x - float(t0.x)) < 60:
			use()
			continue
		frame()
	return "timeout st=%s hp=%d" % [b.st, b.hp]

## Guardião de Ferro: fica longe; pula as ondas; com os punhos presos, picareta nele (2 golpes) e
## passa para o lado onde há mais espaço
func gua_fight():
	var B3 = g.K.B3
	var b: Dictionary = B3.boss("guardiao")
	walk_to(float(b.trig) + 30)
	var side := -1.0
	for it in 9000:
		if OS.get_environment("DBG") != "" and it % 20 == 0:
			print("GUA it=%d st=%s t=%d hp=%d bx=%d px=%d py=%d php=%d lives=%d" % [it, b.st, b.t, b.hp, int(b.x), int(px()), int(P.y + P.h), P.hp, g.lives])
		P = g.player
		if not ok():
			return "state"
		if b.done or b.st == "down":
			hold({}, 30)
			return true
		var pcx: float = px()
		var wave := false
		for sh in B3.SHOTS:
			if sh.k == "wave" and absf(sh.x - pcx) < 80 and signf(pcx - sh.x) == signf(sh.vx):
				wave = true
		if wave and P.onGround:
			press("J")
			hold({"J": true}, 14)
			continue
		if b.st == "stuck":
			var gx: float = b.x + side * 92.0
			if absf(pcx - gx) > 10:
				frame({"R" if gx > pcx else "L": true})
				continue
			if (b.x > pcx) != (P.face > 0):
				frame({"R" if b.x > pcx else "L": true})
				continue
			press("G")
			hold({}, 24)
			continue
		if b.st == "hurt":
			# passa por ele (preso/tonto não machuca) para o lado com mais espaço
			side = -1.0 if (b.x - float(b.x0)) > (float(b.x1) - b.x) else 1.0
		var want: float = clampf(b.x + side * 270.0, float(b.x0) + 40, float(b.x1) - 40)
		if absf(want - b.x) < 200:
			side = -side
			want = clampf(b.x + side * 270.0, float(b.x0) + 40, float(b.x1) - 40)
		if absf(pcx - want) > 24 and b.st in ["walk", "hurt", "fight0", "stuck"]:
			frame({"R" if want > pcx else "L": true})
		else:
			frame()
	return "timeout st=%s hp=%d" % [b.st, b.hp]

func mover(k: String, x: float) -> Dictionary:
	for o in g.MV.MV:
		if o.k == k and absf(float(o.get("x0", o.get("x", 0))) - x) < 5:
			return o
	return {}

## anda até x pulando as pedras que rolam na direção do Tomé
func dodge_to(x: float, mx: int = 1500):
	var hold_j := 0
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		var ahead := false
		for o in g.TR.T:
			if o.k == "roll" and o.st in ["idle", "go"] and float(o.get("bx", o.x)) > px() - 40 and absf(float(o.x) - px()) < 900:
				ahead = true
		if px() >= x and P.onGround and not ahead:
			return true
		for o in g.TR.T:
			if o.k == "roll" and o.st == "go" and P.onGround and hold_j <= 0:
				var dx: float = float(o.get("bx", o.x)) - px()
				if dx > 0 and dx < 16.0 * (4.3 + absf(float(o.get("vx", 0.0)))) + 24.0:
					press("J")
					hold_j = 18
		hold_j -= 1
		var go_r: bool = px() < x or (ahead and px() < x + 40)
		frame({"R": go_r, "J": hold_j > 0})
	return "timeout@%d" % int(px())

## anda pela passarela no vento: quando a rajada sopra, abaixa e espera
func gust_walk(x: float):
	for i in 2000:
		P = g.player
		if not ok():
			return "state"
		if px() >= x and P.onGround:
			return true
		var blowing := false
		for o in g.TR.T:
			if o.k == "gust" and g.TR.gust_state(o) == 2 and px() > o.x - 40 and px() < o.x + o.w + 40:
				blowing = true
		frame({"S": true} if blowing else {"R": true})
	return "timeout@%d" % int(px())

## passa pelo vigia: espera abaixado atrás de um caixote/barril; quando ele já passou indo para a
## esquerda (de costas para o Tomé), corre para a direita
func sneak_past(w: Dictionary, x_end: float):
	var V = g.VL
	var spot: Dictionary = {}
	for i in 5000:
		P = g.player
		if not ok():
			return "state"
		if px() >= x_end:
			return true
		var wx: float = float(w.x)
		if float(w.dir) < 0 and int(w.wait) == 0 and wx < px() - 60:
			# ele está de costas, indo embora para a esquerda: corre
			spot = {}
			frame({"R": true})
			continue
		# escolhe o esconderijo: o mais à direita que fique bem atrás dele (ou o mais perto, se ele vem)
		if spot.is_empty() or (float(w.dir) > 0 and int(w.wait) == 0):
			var best: Dictionary = {}
			for h in V.HIDES:
				var hc: float = float(h.x) + float(h.w) / 2
				if hc < wx - 300 and (best.is_empty() or hc > float(best.x)):
					best = h
			if best.is_empty():
				var bd := 1e9
				for h in V.HIDES:
					var hc3: float = float(h.x) + float(h.w) / 2
					if absf(hc3 - px()) < bd:
						bd = absf(hc3 - px())
						best = h
			spot = best
		var hc2: float = float(spot.x) + float(spot.w) / 2
		if absf(px() - hc2) > 6:
			frame({"R": true} if hc2 > px() else {"L": true})
		else:
			frame({"S": true})
	return "timeout@%d" % int(px())

func lift_up(o: Dictionary):
	var s: Dictionary = o.plats[0]
	var r = walk_to(float(s.x) + float(s.w) / 2)
	if not (r is bool and r):
		return "até o elevador: " + str(r)
	use()
	return until({}, func(): return float(o.pos) == 0.0 and float(o.goal) == 0.0, 900)

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(2)
	g.no_coal = true
	for e in g.EN:
		e.dead = 99
	P = g.player
	g.rest_reached.connect(func(n):
		rests.append(n)
		print("REST ", n, " T=", g.T)
		g.running = true)
	var L: Dictionary = g.L
	# ---------------- A · A TRILHA DA SERRA
	S("Pipoca junto", g.X.dog_free())
	walk_to(1060)
	S("degrau 1", jump_to(1170))
	S("degrau 2", jump_to(1310))
	S("degrau 3", jump_to(1450))
	S("em cima do penhasco", walk_to(1970) and P.y < 250)
	S("tábua do vermelho", jump_to(2050))
	hop("R", 0)
	S("vermelho", spec("vermelho"))
	S("desce do penhasco", until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	hold({}, 24)
	walk_to(2620)
	S("passagem baixa (de volta, abaixado)", crawl(2200))
	S("pista 18 no túnel", n_clues() == 1)
	S("sai do túnel", crawl(2620))
	S("pedras rolando", dodge_to(3200))
	walk_to(3240)
	walk_to(3300)
	S("ponte podre 1", jump_to(3375))
	S("ponte podre 2", jump_to(3470))
	S("ponte podre 3", jump_to(3565))
	S("ponte podre 4", jump_to(3660))
	S("outro lado", jump_to(3780))
	S("pé da muralha", walk_to(4420))
	S("sobe entre as paredes", crevice_climb())
	if P.y + P.h > -250:
		jump_to(4540, true)
	S("no alto da muralha", P.onGround and P.y + P.h <= -255)
	S("passarela com vento", gust_walk(5300))
	# volta e desce para entrar pelo bueiro (o desenho fica no túnel)
	walk_to(4500)
	until({"L": true}, func(): return P.onGround and P.y > 400, 300)
	S("até o bueiro", walk_to(4215))
	down()
	S("entrou no bueiro", until({}, func(): return P.y > 800 and P.onGround, 200))
	walk_to(4680)
	S("passagem baixa do túnel", crawl(4990))
	S("desenho do túnel", walk_to(5500))
	walk_to(5725)
	press("U")
	S("saiu no pátio", until({}, func(): return P.y < 600 and P.onGround, 200))
	S("fogueira 1", walk_to(5810))
	S("descansou 1", rests.has(1))
	# ---------------- B · O PÁTIO DOS VIGIAS
	walk_to(6465)
	S("sobe para a passarela", climb_to("U", func(): return P.onGround and P.y + P.h <= 252, 400))
	walk_to(6700)
	S("tábua 2", jump_to(6880))
	walk_to(7000)
	S("tábua podre", jump_to(7170))
	S("tábua do laranja", jump_to(7420, true))
	hop("R", 0)
	S("laranja", spec("laranja"))
	walk_to(7560)
	S("última tábua", jump_to(7740))
	walk_to(8060)
	S("vigia não pegou", g.VL.caught_n == 0)
	S("andaime 1", jump_to(8200))
	S("andaime 2", jump_to(8420, true))
	S("andaime 3", jump_to(8730, true))
	S("andaime 4", jump_to(9000, true))
	S("andaime 5", jump_to(9220, true))
	S("desce longe do cão", until({"R": true}, func(): return P.onGround and P.y > 400 and px() > 9300, 300))
	S("pista 16", walk_to(9800) and n_clues() == 2)
	S("jardim", walk_to(10080))
	use()
	S("Pipoca achou a chave", until({}, func(): return g.has_item("chave"), 600))
	walk_to(10400)
	S("passa pelo vigia 2", sneak_past(g.VL.WATCH[1], 11900))
	S("vigia 2 não pegou", g.VL.caught_n == 0)
	S("fogueira 2", rests.has(2) or walk_to(11970))
	S("descansou 2", rests.has(2))
	# a guarita: o Pipoca late lá atrás e o vigia sai do posto
	var gw: Dictionary = g.VL.WATCH[2]
	hold({}, 10)
	press("D")
	frame()
	S("Pipoca (guarita)", g.M.ctrl)
	walk_to(11720)
	use()
	S("vigia saiu do posto", until({}, func(): return float(gw.x) < 11860, 600))
	press("D")
	frame()
	S("de volta ao Tomé (guarita)", not g.M.ctrl)
	walk_to(12445)
	S("guarita não pegou", g.VL.caught_n == 0)
	use()
	var dl: Dictionary = g.LOCKS.filter(func(l): return l.get("id", "") == "dg1")[0]
	S("destrancou a porta", dl.done)
	S("entra nos porões", until({"R": true}, func(): return px() > 12650, 400))
	# ---------------- C · OS PORÕES
	walk_to(12880)
	S("passagem baixa 1", crawl(13320))
	walk_to(13580)
	S("passagem baixa 2", crawl(14020))
	# a grade com portinhola: o Pipoca segura a placa
	walk_to(14075)
	hold({}, 10)
	press("D")
	frame()
	S("Pipoca (grade)", g.M.ctrl)
	S("Pipoca pela portinhola até a placa", walk_to(14220))
	var pg: Dictionary = g.M.GATES.filter(func(gt): return gt.get("id", "") == "pg3")[0]
	S("a grade subiu", until({}, func(): return pg.open > .85, 200))
	press("D")
	frame()
	S("Pipoca segurando a placa", not g.M.ctrl and g.X.DOG.st == "stay")
	walk_to(14300)
	# térreo: o beco com o desenho enterrado e o amarelo
	walk_to(14650)
	S("espinhos 1", cross_spikes(trap_at("spikes", 14700), 14850))
	walk_to(15050)
	S("espinhos 2", cross_spikes(trap_at("spikes", 15100), 15250))
	walk_to(15680)
	use()
	var dz: Dictionary = g.DRWS.filter(func(d): return d.get("toca") == 2)[0]
	S("Pipoca cavou o desenho", until({}, func(): return dz.got, 600))
	walk_to(15990)
	S("cavalete do amarelo", jump_to(16100))
	hop("R", 0)
	S("amarelo", spec("amarelo"))
	walk_to(15250)
	S("espinhos 2 (volta)", cross_spikes(trap_at("spikes", 15100), 15050))
	walk_to(14850)
	S("espinhos 1 (volta)", cross_spikes(trap_at("spikes", 14700), 14650))
	S("escada do térreo", walk_to(14385))
	S("sobe para o meio", climb_to("U", func(): return P.ladder == null and P.y + P.h <= 282, 500))
	hold({"R": true}, 10)
	# andar do meio: escada para o beco de cima (pista 15)
	S("escada do meio", walk_to(14745))
	S("sobe para cima", climb_to("U", func(): return P.ladder == null and P.y + P.h <= 62, 500))
	jump_to(14650)
	S("pista 15 no beco de cima", walk_to(13300) and n_clues() == 3)
	S("desce pelo buraco da escada", walk_to(14745) and P.y + P.h > 250)
	# espelhos e cristal
	S("até o espelho", walk_to(15560))
	use()
	S("virou o espelho", int(g.X.MIRRORS[0].s) == 0)
	walk_to(15470)
	frame({"R": true})
	S("a luz abre a grade", until({"A": true}, func(): return g.X.CRYSTALS[0].on, 300))
	S("passa a grade", walk_to(16240))
	press("G")
	hold({}, 26)
	S("quebrou a parede rachada", g.X.broken.has("cr1"))
	S("pista 17", walk_to(16700) and n_clues() == 4)
	S("escada para cima", walk_to(17585))
	S("sobe", climb_to("U", func(): return P.ladder == null and P.y + P.h <= 62, 500))
	hold({"R": true}, 10)
	walk_to(17980)
	var hp_rope: int = P.hp
	jump_to(18120)
	S("pendurado na corda", P.get("bar") != null)
	S("vai pela corda", until({"R": true}, func(): return px() > 18640, 600))
	hold({"S": true}, 4)
	S("verde", spec("verde"))
	S("solta depois dos espinhos", wait_ground() and px() > 18620 and P.hp == hp_rope)
	walk_to(19040)
	S("desce para a cisterna", until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	walk_to(19380)
	S("pilar 1", jump_to(19605, true))
	S("vence a Enguia de Cristal", eel_fight())
	for pc in [19605.0, 19845.0, 20105.0, 20345.0]:
		if pc > px() + 20:
			jump_to(pc, true)
	S("pilar 4", absf(px() - 20345) < 20 and P.onGround)
	S("desenho da cisterna", g.DRWS.filter(func(d): return absf(float(d.x) - 20345) < 5)[0].got)
	S("margem", jump_to(20580, true))
	S("fogueira 3", walk_to(20710))
	S("descansou 3", rests.has(3))
	# ---------------- D · AS FORJAS
	var D0 := 21000.0
	walk_to(D0 + 580)
	S("pilar 1", jump_to(D0 + 735))
	S("pilar 2", jump_to(D0 + 895))
	S("chão", jump_to(D0 + 1080))
	S("pista 13", walk_to(D0 + 1300) and n_clues() == 5)
	walk_to(D0 + 1380)
	S("vapor: azul", steam_to(D0 + 1655, func(): return spec("azul")))
	S("plana até o chão", glide_to(D0 + 2000))
	walk_to(D0 + 2170)
	S("prensa 1", cross_spikes(trap_at("spikes", D0 + 2200), D0 + 2380))
	S("prensa 2", cross_spikes(trap_at("spikes", D0 + 2450), D0 + 2620))
	S("martelo", cross_swing(trap_at("axe", D0 + 2850), D0 + 2950))
	walk_to(D0 + 2980)
	var m1: Dictionary = mover("path", D0 + 3030)
	var m2: Dictionary = mover("path", D0 + 3740)
	S("tábua 1", board_path(m1, true))
	S("vai na tábua 1", ride_path(m1, true))
	S("pilar do barril", jump_to(D0 + 3655))
	S("tábua 2", board_path(m2, true))
	S("vai na tábua 2", ride_path(m2, true))
	S("pilar do fim", jump_to(D0 + 4425))
	S("chão depois do tanque", jump_to(D0 + 4600))
	S("ímã", walk_to(D0 + 4800) and g.has_item("ima"))
	walk_to(D0 + 4930)
	S("cavalete", jump_to(D0 + 5010, true))
	jump_to(D0 + 5150)
	S("pendurado na viga (ímã)", P.get("bar") != null and P.bar.get("mag"))
	S("vai pela viga", until({"R": true}, func(): return px() > D0 + 5830, 700))
	hold({"S": true}, 4)
	S("solta no chão", wait_ground() and P.y > 400)
	S("sem queimar", P.hp == 5)
	S("pista 14", walk_to(D0 + 6000) and n_clues() == 6)
	S("vence a Salamandra de Fogo", sal_fight())
	S("fogueira 4", walk_to(D0 + 7410))
	S("descansou 4", rests.has(4))
	# ---------------- E · AS TORRES
	var E0 := 28700.0
	var lf: Dictionary = mover("lift", E0 + 640)
	S("sobe de elevador", lift_up(lf))
	S("alto da torre", walk_to(E0 + 1100) and P.y + P.h <= -255)
	walk_to(E0 + 1600)
	S("pilar", jump_to(E0 + 1670, true))
	S("torre de cima", jump_to(E0 + 1850, true))
	hop("R", 0)
	S("roxo", spec("roxo"))
	S("ventania", gust_walk(E0 + 2380))
	var br: Dictionary = trap_at("bridge", E0 + 2400)
	S("a ponte que desaba", bridge_run(br))
	S("outra torre", P.onGround and P.y + P.h <= -435)
	walk_to(E0 + 4060)
	S("desce da torre", until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	S("desenho da estação", walk_to(E0 + 4350))
	S("vence o Guardião de Ferro", gua_fight())
	S("o trem partiu", walk_to(float(L.door.x) - 100) and g.VH.dep_t >= 0)
	S("trole amarrado", walk_to(float(L.sled.rope[0]) - 60) and g.VH.tied)
	hold({}, 10)
	press("D")
	frame()
	S("Pipoca (trole)", g.M.ctrl)
	walk_to(float(L.sled.rope[0]) + 10)
	use()
	S("Pipoca roeu a corda", not g.VH.tied)
	press("D")
	frame()
	S("sobe no trole", until({"R": true}, func(): return g.VH.mode == "sled", 500))
	var VH = g.VH
	var done_cart = "timeout"
	for i in 5000:
		if VH.mode == "" or not g.running:
			done_cart = true
			break
		var d := {}
		var ground: bool = VH.hy >= VH.sled_y(VH.su) - 1
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
	S("alcançou o trem", done_cart)
	var hk := []
	for o in VH.OBS:
		if o.hit:
			hk.append(o.k + "@" + str(o.u))
	S("trole sem batidas " + str(hk), hk.is_empty())
	var sa = until({}, func(): return not g.running, 300)
	S("fim do episódio", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	print("desenhos: ", g.DRWS.map(func(d): return [int(d.x), int(d.y), d.got]))
	S("final: pistas=%d esp=%d des=%d lápis=%d/%d" % [n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal], n_clues() == 6 and g.SPECGOT.size() == 6 and nd == g.DRWS.size())
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
