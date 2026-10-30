extends "res://tests/route2.gd"
## Teste automático do Episódio 3 (O Covil do Vargas): joga a fase inteira, da fundição até a
## estação velha, pegando as 6 pistas, os 6 lápis especiais e os desenhos.
##   godot --headless --path . -s tests/route3.gd

## espera a tábua que vai e vem (k "path") chegar perto de x e pula nela
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

## vai em cima da tábua até a outra ponta
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

## sobe no vapor segurando PULAR até a condição (ou até pousar)
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

func S(name: String, r) -> void:
	super.S(name, r)
	if OS.get_environment("DBG") != "":
		print(log_lines[-1])

func path_mover(x0: float) -> Dictionary:
	for o in g.MV.MV:
		if o.k == "path" and absf(float(o.x0) - x0) < 5:
			return o
	return {}

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
	# ---------------- A · A FUNDIÇÃO
	walk_to(480)
	S("pula a caixa", jump_to(660))
	S("pista 13", walk_to(1150) and n_clues() == 1)
	walk_to(1480)
	S("pilar 1", jump_to(1635))
	S("pilar 2", jump_to(1795))
	S("chão depois do poço", jump_to(1960))
	walk_to(2180)
	S("vapor: vermelho", steam_to(2455, func(): return spec("vermelho")))
	S("plana até o chão", glide_to(2800))
	walk_to(2990)
	S("prensa 1", cross_spikes(trap_at("spikes", 3020), 3200))
	S("prensa 2", cross_spikes(trap_at("spikes", 3280), 3460))
	S("martelo", cross_swing(trap_at("axe", 3760), 3880))
	S("cavalete do desenho", jump_to(3945))
	S("desce", walk_to(4100))
	walk_to(4380)
	var m1: Dictionary = path_mover(4430)
	var m2: Dictionary = path_mover(5100)
	S("tábua 1", board_path(m1, true))
	S("vai na tábua 1", ride_path(m1, true))
	S("pilar do laranja", jump_to(5015))
	hop("R", 0)
	S("laranja", spec("laranja"))
	walk_to(5040)
	S("tábua 2", board_path(m2, true))
	S("vai na tábua 2", ride_path(m2, true))
	S("pilar do vapor", jump_to(5705))
	S("vapor até o chão", glide_to(6200))
	S("manivela", walk_to(6560))
	for i in 8:
		if not g.CRANKS[0].done:
			use()
	S("porta da manivela abriu", g.CRANKS[0].done)
	S("passa a porta", walk_to(6800))
	walk_to(7080)
	var cr: Dictionary = {}
	for c in g.M.PUSH:
		if absf(float(c.x) - 7140) < 5:
			cr = c
	S("caixa no buraco da placa", until({"R": true}, func(): return float(cr.x) >= 7419 and float(cr.y) >= 449, 900))
	S("portão gf1 abriu", until({}, func(): return g.M.GATES.filter(func(gt): return gt.get("id", "") == "gf1")[0].open > .85, 200))
	S("pula a caixa", jump_to(7540, true))
	S("pista 14", walk_to(8420) and n_clues() == 2)
	S("fogueira 1", walk_to(8830))
	S("descansou 1", rests.has(1))
	# ---------------- B · O RIO SUBTERRÂNEO
	S("cavalete do amarelo", walk_to(9200 + 980) and jump_to(9200 + 1100))
	hop("R", 0)
	S("amarelo", spec("amarelo"))
	S("sobe no barco", until({"R": true}, func(): return g.VH.mode == "raft", 600))
	S("corredeira", ride_raft())
	S("barco sem virar", g.VH.tries == 0)
	S("pista 15", walk_to(17700) and n_clues() == 3)
	S("fogueira 2", walk_to(18010))
	S("descansou 2", rests.has(2))
	# ---------------- C · A CIDADE ABANDONADA
	var HS := house_list()
	S("%d casas" % HS.size(), HS.size() == 9)
	var ld: Dictionary = L.climb[0]
	S("até a escada", walk_to(float(ld.x) + float(ld.w) / 2))
	S("sobe a escada", climb_to("U", func(): return P.onGround and P.y + P.h < float(ld.y) + 4, 600))
	for i in HS.size():
		var hs: Dictionary = HS[i]
		var w: Dictionary = hs.walk
		for o in g.SPECS + g.DRWS + g.CLUES:
			if not o.got and o.x > w.x and o.x < w.x + w.w:
				roof_walk(o.x, hs.chims)
				if o.y < w.y - 50:
					hop("R", 0)
		var endx: float = w.x + w.w - 14
		for c in hs.chims:
			if float(c.x) + float(c.w) > endx - 40:
				endx = float(c.x) - 24
		S("telhado %d" % i, roof_walk(endx, hs.chims))
		if i + 1 < HS.size():
			var nw: Dictionary = HS[i + 1].walk
			var gap: float = nw.x - px()
			var land: float = nw.x + 40
			for c in HS[i + 1].chims:
				if float(c.x) < land + 30 and float(c.x) + float(c.w) > nw.x:
					land = float(c.x) + float(c.w) + 30
			var r2 = jump_to(land, true) if gap < 250 else glide_to(land + 20)
			P = g.player
			if P.get("bar") != null:
				var bb: Dictionary = P.bar
				until({"R": true}, func(): return px() > float(bb.x1) - 40, 600)
				press("J")
				r2 = jump_to(land)
			var gs = P.get("_g")
			if gs is Dictionary and gs.get("tile"):
				r2 = jump_to(nw.x + 40)
			var hn: Dictionary = HS[i + 1].h
			S("pula para o telhado %d (vão %d)" % [i + 1, int(gap)], r2 is bool and r2 and P.onGround and px() > hn.x and px() < hn.x + hn.w and P.y + P.h < 400)
	S("verde", spec("verde"))
	S("pista 16", n_clues() == 4)
	var hl: Dictionary = HS[HS.size() - 1]
	roof_walk(float(hl.walk.x) + float(hl.walk.w) - 10, hl.chims)
	S("desce para a rua", until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	var wh: Dictionary = {}
	for o in g.MV.MV:
		if o.k == "wheel":
			wh = o
	S("embaixo da engrenagem", walk_to(float(wh.x)))
	var HI0: float = float(wh.x) + 380.0
	S("sobe pela engrenagem", mill_ride(HI0, -150))
	S("no alto", P.onGround and P.y < -150)
	S("cavalete do azul", jump_to(HI0 + 300))
	if P.y > -260:
		jump_to(HI0 + 300)
	hop("R", 0)
	S("azul", spec("azul"))
	S("fogueira 3", walk_to(27310))
	S("descansou 3", rests.has(3))
	# ---------------- D · O COFRE
	var D0 := 27600.0
	S("desce os degraus", walk_to(D0 + 1100))
	S("chão do cofre", P.onGround and P.y > 400)
	walk_to(D0 + 1700)
	use()
	walk_to(D0 + 1780)
	use()
	S("portão das alavancas", until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 200))
	S("passa o portão", walk_to(D0 + 2300))
	S("prensa 1", cross_spikes(trap_at("spikes", D0 + 2400), D0 + 2540))
	S("cavalete do roxo", jump_to(D0 + 2565, true) and P.y < 380)
	hop("R", 0)
	S("roxo", spec("roxo"))
	S("desce", walk_to(D0 + 2600))
	S("prensa 2", cross_spikes(trap_at("spikes", D0 + 2620), D0 + 2800))
	S("martelo", cross_swing(trap_at("axe", D0 + 3060), D0 + 3200))
	S("pista 17", walk_to(D0 + 3300) and n_clues() == 5)
	walk_to(D0 + 3500)
	for t in [D0 + 3555, D0 + 3695, D0 + 3850, D0 + 4060, D0 + 4275, D0 + 4425, D0 + 4575]:
		var r = jump_to(t, t == D0 + 4060)
		S("prateleira %d" % int(t - D0), r is bool and r and P.y < 440)
	S("desenho do cofre", g.DRWS.filter(func(d): return absf(float(d.x) - (D0 + 4060)) < 5)[0].got)
	S("chão depois do ouro", jump_to(D0 + 4700))
	walk_to(D0 + 4840)
	var cr2: Dictionary = {}
	for c in g.M.PUSH:
		if absf(float(c.x) - (D0 + 4900)) < 5:
			cr2 = c
	S("caixa na placa do cofre", until({"R": true}, func(): return float(cr2.x) >= D0 + 5199 and float(cr2.y) >= 449, 900))
	S("portão gc1 abriu", until({}, func(): return g.M.GATES.filter(func(gt): return gt.get("id", "") == "gc1")[0].open > .85, 200))
	S("pula a caixa", jump_to(D0 + 5320, true))
	S("pista 18", walk_to(D0 + 5600) and n_clues() == 6)
	S("fogueira 4", walk_to(D0 + 6260))
	S("descansou 4", rests.has(4))
	# ---------------- E · A FUGA AO AMANHECER
	var SLd: Dictionary = L.sled
	S("chega no carrinho e parte sozinho", until({"R": true} if px() < float(SLd.x) else {"L": true}, func(): return g.VH.mode == "sled", 600))
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
	S("carrinho sem batidas " + str(hk), VH.tries == 0)
	walk_to(float(L.door.x) + 30)
	var sa = until({}, func(): return not g.running, 300)
	S("estação velha (fim)", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	print("desenhos: ", g.DRWS.map(func(d): return [int(d.x), int(d.y), d.got]))
	S("final: pistas=%d esp=%d des=%d lápis=%d/%d" % [n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal], n_clues() == 6 and g.SPECGOT.size() == 6 and nd == g.DRWS.size())
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
