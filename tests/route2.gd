extends "res://tests/route.gd"
## Teste automático do Episódio 2 (As Profundezas da Mina): joga a fase inteira, da boca da mina
## até a porta do cofre, pegando as 6 pistas, os 6 lápis especiais e os desenhos.
##   godot --headless --path . -s tests/route2.gd

## pula segurando PULAR o tempo todo (pulo duplo e plana até pousar)
func glide_to(x: float, mx: int = 400):
	press("J")
	var used := false
	for i in mx:
		P = g.player
		if not ok():
			return "state"
		var d := {}
		if px() < x - 5:
			d = {"R": true}
		elif px() > x + 5:
			d = {"L": true}
		if not used and i > 14 and P.vy > -1:
			press("J")
			used = true
		d["J"] = true
		frame(d)
		P = g.player
		if P.onGround and i > 3:
			return true
	return "air"

## pulo duplo parado no lugar (para pegar o que está no alto)
func vjump():
	press("J")
	for i in 16:
		frame({"J": true})
	for i in 30:
		P = g.player
		if P.vy >= -.5:
			break
		frame()
	press("J")
	for i in 14:
		frame({"J": i < 10})
	return wait_ground()

## anda no telhado pulando as chaminés
func roof_walk(x: float, chims: Array):
	for c in chims:
		var cx0: float = float(c.x)
		var cx1: float = float(c.x) + float(c.w)
		if (x > px() and cx0 > px() and cx0 < x) or (x < px() and cx1 < px() and cx1 > x):
			var before: float = cx0 - 24 if x > px() else cx1 + 24
			var r = walk_to(before)
			if not (r is bool and r):
				return "até a chaminé: " + str(r)
			r = jump_to(cx1 + 26 if x > px() else cx0 - 26)
			if not (r is bool and r):
				return "pula a chaminé: " + str(r)
	return walk_to(x)

func lift_ride(top: bool):
	var lf: Dictionary = g.MV.MV[0]
	use()
	return until({}, func(): return lf.pos == lf.goal and (lf.pos == 0.0) == top, 600)

## espera uma tábua do moinho passar embaixo e pula nela; sobe junto e pula para o barranco
func mill_ride(cliff_x: float, cliff_y: float):
	var wh: Dictionary = {}
	for o in g.MV.MV:
		if o.k == "wheel":
			wh = o
	var target = null
	for i in 1500:
		P = g.player
		for s in wh.plats:
			if s.y > 360 and abs(s.x + s.w / 2 - px()) < 140 and s.dx < 0:
				target = s
		if target != null:
			break
		frame()
	if target == null:
		return "nenhuma tábua passou"
	press("J")
	var on := false
	for i in 120:
		var d := {"J": i < 16}
		if px() < target.x + target.w / 2 - 6:
			d["R"] = true
		elif px() > target.x + target.w / 2 + 6:
			d["L"] = true
		frame(d)
		P = g.player
		if P.onGround and P.get("_g") == target:
			on = true
			break
	if not on:
		return "não subiu na tábua"
	# vai junto até o alto, perto do barranco
	for i in 1400:
		frame()
		P = g.player
		if P.get("_g") != target:
			return "caiu da tábua y=%d" % int(P.y)
		if target.y < cliff_y + 40 and target.x + target.w > cliff_x - 260 and target.dx > 0:
			break
	return glide_to(cliff_x + 80)

func house_list() -> Array:
	var out: Array = []
	for s in g.L.solids:
		if s.t == "house":
			var best = null
			var chims: Array = []
			for r in g.L.solids:
				if r.t == "roof" and r.x >= s.x - 2 and r.x + r.w <= s.x + s.w + 2:
					if r.get("chim"):
						chims.append(r)
					elif best == null or r.w > best.w:
						best = r
			out.append({"h": s, "walk": best, "chims": chims})
	return out

func _initialize() -> void:
	g = load("res://scripts/game.gd").new()
	root.add_child(g)
	g.load_level(1)
	g.no_coal = true
	for e in g.EN:
		e.dead = 99
	P = g.player
	g.rest_reached.connect(func(n):
		rests.append(n)
		print("REST ", n, " T=", g.T)
		g.running = true)
	var L: Dictionary = g.L
	# ---------------- A · BOCA DA MINA
	walk_to(600)
	S("pula a caixa", jump_to(720))
	S("pista 7", walk_to(1230) and n_clues() == 1)
	walk_to(1385)
	S("cavalete 1", jump_to(1498))
	S("cavalete 2", jump_to(1648))
	hop("R", 0)
	S("vermelho", spec("vermelho"))
	S("cavalete 3", jump_to(1808))
	S("chão depois do poço", jump_to(1960))
	S("chega na manivela", walk_to(3020))
	for i in 8:
		if not g.CRANKS[0].done:
			use()
	S("porta da manivela abriu", g.CRANKS[0].done)
	S("passa a porta", walk_to(3300))
	walk_to(3420)
	S("caixa no buraco da placa", until({"R": true}, func(): return g.M.PUSH[0].x >= 3719 and g.M.PUSH[0].y >= 449, 900))
	S("portão g1 abriu", until({}, func(): return g.M.GATES[1].open > .85 if g.M.GATES.size() > 1 else g.M.GATES[0].open > .85, 200))
	S("pula a caixa", jump_to(3840, true))
	S("vai ao elevador", walk_to(4328))
	S("sobe de elevador", lift_ride(true))
	S("galeria de cima", walk_to(4450))
	S("corda", walk_to(4780) and g.INV.has("corda"))
	walk_to(5250)
	hop("R", 0)
	S("laranja", spec("laranja"))
	S("desenho 1", walk_to(5580))
	S("desce da galeria", walk_to(5760))
	S("lago tóxico: estaca", stake_cross(5800))
	walk_to(6460)
	S("carrinho 1", jump_to(6560))
	S("espinhos", jump_to(6800, true))
	walk_to(6860)
	S("tábua do desenho", jump_to(7000, true))
	S("desenho 2", walk_to(7040))
	S("desce", walk_to(7300))
	S("degrau 1", jump_to(7540))
	S("degrau 2", jump_to(7700))
	S("degrau 3", jump_to(7850))
	S("degrau 4", jump_to(8000))
	S("alto", jump_to(8120))
	walk_to(8650)
	S("chão", until({}, func(): return P.onGround and P.y > 400, 200))
	walk_to(8860)
	use()
	walk_to(8930)
	use()
	S("portão das alavancas", until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 200))
	S("fogueira 1", walk_to(9460))
	S("descansou 1", rests.has(1))
	# ---------------- B · VALE DO MOINHO
	S("vale", walk_to(10900))
	S("flor", jump_to(10950))
	S("lançado para a pedra", until({}, func(): return P.onGround and P.y < 250, 300))
	walk_to(11235)
	hop("R", 0)
	S("amarelo", spec("amarelo"))
	S("desce da pedra", walk_to(11420))
	S("entra no celeiro", crawl(11660))
	S("lona", g.INV.has("lona"))
	S("sai do celeiro", crawl(11840))
	S("pista 8", walk_to(12110) and n_clues() == 2)
	walk_to(12640)
	S("pedra 1", jump_to(12760))
	S("pedra 2", jump_to(12910))
	S("margem", jump_to(13110))
	S("combina lona+corda", g.try_combine("lona", "corda") != "")
	S("porta do moinho", walk_to(13620))
	use()
	S("moinho girando", g.LOCKS[0].done)
	walk_to(13600)
	S("sobe pelas pás", mill_ride(14000, -150))
	S("alto do barranco", P.onGround and P.y < -150)
	S("desenho 3", walk_to(14820))
	walk_to(15800)
	S("pedra do verde", jump_to(15900))
	S("verde", spec("verde"))
	S("fogueira 2", walk_to(16300))
	S("descansou 2", rests.has(2))
	# ---------------- C · TELHADOS
	S("beira do barranco", walk_to(16700))
	S("pilar", walk_to(16880))
	var HS := house_list()
	S("%d casas" % HS.size(), HS.size() == 19)
	var w0: Dictionary = HS[0].walk
	S("primeiro telhado", walk_to(w0.x + 40) if true else true)
	S("no telhado", until({}, func(): return P.onGround and P.y + P.h < 300, 200))
	for i in HS.size():
		var hs: Dictionary = HS[i]
		var w: Dictionary = hs.walk
		# o que tem neste telhado (lápis especial e desenho no alto: pulo no lugar)
		for o in g.SPECS + g.DRWS + g.ITEMS + g.CLUES:
			if not o.got and o.x > w.x and o.x < w.x + w.w:
				roof_walk(o.x, hs.chims)
				if o.y < w.y - 60:
					hop("R", 0)
		if i == 4:
			S("metade A", g.INV.has("chave_a"))
		if i == 13:
			S("metade B", g.INV.has("chave_b"))
		var endx: float = w.x + w.w - 14
		for c in hs.chims:
			if float(c.x) + float(c.w) > endx - 40:
				endx = float(c.x) - 24
		var r = roof_walk(endx, hs.chims)
		S("telhado %d" % i, r)
		if i + 1 < HS.size():
			var nw: Dictionary = HS[i + 1].walk
			var gap: float = nw.x - px()
			var r2 = jump_to(nw.x + 40, true) if gap < 250 else glide_to(nw.x + 60)
			if P.get("bar") != null:
				# pendurado no varal: anda até a ponta e pula para o telhado
				var bb: Dictionary = P.bar
				until({"R": true}, func(): return px() > float(bb.x1) - 40, 400)
				press("J")
				r2 = jump_to(nw.x + 50)
			var hn: Dictionary = HS[i + 1].h
			S("pula para o telhado %d (vão %d)" % [i + 1, int(gap)], r2 is bool and r2 and P.onGround and px() > hn.x and px() < hn.x + hn.w and P.y + P.h < 400)
	S("pistas na vila (9 e 10)", n_clues() == 4)
	S("azul", spec("azul"))
	S("desce para a rua", until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	S("fogueira 3", walk_to(float(g.CHK.filter(func(c): return c.has("rest") and c.rest == 3)[0].x) + 10))
	S("descansou 3", rests.has(3))
	S("combina a chave", g.try_combine("chave_a", "chave_b") != "")
	var lk: Dictionary = g.LOCKS[1]
	walk_to(float(lk.x) + 40)
	use()
	S("porteira aberta", lk.done)
	# ---------------- D · PROFUNDEZAS
	var D0: float = float(L.sections[3].x)
	S("pista 11", walk_to(D0 + 610) and n_clues() == 5)
	walk_to(D0 + 800)
	S("tábua do roxo", jump_to(D0 + 900))
	hop("R", 0)
	S("roxo", spec("roxo"))
	var SLd: Dictionary = L.sled
	S("vai ao carrinho", walk_to(float(SLd.x)))
	use()
	S("subiu no carrinho", g.VH.mode == "sled")
	var VH = g.VH
	var done_cart = "timeout"
	for i in 4000:
		if VH.mode == "":
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
	S("carrinho chegou", done_cart)
	var hk := []
	for o in VH.OBS:
		if o.hit:
			hk.append(o.k + "@" + str(o.u))
	S("carrinho sem batidas " + str(hk), P.hp == 5 and VH.tries == 0)
	S("pista 12", walk_to(float(L.door.x) - 300) and n_clues() == 6)
	walk_to(float(L.door.x) + 30)
	var sa = until({}, func(): return not g.running, 300)
	S("porta do cofre (fim)", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	print("desenhos: ", g.DRWS.map(func(d): return [int(d.x), int(d.y), d.got]))
	S("final: pistas=%d esp=%d des=%d lápis=%d/%d" % [n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal], n_clues() == 6 and g.SPECGOT.size() == 6 and nd == g.DRWS.size())
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
