extends SceneTree
## Teste automático: joga a Fase 1 inteira, do começo à saída da mina, pegando as 6 pistas,
## os 6 lápis especiais e os 2 desenhos. Uso:
##   godot --headless --path . -s tests/route.gd            (sem inimigos)
##   godot --headless --path . -s tests/route.gd -- inimigos (com inimigos)

var g
var P: Dictionary
var log_lines: Array = []
var fails := 0
var rests: Array = []

func frame(set: Dictionary = {}) -> void:
	for k in ["L", "R", "J", "P", "S", "U", "A"]:
		g.keys[k] = false
	for k in set:
		g.keys[k] = set[k]
	await _rstep()
	while not g.CINE.is_empty():
		await _rstep()

func press(k: String) -> void:
	g.keys[k + "p"] = true

## pula e, no alto do pulo, aperta ↓ (mergulho) e espera bater no chão
func slam_here() -> void:
	await press("J")
	await frame({"J": true})
	for i in 40:
		await frame({"J": true})
		if P.vy > -2:
			break
	await press("S")
	await frame()
	for i in 90:
		await frame()
		if P.onGround or P.ladder != null or P.y > 600:
			break

## lago de veneno: sobe na estaca, crava com o mergulho, espera a ponte cair e atravessa
func stake_cross(sx: float):
	var st: Dictionary = {}
	for o in g.SL.STAKES:
		if abs(float(o.x) - sx) < 5:
			st = o
	if st.is_empty():
		return "sem estaca"
	if not st.done:
		if await px() < sx - 60:
			await walk_to(sx - 60)
		await jump_to(sx)
		if not P.onGround or abs(P.y + P.h - (float(st.y) - 44)) > 6:
			return "não subiu na estaca y=%d" % int(P.y + P.h)
		await slam_here()
		if not await until({}, func(): return st.done and st.lift >= 1.0, 400):
			return "a ponte não caiu"
	return await walk_to(float(st.bridge.x) + float(st.bridge.w) + 40)

func px() -> float:
	return P.x + P.w / 2

func ok() -> bool:
	return g.running

func S(name: String, r) -> void:
	P = g.player
	var bad: bool = (r is String and r != "" and not r.begins_with("ok")) or (r is bool and r == false)
	if bad:
		fails += 1
	log_lines.append("%s %s: %s  [x=%d y=%d vidas=%d hp=%d %s]" % ["✗" if bad else "·", name, str(r), int(await px()), int(P.y), g.lives, P.hp, P.dieMsg])

func walk_to(x: float, mx: int = 1500):
	var last := await px()
	var stuck := 0
	for i in mx:
		P = g.player
		if not await ok():
			return "state"
		if abs(await px() - x) < 6 and P.onGround:
			for j in 10:
				await frame()
			return true
		await frame({"R" if x > await px() else "L": true})
		P = g.player
		if abs(await px() - last) < .05:
			stuck += 1
		else:
			stuck = 0
		last = await px()
		if stuck > 50:
			return "stuck@%d,%d" % [int(await px()), int(P.y)]
	return "timeout@%d" % int(await px())

func wait_ground(set: Dictionary = {}, mx: int = 700):
	for i in mx:
		P = g.player
		if not await ok():
			return "state"
		if P.onGround:
			return true
		await frame(set)
	return "air"

func hold(set: Dictionary, n: int):
	for i in n:
		if not await ok():
			return "state"
		await frame(set)
	return true

func until(set: Dictionary, cond: Callable, mx: int = 900):
	for i in mx:
		P = g.player
		if not await ok():
			return "state"
		if cond.call():
			return true
		await frame(set)
	return "timeout@%d,%d" % [int(await px()), int(P.y)]

func hop(dir: String, ndir: int, h: int = 16):
	await press("J")
	for i in h:
		await frame({"J": true, dir: true} if i < ndir else {"J": true})
	return await wait_ground()

func djump(dir: String):
	var d := {dir: true}
	await press("J")
	for i in 16:
		await frame({"J": true, dir: true})
	for i in 30:
		P = g.player
		if P.vy >= -.5:
			break
		await frame(d)
	await press("J")
	for i in 16:
		await frame({"J": true, dir: true})
	return await wait_ground(d)

func jump_to(x: float, dbl: bool = false, mx: int = 200):
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
		if dbl and not used and i > 14 and P.vy > -1:
			await press("J")
			used = true
		var s := d.duplicate()
		s["J"] = i < 16 or (dbl and i < 34)
		await frame(s)
		P = g.player
		if P.onGround and i > 3:
			return true
	return "air"

func crawl(x: float, mx: int = 600):
	var dir := "R" if x > await px() else "L"
	for i in mx:
		if not await ok():
			return "state"
		if (await px() >= x) if dir == "R" else (await px() <= x):
			for j in 4:
				await frame()
			return true
		await frame({"S": true, dir: true})
	return "timeout@%d,%d" % [int(await px()), int(g.player.y)]

func climb_to(dir: String, cond: Callable, mx: int = 600):
	for i in mx:
		P = g.player
		if cond.call():
			return true
		await frame({dir: true})
	return "timeout y=%d lad=%s" % [int(g.player.y), str(g.player.ladder != null)]

func use():
	await press("A")
	await frame()
	await hold({}, 6)
	return true

func down():
	await press("S")
	await frame({"S": true})
	await hold({}, 40)
	return true

func jr(n: int, dir: String):
	await press("J")
	await hold({"J": true, dir: true}, n)
	return await wait_ground({dir: true})

func wall_climb():
	var dir := "R"
	await press("J")
	await hold({"J": true, dir: true}, 10)
	for i in 18:
		P = g.player
		await until({dir: true}, func(): return g.player.wsl > 0 or g.player.onGround, 90)
		P = g.player
		if P.onGround:
			return P.y + P.h <= 102
		await press("J")
		await frame({"J": true})
		dir = "L" if dir == "R" else "R"
		await hold({"J": true}, 6)
	return "wall@%d,%d" % [int(await px()), int(P.y)]

## sobe a fenda pulando de parede em parede; termina em pé lá em cima
func crevice_climb():
	var dir := "R"
	await press("J")
	await hold({"J": true, dir: true}, 10)
	for i in 24:
		P = g.player
		await until({dir: true}, func(): return g.player.wsl > 0 or g.player.onGround, 90)
		P = g.player
		if P.onGround:
			return P.y + P.h <= -14 or "chão y=%d" % int(P.y + P.h)
		await press("J")
		await frame({"J": true})
		dir = "L" if dir == "R" else "R"
		await hold({"J": true}, 6)
	return "fenda@%d,%d" % [int(await px()), int(P.y)]

func hawk_fight():
	var h: Dictionary = g.K.HAWK
	var mid: float = (h.x0 + h.x1) / 2.0
	for it in 3080:
		P = g.player
		if not await ok():
			return "state"
		if h.done or h.st == "flee":
			await hold({}, 60)
			return true
		match h.st:
			"mark", "dive":
				var tx: float = h.tx - 230 if h.tx > mid else h.tx + 230
				await frame({"R" if tx > await px() else "L": true} if abs(tx - await px()) > 10 else {})
			"stuck":
				var side: float = -1.0 if await px() < h.x else 1.0
				var tx2: float = h.x + side * 44
				if abs(tx2 - await px()) > 6:
					await frame({"R" if tx2 > await px() else "L": true})
				else:
					P.face = -int(side)
					await press("G")
					await hold({}, 24)
			_:
				await frame()
	return "hp=%d st=%s" % [h.hp, h.st]


## Urso-Rei: perseguição. Corre para a direita pulando os troncos, abaixa embaixo do galho, para quando
## a sombra de um pingente está logo à frente, entra abaixado na fresta e pega a coroa do outro lado.
## Rigoroso: o urso não pode encostar no Tomé (nenhum coração perdido) e não pode passar da rocha.
func bear_fight():
	var K = g.K
	var b: Dictionary = K.BEAR
	var rx: float = float(b.rock.x)
	var rend: float = rx + float(b.rock.w)
	var min_hp: int = P.hp
	var past_rock := false
	var saw := {}
	for it in 3000:
		P = g.player
		if not await ok():
			return "state"
		min_hp = min(min_hp, int(P.hp))
		saw[b.st] = 1
		if b.x > rx - 99.0:
			past_rock = true
		if OS.get_environment("BEARDBG") != "" and it % 20 == 0:
			print("bear st=%s t=%d bx=%d px=%d php=%d" % [b.st, b.t, int(b.x), int(await px()), P.hp])
		if K.TOOK.has("urso"):
			await hold({}, 80)
			break
		var pcx: float = await px()
		var feet: float = P.y + P.h
		var d := {"R": true}
		# do outro lado da fresta: espera a coroa rolar e vai pegar
		if P.x > rend + 2:
			var cr = null
			for c in K.CROWNS:
				if c.id == "urso":
					cr = c
			if cr == null or cr.st == "fall" or cr.has("to"):
				await frame({})
				continue
			if abs(cr.x - pcx) > 6:
				await frame({"R" if cr.x > pcx else "L": true})
			else:
				await frame({})
			continue
		# fresta: abaixa e vai
		if pcx > rx - 70:
			await frame({"R": true, "S": true})
			continue
		# pingente marcado logo à frente: espera ele cair (se estiver bem em cima, sai de baixo correndo)
		var wait := false
		var under := false
		for c in K.ICI:
			if c.st in ["shake", "fall"]:
				if abs(c.x - pcx) < 26:
					under = true
				elif c.x - pcx > 0 and c.x - pcx < 80:
					wait = true
		if wait and not under and P.onGround:
			await frame({})
			continue
		var jumped := false
		for o in K.BOBS:
			if o.get("fallen"):
				continue
			var dist: float = o.x - (P.x + P.w)
			if o.k == "branch":
				if dist < 30 and dist > -o.w - 10 and P.onGround:
					d["S"] = true
			elif P.onGround and dist > 0 and dist < max(16.0, abs(P.vx) * 7.0 + 6.0):
				await press("J")
				jumped = true
		if jumped:
			d["J"] = true
			await frame(d)
			for k in 14:
				await frame({"R": true, "J": true})
			continue
		await frame(d)
	if not K.TOOK.has("urso"):
		return "sem coroa st=%s bx=%d px=%d" % [b.st, int(b.x), int(await px())]
	if min_hp < g.MAXHP:
		return "levou golpe (coração %d)" % min_hp
	if past_rock:
		return "urso passou da rocha"
	if not (saw.has("crouch") and saw.has("roar") and K.DROPPED.has("urso")):
		return "faltou ataque: %s" % str(saw.keys())
	for o in K.BOBS:
		if not o.get("fallen"):
			return "urso não arrebentou %s" % o.k
	return true

## pula de um cipó para o próximo (solta no auge do balanço para a frente)
func vine_hop(next_vine, mx: int = 600):
	for i in mx:
		P = g.player
		if not await ok():
			return "state"
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		await frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	await press("J")
	await frame()
	if next_vine == null:
		return await wait_ground()
	return await until({}, func(): return g.player.vine == next_vine or g.player.get("bar") != null or g.player.onGround, 120)

## pula da beirada até agarrar um cipó (com pulo duplo)
func grab_vine(v):
	await press("J")
	for i in 120:
		P = g.player
		if P.vine == v:
			return true
		if i == 16:
			await press("J")
		await frame({"J": i < 40, "R": true})
	return "sem cipó"

func fish_fight():
	var f: Dictionary = g.K.FISH
	for it in 6080:
		P = g.player
		if not await ok():
			return "state"
		if f.done or f.st == "down":
			await hold({}, 30)
			return true
		var pc := Vector2(await px(), P.y + P.h / 2)
		var d := {}
		match f.st:
			"tired":
				var pts: Array = g.K.scale_pts()
				var tgt = null
				for i in 4:
					if f.scales[i]:
						tgt = pts[i]
						break
				if tgt == null:
					await frame()
					continue
				var want_x: float = tgt.x - 230 if pc.x < f.x else tgt.x + 230
				want_x = clamp(want_x, f.x0 + 30, f.x1 - 30)
				if abs(want_x - pc.x) > 30:
					d["R" if want_x > pc.x else "L"] = true
				var hy: float = P.y + 14
				if hy > tgt.y + 6:
					d["U"] = true
				elif hy < tgt.y - 6:
					d["S"] = true
				P.face = 1 if tgt.x > pc.x else -1
				if abs(hy - tgt.y) < 22 and g.NT.harp_cd == 0 and abs(tgt.x - pc.x) < 380:
					g.keys["Gp"] = true
			"aim", "charge":
				var midy: float = (f.y0 + f.y1) / 2.0
				if f.y > midy:
					d["U"] = true
				else:
					d["S"] = true
			"suck":
				d["L" if f.x > pc.x else "R"] = true
			_:
				var want: float = f.x - 300 if pc.x < f.x else f.x + 300
				want = clamp(want, f.x0 + 40, f.x1 - 40)
				if abs(want - pc.x) > 20:
					d["R" if want > pc.x else "L"] = true
		await frame(d)
	return "hp=%d st=%s" % [f.hp, f.st]

## bola de neve rolando na direção do Tomé: anda até disparar e pula por cima quando ela chega
func dodge_roll(x: float, i: int):
	await walk_to(x)
	var o: Dictionary = g.TR.by_kind("roll")[i]
	var r = await until({}, func(): return o.st == "go" and o.bx - px() < 85, 400)
	if r != true:
		return "não rolou: " + str(r) + " st=" + o.st
	await press("J")
	await hold({"J": true}, 16)
	await wait_ground()
	await hold({}, 10)
	return o.bx < await px() - 20 or "bola em %d" % int(o.bx)

## corre (dois toques em →) até x
func run_to(x: float):
	await frame({"R": true})
	await frame({})
	for i in 300:
		P = g.player
		if await px() >= x:
			return true
		await frame({"R": true})
	return "timeout@%d" % int(await px())

func ride():
	var RD = g.RD
	for it in 4080:
		if not RD.riding:
			return RD.done
		var d := {}
		for o in RD.OBS:
			var dx: float = o.x - RD.hx
			if dx < -200 or dx > 260:
				continue
			# pula em cima da marca de cascos (o melhor ponto)
			if o.k in ["log", "rock", "gap", "fence", "logs", "leap"] and not o.hit and RD.hy >= 500:
				var tk: float = RD.takeoff_x(o)
				if RD.hx >= tk - 3 and RD.hx < tk + 6:
					await press("J")
					d["J"] = true
			if o.k in ["branch", "rope"] and dx < 110 and dx > -130:
				d["S"] = true
			if dx > -40:
				break
		await frame(d)
	return "não terminou x=%d" % int(RD.hx)

func _to_bar():
	for i in 600:
		P = g.player
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		await frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	await press("J")
	await frame()
	return await until({}, func(): return g.player.get("bar") != null, 120)

func on_perch() -> bool:
	return P.onGround and P.y + P.h <= 397

func boss_fight():
	for it in 60:
		P = g.player
		var b: Dictionary = g.X.BOSS
		if b.done or b.st == "down":
			await hold({}, 160)
			return true
		if not await ok():
			return "state"
		if await on_perch():
			# espera ele se afastar e desce de novo
			await until({}, func(): return g.X.BOSS.st == "idle" or g.X.BOSS.st == "down", 600)
			if g.X.BOSS.st == "down":
				continue
			await walk_to(5005)
			await until({}, func(): return P.onGround and P.y + P.h >= 494, 60)
		await walk_to(4905)
		# no chão: ele investe; pula para o galho quando chega perto
		await until({}, func(): return g.X.BOSS.st == "charge" and abs(g.X.BOSS.x - px()) < 330, 400)
		await jump_to(4905, true)
		await hold({}, 4)
	return "hp=%d st=%s" % [g.X.BOSS.hp, g.X.BOSS.st]

## pilota o trenó/carrinho até o fim (pula pedras, troncos e rachaduras; abaixa nos galhos)
func sled_drive():
	var VH = g.VH
	for i in 5000:
		if VH.mode == "":
			return true
		if not await ok():
			return "state"
		var d := {}
		var ground: bool = VH.hy >= VH.sled_y(VH.su) - 1
		for o in VH.OBS:
			var dx: float = o.x - VH.hx
			if o.hit or o.k == "bump" or o.k == "kick" or dx < -140 or dx > 300:
				continue
			if o.k in ["rock", "log"] and ground and dx < VH.spd * 9.0 + 24 and dx > 30:
				await press("J")
			if o.k == "crack" and ground and dx < 40 and dx > -5:
				await press("J")
			if o.k == "branch" and dx < 110 and dx > -100:
				d["S"] = true
			break
		await frame(d)
	return "timeout"

func n_clues() -> int:
	return g.CLUEGOT.size()

func spec(c: String) -> bool:
	return g.SPECGOT.has(c)

## a armadilha do tipo k mais perto de x
func trap_at(k: String, x: float) -> Dictionary:
	var best: Dictionary = {}
	for o in g.TR.T:
		if o.k == k and (best.is_empty() or abs(o.x - x) < abs(best.x - x)):
			best = o
	return best

## espera os espinhos acabarem de descer e atravessa andando
func cross_spikes(o: Dictionary, x_after: float):
	var per: int = o.get("per", 140)
	for i in 400:
		if (g.T + int(o.get("ph", 0))) % per == per / 2 + 8:
			break
		await frame()
	return await walk_to(x_after)

## tronco-pêndulo: espera ele subir para o lado de lá e passa correndo por baixo
func cross_swing(o: Dictionary, x_after: float):
	for i in 400:
		var th: float = fposmod(TAU * (g.T + o.get("ph", 0)) / float(o.per), TAU)
		if abs(th - deg_to_rad(215)) < .04:
			break
		await frame()
	return await run_to(x_after)

## corta a teia com a picareta (de frente para ela)
func cut_web(o: Dictionary):
	await walk_to(o.x - 22)
	P.face = 1
	await press("G")
	await hold({}, 24)
	return o.cut or "teia inteira"

## pula num cogumelo saltador e deixa ele lançar até pousar
func bounce_to(bx: float):
	await press("J")
	var launched := false
	for i in 300:
		P = g.player
		if not await ok():
			return "state"
		if P.get("launchT", 0) > 0:
			launched = true
		var d := {}
		if not launched:
			if await px() < bx - 4:
				d = {"R": true}
			elif await px() > bx + 4:
				d = {"L": true}
			d["J"] = i < 16
		await frame(d)
		P = g.player
		if launched and P.onGround:
			return true
	return "não foi lançado" if not launched else "air"

## corredeira: pula pedras, troncos e quedas; abaixa nos galhos
func ride_raft():
	var VH = g.VH
	for it in 4080:
		if VH.mode != "raft":
			return VH.raft_done
		var d := {}
		var wl: float = VH.water_y(VH.hx)
		for f in VH.RA.falls:
			var df: float = f - VH.hx
			if df > 4 and df < 40 and VH.hy >= wl - 1:
				await press("J")
				d["J"] = true
		for o in VH.OBS:
			var dx: float = o.x - VH.hx
			if dx < -240 or dx > 220 or o.k == "rapid":
				continue
			if o.k in ["rock", "log"] and dx < 70 and dx > 26 and VH.hy >= wl - 1:
				await press("J")
				d["J"] = true
			var dw: float = g.VH.DUCK_W.get(o.k, 0.0)
			if dw > 0 and dx < 120 and dx > -(dw + 36):
				d["S"] = true
			if dx > -40:
				break
		await frame(d)
	return "não terminou x=%d" % int(VH.hx)

## subida da montanha: anda; perto de um precipício espera a rajada passar (abaixado) e pula
func climb_gusts(x_end: float):
	var chasms: Array = g.L.chasms
	for it in 3080:
		P = g.player
		if not await ok():
			return "state"
		if await px() >= x_end and P.onGround:
			return true
		var gusting := false
		for o in g.TR.T:
			if o.k == "gust" and g.TR.gust_state(o) > 0 and await px() > o.x - 220 and await px() < o.x + o.w + 40:
				gusting = true
		# degrau à frente?
		var step_up := false
		for s in g.SOL:
			if s.t == "ground" and s.x > await px() and s.x - await px() < 40 and s.y < P.y + P.h - 4 and P.onGround:
				step_up = true
		var edge := false
		for c in chasms:
			if c[0] - await px() > 0 and c[0] - await px() < 30 and P.onGround:
				edge = true
		if edge:
			if gusting:
				await frame({"S": true})
				continue
			await press("J")
			for i in 40:
				await frame({"J": i < 18, "R": true})
				P = g.player
				if P.onGround and i > 4:
					break
			continue
		if step_up:
			await press("J")
			for i in 30:
				await frame({"J": i < 12, "R": true})
				P = g.player
				if P.onGround and i > 4:
					break
			continue
		if gusting and g.TR.T.any(func(o): return o.k == "gust" and g.TR.gust_state(o) == 2 and px() > o.x and px() < o.x + o.w):
			await frame({"R": true})
		else:
			await frame({"R": true})
	return "timeout@%d,%d" % [int(await px()), int(P.y)]

## ponte que se solta: corre e pula os vãos
func bridge_run(o: Dictionary):
	var gaps: Array = []
	for gi in o.get("gaps", []):
		gaps.append(o.x + gi * 40.0)
	await frame({"R": true})
	await frame({})
	for it in 600:
		P = g.player
		if not await ok():
			return "state"
		if await px() > o.x + o.w + 40 and P.onGround:
			return true
		var d := {"R": true}
		for gx in gaps:
			if gx - await px() > 0 and gx - await px() < 34 and P.onGround:
				await press("J")
		d["J"] = not P.onGround and P.vy < 0
		await frame(d)
	return "timeout@%d,%d" % [int(await px()), int(P.y)]

## voo: para cada grupo de obstáculos à frente calcula as alturas livres e vai para a mais perto
func _obs_box(o: Dictionary) -> Array:
	match o.k:
		"flock":
			return [o.x - 30, o.x + 90, o.y - 26, o.y + 64]
		"cloud":
			return [o.x + 10, o.x + o.w - 10, o.y + 8, o.y + o.h - 8]
		"spire":
			return [o.x - 44, o.x + 44, float(o.top) + 6, 2000.0]
		"hawk":
			if o.st == "gone":
				return []
			var ty: float = o.get("ty", o.y)
			if o.st in ["warn", "dive", "sweep"]:
				return [o.x - 400, o.x + 40, ty - 18, ty + 18]
			return []
	return []

func _free_spans(boxes: Array, top: float, low: float) -> Array:
	# alturas (hy) livres: a caixa do avião vai de hy-46 a hy-6
	var spans := [[top, low]]
	for bx in boxes:
		var cut0: float = bx[2] + 6 - 14
		var cut1: float = bx[3] + 46 + 14
		var out := []
		for sp in spans:
			if sp[1] < cut0 or sp[0] > cut1:
				out.append(sp)
			else:
				if sp[0] < cut0:
					out.append([sp[0], cut0])
				if sp[1] > cut1:
					out.append([cut1, sp[1]])
		spans = out
	return spans

func fly_plane():
	var VH = g.VH
	for it in 6080:
		if VH.mode != "plane":
			return VH.plane_done
		if VH.phase != "fly":
			await frame()
			continue
		var groups := []
		var list := []
		for o in VH.OBS:
			var bx := await _obs_box(o)
			if bx.is_empty() or bx[1] < VH.hx - 60 or bx[0] > VH.hx + 900:
				continue
			list.append(bx)
		list.sort_custom(func(a, b): return a[0] < b[0])
		for bx in list:
			if groups.is_empty() or bx[0] > groups.back()[0][0] + 120:
				groups.append([bx])
			else:
				groups.back().append(bx)
		var target: float = VH.hy
		if not groups.is_empty():
			var spans := await _free_spans(groups[0], VH.PL.top + 10, VH.PL.low - 10)
			var nxt := []
			if groups.size() > 1:
				nxt = await _free_spans(groups[1], VH.PL.top + 10, VH.PL.low - 10)
			var best := 1e9
			for sp in spans:
				# longe das beiradas da faixa livre (o avião não para na hora: sobra margem)
				var m: float = min(18.0, (sp[1] - sp[0]) * .25)
				for k in 9:
					var y: float = lerpf(sp[0] + m, sp[1] - m, k / 8.0)
					var c: float = abs(y - VH.hy)
					if not nxt.is_empty():
						var dn := 1e9
						for sp2 in nxt:
							dn = min(dn, 0.0 if (y >= sp2[0] and y <= sp2[1]) else min(abs(y - sp2[0]), abs(y - sp2[1])))
						c += dn * 2.0
					if c < best:
						best = c
						target = y
		# onde o avião vai parar se soltar agora (freia com .22 por quadro)
		var pred: float = VH.hy + VH.vy * abs(VH.vy) / .44
		var dd := {}
		if pred > target + 5:
			dd["U"] = true
		elif pred < target - 5:
			dd["S"] = true
		await frame(dd)
	return "não terminou x=%d" % int(VH.hx)

## bola gigante: corre pulando os obstáculos e se abaixa no buraco do chão
func boulder_run(o: Dictionary):
	var obs: Array = []
	for sb in g.SOL:
		if sb.get("bob") and sb.bob != "barricade":
			obs.append(float(sb.x))
	for pit in g.L.pits:
		if pit[0] > o.x and pit[0] < o.end:
			obs.append(float(pit[0]))
	var niche: float = (o.niche[0] + o.niche[1]) / 2.0
	await frame({})
	await frame({"R": true})
	await frame({})
	var jt := 0
	for it in 1800:
		P = g.player
		if not await ok():
			return "state"
		if await px() > niche - 70:
			break
		for ox in obs:
			var ahead: float = ox - (await px() + P.w / 2)
			if ahead > 20 and ahead < 64 and P.onGround and jt <= 0:
				await press("J")
				jt = 14
		jt -= 1
		await frame({"R": true, "J": jt > 0})
	# entra no buraco e se abaixa até a bola passar
	for it in 400:
		P = g.player
		if o.get("passed", false) or o.st in ["break", "done"]:
			break
		if await px() > o.niche[0] + 14 and await px() < o.niche[1] - 14 and P.onGround:
			await frame({"S": true})
		else:
			await frame({"R" if niche > await px() else "L": true})
	await hold({}, 30)
	return o.get("passed", false) or "bola: " + o.st

func _initialize() -> void:
	await _rec_setup(0)
	var with_en := OS.get_cmdline_user_args().has("inimigos")
	if not with_en:
		g.no_coal = true
		for e in g.EN:
			e.dead = 99
	P = g.player
	g.rest_reached.connect(func(n):
		rests.append(n)
		print("REST ", n, " T=", g.T)
		g.running = true)
	await S("pista 1", await walk_to(600))
	await S("pistas=%d" % await n_clues(), await n_clues() == 1)
	await S("abaixa sob as toras", await crawl(870))
	await walk_to(980)
	await S("pedra 1 da escada", await jump_to(1060))
	await S("pedra 2 da escada", await jump_to(1170))
	await S("alto da escada de pedras", await jump_to(1300))
	await walk_to(1570)
	await S("chega à ponte", await walk_to(2065))
	await S("lago de veneno 1: ponte da estaca", await stake_cross(2040))
	await walk_to(2605)
	await S("espinhos da manhã", await cross_spikes(await trap_at("spikes", 2640), 2780))
	await S("vai à escada", await walk_to(2835))
	await S("sobe a escada", await climb_to("U", func(): return P.y + P.h <= 228, 400))
	await walk_to(2930)
	await S("corda", g.INV.has("corda"))
	await S("volta à escada", await walk_to(2835))
	await S("sobe ao telhado", await climb_to("U", func(): return P.ladder == null and P.y < 100, 300))
	await hold({}, 10)
	await S("laranja", await spec("laranja"))
	await S("desce", await climb_to("S", func(): return P.onGround and P.y > 400, 500))
	await walk_to(3200)
	await S("caixa ★", await hop("R", 5))
	await S("empurra a caixa", await until({"R": true}, func(): return g.M.PUSH[0].x >= 3529 and g.M.PUSH[0].y >= 449, 700))
	await S("portão abriu", await until({}, func(): return g.M.GATES[0].open > .85, 200))
	await S("pula a caixa", await jump_to(3670, true))
	await S("sai de trás da paliçada", await walk_to(3780))
	await S("flor-catapulta", await jump_to(3850))
	await walk_to(3855)
	await S("lançado ao galho alto", await until({}, func(): return P.onGround and P.y + P.h <= 232 and P.x > 3990, 400))
	await S("corre", await walk_to(4185))
	await press("J")
	await hold({"J": true, "R": true}, 16)
	await S("agarra cipó", await until({"R": true}, func(): return P.vine != null, 80))
	for i in 500:
		P = g.player
		if P.vine == null:
			break
		var v: Dictionary = P.vine
		await frame({"R": true} if v.om > 0 else {"L": true})
		if v.th > .35 and v.om > 0:
			break
	await press("J")
	await frame()
	await S("pousa", await wait_ground())
	await S("desenho 1", g.DRWS.filter(func(d): return d.got).size() == 1)
	await S("chão rachado", await walk_to(4685))
	await slam_here()
	await S("mergulho quebrou o chão", g.X.broken.has("chao1"))
	await walk_to(4690)
	await S("desce a escada do esconderijo", await climb_to("S", func(): return P.onGround and P.y > 800, 500))
	await hold({}, 60)
	await S("entrou na sala", g.player.y > 800)
	await S("gancho", await walk_to(4920))
	await walk_to(4930)
	await jr(16, "R")
	await S("vermelho", await spec("vermelho"))
	await S("parede falsa", await walk_to(4420))
	await S("sala secreta 1", g.X.found.has("s1"))
	await S("volta à escada", await walk_to(4690))
	await S("sobe com ↑", await climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 500, 500))
	await S("combina corda+gancho", g.try_combine("corda", "gancho") != "")
	await S("arena do javali", await walk_to(5090))
	await S("javali apareceu", g.X.boss_active())
	await S("sobe no galho", await jump_to(4905, true))
	await S("venceu o javali", await boss_fight())
	await walk_to(5290)
	await S("caixa", await jump_to(5345))
	await S("vai ao barranco", await walk_to(5590))
	await use()
	await S("corda presa", g.LOCKS[0].done)
	await S("vai à corda", await walk_to(5618))
	await S("sobe a corda", await climb_to("U", func(): return P.ladder == null and P.y < 100, 500))
	await S("rocha rachada", await walk_to(5680))
	await press("G")
	await hold({}, 26)
	await S("golpe quebrou a rocha", g.X.broken.has("rock1"))
	await S("cachorro amarrado", await walk_to(5780))
	await use()
	await S("Pipoca solto", g.X.dog_free())
	await S("portão alto", await walk_to(5860))
	await hold({}, 20)
	await press("D")
	await frame()
	await S("controla o Pipoca", g.M.ctrl)
	await S("Pipoca pela portinhola até a placa", await walk_to(5956))
	await S("portão abriu", await until({}, func(): return g.M.GATES[1].open > .85, 200))
	await press("D")
	await frame()
	await S("de volta ao Tomé", not g.M.ctrl and g.X.DOG.st == "stay")
	await S("toca", await walk_to(6020))
	await use()
	await S("Pipoca buscou o desenho", await until({}, func(): return g.DRWS[2].got, 700))
	await S("moita: pista 2 e amarelo", await walk_to(6210))
	await S("pistas=2 amarelo", await n_clues() == 2 and await spec("amarelo"))
	await S("desce do platô", await walk_to(6420))
	await S("lago de veneno 2: ponte da estaca", await stake_cross(6480))
	await walk_to(6940)
	await S("fogueira grande 1", rests.has(1))
	await walk_to(7050)
	await S("rasteja para a fenda", await crawl(7270))
	await S("sobe a fenda pulando nas paredes", await crevice_climb())
	await S("topo da fenda", await walk_to(7390))
	await walk_to(8340)
	await S("galho 1 das copas", await jump_to(8490))
	await walk_to(8545)
	await S("galho 2", await jump_to(8700, true))
	await walk_to(8745)
	await S("galho rachado 1", await jump_to(8875))
	await S("galho 3", await jump_to(9040, true))
	await walk_to(9105)
	await S("flor das copas", await jump_to(9200))
	await walk_to(9220)
	await S("lançado ao galho alto", await until({}, func(): return P.onGround and P.y + P.h <= -250, 400))
	await walk_to(9515)
	await S("desce ao galho 4", await jump_to(9670))
	await walk_to(9730)
	await S("galho rachado 2", await jump_to(9845))
	await S("galho 5", await jump_to(10010, true))
	await S("desce ao chão", await walk_to(10140))
	await walk_to(10240)
	await S("tronco-pêndulo", await cross_swing(await trap_at("swing", 10450), 10730))
	await S("passou o tronco", P.hp == 5)
	await walk_to(10730)
	await hold({}, 20)
	await press("D")
	await frame()
	await S("Pipoca no portão da tarde", g.M.ctrl)
	await S("Pipoca até a placa", await walk_to(10910))
	await S("portão 4 abriu", await until({}, func(): return g.M.GATES[2].open > .85, 200))
	await press("D")
	await frame()
	await S("Tomé passa o portão 4", await walk_to(10980))
	await walk_to(11025)
	await S("sobe a torre", await climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 64, 500))
	await walk_to(11358)
	await S("desce a torre", await climb_to("S", func(): return P.onGround and P.y > 400, 500))
	await walk_to(11450)
	await S("caixa no buraco da placa 5", await until({"R": true}, func(): return g.M.PUSH[4].x >= 11789 and g.M.PUSH[4].y >= 449, 900))
	await S("portão 5 abriu", await until({}, func(): return g.M.GATES[3].open > .85, 200))
	await S("pula a caixa 5", await jump_to(11825))
	await S("passa o portão 5", await walk_to(12040))
	await walk_to(12350)
	await walk_to(12420)
	await S("armadura", await jump_to(12479))
	await S("beira da ilha", await walk_to(12575))
	await S("vitória-régia 1", await jump_to(12676))
	await S("vr 2", await jump_to(12816))
	await S("vr 3", await jump_to(12946))
	await S("tronco molhado", await jump_to(13090))
	await S("ponta do tronco", await walk_to(13200))
	await S("ilha 2", await jump_to(13330))
	await S("lama até o poço", await walk_to(13515))
	await S("cai no poço", await until({"R": true}, func(): return P.ladder != null or P.y > 700, 200))
	await S("desce a escada", await climb_to("S", func(): return P.onGround and P.y > 800, 400))
	await S("gruta", await walk_to(13750))
	await S("engrenagem e pista 3", g.INV.has("engrenagem") and await n_clues() == 3)
	await S("pula na água", await until({"L": true}, func(): return P.swim, 400))
	await S("mergulha", await until({"L": true, "S": true}, func(): return px() < 13240 and P.y > 990, 400))
	await S("túnel", await until({"L": true}, func(): return px() < 13150, 300))
	await S("bolsão de ar", await until({"U": true}, func(): return P.y < 962, 300))
	await press("J")
	await hold({"J": true, "L": true}, 14)
	await S("borda", await wait_ground({"L": true}))
	await S("sala secreta 2", g.X.found.has("s2"))
	await hold({"R": true}, 30)
	await S("volta mergulhando", await until({"R": true, "S": true}, func(): return px() > 13190 and P.y > 1000, 400))
	await S("sai do túnel", await until({"R": true}, func(): return px() > 13380, 400))
	await S("sobe", await until({"U": true, "R": true}, func(): return P.y < 912, 300))
	await press("J")
	await hold({"J": true, "R": true}, 16)
	await S("fora da água", await wait_ground({"R": true}))
	await S("fôlego ok", g.lives >= 3)
	await walk_to(13750)
	await S("volta à escada", await walk_to(13550))
	await S("sobe", await climb_to("U", func(): return P.y + P.h <= 504, 400))
	await S("sai do poço", await jump_to(13640))
	await walk_to(13690)
	await S("pula o brejo", await jump_to(13840))
	await S("gavião-rei apareceu", await until({"R": true}, func(): return g.K.HAWK.active, 300))
	await S("venceu o gavião-rei", await hawk_fight())
	await S("ilha 3", await walk_to(15090))
	await S("fogueira grande 2", rests.has(2))
	await S("sobe a rede", await climb_to("U", func(): return P.ladder == null and P.y + P.h <= 152, 400))
	await S("galho: manivela + verde", await walk_to(15220))
	await S("manivela_q", g.INV.has("manivela_q") and await spec("verde"))
	await walk_to(15110)
	await S("desce", await climb_to("S", func(): return P.onGround and P.y > 400, 500))
	await S("combina engrenagem+manivela", g.try_combine("engrenagem", "manivela_q") != "")
	await S("comporta", await walk_to(15230))
	await S("botão vira manivela na comporta", g.use_mode() == "crank")
	for k in 6:
		await use()
		await hold({}, 6)
	await S("escoa", await until({}, func(): return g.SWAMP.filter(func(s): return s.get("id") == "canal")[0].y >= 639, 400))
	await S("passa a comporta", await walk_to(15318))
	await S("pedra 1", await jump_to(15410))
	await S("pedra 2", await jump_to(15550))
	await walk_to(15580)
	# anda até a beira e solta: cai no vão (segurando → até o fim, ele agarraria a beirada da outra pedra)
	await hold({"R": true}, 9)
	await S("pedrinha (pista 4)", await until({}, func(): return P.onGround and P.y > 520, 100))
	await S("pistas=4", await n_clues() >= 4)
	await S("pedra 3", await jump_to(15690))
	await S("margem do pântano", await jump_to(15780))
	await S("abaixado sob a colmeia 2", await crawl(15955))
	await S("colmeia 2 quieta", await trap_at("hive", 15905).st == "idle")
	await walk_to(16035)
	await S("mergulha", await until({"R": true, "S": true}, func(): return px() > 16190 and P.y > 600, 300))
	await S("atravessa o túnel d'água", await until({"R": true}, func(): return px() > 17360, 1200))
	await S("respirou nas bolhas", g.lives >= 3)
	await S("sobe", await until({"U": true, "R": true}, func(): return P.y < 515, 300))
	await S("sai da água", await jump_to(17550))
	await walk_to(17720)
	await S("régia 1", await jump_to(17846))
	await S("régia 2", await jump_to(17996))
	await S("régia 3", await jump_to(18146))
	await S("tronco boiando", await jump_to(18310))
	await walk_to(18420)
	await S("régia 4", await jump_to(18566))
	await S("régia 5", await jump_to(18716))
	await S("régia 6", await jump_to(18866))
	await S("margem do lamaçal", await jump_to(18990))
	await walk_to(19070)
	await S("cipó 1", await grab_vine(g.VINES[1]))
	await S("cipó 2", await vine_hop(g.VINES[2]))
	await S("cipó 3", await vine_hop(g.VINES[3]))
	await S("outra margem", await vine_hop(null))
	await S("vivo no lamaçal", g.lives >= 3 and await px() > 19990)
	await walk_to(20430)
	await S("cipó da ribanceira", await grab_vine(g.VINES[4]))
	await S("agarra a corda", await _to_bar())
	await S("anda pendurado", await until({"R": true}, func(): return px() > 21480, 600))
	await press("J")
	await frame()
	await S("solta na margem", await wait_ground())
	await walk_to(21590)
	await S("abaixado sob a colmeia 1", await crawl(21705))
	await S("colmeia 1 quieta", await trap_at("hive", 21655).st == "idle")
	await walk_to(21775)
	await S("mergulho 2", await until({"R": true, "S": true}, func(): return px() > 22040 and P.y > 600, 300))
	await S("túnel d'água 2", await until({"R": true}, func(): return px() > 23060, 1200))
	await S("sobe do mergulho 2", await until({"U": true, "R": true}, func(): return P.y < 515, 300))
	await S("sai do mergulho 2", await jump_to(23230))
	await walk_to(23290)
	await S("abaixado sob a colmeia 3", await crawl(23408))
	await S("colmeia 3 quieta", await trap_at("hive", 23358).st == "idle")
	await S("lago", await walk_to(23460))
	for i in 600:
		P = g.player
		if g.NT.helmet and g.NT.harpoon:
			break
		var tx: float = 23840.0 if not g.NT.harpoon else 23720.0
		await frame({"R": await px() < tx - 4, "L": await px() > tx + 4, "S": P.y < 836, "U": P.y > 846})
	await S("capacete e arpão", g.NT.helmet and g.NT.harpoon)
	await S("bagre-rei apareceu", await until({"R": true}, func(): return g.K.FISH.active, 300))
	await S("venceu o bagre-rei", await fish_fight())
	await S("corrente de bolhas", await until({"R": true}, func(): return px() > 25150, 600))
	await S("subiu na corrente", await until({"R": true}, func(): return P.onGround and P.y < 480, 400))
	await S("margem do rio", await walk_to(25480))
	await use()
	await S("subiu na jangada", g.VH.mode == "raft")
	await S("corredeira", await ride_raft())
	await S("jangada sem virar", g.VH.tries == 0)
	await S("fogueira grande 3", await walk_to(32820) and rests.has(3))
	await walk_to(33190)
	await S("pula a pedra", await jump_to(33320, true))
	await S("empurra a bola de neve", await until({"R": true}, func(): return g.NT.SNOWB[0].x + g.NT.SNOWB[0].w >= 33687, 900))
	await S("bola cresceu", g.NT.SNOWB[0].w > 75)
	await S("sobe na bola", await jump_to(33610))
	await S("paredão", await jump_to(33750, true))
	await S("gelo", await walk_to(34340))
	await walk_to(34510)
	await S("bola rolando 1", await dodge_roll(34770, 0))
	await S("bola rolando 2", await dodge_roll(35290, 1))
	await walk_to(35720)
	await S("pula o buraco de gelo", await jump_to(36005, true))
	await S("pedra da bola 2", await jump_to(36115))
	await walk_to(36118)
	await S("empurra a bola 3", await until({"R": true}, func(): return g.NT.SNOWB[2].x + g.NT.SNOWB[2].w >= 36247, 900))
	await S("sobe na bola 3", await jump_to(36220))
	await S("2º paredão", await jump_to(36290, true))
	await walk_to(36385)
	await S("vila", await walk_to(37040))
	await walk_to(37240)
	await S("desce na caverna de gelo", await climb_to("S", func(): return P.onGround and P.y > 800, 500))
	await walk_to(37650)
	await S("bloco de gelo 1", await jump_to(37730))
	await S("desce do bloco 1", await jump_to(37860))
	await walk_to(38070)
	await S("bloco de gelo 2", await jump_to(38150))
	await S("desce do bloco 2", await jump_to(38280))
	await walk_to(38750)
	await S("sobe da caverna", await climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	await walk_to(38900)
	await walk_to(39090)
	await S("carroça", await jump_to(39245))
	await S("empurra a bola 2", await until({"R": true}, func(): return g.NT.HOLES[0].filled, 900))
	await S("cavalo", await walk_to(39900))
	await use()
	await S("cavalgada começou", await until({}, func(): return g.RD.riding, 400))
	await S("cavalgada", await ride())
	await S("sem tropeço", g.RD.tries == 0)
	await S("toca do urso", await walk_to(50400))
	await S("urso acordou", g.K.BEAR.st != "wait")
	await S("Urso-Rei: fuga pela fresta e coroa", await bear_fight())
	await S("urso desistiu", await until({}, func(): return g.K.BEAR.done, 600))
	await S("coroa do urso na coleção", root.get_node("Save").getv("gallery", "crown_urso", false))
	# o trenó parte sozinho quando o Tomé chega nele
	await S("chega no trenó e parte sozinho", await until({"R": true}, func(): return g.VH.mode == "sled", 600))
	await S("trenó chegou", await sled_drive())
	await S("fogueira grande 4", await walk_to(53090) and rests.has(4))
	await S("subida da montanha", await climb_gusts(55630))
	await S("ponte de cordas", await bridge_run(await trap_at("bridge", 55660)))
	await S("pista do avião: embarca sozinho", await until({"R": true}, func(): return g.VH.mode == "plane", 1500))
	await S("decolou", g.VH.mode == "plane")
	await S("voo", await fly_plane())
	await S("avião sem rodopiar", g.VH.tries == 0)
	await S("fogueira grande 5", await walk_to(64280) and rests.has(5))
	await S("margem", await walk_to(64470))
	var axe: Dictionary = g.TR.by_kind("axe")[0]
	await walk_to(64460)
	# pula a lâmina quando ela está indo para o lado de lá
	await S("espera o machado", await until({}, func(): g.TR.axe_blade(axe); return axe.ang > .35, 300))
	await S("pula a lâmina do machado", await jump_to(64800, true))
	await S("noite", await walk_to(64725))
	await S("espaço depois do machado", await walk_to(64910))
	await S("caixa", await jump_to(64975))
	if await px() < 65000:
		await jump_to(65040, true)
	await walk_to(65245)
	await S("cogumelo saltador 1", await bounce_to(65295))
	await S("chapéu alto", P.y + P.h <= 232)
	await S("cogumelo saltador 2 (gigante laranja)", await bounce_to(65755))
	await S("chapéu mais alto", P.y + P.h <= 152)
	await S("desce de chapéu", await jump_to(66265))
	await S("fim do bosque", await jump_to(66450))
	await S("lago de veneno 3: ponte da estaca", await stake_cross(67100))
	await walk_to(67760)
	await S("desce no poço da mina", await climb_to("S", func(): return P.onGround and P.y > 820, 500))
	await walk_to(67825)
	await S("espinhos do poço", await cross_spikes(await trap_at("spikes", 67850), 67980))
	await S("viga do poço", await crawl(68120))
	await walk_to(68270)
	await S("carrinho do poço", await jump_to(68460))
	await walk_to(68675)
	await S("tábua do poço 1", await jump_to(68740))
	await S("tábua do poço 2", await jump_to(68825))
	await S("depois das tábuas", await jump_to(68920))
	await walk_to(69600)
	await S("viga 2 do poço", await crawl(69750))
	await walk_to(69970)
	await S("sobe do poço", await climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	await walk_to(70120)
	await S("porta do galpão", await walk_to(70370))
	await hold({}, 20)
	await press("D")
	await frame()
	await S("Pipoca", g.M.ctrl)
	await S("Pipoca entra pela portinhola", await walk_to(70600))
	await S("óleo", g.INV.has("oleo"))
	await S("Pipoca sai", await walk_to(70370))
	await press("D")
	await frame()
	await S("Tomé", not g.M.ctrl)
	await S("telhado do galpão", await jump_to(70445, true))
	await S("desce do telhado", await walk_to(70740))
	await S("escada da coruja", await walk_to(71005))
	await S("sobe", await climb_to("U", func(): return P.ladder == null and P.onGround and P.y + P.h <= 42, 500))
	await S("pavio", await walk_to(71040))
	await S("azul", await walk_to(70910))
	await S("pavio+azul", g.INV.has("pavio") and await spec("azul"))
	await walk_to(71005)
	await S("desce", await climb_to("S", func(): return P.onGround and P.y > 400, 600))
	await S("combina óleo+pavio", g.try_combine("oleo", "pavio") != "")
	await S("laje do X", await walk_to(70810))
	await use()
	await S("quebrou a laje", g.X.broken.has("slab"))
	await S("desce na câmara", await climb_to("S", func(): return P.onGround and P.y > 800, 500))
	var rg = await walk_to(70498)
	await S("lápis dourado %s" % str(rg), g.X.GOLD.got)
	await walk_to(70885)
	await S("plataforma 1", await jump_to(70895) is bool and P.y + P.h < 850)
	await S("pl. 2", await jump_to(70960) is bool and P.y + P.h < 795)
	await S("pl. 3", await jump_to(70888) is bool and P.y + P.h < 740)
	await S("sala secreta 3", g.X.found.has("s3"))
	await S("desce", await until({"L": true}, func(): return P.onGround and P.y > 850, 300))
	await S("escada da laje", await walk_to(70810))
	await S("sobe", await climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	await walk_to(71005)
	await S("rede de caçador", await walk_to(71070))
	await press("D")
	await frame()
	await S("Pipoca (rede)", g.M.ctrl)
	await S("Pipoca no poste", await walk_to(71065))
	await press("A")
	await hold({}, 8)
	await S("rede caiu", g.TR.by_kind("net")[0].st == "down")
	await press("D")
	await frame()
	await S("Tomé de novo", not g.M.ctrl)
	await S("jaula prendeu", await until({"R": true}, func(): return g.TR.trapped != null, 300))
	await hold({}, 30)
	await press("D")
	await frame()
	await S("Pipoca (jaula)", g.M.ctrl)
	await S("Pipoca no poste da jaula", await walk_to(71162))
	await press("A")
	await hold({}, 8)
	await S("jaula abriu", g.TR.trapped == null)
	await press("D")
	await frame()
	await S("Tomé livre", not g.M.ctrl)
	await S("cogumelo", await until({"R": true}, func(): return P.vy < -15, 300))
	var dj := false
	for i in 200:
		P = g.player
		if not dj and P.vy > -1:
			await press("J")
			dj = true
		await frame({"R": await px() < 71370, "J": dj and i < 60})
		P = g.player
		if dj and P.onGround:
			break
	await S("quica + pulo duplo", g.player.y < 130)
	await S("desenho 2", await walk_to(71440))
	await walk_to(71540)
	await S("desce do galho", await until({}, func(): return P.onGround and P.y > 400, 200))
	await S("entrada do túnel", await walk_to(71550))
	await use()
	await S("barreira aberta", g.LOCKS[2].done)
	await walk_to(71725)
	await use()
	await walk_to(71785)
	await use()
	await S("portão das alavancas", await until({}, func(): return g.EV.GATE.lift >= g.EV.GATE.h - 8, 200))
	await S("passa o portão (sem abaixar)", await walk_to(72105))
	await S("tábua podre", await jump_to(72210))
	await S("depois da tábua", await jump_to(72360))
	await walk_to(72400)
	await S("carrinho do túnel", await jump_to(72600))
	await walk_to(72735)
	await S("tábuas 1", await jump_to(72810))
	await S("tábuas 2", await jump_to(72900))
	await S("fim das tábuas", await jump_to(73000))
	await walk_to(73040)
	await S("viga 2 do túnel", await crawl(73190))
	await S("chega na manivela", await walk_to(73260))
	for k in 6:
		await use()
		await hold({}, 6)
	await S("porta da manivela abriu", g.CRANKS[0].done)
	await S("túnel da pedra", await walk_to(73650))
	var bol: Dictionary = await trap_at("boulder", 73500)
	await S("a pedra caiu", await until({"R": true}, func(): return bol.st != "idle", 200))
	await S("fuga da pedra", await boulder_run(bol))
	await S("sem ser atropelado", P.hp == 5)
	await until({"S": true}, func(): return bol.st in ["break", "done"], 600)
	await S("sai do buraco", await jump_to(77140))
	await S("túnel", await walk_to(77590))
	await S("rasteja", await crawl(77750))
	await S("escada do nicho", await walk_to(77950))
	await S("desce", await climb_to("S", func(): return P.onGround and P.y > 700, 500))
	await S("roxo no nicho", await walk_to(77760) and await spec("roxo"))
	await walk_to(77980)
	await S("rasteja divisória", await crawl(78045))
	await S("pistas=6 (crachá)", await n_clues() == 6)
	await S("vilão ainda não", not g.VIL.go)
	await walk_to(78080)
	await S("sobe pela saída", await climb_to("U", func(): return P.ladder == null and P.onGround and P.y < 480, 500))
	await S("vilão foge", await walk_to(78300))
	await S("perseguição começou", g.VIL.go)
	await walk_to(78630)
	await S("1º buraco", await jump_to(78800))
	await walk_to(78920)
	await S("desliza sob a viga", await crawl(79050))
	await walk_to(79285)
	await S("2º buraco", await jump_to(79490, true))
	await walk_to(79550)
	await S("pula o carrinho parado", await jump_to(79700, true))
	await walk_to(79770)
	await S("tábua 1", await jump_to(79860))
	await S("tábua 2", await jump_to(79990))
	await S("tábua 3", await jump_to(80120))
	await S("chão", await jump_to(80230))
	await walk_to(80370)
	await S("viga 2", await crawl(80500))
	await S("vilão entrou na mina", await until({"R": true}, func(): return g.VIL.gone or px() > 80800, 900))
	await S("vilão entrou", await until({}, func(): return g.VIL.gone, 400))
	await walk_to(80915)
	var sa = await until({}, func(): return not g.running, 300)
	await S("saída", sa is String and sa == "state")
	var nd: int = g.DRWS.filter(func(d): return d.got).size()
	await S("segredos %d/3 dourado=%s chefe=%s" % [g.X.found.size(), str(g.X.GOLD.got), str(g.X.BOSS.done)], g.X.found.size() == 3 and g.X.GOLD.got and g.X.BOSS.done)
	print("FIM T=", g.T)
	await S("final: pistas=%d esp=%d des=%d lápis=%d/%d tempo=%ds" % [await n_clues(), g.SPECGOT.size(), nd, g.STATS.pen, g.STATS.penTotal, g.time_left / 60], await n_clues() == 6 and g.SPECGOT.size() == 6 and nd == 3)
	for l in log_lines:
		print(l)
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------- gravação (gerado por mkrec.py)
var main
var rec_steps := 0
var rec_acc := 0.0
var rec_n := 0
var posf: FileAccess
var REC_EVERY := int(OS.get_environment("REC_EVERY")) if OS.get_environment("REC_EVERY") != "" else 2600
var REC_LEN := int(OS.get_environment("REC_LEN")) if OS.get_environment("REC_LEN") != "" else 330
var REC_SKIP := int(OS.get_environment("REC_SKIP")) if OS.get_environment("REC_SKIP") != "" else 0

func _rec_setup(lvl: int) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var sv = root.get_node("Save")
	for id in ["cipo", "mergulho", "neve", "pipoca", "picareta", "cavalo", "mina", "toxico", "javali", "gaviao", "bagre", "urso", "vargas", "bola", "aviao", "jangada", "colmeia", "carrinho", "moinho", "telhados"]:
		sv.setv("comic", id, true)
	sv.setv("opt", "tut_asked", true)
	main.start_level(false, lvl)
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
		await process_frame
	for c in main.ui_layer.get_children():
		if c.has_method("_end"):
			c._end()
	await process_frame
	if main.panel and main.panel.has_meta("ok"):
		main.panel.get_meta("ok").call()
	g = main.game
	main.set_physics_process(false)
	main.hud_layer.visible = false
	# o robô joga sozinho: nada de telas do main (pista, fogueira, resultados, Isis...) por cima do jogo
	for sg in g.get_signal_list():
		for cn in g.get_signal_connection_list(sg.name):
			var cb: Callable = cn.callable
			if cb.get_object() == main:
				g.disconnect(sg.name, cb)
	main.rec_zoom = float(OS.get_environment("REC_ZOOM")) if OS.get_environment("REC_ZOOM") != "" else 1.3
	main.cam_zoom = main.rec_zoom
	g.lives = 99
	g.auto_cine = true
	posf = FileAccess.open(OS.get_environment("REC_OUT") + ".pos", FileAccess.WRITE)

func _rstep() -> void:
	Interp.restore()
	g.step()
	rec_steps += 1
	var mx := OS.get_environment("REC_MAXX")
	if mx != "" and g.player.x > float(mx):
		print("REC_MAXX: fim em x=%d" % int(g.player.x))
		if posf:
			posf.close()
		quit()
		await process_frame
		return
	if rec_steps % 3000 == 0 and OS.get_environment("REC_DBG") != "":
		print("step %d x=%d y=%d cine=%s st=%s boss=%s" % [rec_steps, int(g.player.x), int(g.player.y), str(g.CINE.keys()), str(main.state), str(g.X.BOSS.get("st", ""))])
	var ph: int = (rec_steps - REC_SKIP) % REC_EVERY
	if rec_steps >= REC_SKIP and ph < REC_LEN:
		rec_acc += 30.0 / 44.0
		if rec_acc >= 1.0:
			rec_acc -= 1.0
			g.ip_div = 1
			g.ip_phase = 1
			g.flash_t = 0
			main.hud_layer.visible = false
			for c in main.ui_layer.get_children():
				if c.has_method("_end"):
					c._end()
			var vs: Vector2 = main.get_viewport().get_visible_rect().size
			var z: float = g.camera.zoom.x
			var c0: Vector2 = g.camera.position
			var u: float = (g.player.x + 12 - c0.x) * z / vs.x
			var v: float = (g.player.y + 20 - c0.y) * z / vs.y
			if posf:
				posf.store_line("%d %d %.4f %.4f %d %d" % [rec_n, int((rec_steps - REC_SKIP) / REC_EVERY), u, v, int(g.player.x), int(g.player.y)])
			rec_n += 1
			await process_frame
