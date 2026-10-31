extends "res://tests/rec/route2.gd"
## Teste automático do Episódio 3 (O Covil do Vargas · a fortaleza na serra): joga a fase inteira, da
## trilha da serra até a estação velha, pegando as 6 pistas, os 6 lápis especiais e os desenhos, e
## passando pelos dois caminhos onde há escolha (o de cima e o de baixo).
##   godot --headless --path . -s tests/route3.gd

func S(name: String, r) -> void:
	await super.S(name, r)
	if OS.get_environment("DBG") != "":
		print(log_lines[-1])

## espera a tábua que vai e vem (k "path") chegar perto da ponta e pula nela
func board_path(o: Dictionary, at_start: bool):
	var s: Dictionary = o.plats[0]
	var x_end: float = float(o.x0) if at_start else float(o.x1)
	var r = await until({}, func(): return absf(float(s.x) - x_end) < 6, 900)
	if not (r is bool and r):
		return "a tábua não veio: " + str(r)
	await press("J")
	for i in 160:
		var d := {"J": i < 16}
		var c: float = float(s.x) + float(s.w) / 2
		if await px() < c - 8:
			d["R"] = true
		elif await px() > c + 8:
			d["L"] = true
		await frame(d)
		P = g.player
		if P.onGround and P.get("_g") == s:
			return true
		if not await ok():
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
		if await px() < c - 20:
			d["R"] = true
		elif await px() > c + 20:
			d["L"] = true
		await frame(d)
	return "timeout"

## sobe no vapor segurando PULAR até a condição
func steam_to(x: float, cond: Callable, mx: int = 400):
	await press("J")
	var used := false
	for i in mx:
		P = g.player
		if not await ok():
			return "state"
		if cond.call():
			return true
		var d := {"J": true}
		if await px() < x - 6:
			d["R"] = true
		elif await px() > x + 6:
			d["L"] = true
		if not used and i > 14 and P.vy > -1:
			await press("J")
			used = true
		await frame(d)
	return "timeout@%d,%d" % [int(await px()), int(P.y)]

## Enguia de Cristal: sai do pilar que borbulha; com ela tonta no pilar, pula na cabeça
func eel_fight():
	var B3 = g.K.B3
	var b: Dictionary = B3.boss("enguia")
	for it in 8000:
		if OS.get_environment("DBG") != "" and (it % 20 == 0 or (OS.get_environment("DBG") == "2" and b.st in ["warn", "lunge", "stuck", "dive", "hurt"])):
			print("EEL it=%d st=%s t=%d hp=%d bx=%d hx=%d px=%d py=%d php=%d lives=%d" % [it, b.st, b.t, b.hp, int(b.x), int(b.get("hx", 0)), int(await px()), int(P.y + P.h), P.hp, g.lives])
		P = g.player
		if not await ok():
			return "state"
		if b.done or b.st == "down":
			await hold({}, 30)
			return true
		var on: int = B3._on_pillar(b)
		if P.onGround and on < 0:
			await jump_to(B3._pc(b, B3._pillar_of(await px(), b)), true)
			continue
		if b.st == "warn" and on >= 0 and on == int(b.tp) and P.onGround:
			if OS.get_environment("DBG") != "":
				print("  pula do pilar ", on)
			# ela vai dar o bote neste pilar: pula para o vizinho do lado contrário ao vão dela
			var away: int = 1 if b.x < B3._pc(b, on) else -1
			var nx: int = on + away
			if nx < 0 or nx >= b.pillars.size():
				nx = on - away
			await jump_to(B3._pc(b, nx), true)
			continue
		if b.st == "stuck" and b.t > 4 and int(b.get("hits_now", 0)) == 0 and P.onGround and on >= 0 and on != int(b.tp):
			# os dentes presos no pilar vizinho: pula na cabeça e volta
			var back: float = B3._pc(b, on)
			if OS.get_environment("DBG") != "":
				print("  cabeça em ", int(b.hx), " de ", int(await px()))
			await jump_to(float(b.hx), true)
			if OS.get_environment("DBG") != "":
				print("  caiu em ", int(await px()), " hp=", b.hp, " st=", b.st, " hn=", b.get("hits_now", 0))
			if B3._on_pillar(b) == int(b.tp) or not P.onGround:
				await wait_ground()
			await jump_to(back, true)
			continue
		await frame()
	return "timeout st=%s hp=%d" % [b.st, b.hp]

## Salamandra de Fogo: espera no balcão da 1ª caixa; vira a água quando ela passa embaixo; apagada,
## pula em cima dela e volta para o balcão
func sal_fight():
	var B3 = g.K.B3
	var b: Dictionary = B3.boss("salamandra")
	var t0: Dictionary = B3.TANKS[0]
	var spots: Array = [float(t0.x) - 166.0, float(t0.x) - 74.0]
	var spot: float = spots[1]
	await walk_to(float(b.trig) + 40)
	await jump_to(spot, true)
	for it in 9000:
		if OS.get_environment("DBG") != "" and (it % 20 == 0 or (OS.get_environment("DBG") == "2" and b.st in ["cool", "hurt", "flee", "flare"])):
			print("SAL it=%d st=%s t=%d hp=%d bx=%d px=%d py=%d php=%d lives=%d" % [it, b.st, b.t, b.hp, int(b.x), int(await px()), int(P.y + P.h), P.hp, g.lives])
		P = g.player
		if not await ok():
			return "state"
		if b.done or b.st == "down":
			await hold({}, 30)
			return true
		var on_balc: bool = P.onGround and absf(P.y + P.h - float(t0.py)) < 6
		if OS.get_environment("DBG") != "" and P.hp < int(b.get("_php", 5)):
			print("  AI! st=%s t=%d px=%d py=%d shots=%s" % [b.st, b.t, int(await px()), int(P.y + P.h), str(B3.SHOTS.map(func(q): return "%s@%d,%d" % [q.k, int(q.x), int(q.y)]))])
		b["_php"] = P.hp
		if b.st == "wait":
			await frame({"R": true})
			continue
		if b.st == "cool" and b.t > 10 and b.t < 80:
			# pula do balcão em cima dela; acertou, volta direto para o balcão
			await press("J")
			for k in 120:
				P = g.player
				if b.st != "cool" or (P.onGround and k > 6):
					break
				await frame({"R" if b.x > await px() else "L": true, "J": k < 10})
			continue
		if P.onGround and not on_balc:
			var fire_near := false
			for sh in B3.SHOTS:
				if sh.k == "fire" and not sh.get("arc", false) and absf(sh.x - await px()) < 120 and signf(await px() - sh.x) == signf(sh.vx):
					fire_near = true
			if fire_near:
				await press("J")
				await hold({"J": true}, 14)
				continue
			await jump_to(spot, true)
			continue
		if on_balc:
			# perigos no balcão: bola em arco caindo aqui, coluna de fogo, chama acesa
			var danger := false
			var dx0: float = await px()
			for sh in B3.SHOTS:
				if sh.k == "fire" and sh.get("arc", false):
					var lx: float = sh.x
					var ly: float = sh.y
					var vy: float = sh.vy
					for k in 80:
						vy += .35
						lx += sh.vx
						ly += vy
						if vy > 0 and ly >= float(t0.py):
							break
					if absf(lx - await px()) < 60:
						danger = true
						dx0 = lx
				if sh.k == "flame" and absf(sh.x - await px()) < 56:
					danger = true
					dx0 = sh.x
			if b.st == "flare" and b.t < 70 and absf(float(b.flx) - await px()) < 66:
				danger = true
				dx0 = float(b.flx)
			if danger:
				spot = spots[0] if absf(dx0 - spots[1]) < absf(dx0 - spots[0]) else spots[1]
		if on_balc and absf(await px() - spot) > 8:
			await frame({"R" if spot > await px() else "L": true})
			continue
		if t0.st == "full" and b.st in ["walk", "flare"] and absf(b.x - float(t0.x)) < 70:
			await use()
			continue
		await frame()
	return "timeout st=%s hp=%d" % [b.st, b.hp]

## Guardião de Ferro: fica longe; pula as ondas; com os punhos presos, picareta nele (2 golpes) e
## passa para o lado onde há mais espaço
func gua_fight():
	var B3 = g.K.B3
	var b: Dictionary = B3.boss("guardiao")
	await walk_to(float(b.trig) + 30)
	var side := -1.0
	for it in 9000:
		if OS.get_environment("DBG") != "" and it % 20 == 0:
			print("GUA it=%d st=%s t=%d hp=%d bx=%d px=%d py=%d php=%d lives=%d" % [it, b.st, b.t, b.hp, int(b.x), int(await px()), int(P.y + P.h), P.hp, g.lives])
		P = g.player
		if not await ok():
			return "state"
		if b.done or b.st == "down":
			await hold({}, 30)
			return true
		if OS.get_environment("DBG") != "" and P.hp < int(b.get("_php", 5)):
			print("  AI! st=%s t=%d px=%d py=%d bx=%d shots=%s" % [b.st, b.t, int(await px()), int(P.y + P.h), int(b.x), str(B3.SHOTS.map(func(q): return "%s@%d,%d,%d" % [q.k, int(q.x), int(q.y), q.t]))])
		b["_php"] = P.hp
		if b.st == "wait":
			await frame({"R": true})
			continue
		var pcx: float = await px()
		var wave := false
		for sh in B3.SHOTS:
			if sh.k == "wave" and absf(sh.x - pcx) < 80 and signf(pcx - sh.x) == signf(sh.vx):
				wave = true
		if wave and P.onGround:
			await press("J")
			await hold({"J": true}, 14)
			continue
		# pedra do teto caindo perto: sai de baixo
		var rock_x := 1e9
		for sh in B3.SHOTS:
			if sh.k == "rock" and absf(sh.x - pcx) < 46:
				rock_x = sh.x
		if rock_x < 1e8:
			var away: float = 1.0 if pcx >= rock_x else -1.0
			if pcx + away * 60 > float(b.x1) - 30 or pcx + away * 60 < float(b.x0) + 30:
				away = -away
			await frame({"R" if away > 0 else "L": true})
			continue
		if b.st in ["raise", "slam"] and absf(pcx - b.x) < 230:
			await frame({"R" if pcx > b.x else "L": true})
			continue
		if b.st == "stuck" and int(b.get("hs", 0)) == 0:
			var gx: float = b.x + side * 92.0
			if absf(pcx - gx) > 10:
				await frame({"R" if gx > pcx else "L": true})
				continue
			if (b.x > pcx) != (P.face > 0):
				await frame({"R" if b.x > pcx else "L": true})
				continue
			await press("G")
			await hold({}, 24)
			continue
		if b.st == "hurt":
			# afasta-se dele: para o lado onde já está, se houver espaço; senão passa por ele
			side = 1.0 if pcx > b.x else -1.0
			if (side > 0 and float(b.x1) - b.x < 330) or (side < 0 and b.x - float(b.x0) < 330):
				side = -side
		var want: float = clampf(b.x + side * 270.0, float(b.x0) + 40, float(b.x1) - 40)
		if absf(want - b.x) < 200:
			side = -side
			want = clampf(b.x + side * 270.0, float(b.x0) + 40, float(b.x1) - 40)
		if absf(pcx - want) > 24 and b.st in ["walk", "hurt", "fight0", "stuck"]:
			await frame({"R" if want > pcx else "L": true})
		else:
			await frame()
	return "timeout st=%s hp=%d" % [b.st, b.hp]

## dentro do trem, com a Isis: passa pelos capangas escondida, gira os trincos das portas e puxa o freio
func isis_train():
	var L: Dictionary = g.L
	var x0: float = float(L.isisTrain.x0)
	var TW: float = float(L.isisTrain.wagon)
	var done := [false]
	g.isis_done.connect(func(): done[0] = true)
	P = g.player
	for wi in 4:
		var wx: float = x0 + 100 + wi * TW
		# os capangas deste vagão
		for w in g.VL.WATCH:
			if float(w.x0) > wx - 20 and float(w.x0) < wx + TW - 100:
				var r = await train_sneak(w)
				if not (r is bool and r):
					return "capanga do vagão %d: %s" % [wi + 1, str(r)]
		if wi < 3:
			# o trinco da porta da frente
			var ck: Dictionary = {}
			for c in g.CRANKS:
				if absf(float(c.x) - (wx + TW - 45)) < 40:
					ck = c
			if ck.is_empty():
				return "sem trinco no vagão %d" % (wi + 1)
			await walk_to(float(ck.x) - 10.0)
			await hold({}, 3)
			for k in 8:
				if ck.done:
					break
				await press("A")
				await hold({}, 8)
			if not ck.done:
				return "trinco %d não abriu" % (wi + 1)
			# espera o capanga do próximo vagão virar de costas antes de passar pela porta
			for w2 in g.VL.WATCH:
				if float(w2.x0) > wx + TW - 20 and float(w2.x0) < wx + 2 * TW - 100:
					await until({}, func(): return float(w2.dir) > 0 and int(w2.wait) == 0 and float(w2.x) > float(w2.x0) + 80, 900)
			if not await walk_to(wx + TW + 60):
				return "não passou a porta %d" % (wi + 1)
	await walk_to(float(L.isisBrake.x) - 10.0)
	await hold({}, 3)
	if not g.near_brake():
		return "longe do freio (x=%d)" % int(await px())
	await use()
	var r2 = await until({}, func(): return done[0], 300)
	return true if done[0] else "freio: " + str(r2)

## passa por um capanga do vagão: espera ele ir para a frente, corre até o esconderijo no meio da ronda,
## abaixa, deixa ele passar de volta e corre para a porta
func train_sneak(w: Dictionary):
	var x0: float = float(w.x0)
	var x1: float = float(w.x1)
	var hide: Dictionary = {}
	for h in g.VL.HIDES:
		var hc: float = float(h.x) + float(h.w) / 2
		if hc > x0 + 20 and hc < x1 - 20:
			hide = h
	if hide.is_empty():
		return "sem esconderijo na ronda"
	var hc2: float = float(hide.x) + float(hide.w) / 2
	var stage := 0
	var cn: int = g.VL.caught_n
	for i in 4000:
		P = g.player
		if not await ok():
			return "state"
		if g.VL.caught_n != cn:
			cn = g.VL.caught_n
			stage = 0
		var wx: float = float(w.x)
		if await px() >= x1 + 60:
			return true
		if stage == 0:
			# espera ele andar para a frente (de costas) e chega no esconderijo; enquanto isso, fica
			# fora do alcance do lampião
			if float(w.dir) > 0 and int(w.wait) == 0 and wx > hc2 + 55 and await px() < x0 - 300:
				stage = 1
			elif await px() > x0 - 390:
				await frame({"L": true})
				continue
			await frame({})
			continue
		if stage == 1:
			if absf(await px() - hc2) > 5:
				await frame({"R" if hc2 > await px() else "L": true})
				continue
			stage = 2
		if stage == 2:
			# abaixada atrás do esconderijo até ele voltar e passar
			if float(w.dir) < 0 and int(w.wait) == 0 and wx < await px() - 70:
				stage = 3
			await frame({"S": true})
			continue
		await frame({"R": true})
	return "timeout@%d" % int(await px())

## o Vargas em cima dos vagões: pula os barris e a investida, desvia do carvão, defende o clarão com a
## lanterna (✦) e bate (picareta) quando ele cansa
func vargas_fight():
	var B3 = g.K.B3
	var b: Dictionary = B3.boss("vargas")
	await walk_to(float(b.trig) + 30)
	for it in 9000:
		P = g.player
		if OS.get_environment("DBG") != "" and it % 20 == 0:
			print("VG it=%d st=%s t=%d hp=%d bx=%d px=%d py=%d php=%d lives=%d" % [it, b.st, b.t, b.hp, int(b.x), int(await px()), int(P.y + P.h), P.hp, g.lives])
		if b.done or b.st == "down":
			var r = await until({}, func(): return not g.running, 400)
			return true
		if not await ok():
			return "state"
		if b.st in ["wait", "intro"]:
			await frame({"R": true} if b.st == "wait" else {})
			continue
		var pcx: float = await px()
		var ground: bool = P.onGround
		# o clarão: defende com a lanterna
		if b.st == "lamp" and B3.can_defend():
			await use()
			continue
		# barril chegando: pula
		var jump := false
		for sh in B3.SHOTS:
			if sh.k == "barrel" and sh.t >= 0 and signf(pcx - sh.x) == signf(sh.vx) and absf(sh.x - pcx) < 110 + absf(sh.vx) * 6:
				jump = true
		# investida: pula por cima (pulo duplo)
		if b.st == "charge" and b.t >= 12 and signf(pcx - b.x) == float(b.dir) and absf(b.x - pcx) < 120 + (6.5 + B3._vphase(b) * 1.4) * 9:
			jump = true
		if jump and ground:
			await press("J")
			var used := false
			for i in 60:
				var d := {"J": true}
				if not used and i > 10 and g.player.vy > -1:
					await press("J")
					used = true
				await frame(d)
				if g.player.onGround and i > 4:
					break
			continue
		# carvão caindo perto: sai de baixo
		var away := 0.0
		var sumx := 0.0
		var nc := 0
		var hitme := false
		for sh in B3.SHOTS:
			if sh.k == "coal":
				var gy0: float = float(b.get("y0", b.y)) - 6.0
				var tt: float = (-sh.vy + sqrt(maxf(0.0, sh.vy * sh.vy + 2.0 * .4 * (gy0 - sh.y)))) / .4
				var lx: float = sh.x + sh.vx * tt
				sumx += lx
				nc += 1
				if absf(lx - pcx) < 46:
					hitme = true
		if hitme and nc > 0:
			away = 1.0 if pcx > sumx / nc else -1.0
		if away != 0.0:
			if pcx + away * 60 > float(b.x1) - 20 or pcx + away * 60 < float(b.x0) + 20:
				away = -away
			await frame({"R" if away > 0 else "L": true})
			continue
		if b.st == "tired" and b.t >= 0:
			var gx: float = b.x - 56.0 if pcx < b.x else b.x + 56.0
			if absf(pcx - gx) > 10:
				await frame({"R" if gx > pcx else "L": true})
				continue
			if (b.x > pcx) != (P.face > 0):
				await frame({"R" if b.x > pcx else "L": true})
				continue
			await press("G")
			await hold({}, 22)
			continue
		# fica a uma distância dele
		var want: float = clampf(b.x + (-1.0 if pcx < b.x else 1.0) * 260.0, float(b.x0) + 40, float(b.x1) - 40)
		if absf(want - b.x) < 180:
			want = clampf(b.x - (-1.0 if pcx < b.x else 1.0) * 260.0, float(b.x0) + 40, float(b.x1) - 40)
		if absf(pcx - want) > 30 and b.st in ["idle", "hurt"]:
			await frame({"R" if want > pcx else "L": true})
		else:
			await frame()
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
		if not await ok():
			return "state"
		var ahead := false
		for o in g.TR.T:
			if o.k == "roll" and o.st in ["idle", "go"] and float(o.get("bx", o.x)) > await px() - 40 and absf(float(o.x) - await px()) < 900:
				ahead = true
		if await px() >= x and P.onGround and not ahead:
			return true
		for o in g.TR.T:
			if o.k == "roll" and o.st == "go" and P.onGround and hold_j <= 0:
				var dx: float = float(o.get("bx", o.x)) - await px()
				if dx > 0 and dx < 16.0 * (4.3 + absf(float(o.get("vx", 0.0)))) + 24.0:
					await press("J")
					hold_j = 18
		hold_j -= 1
		var go_r: bool = await px() < x or (ahead and await px() < x + 40)
		await frame({"R": go_r, "J": hold_j > 0})
	return "timeout@%d" % int(await px())

## anda pela passarela no vento: quando a rajada sopra, abaixa e espera
func gust_walk(x: float):
	for i in 2000:
		P = g.player
		if not await ok():
			return "state"
		if await px() >= x and P.onGround:
			return true
		var blowing := false
		for o in g.TR.T:
			if o.k == "gust" and g.TR.gust_state(o) == 2 and await px() > o.x - 40 and await px() < o.x + o.w + 40:
				blowing = true
		await frame({"S": true} if blowing else {"R": true})
	return "timeout@%d" % int(await px())

## passa pelo vigia: espera abaixado atrás de um caixote/barril; quando ele já passou indo para a
## esquerda (de costas para o Tomé), corre para a direita
func sneak_past(w: Dictionary, x_end: float):
	var V = g.VL
	var spot: Dictionary = {}
	for i in 5000:
		P = g.player
		if not await ok():
			return "state"
		if await px() >= x_end:
			return true
		var wx: float = float(w.x)
		if float(w.dir) < 0 and int(w.wait) == 0 and wx < await px() - 60:
			# ele está de costas, indo embora para a esquerda: corre
			spot = {}
			await frame({"R": true})
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
					if absf(hc3 - await px()) < bd:
						bd = absf(hc3 - await px())
						best = h
			spot = best
		var hc2: float = float(spot.x) + float(spot.w) / 2
		if absf(await px() - hc2) > 6:
			await frame({"R": true} if hc2 > await px() else {"L": true})
		else:
			await frame({"S": true})
	return "timeout@%d" % int(await px())

func lift_up(o: Dictionary):
	var s: Dictionary = o.plats[0]
	var r = await walk_to(float(s.x) + float(s.w) / 2)
	if not (r is bool and r):
		return "até o elevador: " + str(r)
	await use()
	return await until({}, func(): return float(o.pos) == 0.0 and float(o.goal) == 0.0, 900)

func _initialize() -> void:
	await _rec_setup(2)
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
	await S("sem o Pipoca no Ep. 3", not g.X.dog_free())
	await walk_to(1060)
	await S("degrau 1", await jump_to(1170))
	await S("degrau 2", await jump_to(1310))
	await S("degrau 3", await jump_to(1450))
	await S("em cima do penhasco", await walk_to(1970) and P.y < 250)
	await S("tábua do vermelho", await jump_to(2050))
	await hop("R", 0)
	await S("vermelho", await spec("vermelho"))
	await S("desce do penhasco", await until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	await hold({}, 24)
	await walk_to(2620)
	await S("passagem baixa (de volta, abaixado)", await crawl(2200))
	await S("pista 18 no túnel", await n_clues() == 1)
	await S("sai do túnel", await crawl(2620))
	await S("pedras rolando", await dodge_to(3200))
	await walk_to(3240)
	await walk_to(3300)
	await S("ponte podre 1", await jump_to(3375))
	await S("ponte podre 2", await jump_to(3470))
	await S("ponte podre 3", await jump_to(3565))
	await S("ponte podre 4", await jump_to(3660))
	await S("outro lado", await jump_to(3780))
	await S("pé da muralha", await walk_to(4420))
	await S("sobe entre as paredes", await crevice_climb())
	if P.y + P.h > -250:
		await jump_to(4540, true)
	await S("no alto da muralha", P.onGround and P.y + P.h <= -255)
	await S("passarela com vento", await gust_walk(5300))
	# volta e desce para entrar pelo bueiro (o desenho fica no túnel)
	await walk_to(4500)
	await until({"L": true}, func(): return P.onGround and P.y > 400, 300)
	await S("até o bueiro", await walk_to(4215))
	await down()
	await S("entrou no bueiro", await until({}, func(): return P.y > 800 and P.onGround, 200))
	await walk_to(4680)
	await S("passagem baixa do túnel", await crawl(4990))
	await S("desenho do túnel", await walk_to(5500))
	await walk_to(5725)
	await press("U")
	await S("saiu no pátio", await until({}, func(): return P.y < 600 and P.onGround, 200))
	await S("fogueira 1", await walk_to(5810))
	await S("descansou 1", rests.has(1))
	# ---------------- B · O PÁTIO DOS VIGIAS
	await walk_to(6465)
	await S("sobe para a passarela", await climb_to("U", func(): return P.onGround and P.y + P.h <= 252, 400))
	await walk_to(6700)
	await S("tábua 2", await jump_to(6880))
	await walk_to(7000)
	await S("tábua podre", await jump_to(7170))
	await S("tábua do laranja", await jump_to(7420, true))
	await hop("R", 0)
	await S("laranja", await spec("laranja"))
	await walk_to(7560)
	await S("última tábua", await jump_to(7740))
	await walk_to(8060)
	await S("vigia não pegou", g.VL.caught_n == 0)
	await S("andaime 1", await jump_to(8200))
	await S("andaime 2", await jump_to(8420, true))
	await S("andaime 3", await jump_to(8730, true))
	await S("andaime 4", await jump_to(9000, true))
	await S("andaime 5", await jump_to(9220, true))
	await S("desce longe do cão", await until({"R": true}, func(): return P.onGround and P.y > 400 and px() > 9300, 300))
	await S("pista 16", await walk_to(9800) and await n_clues() == 2)
	await S("jardim", await walk_to(10010))
	await use()
	await S("quebrou a pedra solta", g.X.broken.has("crk1"))
	await walk_to(10100)
	await S("pegou a chave", await until({}, func(): return g.has_item("chave"), 60))
	await walk_to(10400)
	await S("passa pelo vigia 2", await sneak_past(g.VL.WATCH[1], 11900))
	await S("vigia 2 não pegou", g.VL.caught_n == 0)
	await S("fogueira 2", rests.has(2) or await walk_to(11970))
	await S("descansou 2", rests.has(2))
	# a guarita: a pedrinha no balde do poço tira o vigia do posto
	var gw: Dictionary = g.VL.WATCH[2]
	await S("atrás do caixote da guarita", await walk_to(11993))
	await S("botão USAR (pedrinha)", g.use_available())
	await use()
	await S("vigia saiu do posto", await until({"S": true}, func(): return int(gw.lt) > 0, 80))
	await S("vigia passou pelo caixote", await until({"S": true}, func(): return float(gw.x) < 11880, 600))
	await hold({}, 4)
	await walk_to(12445)
	await S("guarita não pegou", g.VL.caught_n == 0)
	await use()
	var dl: Dictionary = g.LOCKS.filter(func(l): return l.get("id", "") == "dg1")[0]
	await S("destrancou a porta", dl.done)
	await S("entra nos porões", await until({"R": true}, func(): return px() > 12650, 400))
	# ---------------- C · OS PORÕES
	var C0 := 12600.0
	await walk_to(C0 + 260)
	await S("passagem baixa 1", await crawl(C0 + 580))
	await walk_to(C0 + 820)
	await S("passagem baixa 2", await crawl(C0 + 1120))
	# a grade: a manivela
	await walk_to(C0 + 1180)
	await hold({}, 3)
	await S("botão vira manivela (grade)", g.use_mode() == "crank")
	for k in 7:
		await press("A")
		await hold({}, 8)
	await S("a grade subiu", g.CRANKS.filter(func(c): return c.get("gate", "") == "pg3")[0].done)
	await S("passa pela grade", await walk_to(C0 + 1300))
	# térreo: espinhos, o desenho atrás da parede rachada e o amarelo no beco
	await walk_to(C0 + 1500)
	await S("espinhos 1", await cross_spikes(await trap_at("spikes", C0 + 1560), C0 + 1700))
	await walk_to(C0 + 1720)
	await S("espinhos 2", await cross_spikes(await trap_at("spikes", C0 + 1780), C0 + 1920))
	await walk_to(C0 + 2000)
	await use()
	await S("quebrou a parede rachada", g.X.broken.has("crk2"))
	var dz: Dictionary = g.DRWS.filter(func(d): return d.get("crack") == "crk2")[0]
	await walk_to(C0 + 2090)
	await S("pegou o desenho do porão", await until({}, func(): return dz.got, 120))
	await walk_to(C0 + 2390)
	await S("cavalete do amarelo", await jump_to(C0 + 2500))
	await hop("R", 0)
	await S("amarelo", await spec("amarelo"))
	await walk_to(C0 + 1940)
	await S("espinhos 2 (volta)", await cross_spikes(await trap_at("spikes", C0 + 1780), C0 + 1720))
	await walk_to(C0 + 1700)
	await S("espinhos 1 (volta)", await cross_spikes(await trap_at("spikes", C0 + 1560), C0 + 1500))
	await S("escada do térreo", await walk_to(C0 + 1415))
	await S("sobe para o meio", await climb_to("U", func(): return P.ladder == null and P.y + P.h <= 282, 500))
	await hold({"R": true}, 10)
	# andar do meio: escada para o beco de cima (pista 15)
	await S("escada do meio", await walk_to(C0 + 1745))
	await S("sobe para cima", await climb_to("U", func(): return P.ladder == null and P.y + P.h <= 62, 500))
	await jump_to(C0 + 1620)
	await S("pista 15 no beco de cima", await walk_to(C0 + 500) and await n_clues() == 3)
	await S("desce pelo buraco da escada", await walk_to(C0 + 1745) and await wait_ground() and P.y + P.h > 250)
	await walk_to(C0 + 1840)
	await press("G")
	await hold({}, 26)
	await S("quebrou a parede rachada do meio", g.X.broken.has("cr1"))
	await S("pista 17", await walk_to(C0 + 2600) and await n_clues() == 4)
	await walk_to(C0 + 2790)
	await S("espinhos do meio 1", await cross_spikes(await trap_at("spikes", C0 + 2850), C0 + 2990))
	await walk_to(C0 + 3090)
	await S("espinhos do meio 2", await cross_spikes(await trap_at("spikes", C0 + 3150), C0 + 3290))
	await S("escada para cima", await walk_to(C0 + 3625))
	await S("sobe", await climb_to("U", func(): return P.ladder == null and P.y + P.h <= 62, 500))
	await hold({"R": true}, 10)
	await walk_to(C0 + 3780)
	var hp_rope: int = P.hp
	await jump_to(C0 + 3920)
	await S("pendurado na corda", P.get("bar") != null)
	await S("vai pela corda", await until({"R": true}, func(): return px() > C0 + 4390, 600))
	await hold({"S": true}, 4)
	await S("verde", await spec("verde"))
	await S("solta depois dos espinhos", await wait_ground() and await px() > C0 + 4370 and P.hp == hp_rope)
	await walk_to(C0 + 4775)
	await S("desce para a cisterna", await until({"R": true}, func(): return P.onGround and P.y + P.h > 400, 300))
	await walk_to(C0 + 4830)
	await S("degrau da cisterna", await jump_to(C0 + 4895))
	await S("laje alta", await jump_to(C0 + 5020))
	var cw: Dictionary = g.L.water.filter(func(w): return w.get("zap"))[0]
	var pcs: Array = cw.pillars.map(func(q): return float(q) + 45.0)
	for pc in pcs:
		await jump_to(pc, true)
	await S("último pilar", absf(await px() - float(pcs[-1])) < 20 and P.onGround)
	await S("desenho da cisterna", g.DRWS.filter(func(d): return absf(float(d.x) - float(pcs[-1])) < 5)[0].got)
	await S("margem", await jump_to(float(cw.x) + float(cw.w) + 80, true))
	var c3: Array = g.L.checks.filter(func(c): return c.size() > 2 and int(c[3]) == 3)[0]
	await S("fogueira 3", await walk_to(float(c3[0]) + 10))
	await S("descansou 3", rests.has(3))
	# ---------------- D · AS FORJAS
	var D0: float = float(L.sections[3].x)
	await walk_to(D0 + 580)
	await S("pilar 1", await jump_to(D0 + 735))
	await S("pilar 2", await jump_to(D0 + 895))
	await S("chão", await jump_to(D0 + 1080))
	await S("pista 13", await walk_to(D0 + 1300) and await n_clues() == 5)
	await walk_to(D0 + 1380)
	await S("vapor: azul", await steam_to(D0 + 1655, func(): return spec("azul")))
	await S("plana até o chão", await glide_to(D0 + 2000))
	await walk_to(D0 + 2170)
	await S("prensa 1", await cross_spikes(await trap_at("spikes", D0 + 2200), D0 + 2380))
	await S("prensa 2", await cross_spikes(await trap_at("spikes", D0 + 2450), D0 + 2620))
	await S("martelo", await cross_swing(await trap_at("axe", D0 + 2850), D0 + 2950))
	await walk_to(D0 + 2980)
	var m1: Dictionary = await mover("path", D0 + 3030)
	var m2: Dictionary = await mover("path", D0 + 3740)
	await S("tábua 1", await board_path(m1, true))
	await S("vai na tábua 1", await ride_path(m1, true))
	await S("pilar do barril", await jump_to(D0 + 3655))
	await S("tábua 2", await board_path(m2, true))
	await S("vai na tábua 2", await ride_path(m2, true))
	await S("pilar do fim", await jump_to(D0 + 4425))
	await S("chão depois do tanque", await jump_to(D0 + 4600))
	await S("ímã", await walk_to(D0 + 4800) and g.has_item("ima"))
	await walk_to(D0 + 4930)
	await S("cavalete", await jump_to(D0 + 5010, true))
	await jump_to(D0 + 5150)
	await S("pendurado na viga (ímã)", P.get("bar") != null and P.bar.get("mag"))
	await S("vai pela viga", await until({"R": true}, func(): return px() > D0 + 5830, 700))
	await hold({"S": true}, 4)
	await S("solta no chão", await wait_ground() and P.y > 400)
	await S("sem queimar", P.hp == 5)
	await S("pista 14", await walk_to(D0 + 6000) and await n_clues() == 6)
	await S("vence a Salamandra de Fogo", await sal_fight())
	await S("fogueira 4", await walk_to(D0 + 7410))
	await S("descansou 4", rests.has(4))
	# ---------------- E · AS TORRES
	var E0: float = float(L.sections[4].x)
	var lf: Dictionary = await mover("lift", E0 + 640)
	await S("sobe de elevador", await lift_up(lf))
	await S("alto da torre", await walk_to(E0 + 1100) and P.y + P.h <= -255)
	await walk_to(E0 + 1600)
	await S("pilar", await jump_to(E0 + 1670, true))
	await S("torre de cima", await jump_to(E0 + 1850, true))
	await hop("R", 0)
	await S("roxo", await spec("roxo"))
	await S("ventania", await gust_walk(E0 + 2380))
	var br: Dictionary = await trap_at("bridge", E0 + 2400)
	await S("a ponte que desaba", await bridge_run(br))
	await S("outra torre", P.onGround and P.y + P.h <= -435)
	await walk_to(E0 + 4060)
	await S("desce da torre", await until({"R": true}, func(): return P.onGround and P.y > 400, 300))
	await S("desenho da estação", await walk_to(E0 + 4350))
	await S("vence o Guardião de Ferro", await gua_fight())
	await S("o trem partiu", await walk_to(float(L.door.x) - 100) and g.VH.dep_t >= 0)
	await S("trole solto", not g.VH.tied)
	await S("sobe no trole", await until({"R": true}, func(): return g.VH.mode == "sled", 500))
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
				await press("J")
			if o.k == "crack" and ground and dx < 40 and dx > -5:
				await press("J")
			if o.k == "branch" and dx < 110 and dx > -100:
				d["S"] = true
			break
		await frame(d)
	await S("alcançou o trem", done_cart)
	var hk := []
	for o in VH.OBS:
		if o.hit:
			hk.append(o.k + "@" + str(o.u))
	await S("trole sem batidas " + str(hk), hk.is_empty())
	var started := [false]
	g.isis_start.connect(func(): started[0] = true)
	await until({}, func(): return started[0] or not g.running, 300)
	await S("o trole alcançou o trem: agora é a Isis", started[0])
	g.begin_isis()
	P = g.player
	await S("Isis dentro do trem", P.get("isis") == true and await px() > float(L.isisTrain.x0))
	await S("a Isis foge pelo trem e puxa o freio", await isis_train())
	g.begin_vargas()
	P = g.player
	await S("o Tomé em cima dos vagões", not P.get("isis") and P.onGround or await wait_ground())
	var endv := [false]
	g.results_ready.connect(func(): endv[0] = true)
	await S("vence o Vargas", await vargas_fight())
	await S("fim do episódio (resultados)", endv[0])
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	print("desenhos: ", g.DRWS.map(func(d): return [int(d.x), int(d.y), d.got]))
	await S("final: pistas=%d esp=%d des=%d lápis=%d/%d" % [await n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal], await n_clues() == 6 and g.SPECGOT.size() == 6 and nd == g.DRWS.size())
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
