extends "res://tests/rec/route.gd"
## Teste automático do Episódio 2 (As Profundezas da Mina): joga a fase inteira, da boca da mina
## até a porta do cofre, pegando as 6 pistas, os 6 lápis especiais e os desenhos.
##   godot --headless --path . -s tests/route2.gd

## pula segurando PULAR o tempo todo (pulo duplo e plana até pousar)
func glide_to(x: float, mx: int = 400):
	await press("J")
	var used := false
	for i in mx:
		P = g.player
		if not await ok():
			return "state"
		var d := {}
		if await px() < x - 5:
			d = {"R": true}
		elif await px() > x + 5:
			d = {"L": true}
		if not used and i > 14 and P.vy > -1:
			await press("J")
			used = true
		d["J"] = true
		await frame(d)
		P = g.player
		if P.onGround and i > 3:
			return true
	return "air"

## pulo duplo parado no lugar (para pegar o que está no alto)
func vjump():
	await press("J")
	for i in 16:
		await frame({"J": true})
	for i in 30:
		P = g.player
		if P.vy >= -.5:
			break
		await frame()
	await press("J")
	for i in 14:
		await frame({"J": i < 10})
	return await wait_ground()

## anda no telhado pulando as chaminés (as quentes: espera a labareda baixar, pulo duplo) e as telhas soltas
func roof_walk(x: float, chims: Array):
	for c in chims:
		var cx0: float = float(c.x)
		var cx1: float = float(c.x) + float(c.w)
		if (x > await px() and cx0 > await px() and cx0 < x) or (x < await px() and cx1 < await px() and cx1 > x):
			var before: float = cx0 - 24 if x > await px() else cx1 + 24
			var r = await walk_to(before)
			if not (r is bool and r):
				return "até a chaminé: " + str(r)
			if c.get("hot"):
				var hc: Dictionary = {}
				for h in g.VL.HOT:
					if abs(float(h.x) - cx0) < 3:
						hc = h
				await until({}, func(): return g.VL.hot_phase(hc) == 0 and int((g.T + int(hc.get("ph", 0))) % int(hc.per)) < 20, 400)
			r = await jump_to(cx1 + 26 if x > await px() else cx0 - 26, c.get("hot", 0) == 1 or float(c.get("h", 0)) > 50)
			if not (r is bool and r):
				return "pula a chaminé: " + str(r)
	return await walk_to(x)

func lift_ride(top: bool):
	var lf: Dictionary = g.MV.MV[0]
	await use()
	return await until({}, func(): return lf.pos == lf.goal and (lf.pos == 0.0) == top, 600)

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
			if s.y > 360 and abs(s.x + s.w / 2 - await px()) < 140 and s.dx < 0:
				target = s
		if target != null:
			break
		await frame()
	if target == null:
		return "nenhuma tábua passou"
	await press("J")
	var on := false
	for i in 120:
		var d := {"J": i < 16}
		if await px() < target.x + target.w / 2 - 6:
			d["R"] = true
		elif await px() > target.x + target.w / 2 + 6:
			d["L"] = true
		await frame(d)
		P = g.player
		if P.onGround and P.get("_g") == target:
			on = true
			break
	if not on:
		return "não subiu na tábua"
	# vai junto até o alto, perto do barranco
	for i in 1400:
		await frame()
		P = g.player
		if P.get("_g") != target:
			return "caiu da tábua y=%d" % int(P.y)
		if target.y < cliff_y + 40 and target.x + target.w > cliff_x - 260 and target.dx > 0:
			break
	return await glide_to(cliff_x + 80)

## nada até (x, feet_y) até a condição (debaixo d'água: ↓ mergulha, PULAR dá braçada para cima)
func swim_to(x: float, fy: float, cond: Callable, mx: int = 900):
	for i in mx:
		P = g.player
		if not await ok():
			return "state"
		if cond.call():
			return true
		var d := {}
		if await px() < x - 8:
			d["R"] = true
		elif await px() > x + 8:
			d["L"] = true
		var feet: float = P.y + P.h
		if feet < fy - 6:
			d["S"] = true
		elif feet > fy + 30 and i % 10 == 0:
			await press("J")
		await frame(d)
	return "timeout@%d,%d" % [int(await px()), int(P.y)]

## do fundo do lago até em cima de uma vitória-régia (sobe com braçadas e pula para fora da água)
func surface_to_lily(x: float):
	for i in 900:
		P = g.player
		if not await ok():
			return "state"
		if P.onGround and P.y + P.h < -100:
			return true
		var d := {}
		if await px() < x - 6:
			d["R"] = true
		elif await px() > x + 6:
			d["L"] = true
		if i % 6 == 0:
			await press("J")
		d["J"] = true
		await frame(d)
	return "timeout@%d,%d swim=%s" % [int(await px()), int(P.y), str(P.swim)]

## Brutus (o cão do Vargas), preso na corrente: em cima de uma banca, espera o Pipoca provocar;
## quando a corrente estica no chão, MERGULHO na argola que brilha (3 argolas, uma por banca)
func brutus_fight():
	var b: Dictionary = g.X.BOSS
	await until({"R": true}, func(): return b.active and b.st != "wait", 300)
	var mid: float = (float(b.x0) + float(b.x1)) / 2.0
	for it in 3000:
		P = g.player
		if OS.get_environment("DBG") != "" and it % 10 == 0:
			print("BR it=%d st=%s t=%d hp=%d bx=%d px=%d py=%d php=%d" % [it, b.st, b.t, b.hp, int(b.x), int(await px()), int(P.y + P.h), P.hp])
		if b.done or b.st == "down":
			await hold({}, 170)
			return true
		if not await ok():
			return "state"
		if b.st in ["wait", "intro"]:
			await frame({"R": true})
			continue
		if b.st == "stun":
			# tonto no muro: corre até perto e pula na cabeça
			if abs(await px() - b.x) > 120:
				await frame({"R": true} if b.x > await px() else {"L": true})
				continue
			await jump_to(b.x, false, 80)
			await hold({}, 2)
			if b.st == "hurt" or b.hp < 1:
				await until({"L": true} if b.x > mid else {"R": true}, func(): return abs(px() - b.x) > 260, 90)
			continue
		if b.st == "charge" and sign(await px() - b.x) == float(b.dir) and abs(b.x - await px()) < 230 + b.spd * 7 and P.onGround:
			# a investida chegando: pulo duplo por cima
			await press("J")
			var used := false
			for i in 70:
				var d := {"J": true}
				if not used and i > 10 and g.player.vy > -1:
					await press("J")
					used = true
				await frame(d)
				if g.player.onGround and i > 4:
					break
			continue
		if b.st in ["idle", "hurt", "paw", "bite"]:
			# espera perto do muro do lado oposto ao dele (no chão): ele vem, o Tomé pula, ele bate no muro
			var spot: float = float(b.x0) + 190.0 if b.x > mid else float(b.x1) - 190.0
			if abs(await px() - spot) > 12 or P.y + P.h < 480:
				await frame({"L": true} if spot < await px() else {"R": true})
				continue
		await frame()
	return "hp=%d st=%s" % [b.hp, b.st]

## Morcego-Rei: sobe em cada plataforma e acende a lamparina (✦ USAR)
func bat_fight():
	var h: Dictionary = g.K.HAWK
	for pass_n in 6:
		if h.done or h.st in ["dazzle", "fall", "down", "flee"]:
			break
		var r0 = await _bat_pass(h)
		if r0 is String:
			return r0
	var r = await until({}, func(): return h.done or h.st in ["down", "flee"], 600)
	await hold({}, 40)
	return r

func _bat_pass(h: Dictionary):
	var lamps: Array = h.lamps.duplicate()
	lamps.sort_custom(func(a, c): return abs(a.x - px()) < abs(c.x - px()))
	for l in lamps:
		P = g.player
		if h.done or h.st in ["dazzle", "fall", "down", "flee"]:
			break
		if l.lit:
			continue
		for tries in 4:
			P = g.player
			if not await ok():
				return "state"
			if P.onGround and abs(P.y + P.h - float(l.y)) < 6 and abs(await px() - float(l.x)) < 40:
				break
			if P.y + P.h < float(l.y) - 6 or P.y + P.h > 494:
				pass
			await walk_to(float(l.x) - 80)
			await jump_to(float(l.x), true)
		await use()
		if not l.lit:
			return "não acendeu a lamparina em %d (y=%d)" % [int(l.x), int(P.y + P.h)]
	return true

## pulando de vitória-régia em vitória-régia até a que fica em x
func lily_hop(x: float):
	for n in 12:
		P = g.player
		if not await ok():
			return "state"
		if P.swim:
			# caiu (a vitória-régia afundou no meio do pulo): nada até a mais perto e sobe nela
			var bl: float = x
			var bdd := 1e9
			for l in g.LILY:
				var lc: float = float(l.x) + float(l.w) / 2
				if abs(lc - await px()) < bdd and int(l.get("st", 0)) == 0 and not l.get("big"):
					bdd = abs(lc - await px())
					bl = lc
			await surface_to_lily(bl)
			continue
		if abs(await px() - x) < 14 and P.onGround:
			return true
		var dir: float = 1.0 if x > await px() else -1.0
		var nx: float = x
		var best := 1e9
		for l in g.LILY:
			var cx: float = float(l.x) + float(l.w) / 2
			var dd: float = (cx - await px()) * dir
			if dd > 20 and dd < 230 and dd < best and (cx - x) * dir <= 1 and int(l.get("st", 0)) == 0:
				best = dd
				nx = cx
		if best >= 1e9:
			nx = x
		await jump_to(nx, abs(nx - await px()) > 150)
	return abs(await px() - x) < 14

## Sapo-Rei: parado na vitória-régia de uma colmeia; quando a mira trava, pula no lugar (a língua
## gruda na colmeia); com o sapo tonto, pula na cabeça dele
func frog_fight():
	var f: Dictionary = g.K.FISH
	for it in 1000:
		P = g.player
		if OS.get_environment("DBG") != "" and it % 5 == 0:
			print("FR it=%d st=%s t=%d hp=%d fx=%d px=%d py=%d swim=%s phl=%d tg=%s" % [it, f.st, f.t, f.hp, int(f.x), int(await px()), int(P.y + P.h), str(P.swim), P.hp, str(f.tg.get("st", ""))])
		if f.done or f.st == "down":
			await hold({}, 60)
			return true
		if not await ok():
			return "state"
		if P.swim:
			# caiu na água: nada até a vitória-régia mais perto e pula para cima dela
			var best: Dictionary = {}
			var bd := 1e9
			for l in g.LILY:
				var dd: float = abs(float(l.x) + float(l.w) / 2 - await px())
				if dd < bd and l.st == 0 and not l.get("big"):
					bd = dd
					best = l
			await surface_to_lily(float(best.x) + float(best.w) / 2)
			await frame()
			continue
		# a colmeia mais perto do sapo que ainda está no cipó
		var hv: Dictionary = {}
		var hd := 1e9
		for h2 in f.hives:
			if h2.st == "hang":
				var dd2: float = abs(float(h2.x) - f.x)
				if dd2 < hd:
					hd = dd2
					hv = h2
		if f.st == "dizzy":
			# vai até a vitória-régia mais perto do sapo e pula na cabeça dele
			var nl: float = 1e9
			var lx := await px()
			for l in g.LILY:
				var cx: float = float(l.x) + float(l.w) / 2
				if not l.get("big") and cx < f.x and abs(cx - f.x) < nl:
					nl = abs(cx - f.x)
					lx = cx
			if abs(await px() - lx) > 14:
				await lily_hop(lx)
				continue
			await press("J")
			var used := false
			for i in 140:
				P = g.player
				var d := {"J": i < 16 or (used and i < 40)}
				if await px() < f.x - 16:
					d["R"] = true
				elif await px() > f.x + 16:
					d["L"] = true
				if not used and i > 12 and P.vy > -1:
					await press("J")
					used = true
				await frame(d)
				P = g.player
				if f.st in ["hurt", "down"] or (P.onGround and i > 3) or P.swim:
					break
			if f.st in ["hurt", "down"]:
				# quicou na cabeça: volta para as vitórias-régias
				for i in 60:
					await frame({"L": true})
					P = g.player
					if P.onGround and i > 4:
						break
			continue
		if hv.is_empty():
			await frame()
			continue
		var hx: float = float(hv.x)
		if abs(await px() - hx) > 14 or not P.onGround:
			if P.onGround:
				await lily_hop(hx)
			else:
				await frame({"R": true} if await px() < hx else {"L": true})
			continue
		# parado na frente da colmeia: espera a mira travar e pula no lugar
		var aim_t: int = 40 if f.hp <= 1 else 52
		if f.st == "aim" and f.t >= aim_t - 8:
			await press("J")
			for i in 14:
				await frame({"J": true})
			await wait_ground()
			continue
		await frame()
	return "hp=%d st=%s" % [f.hp, f.st]

func house_list() -> Array:
	var out: Array = []
	for s in g.L.solids:
		if s.t == "house":
			var parts: Array = []
			var chims: Array = []
			for r in g.L.solids:
				if r.x < s.x - 2 or r.x + r.w > s.x + s.w + 2:
					continue
				if r.t == "roof" and r.get("chim"):
					chims.append(r)
				elif r.t == "roof" and r.get("walk"):
					parts.append(r)
				elif r.t == "plat" and r.get("roofhole"):
					chims.append({"x": r.x, "w": r.w, "h": 0})
			var x0: float = 1e9
			var x1: float = -1e9
			for r in parts:
				x0 = min(x0, float(r.x))
				x1 = max(x1, float(r.x) + float(r.w))
			# telhas soltas viram um obstáculo só (pula por cima de todas)
			var obs: Array = []
			var loose: Array = chims.filter(func(c): return not c.has("t"))
			if not loose.is_empty():
				var lx0: float = loose.map(func(c): return float(c.x)).min()
				var lx1: float = loose.map(func(c): return float(c.x) + float(c.w)).max()
				obs.append({"x": lx0, "w": lx1 - lx0, "h": 0})
			for c in chims:
				if c.has("t"):
					obs.append(c)
			obs.sort_custom(func(a, b): return float(a.x) < float(b.x))
			out.append({"h": s, "walk": {"x": x0, "w": x1 - x0, "y": float(parts[0].y)}, "chims": obs})
	return out

func _initialize() -> void:
	await _rec_setup(1)
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
	await walk_to(600)
	await S("pula a caixa", await jump_to(720))
	await S("pista 7", await walk_to(1230) and await n_clues() == 1)
	await walk_to(1385)
	await S("cavalete 1", await jump_to(1498))
	await S("cavalete 2", await jump_to(1648))
	await hop("R", 0)
	await S("vermelho", await spec("vermelho"))
	await S("cavalete 3", await jump_to(1808))
	await S("chão depois do poço", await jump_to(1960))
	await S("chega na manivela", await walk_to(3020))
	for i in 8:
		if not g.CRANKS[0].done:
			await use()
	await S("porta da manivela abriu", g.CRANKS[0].done)
	await S("passa a porta", await walk_to(3300))
	await walk_to(3420)
	await S("caixa no buraco da placa", await until({"R": true}, func(): return g.M.PUSH[0].x >= 3719 and g.M.PUSH[0].y >= 449, 900))
	await S("portão g1 abriu", await until({}, func(): return g.M.GATES[1].open > .85 if g.M.GATES.size() > 1 else g.M.GATES[0].open > .85, 200))
	await S("pula a caixa", await jump_to(3840, true))
	await S("vai ao elevador", await walk_to(4328))
	await S("sobe de elevador", await lift_ride(true))
	await S("galeria de cima", await walk_to(4450))
	await S("corda", await walk_to(4780) and g.INV.has("corda"))
	await walk_to(5250)
	await hop("R", 0)
	await S("laranja", await spec("laranja"))
	await S("desenho 1", await walk_to(5580))
	await S("desce da galeria", await walk_to(5760))
	await S("lago tóxico: estaca", await stake_cross(5800))
	await walk_to(6460)
	await S("carrinho 1", await jump_to(6560))
	await S("espinhos", await jump_to(6800, true))
	await walk_to(6860)
	await S("tábua do desenho", await jump_to(7000, true))
	await S("desenho 2", await walk_to(7040))
	await S("desce", await walk_to(7300))
	await S("degrau 1", await jump_to(7540))
	await S("degrau 2", await jump_to(7700))
	await S("degrau 3", await jump_to(7850))
	await S("degrau 4", await jump_to(8000))
	await S("alto", await jump_to(8120))
	await walk_to(8650)
	await S("chão", await until({}, func(): return P.onGround and P.y > 400, 200))
	await walk_to(8860)
	await use()
	await walk_to(8930)
	await use()
	await S("portão das alavancas", await until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 200))
	await S("fogueira 1", await walk_to(9460))
	await S("descansou 1", rests.has(1))
	# ---------------- B · VALE DO MOINHO
	await S("vale", await walk_to(10900))
	await S("flor", await jump_to(10950))
	await S("lançado para a pedra", await until({}, func(): return P.onGround and P.y < 250, 300))
	await walk_to(11235)
	await hop("R", 0)
	await S("amarelo", await spec("amarelo"))
	await S("desce da pedra", await walk_to(11420))
	await S("entra no celeiro", await crawl(11660))
	await S("lona", g.INV.has("lona"))
	await S("sai do celeiro", await crawl(11840))
	await S("pista 8", await walk_to(12110) and await n_clues() == 2)
	await walk_to(12640)
	await S("pedra 1", await jump_to(12760))
	await S("pedra 2", await jump_to(12910))
	await S("margem", await jump_to(13110))
	await S("combina lona+corda", g.try_combine("lona", "corda") != "")
	await S("porta do moinho", await walk_to(13620))
	await use()
	await S("moinho girando", g.LOCKS[0].done)
	await walk_to(13600)
	await S("sobe pelas pás", await mill_ride(14000, -150))
	await S("alto do barranco", P.onGround and P.y < -150)
	# o caixote na placa abre a cancela
	var cr: Dictionary = {}
	for c in g.M.PUSH:
		if absf(float(c.x) - 14220) < 5:
			cr = c
	await walk_to(float(cr.x) - 22)
	await S("empurra o caixote para a placa", await until({"R": true}, func(): return float(cr.y) > -150 - 60 + 10, 600))
	await hold({}, 30)
	await walk_to(float(cr.x) - 30)
	await jump_to(float(cr.x) + 30)
	await S("a cancela abriu", await walk_to(14680))
	# o lago raso do Sapo-Rei: só as vitórias-régias
	await S("primeira vitória-régia", await jump_to(14826))
	await S("entra na arena do Sapo-Rei", await until({"R": true}, func(): return g.K.FISH.active, 200) if not g.K.FISH.active else true)
	await S("vence o Sapo-Rei", await frog_fight())
	if P.swim:
		await surface_to_lily(14996)
	await S("vitória-régia do verde", await lily_hop(15196))
	await vjump()
	await S("verde", g.SPECGOT.has("verde"))
	await S("última vitória-régia", await lily_hop(15946))
	await S("margem de lá", await jump_to(16080) and P.onGround and P.y < -100)
	await S("desenho 3", await walk_to(16120))
	await S("fogueira 2", await walk_to(16300))
	await S("descansou 2", rests.has(2))
	# ---------------- C · TELHADOS
	await S("beira do barranco", await walk_to(16700))
	await S("pilar", await walk_to(16880))
	var HS := await house_list()
	await S("%d casas" % HS.size(), HS.size() == 12)
	var w0: Dictionary = HS[0].walk
	await S("primeiro telhado", await walk_to(w0.x + 40) if true else true)
	await S("no telhado", await until({}, func(): return P.onGround and P.y + P.h < 300, 200))
	for i in HS.size():
		var hs: Dictionary = HS[i]
		var w: Dictionary = hs.walk
		# o que tem neste telhado (lápis especial e desenho no alto: pulo no lugar)
		for o in g.SPECS + g.DRWS + g.ITEMS + g.CLUES:
			if not o.got and o.x > w.x and o.x < w.x + w.w:
				var smoke = null
				for c in hs.chims:
					if c.has("t") and o.x > float(c.x) - 30 and o.x < float(c.x) + float(c.w) + 30:
						smoke = c
				if smoke != null and o.y < w.y - 100:
					# lá no alto da fumaça: sobe na chaminé e plana na fumaça
					await roof_walk(float(smoke.x) - 30, hs.chims)
					await jump_to(float(smoke.x) + float(smoke.w) / 2, true)
					await until({"J": true}, func(): return o.got, 160)
					await wait_ground()
				else:
					await roof_walk(o.x, hs.chims)
					if o.y < w.y - 60:
						await hop("R", 0)
		if i == 2:
			await S("metade A", g.INV.has("chave_a"))
		if i == 9:
			await S("metade B", g.INV.has("chave_b"))
		var endx: float = w.x + w.w - 14
		for c in hs.chims:
			if float(c.x) + float(c.w) > endx - 40:
				endx = float(c.x) - 24
		var r = await roof_walk(endx, hs.chims)
		await S("telhado %d" % i, r)
		if i + 1 < HS.size():
			var nw: Dictionary = HS[i + 1].walk
			var gap: float = nw.x - await px()
			var r2
			if float(nw.y) < float(w.y) - 150:
				# sobrado alto demais: desce no toldo, ele joga para cima, e pulo duplo no alto
				var aw: Dictionary = g.L.awnings[0]
				var amid: float = float(aw.x) + float(aw.w) / 2
				await press("J")
				var launched = "timeout"
				for k in 300:
					P = g.player
					if P.vy < -12.0 and not P.onGround and P.y + P.h > float(w.y):
						launched = true
						break
					var d := {"J": k < 14}
					if await px() < amid - 8:
						d["R"] = true
					elif await px() > amid + 8:
						d["L"] = true
					await frame(d)
				var dj := false
				for k in 200:
					P = g.player
					var d := {"J": true}
					if await px() < nw.x + 60:
						d["R"] = true
					if not dj and P.vy > -2.0:
						await press("J")
						dj = true
					await frame(d)
					P = g.player
					if P.onGround and k > 5:
						break
				r2 = launched
			else:
				var land: float = nw.x + 40
				for c in HS[i + 1].chims:
					if float(c.x) < land + 30 and float(c.x) + float(c.w) > nw.x:
						land = float(c.x) + float(c.w) + 30
				r2 = await jump_to(land, true) if gap < 250 else await glide_to(land + 20)
			P = g.player
			if P.get("bar") != null:
				# pendurado no varal: anda até a ponta e pula para o telhado
				var bb: Dictionary = P.bar
				await until({"R": true}, func(): return px() > float(bb.x1) - 40, 400)
				await press("J")
				r2 = await jump_to(nw.x + 50)
			var gs = P.get("_g")
			if gs is Dictionary and gs.get("tile"):
				# pousou nas telhas soltas: corre antes que caiam
				r2 = await jump_to(nw.x + 40)
			var hn: Dictionary = HS[i + 1].h
			await S("pula para o telhado %d (vão %d)" % [i + 1, int(gap)], r2 is bool and r2 and P.onGround and await px() > hn.x and await px() < hn.x + hn.w and P.y + P.h < 400)
	await S("pistas na vila (9 e 10)", await n_clues() == 4)
	await S("azul", await spec("azul"))
	await S("desce para o quintal", await until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	await S("Brutus", await brutus_fight())
	await S("portão do quintal abriu", await walk_to(float(g.X.BOSS.x1) + 60))
	await S("fogueira 3", await walk_to(float(g.CHK.filter(func(c): return c.has("rest") and c.rest == 3)[0].x) + 10))
	await S("descansou 3", rests.has(3))
	await S("combina a chave", g.try_combine("chave_a", "chave_b") != "")
	var lk: Dictionary = g.LOCKS[1]
	await walk_to(float(lk.x) + 40)
	await use()
	await S("porteira aberta", lk.done)
	await S("porteira sobe (animação)", await until({}, func(): return g.M.GATES.filter(func(gt): return gt.get("id", "") == "vgate")[0].open >= 1.0, 300))
	# ---------------- D · PROFUNDEZAS
	var D0: float = float(L.sections[3].x) - 420.0
	await S("pista 11", await walk_to(D0 + 610) and await n_clues() == 5)
	g.lantern_lit = true
	await walk_to(25400)
	await S("tábuas podres do poço", await jump_to(25560) and await jump_to(25820, true))
	await walk_to(26020)
	await S("espinhos da galeria", await cross_spikes(await trap_at("spikes", 26120), 26260))
	var SLd: Dictionary = L.sled
	await S("chega no carrinho e parte sozinho", await until({"R": true} if await px() < float(SLd.x) else {"L": true}, func(): return g.VH.mode == "sled", 600))
	await S("subiu no carrinho", g.VH.mode == "sled")
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
				await press("J")
			if o.k == "crack" and ground and dx < 40 and dx > -5:
				await press("J")
			if o.k == "branch" and dx < 110 and dx > -100:
				d["S"] = true
			break
		await frame(d)
	await S("carrinho chegou", done_cart)
	var hk := []
	for o in VH.OBS:
		if o.hit:
			hk.append(o.k + "@" + str(o.u))
	await S("carrinho sem batidas " + str(hk), P.hp == 5 and VH.tries == 0)
	await S("espinhos depois do carrinho", await walk_to(28260) and await cross_spikes(await trap_at("spikes", 28360), 28500))
	await S("entra na caverna", await until({"R": true}, func(): return g.K.HAWK.active, 400))
	await S("vence o Morcego-Rei", await hawk_fight())
	var hx0: float = float(L.hawk.x0)
	await walk_to(hx0 + 420)
	await S("tábua do roxo", await jump_to(hx0 + 540))
	await hop("R", 0)
	await S("roxo", await spec("roxo"))
	await S("pista 12", await walk_to(float(L.door.x) - 70) and await n_clues() == 6)
	await walk_to(float(L.door.x) + 30)
	var sa = await until({}, func(): return not g.running, 300)
	await S("porta do cofre (fim)", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	print("desenhos: ", g.DRWS.map(func(d): return [int(d.x), int(d.y), d.got]))
	await S("final: pistas=%d esp=%d des=%d lápis=%d/%d" % [await n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal], await n_clues() == 6 and g.SPECGOT.size() == 6 and nd == g.DRWS.size())
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
